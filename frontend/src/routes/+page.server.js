// Denne fil indeholder server-side kode til at hente befordringer fra backend API'et.
// Den bruger SvelteKits "load" funktion til at hente data, som derefter kan bruges i den tilhørende Svelte-komponent.
// Det returnerede objekt vil være tilgængeligt i komponenten som "data.befordringer".
export async function load({ fetch }) {
    const res = await fetch('http://localhost:8000/befordringer');
    const befordringer = await res.json();
    return { befordringer };
}