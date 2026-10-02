import { csvCpr, csvResponse, type CsvColumn } from "$lib/server/csv";
import { backendUserFetcher } from "$lib/server/backendApi";

import type { RequestHandler } from "./$types";


/**
 * CSV of everyone currently receiving kørselsgodtgørelse for egenbefordring.
 *
 * The CSV mechanics — separator, BOM, quoting, filename, headers — live in
 * $lib/server/csv so every dataudtræk in the application behaves identically
 * in Excel. This route only says which endpoint and which columns.
 */

const COLUMNS: CsvColumn[] = [
  { key: "modtager_navn", header: "Navn" },
  { key: "modtager_cpr", header: "CPR", format: csvCpr },
  { key: "modtager_type", header: "Type" },
  { key: "elever", header: "Elever" },
  { key: "antal_elever", header: "Antal elever" },
  { key: "antal_koerselsraekker", header: "Antal kørselsrækker" },
];


export const GET: RequestHandler = async (event) => {
  const api = backendUserFetcher(event);

  const res = await api("/overview/koerselsgodtgoerelse_modtagere");

  if (!res.ok) {
    console.error("Failed to fetch kørselsgodtgørelse modtagere:", res.status);

    return new Response("Kunne ikke hente modtagerlisten", { status: 502 });
  }

  const rows: Record<string, unknown>[] = await res.json();

  return csvResponse(rows, COLUMNS, "koerselsgodtgoerelse-modtagere");
};
