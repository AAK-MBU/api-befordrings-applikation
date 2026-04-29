import { env as publicEnv } from "$env/dynamic/public";


// Small helper to keep response checks consistent
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


export async function load({ params, fetch }) {
  const { cpr } = params;

  const API_URL = publicEnv.PUBLIC_API_BASE_URL;


  // Fetch primary citizen data and lookup lists in parallel
  const [
    stamdataRes,
    parentsRes,
    bevillingerRes,
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
    dageRes
  ] = await Promise.all([
    fetch(`${API_URL}/citizen/stamdata/${cpr}`),
    fetch(`${API_URL}/citizen/stamdata/${cpr}/parents`),
    fetch(`${API_URL}/bevilling/get_student_bevillinger/${cpr}`),

    fetch(`${API_URL}/lookup/status`),
    fetch(`${API_URL}/lookup/skolematrikel`),
    fetch(`${API_URL}/lookup/hjemler`),
    fetch(`${API_URL}/lookup/afgoerelsesbreve`),
    fetch(`${API_URL}/lookup/sagsbehandlere`),
    fetch(`${API_URL}/lookup/ppr_sagsbehandlere`),
    fetch(`${API_URL}/lookup/hjaelpemidler`),
    fetch(`${API_URL}/lookup/tidspunkter`),
    fetch(`${API_URL}/lookup/koerselstyper`),
    fetch(`${API_URL}/lookup/koerselstype_tillaeg`),
    fetch(`${API_URL}/lookup/dage`)
  ]);


  // Fail early if any required request failed
  await assertResponseOk(stamdataRes, "Failed to fetch stamdata");
  await assertResponseOk(parentsRes, "Failed to fetch parents");
  await assertResponseOk(bevillingerRes, "Failed to fetch bevillinger");

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


  // Parse response data
  const stamdataResponse = await stamdataRes.json();
  const parents = await parentsRes.json();
  const bevillinger = await bevillingerRes.json();

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


  // Each bevilling has its own nested kørselsrækker
  const bevillingerWithKoerselsraekker = await Promise.all(
    bevillinger.map(async (bevilling: any) => {
      const koerselsraekkerRes = await fetch(
        `${API_URL}/bevilling/get_bevilling_koerselsraekker/${bevilling.bevilling_id}`
      );

      if (!koerselsraekkerRes.ok) {
        console.error("Failed to fetch kørselsrækker");
        console.error("Bevilling ID:", bevilling.bevilling_id);
        console.error("Status:", koerselsraekkerRes.status);
        console.error("Response:", await koerselsraekkerRes.text());

        return {
          ...bevilling,
          koerselsraekker: []
        };
      }

      const koerselsraekker = await koerselsraekkerRes.json();

      return {
        ...bevilling,
        koerselsraekker
      };
    })
  );


  // Backend sometimes returns stamdata as a list and sometimes as an object
  const stamdata = Array.isArray(stamdataResponse)
    ? stamdataResponse[0]
    : stamdataResponse;


  return {
    cpr,
    stamdata,
    parents,
    bevillinger: bevillingerWithKoerselsraekker,

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
      dage
    }
  };
}