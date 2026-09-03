import { backendUserFetcher } from "$lib/server/backendApi";
import type { PageServerLoad } from "./$types";


/**
 * The dropdown lists this page hands to its components.
 *
 * Missing lookup data degrades to empty dropdowns rather than an error page:
 * the revurderinger list is the point of the page, and it is still readable
 * without them.
 */
function toLookupOptions(lookup: Record<string, any>) {
  return {
    koerselstyper: lookup.koerselstyper ?? [],
    tidspunkter: lookup.tidspunkter ?? [],
    hjemler: lookup.hjemler ?? [],
    afgoerelsesbreve: lookup.afgoerelsesbreve ?? [],
    koerselstypeTillaeg: lookup.koerselstype_tillaeg ?? [],
    dage: lookup.dage ?? [],
    statuser: lookup.status ?? [],
    skolematrikler: lookup.skolematrikel ?? [],
    sagsbehandlere: lookup.sagsbehandlere ?? [],
    pprSagsbehandlere: lookup.ppr_sagsbehandlere ?? [],
    hjaelpemidler: lookup.hjaelpemidler ?? [],
    ungdomsuddannelser: lookup.ungdomsuddannelser ?? [],
    rutetyper: lookup.rutetyper ?? [],
  };
}


export const load: PageServerLoad = async (event) => {
  const api = backendUserFetcher(event);

  // One request for all thirteen dropdown lists. Fetching them individually
  // made this page's load fourteen requests, thirteen of them reference data.
  const [revurderingerRes, lookupRes] = await Promise.all([
    api("/overview/revurderinger"),
    api("/lookup/all"),
  ]);

  if (!lookupRes.ok) {
    console.error("Failed to fetch lookup data:", lookupRes.status);
  }

  const lookupOptions = toLookupOptions(lookupRes.ok ? await lookupRes.json() : {});

  if (!revurderingerRes.ok) {
    console.error("Failed to fetch revurderinger:", revurderingerRes.status);
    return { revurderinger: [], ...lookupOptions };
  }

  const revurderinger = await revurderingerRes.json();

  return { revurderinger, ...lookupOptions };
};
