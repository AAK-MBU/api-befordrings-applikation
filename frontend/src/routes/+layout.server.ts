import { getLogoutUrl } from "$lib/server/auth";

import type { LayoutServerLoad } from "./$types";


/**
 * Hand the signed-in user's claims to the UI.
 *
 * locals.user is set by the auth guard in hooks.server.ts and is always
 * present — the guard redirects to the IdP rather than resolving a request
 * without it. These are the user's own ID token claims, so there is nothing
 * here that they are not already entitled to see.
 */
export const load: LayoutServerLoad = ({ locals }) => {
  return {
    user: locals.user,
    logoutUrl: getLogoutUrl()
  };
};
