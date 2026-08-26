import {
  forwardAuthRequest,
  relayAuthResponse,
  serializeLoginAttemptCleared,
  serializeReturnToCleared
} from "$lib/server/auth";

import type { RequestHandler } from "./$types";


/**
 * Same-origin passthrough to the backend's OIDC endpoints (/auth/login,
 * /auth/logout, and /auth/callback where it is registered as such).
 *
 * The backend runs with root_path="/api" and expects an edge reverse proxy to
 * forward /api to it. Where that proxy exists this route never sees a request;
 * where it does not — local compose publishes the API on its own port instead —
 * this makes the same URLs work anyway. Either way the browser only ever talks
 * to the app's own origin, which is what keeps the session cookie usable.
 *
 * hooks.server.ts leaves /api/auth unguarded: these are the endpoints that
 * establish a session, so requiring one would deadlock the flow.
 *
 * Only GET is proxied — create_oidc_router() defines no other methods.
 */
export const GET: RequestHandler = async ({ params, url, request }) => {
  const forwarded = await forwardAuthRequest(
    params.path,
    url.search,
    request.headers.get("cookie")
  );

  const location = forwarded.response.headers.get("location");

  if (location) {
    forwarded.headers.set("location", location);
  }

  // Logging out makes the browser deliberately anonymous, which retires both of
  // the guard's in-flight login markers.
  //
  // The login-attempt marker matters most: it means "we just sent this browser
  // to the IdP", and the guard reports a broken login when it sees that marker
  // alongside no session. A successful login leaves it set for the rest of its
  // 60s window on purpose — clearing it on the way back through /callback would
  // disarm the very case it exists for, because the failure it detects is the
  // *backend's* Set-Cookie not reaching the browser, while this app's own
  // Set-Cookie would still arrive. Logging out is the one transition to
  // anonymous that is expected, so the marker is stale rather than diagnostic:
  // left in place, the next page load reports a login failure that never
  // happened.
  if (params.path === "logout") {
    forwarded.headers.append("set-cookie", serializeLoginAttemptCleared());
    forwarded.headers.append("set-cookie", serializeReturnToCleared());
  }

  return relayAuthResponse(forwarded);
};
