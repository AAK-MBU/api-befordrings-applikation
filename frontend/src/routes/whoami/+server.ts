import type { RequestHandler } from "./$types";


/**
 * Diagnostic: show who the auth guard thinks you are.
 *
 * Reaching this route at all is the signal. locals.user is set by
 * hooks.server.ts from the backend's /me, which resolves the browser's own
 * session cookie against the IdP-issued ID token — so a 200 here means the
 * cookie survived the login round trip and the claims came back. Anonymous
 * requests never get this far; the guard redirects them to the IdP first.
 *
 * Also written to the server log, so `docker compose logs -f frontend` shows
 * the claims without a browser in the loop.
 */
export const GET: RequestHandler = ({ locals }) => {
  const claims = JSON.stringify(locals.user, null, 2);

  console.log(`[auth] whoami\n${claims}`);

  return new Response(claims, {
    headers: {
      "content-type": "application/json; charset=utf-8",
      // A snapshot of one session — a cached copy would show the next visitor
      // somebody else's identity.
      "cache-control": "no-store"
    }
  });
};
