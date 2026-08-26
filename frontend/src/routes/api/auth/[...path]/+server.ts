import { forwardAuthRequest, relayAuthResponse } from "$lib/server/auth";

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

  return relayAuthResponse(forwarded);
};
