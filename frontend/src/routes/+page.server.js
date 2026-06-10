import { backendApiFetch } from "$lib/server/backendApi";


async function assertResponseOk(response, errorMessage) {
  if (response.ok) {
    return;
  }

  const errorText = await response.text();

  console.error(errorMessage);
  console.error("Status:", response.status);
  console.error("Response:", errorText);

  throw new Error(`${errorMessage}: ${response.status}`);
}


export async function load({ fetch }) {
  const activeBevillingerRes = await backendApiFetch(
    fetch,
    "/overview/aktive_bevillinger"
  );

  const fejledeBevillingerRes = await backendApiFetch(
    fetch,
    "/overview/fejlede_bevillinger"
  );

  await assertResponseOk(
    activeBevillingerRes,
    "Failed to fetch active bevillinger"
  );

  await assertResponseOk(
    fejledeBevillingerRes,
    "Failed to fetch fejlede bevillinger"
  );

  const activeBevillinger = await activeBevillingerRes.json();
  const fejledeBevillinger = await fejledeBevillingerRes.json();

  return {
    activeBevillinger,
    fejledeBevillinger
  };
}