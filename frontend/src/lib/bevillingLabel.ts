/**
 * How a bevilling is named on screen.
 *
 * Two numbers, two jobs:
 *
 *   loebenummer   counts within the child (1, 2, 3). This is what a caseworker
 *                 sees and refers to. bevilling_id counts across the whole
 *                 table, so a child with #1, #13 and #19 reads as a child with
 *                 sixteen bevillinger nobody can find.
 *
 *   bevilling_id  is the real key — API routes, audit log, foreign keys, and
 *                 anything reported to us as a bug. Never hidden, just demoted.
 *
 * Both are shown together wherever getting the wrong one would be costly.
 */

/** "Bevilling 2", or "Bevilling #13" for a row that has no number yet. */
export function bevillingLabel(bevilling: any): string {
  // Rows created before migration 008 ran — or read through a view that has not
  // been refreshed — have no loebenummer. Falling back to the system id keeps
  // the label truthful instead of rendering "Bevilling null".
  if (bevilling?.loebenummer == null) return `Bevilling #${bevilling?.bevilling_id ?? "?"}`;

  return `Bevilling ${bevilling.loebenummer}`;
}

/** "#13" — the system id, for support and destructive confirmations. */
export function bevillingSystemId(bevilling: any): string {
  return `#${bevilling?.bevilling_id ?? "?"}`;
}

/**
 * "Bevilling 2 (#13)" — both numbers, for places where picking the wrong row
 * is expensive and precision beats brevity.
 */
export function bevillingLabelWithId(bevilling: any): string {
  if (bevilling?.loebenummer == null) return bevillingLabel(bevilling);

  return `${bevillingLabel(bevilling)} (${bevillingSystemId(bevilling)})`;
}


/**
 * "Bevilling 2 - Udløbet" — the label with the bevilling's current status.
 *
 * For pickers, where the caseworker is choosing between a child's bevillinger
 * and the number alone does not say which is which. A child with three
 * bevillinger typically has one Aktiv and two Udløbet, and that is the thing
 * being chosen on.
 *
 * Deliberately NOT folded into bevillingLabel: that one also labels the badge
 * on a sagsforløb comment, where the status shown would be the status NOW
 * rather than when the comment was written — a comment attached to a bevilling
 * that has since expired would read as if it had always been expired.
 *
 * Falls back to the plain label when no status is present, rather than
 * printing a dangling dash.
 */
export function bevillingLabelWithStatus(bevilling: any): string {
  const status = String(bevilling?.status_tekst ?? "").trim();

  if (!status) return bevillingLabel(bevilling);

  return `${bevillingLabel(bevilling)} - ${status}`;
}
