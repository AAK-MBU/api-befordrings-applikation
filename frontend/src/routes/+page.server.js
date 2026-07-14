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
  const bevillingerRes = await backendApiFetch(
    fetch,
    "/overview/alle_bevillinger"
  );

  await assertResponseOk(
    bevillingerRes,
    "Failed to fetch bevillinger"
  );

  const bevillinger = await bevillingerRes.json();

  return { bevillinger };
}