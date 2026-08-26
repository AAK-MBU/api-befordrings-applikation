/**
 * Server-rendered standalone pages for the states outside the application.
 *
 * These are served straight from the auth guard rather than as SvelteKit
 * routes. The root +layout.svelte renders the full navigation and fetches
 * /overview/* on mount, and a user who is logged out or holds no roles must see
 * none of that — but there is no way to opt out of the *root* layout
 * (+page@.svelte resets to it). Answering in the hook means the request never
 * reaches the router, so there is no shell and no data calls.
 *
 * Consequently the markup cannot use the app's Tailwind build, hence the inline
 * stylesheet. It is shared so these pages stay recognisably the same product.
 */

export function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}


export type StatusPage = {
  /** Browser tab title; the product name is appended. */
  title: string;
  /** HTTP status. 403 for "not allowed", 200 for a page that is the happy path. */
  status: number;
  heading: string;
  /** Pre-escaped HTML for the body. */
  bodyHtml: string;
  /** Pre-escaped HTML for the footer action, omitted when absent. */
  footerHtml?: string;
};


export function statusPage({
  title,
  status,
  heading,
  bodyHtml,
  footerHtml
}: StatusPage) {
  const html = `<!doctype html>
<html lang="da">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)} · Befordringssystemet</title>
<!-- Suppresses the browser's automatic /favicon.ico request. That request goes
     through the auth guard like any other, and an anonymous one used to consume
     the login attempt before the user had made one. -->
<link rel="icon" href="data:,">
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
  header .mark { width: 2rem; height: 2rem; border-radius: 0.25rem; background: #2ab4a0; flex: none; }
  header p { margin: 0; color: #fff; font-size: 0.8rem; letter-spacing: 0.18em; font-weight: 700; }
  header span { display: block; color: #7ec8e3; font-size: 0.62rem; letter-spacing: 0.14em; font-weight: 500; }
  .body { padding: 1.75rem; }
  h1 { margin: 0 0 1rem; font-size: 1.3rem; line-height: 1.3; }
  p { margin: 0 0 1rem; }
  p:last-child { margin-bottom: 0; }
  .who {
    margin: 0 0 1.25rem; padding: 0.75rem 1rem;
    background: #f8fafc; border-left: 3px solid #2ab4a0; border-radius: 0.25rem;
    font-size: 0.875rem; color: #475569; word-break: break-word;
  }
  .who strong { color: #0f172a; }
  .note { font-size: 0.875rem; color: #475569; }
  a { color: #0b6ea8; }
  footer { padding: 1.25rem 1.75rem; border-top: 1px solid #e2e8f0; }
  .btn {
    display: inline-block; padding: 0.6rem 1.1rem; border-radius: 0.375rem;
    background: #032a42; color: #fff; font-size: 0.9rem; font-weight: 600;
    text-decoration: none;
  }
  .btn:hover { background: #05405f; }
  .quiet { color: #b91c1c; font-weight: 600; text-decoration: none; }
  .quiet:hover { text-decoration: underline; }
</style>
</head>
<body>
  <main class="card">
    <header>
      <div class="mark"></div>
      <p>BEFORDRING<span>AARHUS KOMMUNE</span></p>
    </header>
    <div class="body">
      <h1>${escapeHtml(heading)}</h1>
      ${bodyHtml}
    </div>
    ${footerHtml ? `<footer>${footerHtml}</footer>` : ""}
  </main>
</body>
</html>`;

  return new Response(html, {
    status,
    headers: {
      "content-type": "text/html; charset=utf-8",
      // Tied to one browser's session state — a cached copy would show the next
      // person a stale identity, or keep showing this after it stopped applying.
      "cache-control": "no-store"
    }
  });
}
