/**
 * Opening a create form in its own browser window.
 *
 * A modal cannot leave the page, so a caseworker filling one in cannot look at
 * the case behind it. A real window can be moved to a second screen, which is
 * what was asked for.
 */

/** Keeps the window a usable size without pushing it off a 1080p screen. */
const BREDDE = 1200;
const HOEJDE = 950;


/**
 * Open `sti` in a popup window.
 *
 * `navn` names the window, so clicking the same button twice focuses the
 * window that is already open instead of opening a second, half-filled form.
 *
 * Returns false when the browser refused — popup blockers answer with null —
 * so the caller can fall back to the in-page modal rather than appearing to do
 * nothing. Note that a blocker only steps in when the call is not a user
 * gesture, so in practice this is the rare path.
 */
export function aabnSagVindue(
  sti: string,
  navn: string,
  stoerrelse: { bredde?: number; hoejde?: number } = {}
): boolean {
  if (typeof window === "undefined") {
    return false;
  }

  const bredde = Math.min(stoerrelse.bredde ?? BREDDE, window.screen.availWidth);
  const hoejde = Math.min(stoerrelse.hoejde ?? HOEJDE, window.screen.availHeight - 40);

  try {
    const vindue = window.open(
      sti,
      navn,
      `popup,width=${bredde},height=${hoejde}`
    );

    if (!vindue) {
      return false;
    }

    vindue.focus();
    return true;
  } catch (fejl) {
    console.error("Kunne ikke åbne vindue", fejl);
    return false;
  }
}
