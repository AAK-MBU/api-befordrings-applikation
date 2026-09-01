import { env as publicEnv } from "$env/dynamic/public";

import type { CurrentUser } from "$lib/auth";

import { getApiBaseUrl } from "./backendApi";


export type SessionProbe =
  | { status: "authenticated"; user: CurrentUser }
  | { status: "anonymous" }
  | { status: "unavailable"; reason: string };


/**
 * Browser-facing URL that starts the OIDC flow.
 *
 * The backend mounts create_oidc_router() at /auth/login and runs with
 * root_path="/api", so behind the edge reverse proxy the browser reaches it at
 * /api/auth/login. Deployments without that proxy — docker-compose_local.yml
 * publishes the API directly on :8000 — must set PUBLIC_OIDC_LOGIN_URL to an
 * absolute URL instead.
 */
export function getLoginUrl() {
  return publicEnv.PUBLIC_OIDC_LOGIN_URL || "/api/auth/login";
}


/**
 * Browser-facing URL that ends the session.
 *
 * Mirrors getLoginUrl: create_oidc_router() mounts /auth/logout next to
 * /auth/login, so the same prefix rules apply.
 */
export function getLogoutUrl() {
  return publicEnv.PUBLIC_OIDC_LOGOUT_URL || "/api/auth/logout";
}


/**
 * Ask the backend who the *browser* is, by replaying its cookie against /me.
 *
 * Deliberately sends no X-API-Key: a shared key resolves on the backend as an
 * automated caller, and the question here is specifically whether this browser
 * holds an OIDC session of its own.
 *
 * Uses the global fetch rather than event.fetch on purpose — the backend is a
 * different origin, and SvelteKit's fetch applies its own credential rules to
 * cross-origin requests. Here the cookie is passed explicitly and must arrive
 * exactly as given.
 */
export async function probeSession(cookie: string | null): Promise<SessionProbe> {
  // Without a cookie there cannot be a session, so skip the round-trip.
  if (!cookie) {
    return { status: "anonymous" };
  }

  // Outside the try: a missing PUBLIC_API_BASE_URL is a deployment error and
  // should surface as such, not be folded into "backend is down".
  const meUrl = `${getApiBaseUrl()}/me`;

  let response: Response;

  try {
    response = await fetch(meUrl, { headers: { cookie } });
  } catch (cause) {
    return { status: "unavailable", reason: `GET ${meUrl} failed: ${cause}` };
  }

  if (response.status === 401) {
    return { status: "anonymous" };
  }

  if (!response.ok) {
    return {
      status: "unavailable",
      reason: `GET ${meUrl} returned ${response.status}`
    };
  }

  return { status: "authenticated", user: (await response.json()) as CurrentUser };
}


/**
 * Cookie holding where to send the user once they come back authenticated.
 *
 * The backend's create_oidc_router() takes post_login_redirect as a fixed
 * string ("/" here), so it cannot carry a per-request destination. Stashing the
 * target before handing off to the IdP lets /callback restore it on the way
 * back, without needing a backend or library change.
 */
export const RETURN_TO_COOKIE = "oidc_return_to";

// Long enough to finish a login (including an MFA prompt), short enough that a
// stale destination does not resurface days later.
const RETURN_TO_MAX_AGE_SECONDS = 900;


/**
 * Serialize the Set-Cookie header that stores the post-login destination.
 *
 * SameSite=Lax is required: the user returns from the IdP via a top-level
 * cross-site navigation, and a Strict cookie would not be sent.
 *
 * Secure is set only for https. Guessing wrong in that direction is the safe
 * failure: a missing Secure flag still works, whereas Secure on a plain-http
 * deployment would silently drop the cookie and break deep links.
 */
export function serializeReturnTo(target: string, secure: boolean) {
  const attributes = [
    `${RETURN_TO_COOKIE}=${encodeURIComponent(target)}`,
    "Path=/",
    "HttpOnly",
    "SameSite=Lax",
    `Max-Age=${RETURN_TO_MAX_AGE_SECONDS}`
  ];

  if (secure) {
    attributes.push("Secure");
  }

  return attributes.join("; ");
}


/** Set-Cookie header that clears the destination once it has been used. */
export function serializeReturnToCleared() {
  return `${RETURN_TO_COOKIE}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0`;
}


/**
 * Validate a stored destination before redirecting to it.
 *
 * Cookies are client-controlled, so this is what stops the login flow being
 * turned into an open redirect. Only same-origin absolute paths pass:
 *
 *   - must start with a single "/" — "//evil.example" is protocol-relative and
 *     would leave the site
 *   - no backslashes — some browsers normalize "\\" to "/", so "/\\evil.example"
 *     is another way to write a protocol-relative URL
 *   - no control characters — CR/LF would be header injection
 */
export function safeReturnTo(target: string | undefined): string | null {
  if (!target) {
    return null;
  }

  if (!target.startsWith("/") || target.startsWith("//")) {
    return null;
  }

  if (target.includes("\\")) {
    return null;
  }

  if (/[\u0000-\u001f\u007f]/.test(target)) {
    return null;
  }

  return target;
}


/**
 * Cookie marking that we just sent this browser through the login flow.
 *
 * Guards against the classic auth redirect loop: if the backend's session
 * cookie never sticks — wrong SameSite, a Secure flag on a plain-http
 * deployment, a proxy dropping Set-Cookie — then /me keeps answering 401, the
 * guard keeps redirecting, and the browser bounces forever with no clue why.
 *
 * Coming back still anonymous within this window means the round trip failed,
 * so the guard reports that instead of retrying.
 */
export const LOGIN_ATTEMPT_COOKIE = "oidc_login_attempt";

// Comfortably longer than a redirect round trip, far shorter than a real login
// (which ends authenticated anyway, so it never reaches the breaker).
const LOGIN_ATTEMPT_MAX_AGE_SECONDS = 60;


export function serializeLoginAttempt(secure: boolean) {
  const attributes = [
    `${LOGIN_ATTEMPT_COOKIE}=1`,
    "Path=/",
    "HttpOnly",
    "SameSite=Lax",
    `Max-Age=${LOGIN_ATTEMPT_MAX_AGE_SECONDS}`
  ];

  if (secure) {
    attributes.push("Secure");
  }

  return attributes.join("; ");
}


/**
 * Clear the marker so a manual reload retries the login rather than sticking
 * on the diagnostic.
 */
export function serializeLoginAttemptCleared() {
  return `${LOGIN_ATTEMPT_COOKIE}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0`;
}


export type ForwardedAuth = {
  response: Response;
  headers: Headers;
};


/**
 * Who is on the other end of a proxied request.
 *
 * Without this the backend only ever sees the frontend container, so every
 * audit row for a login would record this service's address rather than the
 * person's.
 */
export type CallerDetails = {
  ip: string;
  userAgent: string | null;
};


/**
 * Headers for a proxied auth call, identifying the browser behind it.
 *
 * x-forwarded-for is *set*, not appended. Anything already in the incoming
 * header is client-supplied and therefore worthless as evidence, and the
 * backend reads the first entry — so appending would leave a spoofed value
 * winning. SvelteKit's getClientAddress() is the most trustworthy address
 * available here.
 */
function callerHeaders(cookie: string | null, caller?: CallerDetails) {
  const headers = new Headers({ cookie: cookie ?? "" });

  if (caller) {
    headers.set("x-forwarded-for", caller.ip);

    if (caller.userAgent) {
      headers.set("user-agent", caller.userAgent);
    }
  }

  return headers;
}


/**
 * Forward a request to one of the backend's /auth/* endpoints.
 *
 * The OIDC endpoints are proxied same-origin rather than pointing the browser
 * straight at the API, because the session cookie the backend sets has to come
 * back on the app's own origin. Sending the browser to the API host directly
 * would scope that cookie to the API domain, where the guard's /me probe — which
 * replays the *app* origin's cookies — would never see it, and every login would
 * appear to succeed and then leave the user anonymous.
 *
 * Returns the raw response alongside a half-built browser-facing header set, so
 * callers can adjust before finishing with relayAuthResponse.
 */
export async function forwardAuthRequest(
  path: string,
  search: string,
  cookie: string | null,
  caller?: CallerDetails
): Promise<ForwardedAuth> {
  const response = await fetch(`${getApiBaseUrl()}/auth/${path}${search}`, {
    headers: callerHeaders(cookie, caller),
    redirect: "manual"
  });

  const headers = new Headers();

  // getSetCookie(), not get(): the backend may set more than one cookie, and
  // get() would fold them into a single comma-joined value that no browser
  // parses back into the original pairs.
  for (const setCookie of response.headers.getSetCookie()) {
    headers.append("set-cookie", setCookie);
  }

  return { response, headers };
}


/**
 * Finish an auth passthrough.
 *
 * On failure the backend explains itself in the body (FastAPI's {"detail":
 * ...}, e.g. "no pending login state in session"). Dropping it would leave a
 * blank page as the only symptom, so pass it through.
 */
export async function relayAuthResponse({ response, headers }: ForwardedAuth) {
  if (response.status >= 400) {
    const contentType = response.headers.get("content-type");

    if (contentType) {
      headers.set("content-type", contentType);
    }

    return new Response(await response.text(), { status: response.status, headers });
  }

  return new Response(null, { status: response.status, headers });
}
