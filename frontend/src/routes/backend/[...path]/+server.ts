import { backendUserFetch } from "$lib/server/backendApi";

import type { RequestHandler } from "./$types";


/**
 * Pass a browser request through to the backend under the user's own identity.
 *
 * Deliberately sends no X-API-Key: a shared key would make the backend resolve
 * the caller as an automated one, which defeats every per-user rule behind it
 * (require_edit) and attributes writes to "System". request.headers carries the
 * session cookie, which is what authenticates here.
 *
 * hooks.server.ts has already rejected anonymous callers on this path with a
 * 401, so a request reaching this handler has a session.
 */
const proxyRequest: RequestHandler = async ({
  request,
  params,
  url,
  fetch,
  getClientAddress
}) => {
  const body = ["GET", "HEAD"].includes(request.method)
    ? undefined
    : await request.text();

  // The backend's audit trail records the caller's IP, and every browser call
  // reaches it through this proxy — so without this it would log this
  // container's address for every user in the building. Set rather than
  // appended: an incoming x-forwarded-for is client-supplied and the backend
  // reads the first entry, so appending would let a spoofed value win.
  const headers = new Headers(request.headers);
  headers.set("x-forwarded-for", getClientAddress());

  const response = await backendUserFetch(
    fetch,
    `/${params.path}${url.search}`,
    {
      method: request.method,
      headers,
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
