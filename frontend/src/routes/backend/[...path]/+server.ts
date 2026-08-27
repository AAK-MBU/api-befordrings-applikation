import { backendUserFetch } from "$lib/server/backendApi";

import type { RequestHandler } from "./$types";


/**
 * Pass a browser request through to the backend under the user's own identity.
 *
 * Deliberately *not* backendApiFetch: stamping the shared API key would make
 * the backend resolve the caller as an automated one, which defeats every
 * per-user rule behind it (require_edit) and attributes writes to "System".
 * request.headers carries the session cookie, which is what authenticates here.
 *
 * hooks.server.ts has already rejected anonymous callers on this path with a
 * 401, so a request reaching this handler has a session.
 */
const proxyRequest: RequestHandler = async ({ request, params, url, fetch }) => {
  const body = ["GET", "HEAD"].includes(request.method)
    ? undefined
    : await request.text();

  const response = await backendUserFetch(
    fetch,
    `/${params.path}${url.search}`,
    {
      method: request.method,
      headers: request.headers,
      body
    }
  );

  const responseBody = await response.arrayBuffer();

  return new Response(responseBody, {
    status: response.status,
    headers: response.headers
  });
};


export const GET = proxyRequest;
export const POST = proxyRequest;
export const PUT = proxyRequest;
export const PATCH = proxyRequest;
export const DELETE = proxyRequest;
