import { backendApiFetch } from "$lib/server/backendApi";
import type { PageServerLoad } from "./$types";


export const load: PageServerLoad = async ({ fetch }) => {
  const [ansoegningerRes, sagsbehandlereRes, pprRes] = await Promise.all([
    backendApiFetch(fetch, "/overview/new_applications"),
    backendApiFetch(fetch, "/lookup/sagsbehandlere"),
    backendApiFetch(fetch, "/lookup/ppr_sagsbehandlere"),
  ]);

  if (!ansoegningerRes.ok) {
    console.error("Failed to fetch nye ansøgninger:", ansoegningerRes.status);
    return { ansoegninger: [], sagsbehandlere: [], pprSagsbehandlere: [] };
  }

  const [ansoegninger, sagsbehandlere, pprSagsbehandlere] = await Promise.all([
    ansoegningerRes.json(),
    sagsbehandlereRes.ok ? sagsbehandlereRes.json() : [],
    pprRes.ok ? pprRes.json() : [],
  ]);

  return { ansoegninger, sagsbehandlere, pprSagsbehandlere };
};
