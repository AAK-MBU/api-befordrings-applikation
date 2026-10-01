/**
 * Cross-window notifications for a student's case.
 *
 * The create forms can be opened in their own browser window, typically parked
 * on a second screen while the sag page stays on the first. Saving there would
 * otherwise leave the sag page showing a list without the bevilling that was
 * just created — the caseworker's own window, silently stale, which is exactly
 * the state you do not want someone acting on.
 *
 * BroadcastChannel rather than window.opener.postMessage: it also reaches a
 * sag page sitting in a different tab, which is what you get when the create
 * window was opened from a link rather than from the button.
 */

const KANAL_NAVN = "befordring-sag";

export type SagBesked = {
  /** What happened. The listener reloads either way; the type is for logging. */
  type: "bevilling-oprettet" | "brev-oprettet";
  cpr: string;
};


/** Tell any other window showing this student that its data is now stale. */
export function sendSagBesked(besked: SagBesked) {
  // Guarded: this runs in a browser, but BroadcastChannel is also missing in
  // older WebViews, and a failed notification must never take the save with it.
  if (typeof BroadcastChannel === "undefined") {
    return;
  }

  try {
    const kanal = new BroadcastChannel(KANAL_NAVN);
    kanal.postMessage(besked);
    kanal.close();
  } catch (fejl) {
    console.error("Kunne ikke sende besked til andre vinduer", fejl);
  }
}


/**
 * Listen for changes to one student's case. Returns an unsubscribe function,
 * so it can be returned straight from onMount.
 */
export function lytPaaSagBesked(cpr: string, handler: (besked: SagBesked) => void) {
  if (typeof BroadcastChannel === "undefined") {
    return () => {};
  }

  const kanal = new BroadcastChannel(KANAL_NAVN);

  kanal.onmessage = (event: MessageEvent<SagBesked>) => {
    const besked = event.data;

    // Several cases can be open at once, one window each. Only react to this
    // window's student.
    if (besked?.cpr === cpr) {
      handler(besked);
    }
  };

  return () => kanal.close();
}
