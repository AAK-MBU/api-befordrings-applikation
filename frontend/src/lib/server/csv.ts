/**
 * CSV export, shared by every dataudtræk in the application.
 *
 * Exports are served from SvelteKit server routes rather than built in the
 * browser from a Blob: the <a download> then carries the session cookie on its
 * own, the browser owns the save dialog, and nothing has to be held in memory
 * client side.
 *
 * Formatting lives here rather than in the backend so the underlying API
 * endpoints stay plain JSON that other callers can reuse.
 *
 * Three details below are not preferences — each is a way a Danish Excel user
 * receives a file that looks broken, and each was found the hard way.
 */

export type CsvColumn = {
  /** Key on the row object. */
  key: string;
  /** Header text, as the caseworker should see it. */
  header: string;
  /** Optional formatter, for values that are not already strings. */
  format?: (value: unknown, row: Record<string, unknown>) => unknown;
};

// Danish Excel splits on semicolon, not comma — a comma-separated file opens
// as a single column per row, which looks like the export is broken.
const SEPARATOR = ";";

// Excel only recognises a UTF-8 CSV when it starts with a BOM. Without it æ, ø
// and å arrive mangled, which on a list of people's names is not cosmetic.
const BOM = "﻿";

// Excel wants CRLF; LF alone leaves some versions showing one long row.
const LINJESKIFT = "\r\n";

// Excel does NOT read the separator from the file — it uses the system list
// separator from Windows' regional settings. On a machine set to an English
// locale that is a comma, so a semicolon-separated file lands in a single
// column however well-formed it is. This directive overrides that, and Excel
// honours it regardless of locale.
//
// The cost: other readers see it as a row. pandas needs sep=";", skiprows=1,
// and Python's csv module the same. Worth it — these files are opened in
// Excel by caseworkers, not parsed.
const SEP_DIREKTIV = `sep=${SEPARATOR}`;


/**
 * Quote a CSV field.
 *
 * ALWAYS quoted, not only when the value contains a separator. A CPR like
 * 0101101234 is otherwise read as a number and loses its leading zero, which
 * is the classic way a CPR column arrives in Excel corrupted.
 */
export function csvField(value: unknown): string {
  const text = value === null || value === undefined ? "" : String(value);

  return `"${text.replace(/"/g, '""')}"`;
}


/** The CSV body: BOM, separator directive, header line, then the data rows. */
export function csvBody(
  rows: Record<string, unknown>[],
  columns: CsvColumn[]
): string {
  const linjer = [
    columns.map((column) => csvField(column.header)).join(SEPARATOR),
    ...rows.map((row) =>
      columns
        .map((column) =>
          csvField(column.format ? column.format(row[column.key], row) : row[column.key])
        )
        .join(SEPARATOR)
    ),
  ];

  return BOM + SEP_DIREKTIV + LINJESKIFT + linjer.join(LINJESKIFT);
}


/**
 * A downloadable CSV response.
 *
 * Args:
 *   rows: the data.
 *   columns: which fields, in which order, under which headers.
 *   filnavn: without the date or the extension — both are added.
 *
 * The filename is dated so a caseworker downloading monthly ends up with a
 * usable archive rather than a folder of "modtagere (3).csv".
 *
 * no-store because every export in this application contains personal data.
 */
export function csvResponse(
  rows: Record<string, unknown>[],
  columns: CsvColumn[],
  filnavn: string
): Response {
  const today = new Date();
  const dato = [
    today.getFullYear(),
    String(today.getMonth() + 1).padStart(2, "0"),
    String(today.getDate()).padStart(2, "0"),
  ].join("-");

  return new Response(csvBody(rows, columns), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${filnavn}-${dato}.csv"`,
      "Cache-Control": "no-store",
    },
  });
}
