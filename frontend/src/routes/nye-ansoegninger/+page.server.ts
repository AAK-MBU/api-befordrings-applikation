import { backendUserFetcher } from "$lib/server/backendApi";
import type { PageServerLoad } from "./$types";


export const load: PageServerLoad = async (event) => {
  const api = backendUserFetcher(event);

  const [ansoegningerRes, sagsbehandlereRes, pprRes, koerselstyperRes] = await Promise.all([
    api("/overview/new_applications"),
    api("/lookup/sagsbehandlere"),
    api("/lookup/ppr_sagsbehandlere"),
    api("/lookup/koerselstyper"),
  ]);

  if (!ansoegningerRes.ok) {
    console.error("Failed to fetch nye ansøgninger:", ansoegningerRes.status);
    return { ansoegninger: [], sagsbehandlere: [], pprSagsbehandlere: [], koerselstyper: [] };
  }

  const [ansoegninger, sagsbehandlere, pprSagsbehandlere, koerselstyper] = await Promise.all([
    ansoegningerRes.json(),
    sagsbehandlereRes.ok ? sagsbehandlereRes.json() : [],
    pprRes.ok ? pprRes.json() : [],
    koerselstyperRes.ok ? koerselstyperRes.json() : [],
  ]);

  return { ansoegninger, sagsbehandlere, pprSagsbehandlere, koerselstyper };
};
