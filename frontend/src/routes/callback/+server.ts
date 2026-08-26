import {
  forwardAuthRequest,
  relayAuthResponse,
  RETURN_TO_COOKIE,
  safeReturnTo,
  serializeReturnToCleared
} from "$lib/server/auth";

import type { RequestHandler } from "./$types";


/**
 * OIDC return leg.
 *
 * Registered at the IdP as the redirect URI, so the authorization code lands
 * here and is handed on to the backend's /auth/callback. Distinct from the
 * generic /api/auth passthrough only because it restores where the user was
 * originally headed.
 *
 * hooks.server.ts leaves this path unguarded — it is what *creates* the
 * session.
 */
export const GET: RequestHandler = async ({ url, request, cookies }) => {
  const forwarded = await forwardAuthRequest(
    "callback",
    url.search,
    request.headers.get("cookie")
  );

  const location = forwarded.response.headers.get("location");

  if (location) {
    // The backend always redirects to its fixed post_login_redirect ("/").
    // Prefer the destination the user originally asked for, stashed by the
    // guard before it sent them to the IdP. Validated on the way out because
    // cookies are client-controlled — see safeReturnTo.
    const returnTo =
      forwarded.response.status < 400
        ? safeReturnTo(cookies.get(RETURN_TO_COOKIE))
        : null;

    forwarded.headers.set("location", returnTo ?? location);
    forwarded.headers.append("set-cookie", serializeReturnToCleared());
  }

  return relayAuthResponse(forwarded);
};
