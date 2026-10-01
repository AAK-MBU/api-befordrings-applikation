// Afstandskriteriet: how far a student must live from school to qualify for
// befordring, and when that threshold next changes for them.
//
// The bands come from the befordringsdata sheet:
//
//     0.–3. klasse   > 2,5 km
//     4.–6. klasse   > 6 km
//     7.–9. klasse   > 7 km
//     10. klasse     > 9 km
//
// Two things are derived from them, both of which used to be typed by hand:
//
//   afstandskriterie_klassetrin — the LAST klassetrin the student still meets
//     the criterion in, given their measured distance. The thresholds rise
//     with age, so a student far enough from school keeps qualifying into
//     later bands; one barely above their current threshold does not.
//
//   afstandskriterie_dato — when that stops. Always 30 June, because a Danish
//     school year ends there; the year is the one in which the student
//     finishes the klassetrin above.
//
// Both need the DISTANCE as well as the klassetrin. Without it there is no
// answer, only a guess that the student stops qualifying at the end of their
// current band.

export type Afstandsband = {
  /** Last klassetrin this band covers. */
  tilKlassetrin: number;
  /** The student must live further than this to qualify. */
  graenseKm: number;
};

export const AFSTANDSBAND: readonly Afstandsband[] = [
  { tilKlassetrin: 3, graenseKm: 2.5 },
  { tilKlassetrin: 6, graenseKm: 6 },
  { tilKlassetrin: 9, graenseKm: 7 },
  { tilKlassetrin: 10, graenseKm: 9 }
];

/** How close to the threshold counts as worth flagging. */
export const MARGIN_KM = 0.5;

/** The klassetrin values afstandskriterie_klassetrin can take. */
export const AFSTANDSKRITERIE_KLASSETRIN = AFSTANDSBAND.map((band) => band.tilKlassetrin);


/**
 * Read a klassetrin off the Elev record.
 *
 * elevklassetrin is a free string column, so it can hold "1", "01", "0" — and
 * for a student at an ungdomsuddannelse, nothing meaningful at all. Anything
 * that is not a folkeskole klassetrin yields null, which switches every
 * calculation below off rather than guessing.
 */
export function parseKlassetrin(value: string | number | null | undefined): number | null {
  const match = String(value ?? "").trim().match(/^\d+/);

  if (!match) {
    return null;
  }

  const klassetrin = Number(match[0]);

  if (klassetrin < 0 || klassetrin > 10) {
    return null;
  }

  return klassetrin;
}


/** The band a klassetrin falls in, or null when it is outside folkeskolen. */
export function bandForKlassetrin(klassetrin: number | null): Afstandsband | null {
  if (klassetrin === null) {
    return null;
  }

  return AFSTANDSBAND.find((band) => klassetrin <= band.tilKlassetrin) ?? null;
}


/** The distance a student in this klassetrin must exceed to qualify, in km. */
export function graenseForKlassetrin(elevklassetrin: string | number | null | undefined): number | null {
  return bandForKlassetrin(parseKlassetrin(elevklassetrin))?.graenseKm ?? null;
}


/**
 * afstandskriterie_klassetrin — the last klassetrin the student still meets the
 * criterion in, given how far they actually live from school.
 *
 * The thresholds RISE with age, so a student well above their current band
 * keeps qualifying into later ones. This walks upward from the band they are
 * in now and stops at the first threshold the distance does not clear:
 *
 *     3. klasse, 10,3 km  ->  10   (clears 2,5 / 6 / 7 / 9)
 *     3. klasse,  6,5 km  ->   6   (clears 2,5 and 6, fails 7)
 *     5. klasse,  6,8 km  ->   6   (clears 6, fails 7)
 *
 * This used to return the end of the current band and never look at the
 * distance at all, which happened to be right whenever the distance failed the
 * NEXT threshold — the common case — and understated every other student by
 * years.
 *
 * Strictly greater than: the rule is "længere end", so a distance exactly on a
 * threshold does not clear it.
 *
 * null when the student does not meet even their current threshold. There is
 * then no period during which the criterion holds, and a number would claim
 * otherwise.
 */
export function beregnAfstandskriterieKlassetrin(
  elevklassetrin: string | number | null | undefined,
  skoleafstandKm: number | string | null | undefined
): number | null {
  const klassetrin = parseKlassetrin(elevklassetrin);
  const nuvaerende = bandForKlassetrin(klassetrin);

  if (klassetrin === null || !nuvaerende) {
    return null;
  }

  if (skoleafstandKm === null || skoleafstandKm === undefined || skoleafstandKm === "") {
    return null;
  }

  const afstand = Number(skoleafstandKm);

  if (Number.isNaN(afstand)) {
    return null;
  }

  let sidste: number | null = null;

  for (const band of AFSTANDSBAND) {
    // Bands the student has already passed say nothing about their future.
    if (band.tilKlassetrin < nuvaerende.tilKlassetrin) {
      continue;
    }

    if (afstand > band.graenseKm) {
      sidste = band.tilKlassetrin;
    } else {
      break;
    }
  }

  return sidste;
}


/**
 * afstandskriterie_dato for a student, as an ISO date string ("2029-06-30").
 *
 * A Danish school year runs August–June, so the year a student is currently in
 * ends on 30 June of the *next* calendar year once August has passed. From
 * there it is one 30 June per remaining klassetrin in the band. July counts
 * with the year just finished: the Elev record still holds the klassetrin the
 * student completed, not the one they are about to start.
 */
export function beregnAfstandskriterieDato(
  elevklassetrin: string | number | null | undefined,
  skoleafstandKm: number | string | null | undefined,
  today: Date = new Date()
): string | null {
  const klassetrin = parseKlassetrin(elevklassetrin);
  const tilKlassetrin = beregnAfstandskriterieKlassetrin(elevklassetrin, skoleafstandKm);

  if (klassetrin === null || tilKlassetrin === null) {
    return null;
  }

  const skoleaarSlutter =
    today.getMonth() >= 7 ? today.getFullYear() + 1 : today.getFullYear();

  return `${skoleaarSlutter + (tilKlassetrin - klassetrin)}-06-30`;
}


export type AfstandsMargin = {
  graenseKm: number;
  /** How far the student is from the threshold, always positive. */
  afvigelseKm: number;
  /** True when they are above the threshold (qualifying), false when below. */
  over: boolean;
};


/**
 * Whether a student's distance sits close enough to their threshold to be worth
 * a second look, in either direction.
 *
 * Strictly inside the margin: at exactly 500 m the distance is not flagged, so
 * a threshold of 2,5 km flags 2,1 and 2,9 but not 2,0 or 3,0.
 *
 * Returns null when there is nothing to compare — no klassetrin, or no measured
 * distance.
 */
export function afstandsMargin(
  elevklassetrin: string | number | null | undefined,
  skoleafstandKm: number | string | null | undefined
): AfstandsMargin | null {
  const graenseKm = graenseForKlassetrin(elevklassetrin);

  if (graenseKm === null || skoleafstandKm === null || skoleafstandKm === undefined || skoleafstandKm === "") {
    return null;
  }

  const afstand = Number(skoleafstandKm);

  if (Number.isNaN(afstand)) {
    return null;
  }

  const forskel = afstand - graenseKm;

  if (Math.abs(forskel) >= MARGIN_KM) {
    return null;
  }

  return {
    graenseKm,
    afvigelseKm: Math.abs(forskel),
    over: forskel >= 0
  };
}


/** Danish one-liner for the margin flag, e.g. "0,4 km under grænsen på 2,5 km". */
export function formatAfstandsMargin(margin: AfstandsMargin): string {
  const afvigelse = margin.afvigelseKm.toFixed(1).replace(".", ",");
  const graense = String(margin.graenseKm).replace(".", ",");

  return `${afvigelse} km ${margin.over ? "over" : "under"} grænsen på ${graense} km`;
}
