import { backendApiFetch } from "$lib/server/backendApi";

import type { RequestHandler } from "./$types";


const proxyRequest: RequestHandler = async ({ request, params, url, fetch }) => {
  const body = ["GET", "HEAD"].includes(request.method)
    ? undefined
    : await request.text();

  const response = await backendApiFetch(
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
