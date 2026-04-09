import { env } from '$env/dynamic/private';

export async function load({ params, fetch }) {

  const { cpr } = params;

  const [stamdataRes, parentsRes, citizenBevillingerRes] = await Promise.all([
    fetch(`http://localhost:8000/citizen/stamdata/${cpr}`),
    fetch(`http://localhost:8000/citizen/stamdata/${env.PRIVATE_CPR}/parents`),
    fetch(`http://localhost:8000/bevilling/get_citizen_bevillinger/${cpr}`),
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