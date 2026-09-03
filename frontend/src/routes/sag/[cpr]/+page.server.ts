import { backendUserFetcher } from "$lib/server/backendApi";

import type { PageServerLoad } from "./$types";


type BevillingRecord = Record<string, any> & {
  bevilling_id: number;
};


async function assertResponseOk(response: Response, errorMessage: string) {
  if (response.ok) {
    return;
  }

  const errorText = await response.text();

  console.error(errorMessage);
  console.error("Status:", response.status);
  console.error("Response:", errorText);

  throw new Error(`${errorMessage}: ${response.status}`);
}


export const load: PageServerLoad = async (event) => {
  const { cpr } = event.params;
  const api = backendUserFetcher(event);

  const [
    stamdataRes,
    parentsRes,
    parterRes,
    bevillingerRes,
    aktiviteterRes,
    lookupRes
  ] = await Promise.all([
    api(`/citizen/stamdata/${cpr}`),
    api(`/citizen/stamdata/${cpr}/parents`),
    api(`/part/${cpr}`),
    api(`/bevilling/get_student_bevillinger/${cpr}`),
    api(`/aktivitet/${cpr}`),

    // One request for all thirteen dropdown lists. Fetching them individually
    // meant this page opened eighteen connections against a pool of thirty.
    api("/lookup/all")
  ]);

  await assertResponseOk(stamdataRes, "Failed to fetch stamdata");
  await assertResponseOk(parentsRes, "Failed to fetch parents");
  await assertResponseOk(parterRes, "Failed to fetch parter");
  await assertResponseOk(bevillingerRes, "Failed to fetch bevillinger");
  await assertResponseOk(aktiviteterRes, "Failed to fetch aktiviteter");
  await assertResponseOk(lookupRes, "Failed to fetch lookup data");

  const stamdataResponse = await stamdataRes.json();
  const parents = await parentsRes.json();
  const parter = await parterRes.json();
  const bevillinger: BevillingRecord[] = await bevillingerRes.json();
  const aktiviteter = await aktiviteterRes.json();
  const lookup = await lookupRes.json();

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

  // Ordering: the active bevilling always comes first (active trumps a future
  // or more recently created one). The rest follow, sorted by the latest
  // gyldig_til across their koerselsraekker, descending (most recent end date
  // first). Bevillinger with no koerselsraekker sort to the bottom.
  const maxGyldigTil = (b: BevillingRecord & { koerselsraekker: any[] }): string =>
    b.koerselsraekker.reduce(
      (max: string, k: any) => (k.gyldig_til > max ? k.gyldig_til : max),
      ""
    );

  const isActive = (b: BevillingRecord): number => (b.status_tekst === "Aktiv" ? 1 : 0);

  const sortedBevillinger = [...bevillingerWithKoerselsraekker].sort((a, b) => {
    // Active first.
    const activeDiff = isActive(b) - isActive(a);
    if (activeDiff !== 0) {
      return activeDiff;
    }

    // Then by latest gyldig_til, descending.
    return maxGyldigTil(b).localeCompare(maxGyldigTil(a));
  });

  const stamdata = Array.isArray(stamdataResponse)
    ? stamdataResponse[0]
    : stamdataResponse;

  return {
    cpr,
    stamdata,
    parents,
    parter,
    bevillinger: sortedBevillinger,
    aktiviteter,

    lookupOptions: {
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
    }
  };
};
