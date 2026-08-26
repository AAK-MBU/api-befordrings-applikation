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
