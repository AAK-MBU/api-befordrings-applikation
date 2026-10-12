/**
 * Rutetype classification — "does this kørsel include an afternoon leg?"
 *
 * The same question $lib/tidspunkt answers, asked of the other column.
 *
 * Rutetype now states where a trip starts and ends, which makes the time of
 * day derivable from it: only a route that STARTS at hjem happens in the
 * morning. That is what lets tidspunkt become optional and eventually go —
 * but "Kørsel til institution" still has to know whether there is an
 * afternoon, so the question needs an answer from rutetype too.
 *
 * Matched on the LABEL rather than the id, for the same reason $lib/tidspunkt
 * and $lib/koerselstype do: ids are per-environment autoincrements, the texts
 * are the business terms.
 */

export type RutetypeOption = { id: number | string; label: string };

/**
 * The rutetyper with no afternoon leg.
 *
 * An allow-list of the exceptions rather than a list of the six, because the
 * exceptions are the small, stable set: every other route ends somewhere
 * other than school, which only happens after school. "Mellem hjem og skole"
 * is deliberately NOT here — it covers both ends of the day.
 *
 * "Til skole" is the retiring equivalent of "Fra hjem til skole" and stays
 * until the old rutetyper are removed; see migration 032.
 */
const KUN_MORGEN = ["fra hjem til skole", "til skole"];

export function labelForRutetype(
  rutetyper: RutetypeOption[] | null | undefined,
  rutetypeId: string | number | null | undefined
): string | undefined {
  if (!rutetypeId) return undefined;

  return (rutetyper ?? []).find(
    (rutetype) => Number(rutetype.id) === Number(rutetypeId)
  )?.label;
}

/**
 * True when the chosen rutetype involves an afternoon leg.
 *
 * An unknown or unset rutetype answers false, matching harEftermiddag: the
 * field stays hidden until something has been chosen, rather than appearing
 * and then vanishing.
 */
export function harEftermiddagForRutetype(
  rutetyper: RutetypeOption[] | null | undefined,
  rutetypeId: string | number | null | undefined
): boolean {
  const label = labelForRutetype(rutetyper, rutetypeId);

  if (!label) return false;

  return !KUN_MORGEN.includes(label.trim().toLowerCase());
}
