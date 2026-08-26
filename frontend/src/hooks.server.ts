import type { Handle } from "@sveltejs/kit";

import { getLoginUrl, probeSession, serializeReturnTo } from "$lib/server/auth";


/**
 * Paths that must stay reachable without a session.
 *
 * /callback is the OIDC return leg: it proxies the IdP's authorization code to
 * the backend, which is what *creates* the session. Guarding it would deadlock
 * the flow into a redirect loop.
 */
const PUBLIC_PATHS = ["/callback"];


function matchesPath(pathname: string, candidate: string) {
  return pathname === candidate || pathname.startsWith(`${candidate}/`);
}


function isPublicPath(pathname: string) {
  if (PUBLIC_PATHS.some((publicPath) => matchesPath(pathname, publicPath))) {
    return true;
  }

  // When the login URL is same-origin (the default /api/auth/login, served by
  // the reverse proxy rather than by SvelteKit) it must not be guarded. If the
  // proxy is missing, that path falls through to SvelteKit's 404 — guarding it
  // would instead redirect it to itself forever.
  const loginUrl = getLoginUrl();

  return loginUrl.startsWith("/") && matchesPath(pathname, loginUrl);
}


/**
 * Send the user to the IdP, remembering where they were headed.
 *
 * Built as an explicit Response rather than a thrown redirect() so that the
 * Set-Cookie travels with the 302 unambiguously — the destination cookie is
 * only useful if it survives this exact hop.
 */
function loginRedirect(url: URL) {
  const headers = new Headers({ location: getLoginUrl() });

  headers.append(
    "set-cookie",
    serializeReturnTo(`${url.pathname}${url.search}`, url.protocol === "https:")
  );

  return new Response(null, { status: 302, headers });
}


export const handle: Handle = async ({ event, resolve }) => {
  if (isPublicPath(event.url.pathname)) {
    return resolve(event);
  }

  const probe = await probeSession(event.request.headers.get("cookie"));

  if (probe.status === "unavailable") {
    // Bouncing to the IdP when the API is merely down would present an outage
    // as a login loop, so fail loudly instead.
    console.error(`[auth] session probe unavailable — ${probe.reason}`);

    return new Response("Kunne ikke kontakte API'et", { status: 503 });
  }

  if (probe.status === "anonymous") {
    // /backend/* is fetch()ed by already-loaded pages. A 302 to the IdP would
    // resolve to its HTML login page and blow up in response.json(), so answer
    // with a status the caller can act on.
    if (matchesPath(event.url.pathname, "/backend")) {
      return new Response(null, { status: 401 });
    }

    return loginRedirect(event.url);
  }

  event.locals.user = probe.user;

  return resolve(event);
};
