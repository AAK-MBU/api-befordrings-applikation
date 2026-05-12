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

  const notActiveBevillingerRes = await backendApiFetch(
    fetch,
    "/overview/ikke_aktive_bevillinger"
  );

  await assertResponseOk(
    activeBevillingerRes,
    "Failed to fetch active bevillinger"
  );

  await assertResponseOk(
    notActiveBevillingerRes,
    "Failed to fetch not active bevillinger"
  );

  const activeBevillinger = await activeBevillingerRes.json();
  const notActiveBevillinger = await notActiveBevillingerRes.json();

  return {
    activeBevillinger,
    notActiveBevillinger
  };
}