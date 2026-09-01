import { backendUserFetcher } from "$lib/server/backendApi";
import type { PageServerLoad } from "./$types";


export const load: PageServerLoad = async (event) => {
  const api = backendUserFetcher(event);

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
    rutetyperRes,
  ] = await Promise.all([
    api("/overview/revurderinger"),
    api("/lookup/koerselstyper"),
    api("/lookup/tidspunkter"),
    api("/lookup/hjemler"),
    api("/lookup/afgoerelsesbreve"),
    api("/lookup/koerselstype_tillaeg"),
    api("/lookup/dage"),
    api("/lookup/status"),
    api("/lookup/skolematrikel"),
    api("/lookup/sagsbehandlere"),
    api("/lookup/ppr_sagsbehandlere"),
    api("/lookup/hjaelpemidler"),
    api("/lookup/ungdomsuddannelser"),
    api("/lookup/rutetyper"),
  ]);

  if (!revurderingerRes.ok) {
    console.error("Failed to fetch revurderinger:", revurderingerRes.status);
    return {
      revurderinger: [],
      koerselstyper: [], tidspunkter: [], hjemler: [], afgoerelsesbreve: [],
      koerselstypeTillaeg: [], dage: [], statuser: [], skolematrikler: [],
      sagsbehandlere: [], pprSagsbehandlere: [], hjaelpemidler: [], ungdomsuddannelser: [], rutetyper: [],
    };
  }

  const [
    revurderinger, koerselstyper, tidspunkter, hjemler, afgoerelsesbreve,
    koerselstypeTillaeg, dage, statuser, skolematrikler,
    sagsbehandlere, pprSagsbehandlere, hjaelpemidler, ungdomsuddannelser, rutetyper,
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
    rutetyperRes.ok ? rutetyperRes.json() : [],
  ]);

  return {
    revurderinger, koerselstyper, tidspunkter, hjemler, afgoerelsesbreve,
    koerselstypeTillaeg, dage, statuser, skolematrikler,
    sagsbehandlere, pprSagsbehandlere, hjaelpemidler, ungdomsuddannelser, rutetyper,
  };
};
