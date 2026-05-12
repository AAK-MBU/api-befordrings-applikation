import { env as privateEnv } from "$env/dynamic/private";
import { env as publicEnv } from "$env/dynamic/public";

type FetchFunction = typeof fetch;


function getApiBaseUrl() {
  const apiBaseUrl = publicEnv.PUBLIC_API_BASE_URL;

  if (!apiBaseUrl) {
    throw new Error("Missing PUBLIC_API_BASE_URL");
  }

  return apiBaseUrl;
}


function getApiKey() {
  const apiKey = privateEnv.BEFORDRING_API_KEY;

  if (!apiKey) {
    throw new Error("Missing BEFORDRING_API_KEY");
  }

  return apiKey;
}


function normalizePath(path: string) {
  if (path.startsWith("/")) {
    return path;
  }

  return `/${path}`;
}


export function backendApiFetch(
  fetchFn: FetchFunction,
  path: string,
  options: RequestInit = {}
) {
  const apiBaseUrl = getApiBaseUrl();
  const apiKey = getApiKey();

  const headers = new Headers(options.headers);

  headers.set("X-API-Key", apiKey);

  return fetchFn(`${apiBaseUrl}${normalizePath(path)}`, {
    ...options,
    headers
  });
}