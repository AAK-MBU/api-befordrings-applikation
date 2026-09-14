import { backendUserFetcher } from "$lib/server/backendApi";
import type { PageServerLoad } from "./$types";


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

  const [genbehandlingerRes, lookupRes] = await Promise.all([
    api("/overview/genbehandlinger"),
    api("/lookup/all"),
  ]);

  if (!lookupRes.ok) {
    console.error("Failed to fetch lookup data:", lookupRes.status);
  }

  const lookupOptions = toLookupOptions(lookupRes.ok ? await lookupRes.json() : {});

  if (!genbehandlingerRes.ok) {
    console.error("Failed to fetch genbehandlinger:", genbehandlingerRes.status);
    return { genbehandlinger: [], ...lookupOptions };
  }

  const genbehandlinger = await genbehandlingerRes.json();

  return { genbehandlinger, ...lookupOptions };
};