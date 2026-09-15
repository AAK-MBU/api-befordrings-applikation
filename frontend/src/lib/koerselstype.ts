/**
 * Kørselstype classification — the single source of truth for "which kind of
 * kørsel is this?".
 *
 * These predicates decide which fields a kørselsrække form shows, which values
 * are nulled on save, and whether tillæg apply. They used to exist as three
 * near-copies (KoerselsraekkeTable, CreateBevillingModal, BevillingTable) that
 * had drifted apart: two normalised away whitespace, one did not, so it never
 * matched the real lookup label "Egen befordring" and its egenbefordring
 * distance recalculation silently did nothing.
 *
 * Everything here works off the label rather than the id, because the ids are
 * database identities that differ between environments while the labels are the
 * business terms the caseworkers use.
 */

export type KoerselstypeOption = { id: number | string; label: string };

/**
 * Kørselstyper that are a form of taxa/vogn kørsel. These are the types where
 * Taxa-ID, kørsel til institution and max. transporttid are relevant, and the
 * only ones that can carry tillæg.
 */
export const TAXA_TYPES = new Set([
  "rutekørsel",
  "skånekørsel",
  "solokørsel",
  "variabel kørsel",
]);

/**
 * Kørselstyper the midlertidig-kørsel form actually offers. The lookup table
 * holds every type used anywhere in the system, so without this a caseworker
 * can pick one the form could never have produced.
 *
 * Compared with whitespace stripped, because the lookup labels are not
 * consistent about it ("Variabel kørsel" vs "Variabelkørsel").
 */
export const MIDLERTIDIG_ALLOWED = new Set([
  "egenbefordring",
  "skolerejsekort",
  "rutekørsel",
  "solokørsel",
  "variabelkørsel",
  "skånekørsel",
]);

export function normalizeType(label: string | null | undefined): string {
  return String(label ?? "").trim().toLowerCase();
}

/** Whitespace-insensitive form, for labels that are written both ways. */
function normalizeTypeCompact(label: string | null | undefined): string {
  return normalizeType(label).replace(/\s/g, "");
}

export function labelForType(
  koerselstyper: KoerselstypeOption[] | null | undefined,
  typeId: string | number | null | undefined
): string | undefined {
  if (!typeId) return undefined;

  return (koerselstyper ?? []).find(
    (type: any) => Number(type.id) === Number(typeId)
  )?.label;
}

// Tolerate both "Egen befordring" (the seeded label) and "Egenbefordring".
export function labelIsEgenbefordring(label: string | null | undefined): boolean {
  return normalizeTypeCompact(label) === "egenbefordring";
}

export function labelIsTaxa(label: string | null | undefined): boolean {
  return TAXA_TYPES.has(normalizeType(label));
}

// Transporttid i bus / antal skift only apply to Skolerejsekort.
export function labelIsSkolerejsekort(label: string | null | undefined): boolean {
  return normalizeType(label) === "skolerejsekort";
}

/**
 * Tillæg only apply to befordringstyper that are a form of "kørsel"
 * (Rutekørsel, Skånekørsel, …) — not Skolerejsekort, Skolebus or Cykelbus.
 * Currently the same set as the taxa types; kept separate because it answers a
 * different question and may diverge.
 */
export function labelIsKoersel(label: string | null | undefined): boolean {
  return labelIsTaxa(label);
}

export function isEgenbefordring(
  koerselstyper: KoerselstypeOption[] | null | undefined,
  typeId: string | number | null | undefined
): boolean {
  return labelIsEgenbefordring(labelForType(koerselstyper, typeId));
}

export function isTaxaType(
  koerselstyper: KoerselstypeOption[] | null | undefined,
  typeId: string | number | null | undefined
): boolean {
  return labelIsTaxa(labelForType(koerselstyper, typeId));
}

export function isSkolerejsekort(
  koerselstyper: KoerselstypeOption[] | null | undefined,
  typeId: string | number | null | undefined
): boolean {
  return labelIsSkolerejsekort(labelForType(koerselstyper, typeId));
}

export function isKoerselType(
  koerselstyper: KoerselstypeOption[] | null | undefined,
  typeId: string | number | null | undefined
): boolean {
  return labelIsKoersel(labelForType(koerselstyper, typeId));
}

/**
 * The kørselstyper a form should offer for the given ansøgningstype.
 * Midlertidig kørsel is restricted; everything else gets the full list.
 */
export function availableKoerselstyper(
  koerselstyper: KoerselstypeOption[] | null | undefined,
  ansoegningstype: string | null | undefined
): KoerselstypeOption[] {
  const alle = koerselstyper ?? [];

  if (ansoegningstype !== "Midlertidig kørsel") return alle;

  return alle.filter((type) => MIDLERTIDIG_ALLOWED.has(normalizeTypeCompact(type.label)));
}
