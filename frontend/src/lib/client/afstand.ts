/**
 * Driving-distance calculation — the single source of truth for the
 * geocode → skolekoordinater → køreafstand call chain.
 *
 * This existed as three copies (KoerselsraekkeTable, CreateBevillingModal,
 * BevillingTable) hitting the same three endpoints with three different error
 * strategies: one surfaced the backend's message, one threw generic Danish
 * strings, and one returned silently on any failure.
 *
 * Nothing here throws. Callers get { km, error } and decide how to present it,
 * which is the part that legitimately differs between an inline field hint and
 * a modal-wide error line.
 */

import { backendFetch } from "$lib/client/backendFetch";

export type AfstandResultat = {
  km: number | null;
  /** Danish, user-facing. Null when km is set. */
  error: string | null;
};

/** Prefer the backend's own detail message, fall back to ours. */
async function detailOr(response: Response, fallback: string): Promise<string> {
  try {
    const body = await response.json();
    return body?.detail?.message ?? body?.detail ?? fallback;
  } catch {
    return fallback;
  }
}

async function geocode(
  adresse: string
): Promise<{ latitude: number; longitude: number } | string> {
  const response = await backendFetch(
    `/bevilling/geocode_address?address=${encodeURIComponent(adresse)}`
  );

  if (!response.ok) return await detailOr(response, "Kunne ikke geokode adressen");

  return await response.json();
}

async function skolekoordinater(
  matrikelId: number | string
): Promise<{ latitude: number; longitude: number } | string> {
  const response = await backendFetch(`/lookup/skolematrikel/${matrikelId}/coordinates`);

  if (!response.ok) return await detailOr(response, "Kunne ikke hente skolens koordinater");

  return await response.json();
}

/**
 * Distance in km between two coordinate pairs, as the car drives.
 */
export async function afstandMellemKoordinater(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): Promise<AfstandResultat> {
  const params = new URLSearchParams({
    lat1: String(lat1),
    lon1: String(lon1),
    lat2: String(lat2),
    lon2: String(lon2),
  });

  const response = await backendFetch(`/bevilling/calculate_driving_distance?${params}`);

  if (!response.ok) {
    return { km: null, error: await detailOr(response, "Kunne ikke beregne køreafstand") };
  }

  const data = await response.json();

  // The endpoint has answered under more than one key over time; accept all
  // three rather than silently filling the field with undefined.
  const km = data.distance_km ?? data.distance ?? data.driving_distance_km;

  if (km == null) return { km: null, error: "Ugyldigt svar fra afstandsberegning" };

  return { km: Number(km), error: null };
}

/**
 * Distance from an already-geocoded position to a skolematrikel. Use this when
 * the caller has just geocoded the address itself and would otherwise pay for
 * the same lookup twice.
 */
export async function afstandFraKoordinater(
  lat1: number,
  lon1: number,
  matrikelId: number | string
): Promise<AfstandResultat> {
  const skole = await skolekoordinater(matrikelId);

  if (typeof skole === "string") return { km: null, error: skole };

  return await afstandMellemKoordinater(lat1, lon1, skole.latitude, skole.longitude);
}

/**
 * Distance from a street address to a skolematrikel — the full chain.
 */
export async function afstandFraAdresse(
  adresse: string | null | undefined,
  matrikelId: number | string | null | undefined
): Promise<AfstandResultat> {
  if (!adresse) {
    return { km: null, error: "Ingen adresse på bevillingen — kan ikke beregne afstand" };
  }

  if (!matrikelId) {
    return { km: null, error: "Ingen skole valgt på bevillingen — kan ikke beregne afstand" };
  }

  const borger = await geocode(adresse);

  if (typeof borger === "string") return { km: null, error: borger };

  return await afstandFraKoordinater(borger.latitude, borger.longitude, matrikelId);
}
