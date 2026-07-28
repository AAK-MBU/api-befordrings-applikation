// Business rule: narrow the selectable "Hjemmel" and "Afgørelsesbrev" options
// based on the chosen ansøgningstype (and, for "Midlertidig kørsel", the school
// type). Only "Midlertidig kørsel" is restricted today; every other
// ansøgningstype shows all active options unchanged.
//
// Options are matched by their TEXT (label), not by id: ids are per-environment
// autoincrements, whereas the afgørelsesbrev/hjemmel texts are the stable
// business keys in this system (the afgoerelsesbreve RPA keys its letter logic
// off the exact same afgørelsesbrev texts).

export type LookupOption = { id: number | string; label: string };

export type SkoleType = "folkeskole" | "ungdomsuddannelse" | null;

const MIDLERTIDIG = "Midlertidig kørsel";

// Collapse whitespace + trim so trivial spacing differences don't break a match.
function normalize(text: string): string {
  return String(text ?? "").replace(/\s+/g, " ").trim();
}

// Allowed afgørelsesbrev texts per "Midlertidig kørsel" + school type.
const AFGOERELSESBREV_ALLOW: Record<string, string[]> = {
  [`${MIDLERTIDIG}|folkeskole`]: [
    "Midlertidig kørsel bevilling: § 26, stk. 2 (brækket ben folkeskole)",
    "Midlertidig kørsel afslag: § 26, stk. 2 (brækket ben folkeskole)",
  ],
  [`${MIDLERTIDIG}|ungdomsuddannelse`]: [
    "Midlertidig kørsel bevilling: § 10 (brækket ben ungdomssuddannelse)",
    "Midlertidig kørsel afslag: § 10 (brækket ben ungdomssuddannelse)",
  ],
};

// Allowed hjemmel texts per "Midlertidig kørsel" + school type.
// NOTE: inferred from the § referenced by the afgørelsesbrev above (the request
// listed the afgørelsesbrev allow-list explicitly but not the hjemmel one).
// Adjust if the intended hjemmel mapping differs.
const HJEMMEL_ALLOW: Record<string, string[]> = {
  [`${MIDLERTIDIG}|folkeskole`]: ["§ 26, stk. 2 sygdom"],
  [`${MIDLERTIDIG}|ungdomsuddannelse`]: ["§ 10 (brækket ben)"],
};

// Returns the allow-list key when the current selection is a restricted case,
// otherwise null (meaning: no restriction, show everything).
function ruleKey(ansoegningstype: string | null | undefined, skoleType: SkoleType): string | null {
  if (ansoegningstype === MIDLERTIDIG && skoleType) {
    return `${MIDLERTIDIG}|${skoleType}`;
  }
  return null;
}

// Values that ONLY apply to Midlertidig kørsel — hidden for every other type.
// The afgørelsesbrev set is exactly the union of the allow-lists above (all four
// "Midlertidig kørsel …" texts). For hjemmel we only exclude § 10, since
// § 26, stk. 2 (sygdom) is also used by non-midlertidig afgørelsesbreve.
const MIDLERTIDIG_ONLY_AFGOERELSESBREVE = Object.values(AFGOERELSESBREV_ALLOW).flat();
const MIDLERTIDIG_ONLY_HJEMLER = ["§ 10 (brækket ben)"];

function applyRule(
  all: LookupOption[] | undefined,
  allow: string[] | undefined,
  excludeWhenUnrestricted: string[]
): LookupOption[] {
  const options = all ?? [];

  // Restricted case (Midlertidig kørsel + skoletype): show only the allow-list.
  if (allow) {
    const allowed = new Set(allow.map(normalize));
    return options.filter((option) => allowed.has(normalize(option.label)));
  }

  // Unrestricted case (all other types): show everything EXCEPT Midlertidig-only values.
  const excluded = new Set(excludeWhenUnrestricted.map(normalize));
  return options.filter((option) => !excluded.has(normalize(option.label)));
}

export function filterHjemler(
  all: LookupOption[] | undefined,
  ansoegningstype: string | null | undefined,
  skoleType: SkoleType
): LookupOption[] {
  const key = ruleKey(ansoegningstype, skoleType);
  return applyRule(all, key ? HJEMMEL_ALLOW[key] : undefined, MIDLERTIDIG_ONLY_HJEMLER);
}

export function filterAfgoerelsesbreve(
  all: LookupOption[] | undefined,
  ansoegningstype: string | null | undefined,
  skoleType: SkoleType
): LookupOption[] {
  const key = ruleKey(ansoegningstype, skoleType);
  return applyRule(all, key ? AFGOERELSESBREV_ALLOW[key] : undefined, MIDLERTIDIG_ONLY_AFGOERELSESBREVE);
}
