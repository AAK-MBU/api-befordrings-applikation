/**
 * Driving-distance calculation — the single source of truth for the
 * skolekoordinater → køreafstand call chain.
 *
 * This existed as three copies (KoerselsraekkeTable, CreateBevillingModal,
 * BevillingTable) hitting the same endpoints with three different error
 * strategies: one surfaced the backend's message, one threw generic Danish
 * strings, and one returned silently on any failure.
 *
 * There is no geocoding step. Every address we work with comes from the nightly
 * LOIS sync and carries its own latitude/longitude, and the skolematrikler are a
 * hardcoded list delivered with coordinates — so the coordinates are always
 * already known. An earlier version re-derived them by geocoding the address
 * *text* through OpenRouteService, which threw away good data and then failed
 * whenever ORS could not score the string highly enough (any test address, and
 * in production any unusual road name or recently renamed road).
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
 * Distance from the citizen's stored coordinates to a skolematrikel.
 *
 * Null-tolerant on purpose: the callers read latitude/longitude straight off a
 * bevilling row, and a missing coordinate should be reported to the caseworker
 * rather than sent to the backend as "null".
 */
export async function afstandFraKoordinater(
  lat1: number | null | undefined,
  lon1: number | null | undefined,
  matrikelId: number | string | null | undefined
): Promise<AfstandResultat> {
  if (lat1 == null || lon1 == null) {
    return {
      km: null,
      error: "Ingen koordinater på bevillingens adresse — kan ikke beregne afstand",
    };
  }

  if (!matrikelId) {
    return { km: null, error: "Ingen skole valgt på bevillingen — kan ikke beregne afstand" };
  }

  const skole = await skolekoordinater(matrikelId);

  if (typeof skole === "string") return { km: null, error: skole };

  return await afstandMellemKoordinater(lat1, lon1, skole.latitude, skole.longitude);
}

