import { backendUserFetcher } from "$lib/server/backendApi";
import { getLogoutUrl } from "$lib/server/auth";

import type { LayoutServerLoad } from "./$types";


type Counts = {
  nye: number;
  revurderinger: number;
  genbehandlinger: number;
  forsendelser: number;
};

const INGEN_COUNTS: Counts = {
  nye: 0,
  revurderinger: 0,
  genbehandlinger: 0,
  forsendelser: 0,
};

/**
 * Badge counts for the nav tabs.
 *
 * Loaded here rather than in onMount so they refresh with the rest of the page
 * data: every save in the app already calls invalidateAll(), which re-runs this
 * load. Fetched in onMount they were read exactly once per full page load, so a
 * bevilling entering genbehandling left the badge stale until F5.
 *
 * ONE request, not four. This used to fetch all four worklists in full and
 * take .length — four complete datasets, including the nested kørselsrækker
 * that /overview/revurderinger builds, to render four small numbers. Because
 * it is a layout load it ran again on every invalidateAll, which this codebase
 * calls in 37 places, so every save in the application re-read all four lists
 * end to end. /overview/counts answers the same question in one statement.
 *
 * Counts are decorative — a failed fetch yields zeros rather than breaking the
 * layout, which would take every page down with it.
 */
async function loadCounts(event: Parameters<LayoutServerLoad>[0]): Promise<Counts> {
  const api = backendUserFetcher(event);

  try {
    const res = await api("/overview/counts");

    if (!res.ok) return INGEN_COUNTS;

    const counts = await res.json();

    // Spread over the defaults rather than trusting the body: a missing key
    // should show 0, not "undefined" in the badge.
    return { ...INGEN_COUNTS, ...counts };
  } catch {
    return INGEN_COUNTS;
  }
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
