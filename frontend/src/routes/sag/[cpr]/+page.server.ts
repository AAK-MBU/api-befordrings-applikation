import { backendApiFetch } from "$lib/server/backendApi";

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


export const load: PageServerLoad = async ({ params, fetch }) => {
  const { cpr } = params;

  const [
    stamdataRes,
    parentsRes,
    bevillingerRes,
    // aktiviteterRes,
    statusRes,
    skolematriklerRes,
    hjemlerRes,
    afgoerelsesbreveRes,
    sagsbehandlereRes,
    pprSagsbehandlereRes,
    hjaelpemidlerRes,
    tidspunkterRes,
    koerselstyperRes,
    koerselstypeTillaegRes,
    dageRes,
    ungdomsuddannelserRes
  ] = await Promise.all([
    backendApiFetch(fetch, `/citizen/stamdata/${cpr}`),
    backendApiFetch(fetch, `/citizen/stamdata/${cpr}/parents`),
    backendApiFetch(fetch, `/bevilling/get_student_bevillinger/${cpr}`),
    // backendApiFetch(fetch, `/aktivitet/${cpr}`),

    backendApiFetch(fetch, "/lookup/status"),
    backendApiFetch(fetch, "/lookup/skolematrikel"),
    backendApiFetch(fetch, "/lookup/hjemler"),
    backendApiFetch(fetch, "/lookup/afgoerelsesbreve"),
    backendApiFetch(fetch, "/lookup/sagsbehandlere"),
    backendApiFetch(fetch, "/lookup/ppr_sagsbehandlere"),
    backendApiFetch(fetch, "/lookup/hjaelpemidler"),
    backendApiFetch(fetch, "/lookup/tidspunkter"),
    backendApiFetch(fetch, "/lookup/koerselstyper"),
    backendApiFetch(fetch, "/lookup/koerselstype_tillaeg"),
    backendApiFetch(fetch, "/lookup/dage"),
    backendApiFetch(fetch, "/lookup/ungdomsuddannelser")
  ]);

  await assertResponseOk(stamdataRes, "Failed to fetch stamdata");
  await assertResponseOk(parentsRes, "Failed to fetch parents");
  await assertResponseOk(bevillingerRes, "Failed to fetch bevillinger");
  // await assertResponseOk(aktiviteterRes, "Failed to fetch aktiviteter");
  await assertResponseOk(statusRes, "Failed to fetch status");
  await assertResponseOk(skolematriklerRes, "Failed to fetch skolematrikler");
  await assertResponseOk(hjemlerRes, "Failed to fetch hjemler");
  await assertResponseOk(afgoerelsesbreveRes, "Failed to fetch afgoerelsesbreve");
  await assertResponseOk(sagsbehandlereRes, "Failed to fetch sagsbehandlere");
  await assertResponseOk(pprSagsbehandlereRes, "Failed to fetch ppr sagsbehandlere");
  await assertResponseOk(hjaelpemidlerRes, "Failed to fetch hjaelpemidler");
  await assertResponseOk(tidspunkterRes, "Failed to fetch tidspunkter");
  await assertResponseOk(koerselstyperRes, "Failed to fetch koerselstyper");
  await assertResponseOk(koerselstypeTillaegRes, "Failed to fetch koerselstype tillaeg");
  await assertResponseOk(dageRes, "Failed to fetch dage");
  await assertResponseOk(ungdomsuddannelserRes, "Failed to fetch ungdomsuddannelser");

  const stamdataResponse = await stamdataRes.json();
  const parents = await parentsRes.json();
  const bevillinger: BevillingRecord[] = await bevillingerRes.json();
  // const aktiviteter = await aktiviteterRes.json();
  const statuser = await statusRes.json();
  const skolematrikler = await skolematriklerRes.json();
  const hjemler = await hjemlerRes.json();
  const afgoerelsesbreve = await afgoerelsesbreveRes.json();
  const sagsbehandlere = await sagsbehandlereRes.json();
  const pprSagsbehandlere = await pprSagsbehandlereRes.json();
  const hjaelpemidler = await hjaelpemidlerRes.json();
  const tidspunkter = await tidspunkterRes.json();
  const koerselstyper = await koerselstyperRes.json();
  const koerselstypeTillaeg = await koerselstypeTillaegRes.json();
  const dage = await dageRes.json();
  const ungdomsuddannelser = await ungdomsuddannelserRes.json();

  const bevillingerWithKoerselsraekker = await Promise.all(
    bevillinger.map(async (bevilling) => {
      const koerselsraekkerRes = await backendApiFetch(
        fetch,
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

  // Sort bevillinger by the latest gyldig_til date across their koerselsraekker,
  // descending — bevillinger with the most recent end date appear first.
  // Bevillinger with no koerselsraekker sort to the bottom.
  const maxGyldigTil = (b: BevillingRecord & { koerselsraekker: any[] }): string =>
    b.koerselsraekker.reduce(
      (max: string, k: any) => (k.gyldig_til > max ? k.gyldig_til : max),
      ""
    );

  const sortedBevillinger = [...bevillingerWithKoerselsraekker].sort(
    (a, b) => maxGyldigTil(b).localeCompare(maxGyldigTil(a))
  );

  const stamdata = Array.isArray(stamdataResponse)
    ? stamdataResponse[0]
    : stamdataResponse;

  return {
    cpr,
    stamdata,
    parents,
    bevillinger: sortedBevillinger,
    // aktiviteter,

    lookupOptions: {
      statuser,
      skolematrikler,
      hjemler,
      afgoerelsesbreve,
      sagsbehandlere,
      pprSagsbehandlere,
      hjaelpemidler,
      tidspunkter,
      koerselstyper,
      koerselstypeTillaeg,
      dage,
      ungdomsuddannelser
    }
  };
};
