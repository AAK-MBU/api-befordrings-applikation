/**
 * Claims for the signed-in user, as returned by the backend's GET /me
 * (see backend/app/main.py).
 *
 * These come straight from the validated ID token. The backend keeps no user
 * table — roles and groups are assigned centrally in the IdP — so this is the
 * only source of identity and permissions.
 *
 * Type-only module: safe to import from both server and client code.
 */
export type CurrentUser = {
  sub: string;
  name: string | null;
  email: string | null;
  roles: string[];
  groups: string[];
  organisation: string | null;
  mapped_claims: Record<string, unknown>;
  /** Full validated ID token payload, for claims not surfaced above. */
  raw: Record<string, unknown>;
  /**
   * Whether this user's roles permit writing, as decided by the backend's
   * EDIT_ROLES setting.
   *
   * For presentation only — use it to hide or disable controls the user cannot
   * use. The backend enforces the same rule on every write endpoint
   * (require_edit), so a hidden button is a courtesy, not a security boundary.
   */
  can_edit: boolean;
};
