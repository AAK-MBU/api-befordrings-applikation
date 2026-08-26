import type { LayoutLoad } from './$types';

/**
 * A universal load beside a server load *replaces* the layout's data — the
 * server's return value arrives here as `data` and reaches the component only
 * if it is passed on. Omitting the spread silently drops `user` and
 * `logoutUrl` from +layout.server.ts, which renders the signed-in name as
 * "Ukendt bruger" and the logout link as an <a> with no href: inert text.
 */
export const load: LayoutLoad = ({ url, data }) => {
  return {
    ...data,
    url
  };
};
