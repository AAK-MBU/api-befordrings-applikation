import { env as privateEnv } from '$env/dynamic/private';
import { env as publicEnv } from '$env/dynamic/public';

export async function load({ params, fetch }) {

  const { cpr } = params;

  const API_URL = publicEnv.PUBLIC_API_BASE_URL;

  const [stamdataRes, parentsRes, citizenBevillingerRes] = await Promise.all([
    fetch(`${API_URL}/citizen/stamdata/${cpr}`),
    fetch(`${API_URL}/citizen/stamdata/${privateEnv.PRIVATE_CPR}/parents`),
    fetch(`${API_URL}/bevilling/get_citizen_bevillinger/${cpr}`)
  ]);

  if (!stamdataRes.ok) {
    throw new Error("Failed to fetch stamdata");
  }

  if (!parentsRes.ok) {
    throw new Error("Failed to fetch parents");
  }

  if (!citizenBevillingerRes.ok) {
    throw new Error("Failed to fetch citizen bevillinger");
  }

  const stamdata = await stamdataRes.json();
  const parents = await parentsRes.json();
  const citizenBevillinger = await citizenBevillingerRes.json();

  return {
    stamdata,
    parents,
    citizenBevillinger
  };
}