import { getApiBaseUrl } from "$lib/server/backendApi";
import {
  RETURN_TO_COOKIE,
  safeReturnTo,
  serializeReturnToCleared
} from "$lib/server/auth";

import type { RequestHandler } from "./$types";


/**
 * OIDC return leg.
 *
 * The IdP is configured to redirect here rather than straight to the backend,
 * so this hands the authorization code on to the backend's /auth/callback and
 * relays its session cookie back to the browser. hooks.server.ts leaves this
 * path unguarded — it is what *creates* the session.
 */
export const GET: RequestHandler = async ({ url, request, cookies }) => {
  const params = url.searchParams.toString();
  const backendUrl = `${getApiBaseUrl()}/auth/callback${params ? `?${params}` : ""}`;

  const response = await fetch(backendUrl, {
    headers: {
      cookie: request.headers.get("cookie") ?? ""
    },
    redirect: "manual"
  });

  const headers = new Headers();

  // getSetCookie(), not get(): the backend may set more than one cookie, and
  // get() would fold them into a single comma-joined value that no browser
  // parses back into the original pair.
  for (const cookie of response.headers.getSetCookie()) {
    headers.append("set-cookie", cookie);
  }

  const location = response.headers.get("location");

  if (location) {
    // The backend always redirects to its fixed post_login_redirect ("/").
    // Prefer the destination the user originally asked for, stashed by the
    // guard before it sent them to the IdP. Validated on the way out because
    // cookies are client-controlled — see safeReturnTo.
    const returnTo =
      response.status < 400 ? safeReturnTo(cookies.get(RETURN_TO_COOKIE)) : null;

    headers.set("location", returnTo ?? location);
    headers.append("set-cookie", serializeReturnToCleared());
  }

  // On failure the backend explains itself in the body (FastAPI's {"detail":
  // ...}, e.g. "no pending login state in session"). Dropping it would leave a
  // blank page as the only symptom, so pass it through.
  if (response.status >= 400) {
    const contentType = response.headers.get("content-type");

    if (contentType) {
      headers.set("content-type", contentType);
    }

    return new Response(await response.text(), {
      status: response.status,
      headers
    });
  }

  return new Response(null, {
    status: response.status,
    headers
  });
};
