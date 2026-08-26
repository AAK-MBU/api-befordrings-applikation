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
 * Ask the backend who the *browser* is, by replaying its cookie against /me.
 *
 * Deliberately does not go through backendApiFetch: that stamps the shared
 * X-API-Key, and the question here is specifically whether this browser holds
 * an OIDC session of its own.
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
