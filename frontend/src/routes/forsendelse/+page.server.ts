import { backendUserFetcher } from "$lib/server/backendApi";

import type { PageServerLoad } from "./$types";


export const load: PageServerLoad = async (event) => {
  const api = backendUserFetcher(event);

  const res = await api("/brev/forsendelse");

  if (!res.ok) {
    console.error("Failed to fetch forsendelser:", res.status);
    return { forsendelser: [] };
  }

  return { forsendelser: await res.json() };
};
