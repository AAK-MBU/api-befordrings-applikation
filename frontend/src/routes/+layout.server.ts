import { backendUserFetcher } from "$lib/server/backendApi";
import { getLogoutUrl } from "$lib/server/auth";

import type { LayoutServerLoad } from "./$types";


/**
 * Badge counts for the nav tabs.
 *
 * Loaded here rather than in onMount so they refresh with the rest of the page
 * data: every save in the app already calls invalidateAll(), which re-runs this
 * load. Fetched in onMount they were read exactly once per full page load, so a
 * bevilling entering genbehandling left the badge stale until F5.
 *
 * Counts are decorative — a failed fetch yields 0 rather than breaking the
 * layout, which would take every page down with it.
 */
async function loadCounts(event: Parameters<LayoutServerLoad>[0]) {
  const api = backendUserFetcher(event);

  const paths = {
    nye: "/overview/new_applications",
    revurderinger: "/overview/revurderinger",
    genbehandlinger: "/overview/genbehandlinger",
  } as const;

  const entries = await Promise.all(
    Object.entries(paths).map(async ([key, path]) => {
      try {
        const res = await api(path);
        if (!res.ok) return [key, 0] as const;

        const rows = await res.json();
        return [key, Array.isArray(rows) ? rows.length : 0] as const;
      } catch {
        return [key, 0] as const;
      }
    })
  );

  return Object.fromEntries(entries) as Record<keyof typeof paths, number>;
}


/**
 * Hand the signed-in user's claims to the UI.
 *
 * locals.user is set by the auth guard in hooks.server.ts and is always
 * present — the guard redirects to the IdP rather than resolving a request
 * without it. These are the user's own ID token claims, so there is nothing
 * here that they are not already entitled to see.
 */
export const load: LayoutServerLoad = async (event) => {
  return {
    user: event.locals.user,
    logoutUrl: getLogoutUrl(),
    counts: await loadCounts(event)
  };
};
