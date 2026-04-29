import { env as publicEnv } from "$env/dynamic/public";

export async function load({ fetch }) {
  const API_URL = publicEnv.PUBLIC_API_BASE_URL;

  const active_url = `${API_URL}/overview/aktive_bevillinger`;
  const not_active_url = `${API_URL}/overview/ikke_aktive_bevillinger`;

  console.log("Fetching active bevillinger from:", active_url);
  console.log("Fetching not active bevillinger from:", not_active_url);

  const activeBevillingerRes = await fetch(active_url);
  const notActiveBevillingerRes = await fetch(not_active_url);

  if (!activeBevillingerRes.ok) {
    const errorText = await activeBevillingerRes.text();

    console.error("Failed to fetch active bevillinger");
    console.error("Status:", activeBevillingerRes.status);
    console.error("Response:", errorText);

    throw new Error(`Failed to fetch active bevillinger: ${activeBevillingerRes.status}`);
  }

  if (!notActiveBevillingerRes.ok) {
    const errorText = await notActiveBevillingerRes.text();

    console.error("Failed to fetch active bevillinger");
    console.error("Status:", notActiveBevillingerRes.status);
    console.error("Response:", errorText);

    throw new Error(`Failed to fetch active bevillinger: ${notActiveBevillingerRes.status}`);
  }

  const activeBevillinger = await activeBevillingerRes.json();
  const notActiveBevillinger = await notActiveBevillingerRes.json();

  return {
    activeBevillinger,
    notActiveBevillinger,
  };
}