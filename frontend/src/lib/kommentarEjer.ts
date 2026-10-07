/**
 * Whether the signed-in user wrote a given sagsforløb comment.
 *
 * Mirrors samme_bruger in backend/app/utils/identitet.py, which is what
 * actually decides the delete. Kept in step with it deliberately: this one
 * only hides a button, and a mismatch would either offer a delete the backend
 * refuses, or hide one it would have allowed.
 *
 * Sagsaktivitet records who acted only as a display name, so that string is
 * all there is to compare. Trimmed and case-folded; blank and "System" — the
 * attribution given to RPA callers — are nobody's own.
 */
export function erEgenKommentar(
  udfoertAf: string | null | undefined,
  brugerNavn: string | null | undefined,
): boolean {
  const venstre = (udfoertAf ?? "").trim().toLowerCase();
  const hoejre = (brugerNavn ?? "").trim().toLowerCase();

  if (!venstre || !hoejre) return false;
  if (venstre === "system" || hoejre === "system") return false;

  return venstre === hoejre;
}
