/**
 * "Which of a student's bevillinger is the current one?"
 *
 * The ranking is the same one the nightly sync uses to pick the bevilling a
 * student's matrikel is read from (usp_sync_elev_matrikel_from_bevilling):
 * an aktiv bevilling first, then a kommende one, and otherwise whichever
 * bevilling's kørsel ran latest.
 */

/** Statuses that rank ahead of everything else, best first. */
const STATUS_RANK: Record<string, number> = {
  aktiv: 0,
  kommende: 1
};

/** Any other status — Udløbet, Ophørt, Afslag, Fejlet, Ny, Påbegyndt. */
const OEVRIGE_RANK = 2;

function statusRank(bevilling: any): number {
  const status = String(bevilling?.status_tekst ?? "").trim().toLowerCase();

  return STATUS_RANK[status] ?? OEVRIGE_RANK;
}

/**
 * The latest gyldig_til across a bevilling's kørselsrækker, as "YYYY-MM-DD".
 *
 * Returns "" for a bevilling with no kørselsrækker or no end dates, which
 * sorts it below every bevilling that has one — a string compare on ISO dates
 * orders them correctly and "" is below any of them.
 */
function senesteGyldigTil(bevilling: any): string {
  const raekker: any[] = bevilling?.koerselsraekker ?? [];

  return raekker.reduce((senest: string, raekke: any) => {
    const dato = raekke?.gyldig_til ? String(raekke.gyldig_til).slice(0, 10) : "";

    return dato > senest ? dato : senest;
  }, "");
}

/**
 * Pick the student's current bevilling: aktiv, else kommende, else the one
 * whose kørsel ran latest. Ties inside a tier also fall to the latest
 * gyldig_til.
 *
 * Returns null when the student has no bevillinger at all.
 */
export function vaelgGaeldendeBevilling(bevillinger: any[] | null | undefined): any | null {
  const kandidater = (bevillinger ?? []).filter(Boolean);

  if (kandidater.length === 0) {
    return null;
  }

  return kandidater.reduce((bedste: any, bevilling: any) => {
    const rangforskel = statusRank(bevilling) - statusRank(bedste);

    if (rangforskel !== 0) {
      return rangforskel < 0 ? bevilling : bedste;
    }

    return senesteGyldigTil(bevilling) > senesteGyldigTil(bedste) ? bevilling : bedste;
  });
}
