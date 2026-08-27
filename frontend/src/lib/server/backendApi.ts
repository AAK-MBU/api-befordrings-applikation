import { env as privateEnv } from "$env/dynamic/private";
import { env as publicEnv } from "$env/dynamic/public";

type FetchFunction = typeof fetch;


export function getApiBaseUrl() {
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


/**
 * Call the backend *as the signed-in user* rather than as this application.
 *
 * The shared API key is deliberately absent. require_auth on the backend checks
 * that key first and returns without ever looking at the user, so sending both
 * would resolve every browser request as an anonymous automated caller: role
 * checks would silently pass, and audit attribution would record "System"
 * instead of the person who made the change.
 *
 * The caller's Cookie header has to be forwarded in `options` for this to
 * authenticate — that cookie is the session. Only safe for requests that
 * originate from a browser with a session; server-initiated calls with no user
 * behind them still belong on backendApiFetch.
 */
export function backendUserFetch(
  fetchFn: FetchFunction,
  path: string,
  options: RequestInit = {}
) {
  return fetchFn(`${getApiBaseUrl()}${normalizePath(path)}`, options);
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