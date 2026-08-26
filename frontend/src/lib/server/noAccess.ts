import { env as publicEnv } from "$env/dynamic/public";

import type { CurrentUser } from "$lib/auth";

import { getLogoutUrl } from "./auth";


function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}


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
 * Served straight from the auth guard rather than as a SvelteKit route: the
 * root +layout.svelte renders the full navigation and fetches /overview/* on
 * mount, and a user with no roles must see none of that. There is no way to opt
 * out of the root layout (+page@.svelte resets *to* it), so the request never
 * reaches the router at all.
 *
 * 403, not 401 — the browser is authenticated, it just is not authorised. A 401
 * would invite the guard to send them back to the IdP, which would succeed and
 * change nothing.
 */
export function noAccessPage(user: CurrentUser) {
  const identity = user.name || user.email || user.sub;

  const html = `<!doctype html>
<html lang="da">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ingen adgang · Befordringssystemet</title>
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1.5rem;
    background: #f1f5f9;
    color: #0f172a;
    font: 16px/1.6 system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  .card {
    width: 100%;
    max-width: 34rem;
    background: #fff;
    border-radius: 0.75rem;
    box-shadow: 0 10px 30px rgba(3, 42, 66, 0.12);
    overflow: hidden;
  }
  header {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 1.25rem 1.75rem;
    background: #032a42;
  }
  header .mark {
    width: 2rem; height: 2rem; border-radius: 0.25rem;
    background: #2ab4a0; flex: none;
  }
  header p { margin: 0; color: #fff; font-size: 0.8rem; letter-spacing: 0.18em; font-weight: 700; }
  header span { display: block; color: #7ec8e3; font-size: 0.62rem; letter-spacing: 0.14em; font-weight: 500; }
  .body { padding: 1.75rem; }
  h1 { margin: 0 0 1rem; font-size: 1.3rem; line-height: 1.3; }
  p { margin: 0 0 1rem; }
  .who {
    margin: 0 0 1.25rem; padding: 0.75rem 1rem;
    background: #f8fafc; border-left: 3px solid #2ab4a0; border-radius: 0.25rem;
    font-size: 0.875rem; color: #475569; word-break: break-word;
  }
  .who strong { color: #0f172a; }
  .note { font-size: 0.875rem; color: #475569; }
  a { color: #0b6ea8; }
  footer { padding: 1rem 1.75rem; border-top: 1px solid #e2e8f0; }
  footer a { font-weight: 600; color: #b91c1c; text-decoration: none; }
  footer a:hover { text-decoration: underline; }
</style>
</head>
<body>
  <main class="card">
    <header>
      <div class="mark"></div>
      <p>BEFORDRING<span>AARHUS KOMMUNE</span></p>
    </header>

    <div class="body">
      <h1>Du har ikke adgang til Befordringssystemet</h1>

      <p class="who">Du er logget ind som <strong>${escapeHtml(identity)}</strong>, men der er ikke tildelt dig nogen roller til dette system.</p>

      <p>Adgang tildeles centralt. Du kan ansøge om en rolle gennem ${applyLink()}.</p>

      <p class="note">Når din ansøgning er godkendt, skal du <strong>logge ud og ind igen</strong> — dine roller læses fra login, så en ny rolle vises først efter et nyt login.</p>

      <p class="note">${supportLine()}</p>
    </div>

    <footer><a href="${escapeHtml(getLogoutUrl())}">Log ud</a></footer>
  </main>
</body>
</html>`;

  return new Response(html, {
    status: 403,
    headers: {
      "content-type": "text/html; charset=utf-8",
      // Tied to one user's role set — a cached copy would lock out the next
      // person, or keep showing this after a role is granted.
      "cache-control": "no-store"
    }
  });
}
