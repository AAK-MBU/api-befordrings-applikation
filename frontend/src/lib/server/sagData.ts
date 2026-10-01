/**
 * Loading of a student's case data, shared by the sag page and the standalone
 * "opret bevilling" window.
 *
 * The create form used to live only inside the sag page, so it could take the
 * student's bevillinger and the lookup lists straight from that page's props.
 * Opening it in its own window means it has to load them itself — and loading
 * them a second way would be two copies of the same joins drifting apart.
 * hentSagKerne() is that one copy.
 */

import { error } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";

import type { RequestEvent } from "@sveltejs/kit";


export type BevillingRecord = Record<string, any> & {
  bevilling_id: number;
};


export async function assertResponseOk(response: Response, errorMessage: string) {
  if (response.ok) {
    return;
  }

  const errorText = await response.text();

  console.error(errorMessage);
  console.error("Status:", response.status);
  console.error("Response:", errorText);

  throw new Error(`${errorMessage}: ${response.status}`);
}


/**
 * The student's bevillinger, each with its kørselsrækker attached.
 *
 * Ordering: the active bevilling always comes first (active trumps a future
 * or more recently created one). The rest follow, sorted by the latest
 * gyldig_til across their koerselsraekker, descending (most recent end date
 * first). Bevillinger with no koerselsraekker sort to the bottom.
 */
async function hentBevillinger(api: ReturnType<typeof backendUserFetcher>, cpr: string) {
  const bevillingerRes = await api(`/bevilling/get_student_bevillinger/${cpr}`);

  await assertResponseOk(bevillingerRes, "Failed to fetch bevillinger");

  const bevillinger: BevillingRecord[] = await bevillingerRes.json();

  const bevillingerWithKoerselsraekker = await Promise.all(
    bevillinger.map(async (bevilling) => {
      const koerselsraekkerRes = await api(
        `/bevilling/get_bevilling_koerselsraekker/${bevilling.bevilling_id}`
      );

      if (!koerselsraekkerRes.ok) {
        console.error("Failed to fetch koerselsraekker");
        console.error("Bevilling ID:", bevilling.bevilling_id);
        console.error("Status:", koerselsraekkerRes.status);
        console.error("Response:", await koerselsraekkerRes.text());

        return { ...bevilling, koerselsraekker: [] };
      }

      const koerselsraekker = await koerselsraekkerRes.json();
      return { ...bevilling, koerselsraekker };
    })
  );

  const maxGyldigTil = (b: BevillingRecord & { koerselsraekker: any[] }): string =>
    b.koerselsraekker.reduce(
      (max: string, k: any) => (k.gyldig_til > max ? k.gyldig_til : max),
      ""
    );

  const isActive = (b: BevillingRecord): number => (b.status_tekst === "Aktiv" ? 1 : 0);

  return [...bevillingerWithKoerselsraekker].sort((a, b) => {
    // Active first.
    const activeDiff = isActive(b) - isActive(a);
    if (activeDiff !== 0) {
      return activeDiff;
    }

    // Then by latest gyldig_til, descending.
    return maxGyldigTil(b).localeCompare(maxGyldigTil(a));
  });
}


function mapLookupOptions(lookup: any) {
  return {
    statuser: lookup.status,
    skolematrikler: lookup.skolematrikel,
    hjemler: lookup.hjemler,
    afgoerelsesbreve: lookup.afgoerelsesbreve,
    sagsbehandlere: lookup.sagsbehandlere,
    pprSagsbehandlere: lookup.ppr_sagsbehandlere,
    hjaelpemidler: lookup.hjaelpemidler,
    tidspunkter: lookup.tidspunkter,
    koerselstyper: lookup.koerselstyper,
    koerselstypeTillaeg: lookup.koerselstype_tillaeg,
    dage: lookup.dage,
    ungdomsuddannelser: lookup.ungdomsuddannelser,
    rutetyper: lookup.rutetyper
  };
}


/**
 * Everything the bevilling create form needs: the student, their existing
 * bevillinger, the parties who can receive kørselsgodtgørelse, and the
 * dropdown lists.
 *
 * The sag page loads this too, and adds the feed, parents and parter on top.
 */
export async function hentSagKerne(event: RequestEvent, cpr: string) {
  const api = backendUserFetcher(event);

  const [stamdataRes, recipientsRes, bevillinger, lookupRes] = await Promise.all([
    api(`/citizen/stamdata/${cpr}`),
    api(`/part/${cpr}/recipients`),
    hentBevillinger(api, cpr),

    // One request for all thirteen dropdown lists. Fetching them individually
    // meant this page opened eighteen connections against a pool of thirty.
    api("/lookup/all")
  ]);

  await assertResponseOk(stamdataRes, "Failed to fetch stamdata");
  await assertResponseOk(recipientsRes, "Failed to fetch recipients");
  await assertResponseOk(lookupRes, "Failed to fetch lookup data");

  const stamdataResponse = await stamdataRes.json();
  const recipients = await recipientsRes.json();
  const lookup = await lookupRes.json();

  const stamdata = Array.isArray(stamdataResponse)
    ? stamdataResponse[0]
    : stamdataResponse;

  // /citizen/stamdata/{cpr} answers 200 with a null body for a CPR that is not
  // in Elev, so assertResponseOk above lets it through. Without this the page
  // renders with stamdata = null and dies on the first stamdata.cpr — a blank
  // screen and a console TypeError, with nothing telling the caseworker that
  // the CPR is simply unknown.
  if (!stamdata) {
    throw error(404, `Ingen elev fundet med CPR ${cpr}`);
  }

  return {
    cpr,
    stamdata,
    recipients,
    bevillinger,
    lookupOptions: mapLookupOptions(lookup)
  };
}
