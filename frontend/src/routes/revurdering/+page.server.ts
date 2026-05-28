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
  ] = await Promise.all([
    backendApiFetch(fetch, "/overview/revurderinger"),
    backendApiFetch(fetch, "/lookup/koerselstyper"),
    backendApiFetch(fetch, "/lookup/tidspunkter"),
    backendApiFetch(fetch, "/lookup/hjemler"),
    backendApiFetch(fetch, "/lookup/afgoerelsesbreve"),
    backendApiFetch(fetch, "/lookup/koerselstype_tillaeg"),
    backendApiFetch(fetch, "/lookup/dage"),
  ]);

  if (!revurderingerRes.ok) {
    console.error("Failed to fetch revurderinger:", revurderingerRes.status);
    return { revurderinger: [], koerselstyper: [], tidspunkter: [], hjemler: [], afgoerelsesbreve: [], koerselstypeTillaeg: [], dage: [] };
  }

  const [revurderinger, koerselstyper, tidspunkter, hjemler, afgoerelsesbreve, koerselstypeTillaeg, dage] = await Promise.all([
    revurderingerRes.json(),
    koerselstyperRes.ok ? koerselstyperRes.json() : [],
    tidspunkterRes.ok ? tidspunkterRes.json() : [],
    hjemlerRes.ok ? hjemlerRes.json() : [],
    afgoerelsesbreveRes.ok ? afgoerelsesbreveRes.json() : [],
    koerselstypeTillaegRes.ok ? koerselstypeTillaegRes.json() : [],
    dageRes.ok ? dageRes.json() : [],
  ]);

  return { revurderinger, koerselstyper, tidspunkter, hjemler, afgoerelsesbreve, koerselstypeTillaeg, dage };
};
