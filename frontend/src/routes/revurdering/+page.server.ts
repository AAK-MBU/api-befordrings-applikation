import { backendApiFetch } from "$lib/server/backendApi";
import type { PageServerLoad } from "./$types";


export const load: PageServerLoad = async ({ fetch }) => {
  const [
    revurderingerRes,
    koerselstyperRes,
    tidspunkterRes,
    hjemlerRes,
    afgoerelsesbreveRes,
    koerselstypeTillaegRes,
    dageRes,
    statusRes,
    skolematriklerRes,
    sagsbehandlereRes,
    pprSagsbehandlereRes,
    hjaelpemidlerRes,
    ungdomsuddannelserRes,
  ] = await Promise.all([
    backendApiFetch(fetch, "/overview/revurderinger"),
    backendApiFetch(fetch, "/lookup/koerselstyper"),
    backendApiFetch(fetch, "/lookup/tidspunkter"),
    backendApiFetch(fetch, "/lookup/hjemler"),
    backendApiFetch(fetch, "/lookup/afgoerelsesbreve"),
    backendApiFetch(fetch, "/lookup/koerselstype_tillaeg"),
    backendApiFetch(fetch, "/lookup/dage"),
    backendApiFetch(fetch, "/lookup/status"),
    backendApiFetch(fetch, "/lookup/skolematrikel"),
    backendApiFetch(fetch, "/lookup/sagsbehandlere"),
    backendApiFetch(fetch, "/lookup/ppr_sagsbehandlere"),
    backendApiFetch(fetch, "/lookup/hjaelpemidler"),
    backendApiFetch(fetch, "/lookup/ungdomsuddannelser"),
  ]);

  if (!revurderingerRes.ok) {
    console.error("Failed to fetch revurderinger:", revurderingerRes.status);
    return {
      revurderinger: [],
      koerselstyper: [], tidspunkter: [], hjemler: [], afgoerelsesbreve: [],
      koerselstypeTillaeg: [], dage: [], statuser: [], skolematrikler: [],
      sagsbehandlere: [], pprSagsbehandlere: [], hjaelpemidler: [], ungdomsuddannelser: [],
    };
  }

  const [
    revurderinger, koerselstyper, tidspunkter, hjemler, afgoerelsesbreve,
    koerselstypeTillaeg, dage, statuser, skolematrikler,
    sagsbehandlere, pprSagsbehandlere, hjaelpemidler, ungdomsuddannelser,
  ] = await Promise.all([
    revurderingerRes.json(),
    koerselstyperRes.ok ? koerselstyperRes.json() : [],
    tidspunkterRes.ok ? tidspunkterRes.json() : [],
    hjemlerRes.ok ? hjemlerRes.json() : [],
    afgoerelsesbreveRes.ok ? afgoerelsesbreveRes.json() : [],
    koerselstypeTillaegRes.ok ? koerselstypeTillaegRes.json() : [],
    dageRes.ok ? dageRes.json() : [],
    statusRes.ok ? statusRes.json() : [],
    skolematriklerRes.ok ? skolematriklerRes.json() : [],
    sagsbehandlereRes.ok ? sagsbehandlereRes.json() : [],
    pprSagsbehandlereRes.ok ? pprSagsbehandlereRes.json() : [],
    hjaelpemidlerRes.ok ? hjaelpemidlerRes.json() : [],
    ungdomsuddannelserRes.ok ? ungdomsuddannelserRes.json() : [],
  ]);

  return {
    revurderinger, koerselstyper, tidspunkter, hjemler, afgoerelsesbreve,
    koerselstypeTillaeg, dage, statuser, skolematrikler,
    sagsbehandlere, pprSagsbehandlere, hjaelpemidler, ungdomsuddannelser,
  };
};
