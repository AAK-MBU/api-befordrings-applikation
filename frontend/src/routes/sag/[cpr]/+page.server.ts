import { assertResponseOk, hentSagKerne } from "$lib/server/sagData";
import { backendUserFetcher } from "$lib/server/backendApi";

import type { PageServerLoad } from "./$types";


export const load: PageServerLoad = async (event) => {
  const { cpr } = event.params;
  const api = backendUserFetcher(event);

  // hentSagKerne is shared with /sag/[cpr]/opret-bevilling, which needs the
  // student, their bevillinger and the lookup lists but none of the three
  // below. Kept in the same Promise.all so this page still opens everything
  // in parallel.
  const [kerne, parentsRes, parterRes, aktiviteterRes] = await Promise.all([
    hentSagKerne(event, cpr),
    api(`/citizen/stamdata/${cpr}/parents`),
    api(`/part/${cpr}`),
    api(`/aktivitet/${cpr}`)
  ]);

  await assertResponseOk(parentsRes, "Failed to fetch parents");
  await assertResponseOk(parterRes, "Failed to fetch parter");
  await assertResponseOk(aktiviteterRes, "Failed to fetch aktiviteter");

  return {
    ...kerne,
    parents: await parentsRes.json(),
    parter: await parterRes.json(),
    aktiviteter: await aktiviteterRes.json()
  };
};
