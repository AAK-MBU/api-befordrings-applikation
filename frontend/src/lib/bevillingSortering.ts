/**
 * The order a student's bevillinger are shown in.
 *
 * Active first, then by the latest gyldig_til across their kørselsrækker,
 * descending. Bevillinger with no kørselsrækker sort to the bottom.
 *
 * Active trumps a future or more recently created one, because that is the
 * bevilling a caseworker is actually working on — the one deciding what the
 * child is driven by today. The API returns them in `created_at DESC`, which
 * is neither that order nor a total one: created_at has no tiebreaker, so two
 * bevillinger created in the same transaction ("+ Ny bevilling fra kopi") can
 * come back either way round.
 *
 * Lives here rather than in $lib/server/sagData so the pages that fetch
 * client-side can use the same function. It used to sit in sagData alone,
 * which meant the sag page showed the active bevilling first while the
 * revurdering and genbehandling panels showed the newest — the same student,
 * two different orders, on the page where the active one matters most.
 */

type MedKoerselsraekker = {
  status_tekst?: string | null;
  koerselsraekker?: { gyldig_til?: string | null }[] | null;
};

/** The last day any of a bevilling's kørselsrækker covers, "" when it has none. */
function senesteGyldigTil(bevilling: MedKoerselsraekker): string {
  return (bevilling.koerselsraekker ?? []).reduce(
    (max: string, raekke) => {
      const til = raekke?.gyldig_til ?? "";
      return til > max ? til : max;
    },
    ""
  );
}

function erAktiv(bevilling: MedKoerselsraekker): number {
  return bevilling.status_tekst === "Aktiv" ? 1 : 0;
}

export function sorterBevillinger<T extends MedKoerselsraekker>(
  bevillinger: T[]
): T[] {
  return [...bevillinger].sort((a, b) => {
    const aktivDiff = erAktiv(b) - erAktiv(a);

    if (aktivDiff !== 0) {
      return aktivDiff;
    }

    // ISO dates, so a string comparison is a date comparison.
    return senesteGyldigTil(b).localeCompare(senesteGyldigTil(a));
  });
}
