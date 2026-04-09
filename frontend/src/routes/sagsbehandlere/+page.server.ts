export async function load({ fetch }) {

  const res = await fetch("http://localhost:8000/overview/sagsbehandlere");

  if (!res.ok) {
    throw new Error("Failed to fetch sagsbehandlere");
  }

  const sagsbehandlere = await res.json();

  return {
    sagsbehandlere
  };
}