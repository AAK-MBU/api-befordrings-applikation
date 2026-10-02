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

// TAB, not semicolon or comma.
//
// Excel does not read the separator from the file — it uses the system list
// separator from Windows' regional settings, so a semicolon file opens as one
// column on a machine set to an English locale. The "sep=;" directive fixes
// that, but Excel honours EITHER that directive OR the UTF-8 BOM, never both:
// with sep= present it ignores the BOM and falls back to the ANSI codepage,
// and "Kørselstyper" arrives as "KÃ¸rselstyper".
//
// A tab needs neither. Excel splits on tabs in a UTF-16 file regardless of
// locale, so the separator and the encoding stop fighting.
const SEPARATOR = "\t";

// UTF-16 little-endian, which is what makes the tab above work: Excel detects
// UTF-16 from the FF FE byte-order mark and parses the file as text rather
// than through the locale-dependent CSV path. UTF-8 with a BOM reads the
// characters correctly too, but only under that CSV path — which is where the
// separator problem lives.
//
// Danish names are the whole reason this matters. æ, ø and å mangled on a
// list of children is not cosmetic.
const ENCODING = "utf16le";
const BOM = "\ufeff";

// Excel wants CRLF; LF alone leaves some versions showing one long row.
const LINJESKIFT = "\r\n";


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


/** The CSV text: BOM, header line, then the data rows. Tab-separated. */
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

  return BOM + linjer.join(LINJESKIFT);
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

  // Encoded to UTF-16LE bytes rather than handed over as a JS string, which
  // the platform would otherwise serialise as UTF-8.
  return new Response(Buffer.from(csvBody(rows, columns), ENCODING), {
    headers: {
      "Content-Type": "text/csv; charset=utf-16le",
      "Content-Disposition": `attachment; filename="${filnavn}-${dato}.csv"`,
      "Cache-Control": "no-store",
    },
  });
}
