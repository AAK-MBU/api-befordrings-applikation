import type { RequestHandler } from "./$types";

const BACKEND_URL = process.env.PUBLIC_API_BASE_URL ?? "http://befordringssystemet-api:8000";

export const GET: RequestHandler = async ({ url, request }) => {
  const params = url.searchParams.toString();
  const backendUrl = `${BACKEND_URL}/auth/callback${params ? `?${params}` : ""}`;

  const response = await fetch(backendUrl, {
    headers: {
      cookie: request.headers.get("cookie") ?? ""
    },
    redirect: "manual"
  });

  const headers = new Headers();

  const setCookie = response.headers.get("set-cookie");
  if (setCookie) headers.set("set-cookie", setCookie);

  const location = response.headers.get("location");
  if (location) headers.set("location", location);

  return new Response(null, {
    status: response.status,
    headers
  });
};
