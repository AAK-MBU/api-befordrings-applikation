/**
 * Shared date validation.
 *
 * Native `<input type="date">` accepts years far outside anything meaningful
 * for this domain (HTML allows years up to 275760), so a fat-fingered entry
 * like "202365-01-01" is technically "valid" to the browser. We define a valid
 * date as a real calendar date with an exactly-4-digit year.
 *
 * Note: the `max="9999-12-31"` attribute on the inputs bounds the picker and
 * shows the field as invalid, but does NOT block the value from being read via
 * `bind:value` — these forms submit via JS, so the guard below is what actually
 * stops a bad value from being sent.
 */

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/**
 * True when `value` is a real calendar date written as `YYYY-MM-DD` with a
 * 4-digit year. Empty/`null`/`undefined` are treated as "not provided" and
 * return `true` (use a separate required-check where a date is mandatory).
 */
export function isValidDate(value: unknown): boolean {
  if (value === null || value === undefined || value === "") {
    return true;
  }

  if (typeof value !== "string" || !ISO_DATE.test(value)) {
    return false;
  }

  // Reject impossible calendar dates (e.g. 2026-02-30). Compare components in
  // UTC so the check is timezone-independent: constructing the date and reading
  // it back must yield the same year/month/day (rollover changes them).
  const [year, month, day] = value.split("-").map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));

  return (
    parsed.getUTCFullYear() === year &&
    parsed.getUTCMonth() === month - 1 &&
    parsed.getUTCDate() === day
  );
}

/**
 * Returns the first `[key, value]` whose value is a present-but-invalid date,
 * or `null` if all provided date values are valid. Only keys in `dateKeys`
 * are checked, so non-date fields are ignored.
 */
export function firstInvalidDate(
  payload: Record<string, unknown>,
  dateKeys: string[],
): [string, unknown] | null {
  for (const key of dateKeys) {
    const value = payload[key];

    if (value !== null && value !== undefined && value !== "" && !isValidDate(value)) {
      return [key, value];
    }
  }

  return null;
}
