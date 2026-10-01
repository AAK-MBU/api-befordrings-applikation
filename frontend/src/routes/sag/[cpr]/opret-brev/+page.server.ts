import { hentSagKerne } from "$lib/server/sagData";

import type { PageServerLoad } from "./$types";


export const load: PageServerLoad = async (event) => {
  return await hentSagKerne(event, event.params.cpr);
};
