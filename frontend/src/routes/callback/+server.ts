import type { RequestHandler } from "./$types";

export const GET: RequestHandler = async ({ url }) => {
  const params = url.searchParams.toString();
  const target = `/api/auth/callback${params ? `?${params}` : ""}`;

  return new Response(null, {
    status: 302,
    headers: { Location: target }
  });
};
