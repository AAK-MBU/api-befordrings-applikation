import { env as publicEnv } from "$env/dynamic/public";

import type { CurrentUser } from "$lib/auth";

import { getLogoutUrl } from "./auth";
import { escapeHtml, statusPage } from "./statusPage";


/**
 * Where to apply for a role, and who to ask when that goes wrong.
 *
 * Both optional: an unset URL degrades to plain text rather than a dead link,
 * so the page is still correct in a deployment that has not configured them.
 */
function applyLink() {
  const url = publicEnv.PUBLIC_SYSTEMREGISTER_URL;

  if (!url) {
    return "Systemregisteret";
  }

  return `<a href="${escapeHtml(url)}">Systemregisteret</a>`;
}


function supportLine() {
  const contact = publicEnv.PUBLIC_SUPPORT_CONTACT;

  if (!contact) {
    return "Kontakt support, hvis du mener det er en fejl.";
  }

  return `Kontakt <strong>${escapeHtml(contact)}</strong>, hvis du mener det er en fejl.`;
}


/**
 * Dead-end page for a signed-in user who holds no roles.
 *
 * 403, not 401 — the browser is authenticated, it just is not authorised. A 401
 * would invite the guard to send them back to the IdP, which would succeed and
 * change nothing.
 */
export function noAccessPage(user: CurrentUser) {
  const identity = user.name || user.email || user.sub;

  return statusPage({
    title: "Ingen adgang",
    status: 403,
    heading: "Du har ikke adgang til Befordringssystemet",
    bodyHtml: `
      <p class="who">Du er logget ind som <strong>${escapeHtml(identity)}</strong>, men der er ikke tildelt dig nogen roller til dette system.</p>
      <p>Adgang tildeles centralt. Du kan ansøge om en rolle gennem ${applyLink()}.</p>
      <p class="note">Når din ansøgning er godkendt, skal du <strong>logge ud og ind igen</strong> — dine roller læses fra login, så en ny rolle vises først efter et nyt login.</p>
      <p class="note">${supportLine()}</p>
    `,
    footerHtml: `<a class="quiet" href="${escapeHtml(getLogoutUrl())}">Log ud</a>`
  });
}
