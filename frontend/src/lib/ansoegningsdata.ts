/**
 * What the citizen asked for, read back off Bevilling.ansoegningsdata.
 *
 * Written by the backend at creation from the OS2Forms submission — see
 * migration 029 and app/utils/os2forms_mapping.py. NULL on every bevilling a
 * caseworker made by hand, and on everything predating that migration, so
 * every reader here has to cope with nothing at all.
 *
 * Used to prefill "+ Ny kørselsrække". The rules are deliberately cautious: a
 * prefilled field is a field people accept without reading, so nothing is
 * filled in unless the application states it unambiguously.
 */

export type Koerselsoenske = {
  befordringstype: string | null;
  tidspunkt: string | null;
};

export type Ansoegningsdata = {
  koerselstyper: Koerselsoenske[];
  formular?: string | null;
  version?: number;
};

/**
 * Parse the stored JSON, or null when there is nothing usable.
 *
 * Never throws. The column is free-form text as far as the database is
 * concerned, and a prefill is a convenience — it must not be able to stop a
 * caseworker opening the form.
 */
export function parseAnsoegningsdata(raw: unknown): Ansoegningsdata | null {
  if (!raw) return null;

  let data: unknown = raw;

  if (typeof raw === "string") {
    try {
      data = JSON.parse(raw);
    } catch {
      return null;
    }
  }

  if (typeof data !== "object" || data === null) return null;

  const koerselstyper = (data as Ansoegningsdata).koerselstyper;

  if (!Array.isArray(koerselstyper) || koerselstyper.length === 0) return null;

  return { ...(data as Ansoegningsdata), koerselstyper };
}

/**
 * The single befordringstype to prefill, or null.
 *
 * Only when the application names exactly one. Where several were ticked the
 * caseworker has to choose, and the form says so rather than picking the first
 * — see `multipleTypesNotice`.
 */
export function singleBefordringstype(data: Ansoegningsdata | null): string | null {
  if (!data || data.koerselstyper.length !== 1) return null;

  return data.koerselstyper[0]?.befordringstype ?? null;
}

/**
 * The tidspunkt to prefill, or null.
 *
 * Prefilled when every stated tidspunkt agrees — including across several
 * kørselstyper, since the caseworker then still knows when the kørsel is
 * wanted even though they must pick the type themselves.
 *
 * Entries with no tidspunkt are ignored rather than treated as disagreement:
 * the skolerejsekort checkbox has no morning/afternoon question at all, so a
 * null there means "not asked", not "something different".
 */
export function sharedTidspunkt(data: Ansoegningsdata | null): string | null {
  if (!data) return null;

  const stated = data.koerselstyper
    .map((k) => k.tidspunkt)
    .filter((t): t is string => !!t);

  if (stated.length === 0) return null;

  return stated.every((t) => t === stated[0]) ? stated[0] : null;
}

/**
 * A line telling the caseworker what the application actually asked for, or
 * null when there is nothing worth saying.
 *
 * Shown whenever several kørselstyper were requested — that is the case where
 * the form cannot prefill the type, and the case where the other wishes are
 * easiest to forget once the first række exists.
 */
export function multipleTypesNotice(data: Ansoegningsdata | null): string | null {
  if (!data || data.koerselstyper.length < 2) return null;

  const names = data.koerselstyper
    .map((k) => k.befordringstype)
    .filter((n): n is string => !!n);

  if (names.length < 2) return null;

  return `Ansøgningen nævner ${names.length} kørselstyper: ${names.join(", ")}.`;
}
