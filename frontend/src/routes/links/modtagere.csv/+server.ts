import { backendUserFetcher } from "$lib/server/backendApi";

import type { RequestHandler } from "./$types";


/**
 * CSV of everyone currently receiving kørselsgodtgørelse for egenbefordring.
 *
 * Served from a SvelteKit route rather than fetched in the browser and turned
 * into a Blob: the <a download> then carries the session cookie on its own, the
 * browser owns the save dialog, and nothing has to be held in memory client
 * side.
 *
 * Formatted here rather than in the backend so /overview/koerselsgodtgoerelse_
 * modtagere stays a plain JSON endpoint that other callers can reuse.
 */

// Danish Excel splits on semicolon, not comma — a comma-separated file opens as
// a single column per row, which looks like the export is broken.
const SEPARATOR = ";";

// Excel only recognises a UTF-8 CSV when it starts with a BOM. Without it æ, ø
// and å arrive mangled, which on a list of people's names is not cosmetic.
const BOM = "﻿";

const COLUMNS: { key: string; header: string }[] = [
  { key: "modtager_navn", header: "Navn" },
  { key: "modtager_cpr", header: "CPR" },
  { key: "modtager_type", header: "Type" },
  { key: "elever", header: "Elever" },
  { key: "antal_elever", header: "Antal elever" },
  { key: "antal_koerselsraekker", header: "Antal kørselsrækker" },
];

/**
 * Quote a CSV field.
 *
 * Always quoted rather than only when needed: a CPR like 0101101234 is
 * otherwise read as a number and loses its leading zero, which is the classic
 * way a CPR column arrives in Excel corrupted.
 */
function csvField(value: unknown): string {
  const text = value === null || value === undefined ? "" : String(value);

  return `"${text.replace(/"/g, '""')}"`;
}

export const GET: RequestHandler = async (event) => {
  const api = backendUserFetcher(event);

  const res = await api("/overview/koerselsgodtgoerelse_modtagere");

  if (!res.ok) {
    console.error("Failed to fetch kørselsgodtgørelse modtagere:", res.status);

    return new Response("Kunne ikke hente modtagerlisten", { status: 502 });
  }

  const rows: Record<string, unknown>[] = await res.json();

  const lines = [
    COLUMNS.map((column) => csvField(column.header)).join(SEPARATOR),
    ...rows.map((row) => COLUMNS.map((column) => csvField(row[column.key])).join(SEPARATOR)),
  ];

  // Dated so a caseworker downloading monthly ends up with a usable archive
  // rather than a folder of "modtagere (3).csv".
  const today = new Date().toISOString().slice(0, 10);

  return new Response(BOM + lines.join("\r\n"), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="koerselsgodtgoerelse-modtagere-${today}.csv"`,
      // A list of names and CPR numbers should not sit in any cache.
      "Cache-Control": "no-store",
    },
  });
};
