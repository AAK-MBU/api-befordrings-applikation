/**
 * Tidspunkt classification — "does this kørsel include an afternoon leg?"
 *
 * Only an afternoon journey can go to an institution: a morning kørsel takes
 * the child from home to school, and an SFO or klub is where they go after.
 * So "Kørsel til institution" is a question that only applies to Eftermiddag
 * and Morgen og eftermiddag.
 *
 * Matched on the LABEL rather than the id, for the same reason
 * $lib/koerselstype does: ids are per-environment autoincrements, while the
 * Tidspunkt texts are the business terms and are stable.
 */

export type TidspunktOption = { id: number | string; label: string };

export function labelForTidspunkt(
  tidspunkter: TidspunktOption[] | null | undefined,
  tidspunktId: string | number | null | undefined
): string | undefined {
  if (!tidspunktId) return undefined;

  return (tidspunkter ?? []).find(
    (tidspunkt) => Number(tidspunkt.id) === Number(tidspunktId)
  )?.label;
}

/**
 * True when the label covers an afternoon leg.
 *
 * Substring rather than an equality list, because it has to be true for both
 * "Eftermiddag" and "Morgen og eftermiddag" — and false for "Morgen". A new
 * combination containing the word is classified correctly without this needing
 * to be edited.
 */
export function labelHarEftermiddag(label: string | null | undefined): boolean {
  return String(label ?? "").trim().toLowerCase().includes("eftermiddag");
}

/**
 * True when the chosen tidspunkt includes an afternoon leg, and therefore when
 * "Kørsel til institution" is a meaningful question.
 *
 * An unknown or unset tidspunkt answers false: the field stays hidden until a
 * tidspunkt is chosen, rather than appearing and then vanishing.
 */
export function harEftermiddag(
  tidspunkter: TidspunktOption[] | null | undefined,
  tidspunktId: string | number | null | undefined
): boolean {
  return labelHarEftermiddag(labelForTidspunkt(tidspunkter, tidspunktId));
}
