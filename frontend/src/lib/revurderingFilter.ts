/**
 * The revurdering page's filter, shared by the page and its CSV export.
 *
 * Extracted rather than reimplemented server side. An export that applies its
 * own copy of the rules drifts from the list the caseworker is looking at, and
 * the failure is silent: the file simply contains a different set of cases than
 * the screen showed, and nobody can tell which one is right.
 *
 * So the predicate lives here, the page filters with it, and the export route
 * parses the same filter out of the query string and applies the same
 * function.
 */

export type RevurderingFilter = {
  skole: string;
  sagsbehandler: string;
  pprSagsbehandler: string;
  koerselstype: string;
  fraDato: string;
  tilDato: string;
  hurtigfilter: "" | "overskredet" | "inden30";
};

export const TOMT_FILTER: RevurderingFilter = {
  skole: "",
  sagsbehandler: "",
  pprSagsbehandler: "",
  koerselstype: "",
  fraDato: "",
  tilDato: "",
  hurtigfilter: "",
};

// Query-string names, kept short because they end up in a visible URL.
const PARAM: Record<keyof RevurderingFilter, string> = {
  skole: "skole",
  sagsbehandler: "sb",
  pprSagsbehandler: "ppr",
  koerselstype: "type",
  fraDato: "fra",
  tilDato: "til",
  hurtigfilter: "hurtig",
};


/**
 * Whole days from today until `dateStr`; negative when it has passed.
 *
 * Both sides are built from calendar parts in UTC, so the subtraction is exact
 * whole days. Mixing a UTC-parsed date string with a local midnight — the
 * obvious implementation — leaves the two one timezone offset apart.
 */
export function daysUntil(dateStr: string | null | undefined): number | null {
  if (!dateStr) return null;

  const [aar, maaned, dag] = String(dateStr).slice(0, 10).split("-").map(Number);

  if (!aar || !maaned || !dag) return null;

  const nu = new Date();
  const iDag = Date.UTC(nu.getFullYear(), nu.getMonth(), nu.getDate());
  const maal = Date.UTC(aar, maaned - 1, dag);

  return Math.round((maal - iDag) / 86400000);
}


/** The kørselstyper on a row's kørselsrækker that are not locked. */
function aktiveKoerselstyper(row: any): string[] {
  return (row.koerselsraekker ?? [])
    .filter((k: any) => !k.final)
    .map((k: any) => k.befordringstype_tekst)
    .filter(Boolean);
}


/** True when `row` belongs in the filtered view. */
export function matcherFilter(row: any, filter: RevurderingFilter): boolean {
  if (filter.skole && row.skole_navn !== filter.skole) return false;
  if (filter.sagsbehandler && row.sagsbehandler_tekst !== filter.sagsbehandler) return false;
  if (filter.pprSagsbehandler && row.ppr_sagsbehandler_tekst !== filter.pprSagsbehandler) {
    return false;
  }

  if (filter.koerselstype && !aktiveKoerselstyper(row).includes(filter.koerselstype)) {
    return false;
  }

  // A row with no revurderingsdato is deliberately NOT excluded by the date
  // range — it has no date to fall outside it.
  if (row.revurderingsdato) {
    if (filter.fraDato && row.revurderingsdato < filter.fraDato) return false;
    if (filter.tilDato && row.revurderingsdato > filter.tilDato) return false;
  }

  if (filter.hurtigfilter === "overskredet") {
    if ((daysUntil(row.revurderingsdato) ?? 0) >= 0) return false;
  }

  if (filter.hurtigfilter === "inden30") {
    const dage = daysUntil(row.revurderingsdato);
    if (dage === null || dage < 0 || dage > 30) return false;
  }

  return true;
}


/** True when any part of the filter narrows the list. */
export function harAktivtFilter(filter: RevurderingFilter): boolean {
  return Object.values(filter).some(Boolean);
}


/** The filter as query-string parameters, omitting the empty ones. */
export function filterTilQuery(filter: RevurderingFilter): string {
  const params = new URLSearchParams();

  for (const [key, navn] of Object.entries(PARAM) as [keyof RevurderingFilter, string][]) {
    const vaerdi = filter[key];

    if (vaerdi) params.set(navn, vaerdi);
  }

  return params.toString();
}


/**
 * The filter a query string describes.
 *
 * Unknown or missing parameters fall back to empty, so a hand-edited URL
 * narrows the export less than intended rather than failing — an export is a
 * read, and the caseworker can see from the file what it contained.
 */
export function filterFraQuery(params: URLSearchParams): RevurderingFilter {
  const hurtig = params.get(PARAM.hurtigfilter) ?? "";

  return {
    skole: params.get(PARAM.skole) ?? "",
    sagsbehandler: params.get(PARAM.sagsbehandler) ?? "",
    pprSagsbehandler: params.get(PARAM.pprSagsbehandler) ?? "",
    koerselstype: params.get(PARAM.koerselstype) ?? "",
    fraDato: params.get(PARAM.fraDato) ?? "",
    tilDato: params.get(PARAM.tilDato) ?? "",
    hurtigfilter:
      hurtig === "overskredet" || hurtig === "inden30" ? hurtig : "",
  };
}
