"""Helper for geocoding a Danish address to latitude/longitude coordinates.

Uses the OpenRouteService Geocoding API (structured + text search with
scoring). The token comes from the ORS_API_KEY environment variable via
app.core.config — the same token the distance helpers use, and never from
source.
"""

import re

import requests

from app.core.config import settings


# The geocoder behind OpenRouteService is Pelias, and HeiGIT's unified host
# names it directly: api.openrouteservice.org/geocode is now
# api.heigit.org/pelias/v1. The old host is deprecated and shuts off on
# 24 August 2026.
_PELIAS = "https://api.heigit.org/pelias/v1"

_COUNTRY_CODE = "DK"
_MIN_SCORE = 12


def _ors_key() -> str:
    """The OpenRouteService token, or a clear error naming what is unset.

    Read per call rather than at import so a missing token cannot stop the
    application from starting, and so the message names the variable — an
    empty api_key parameter otherwise comes back as a 403 that reads like a
    revoked key.
    """

    if not settings.ors_api_key:
        raise RuntimeError(
            "ORS_API_KEY is not set, so no address can be geocoded. Set it in "
            "the environment to an OpenRouteService API token."
        )

    return settings.ors_api_key


def _normalize(value: str) -> str:
    return (value or "").strip().lower()


def parse_address(full_address: str) -> tuple[str, str, str, str]:
    """Split a full Danish address string into components.

    Args:
        full_address:
            Address in the format "Road Name 12, 8000 City".

    Returns:
        Tuple of (road_name, house_number, postal_code, city).

    Examples:
        "Bjørnshøjvej 1, 8380 Trige"  ->  ("Bjørnshøjvej", "1", "8380", "Trige")
        "Møllevangs Allé 20, 8210 Aarhus V"  ->  ("Møllevangs Allé", "20", "8210", "Aarhus V")
    """

    street_part, postal_city = full_address.split(", ", 1)
    postal_code, city = postal_city.split(" ", 1)

    tokens = street_part.rsplit(" ", 1)

    if len(tokens) == 2 and re.match(r"^\d+[A-Za-z]?$", tokens[1]):
        road_name, house_number = tokens
    else:
        road_name, house_number = street_part, ""

    return road_name, house_number, postal_code, city


def _fetch_structured_candidates(
    road_name: str,
    house_number: str,
    postal_code: str,
    city: str | None,
) -> list[dict]:
    params = {
        "api_key": _ors_key(),
        "address": f"{road_name} {house_number}",
        "postalcode": postal_code,
        "boundary.country": _COUNTRY_CODE,
        "size": 10,
    }

    if city:
        params["locality"] = city

    response = requests.get(
        f"{_PELIAS}/search/structured",
        params=params,
        timeout=10,
    )
    response.raise_for_status()

    return response.json().get("features", [])


def _fetch_text_candidates(full_address: str) -> list[dict]:
    response = requests.get(
        f"{_PELIAS}/search",
        params={
            "api_key": _ors_key(),
            "text": full_address,
            "boundary.country": _COUNTRY_CODE,
            "size": 10,
        },
        timeout=10,
    )
    response.raise_for_status()

    return response.json().get("features", [])


def _score_candidate(
    feature: dict,
    road_name: str,
    house_number: str,
    postal_code: str,
    city: str,
) -> int:
    props = feature.get("properties", {})

    score = 0

    if _normalize(props.get("layer", "")) == "address":
        score += 5
    if _normalize(props.get("street", "")) == _normalize(road_name):
        score += 4
    if _normalize(props.get("housenumber", "")).startswith(_normalize(house_number)):
        score += 3
    if _normalize(props.get("postalcode", "")) == _normalize(postal_code):
        score += 4
    if _normalize(props.get("locality", "")) == _normalize(city):
        score += 2
    if _normalize(props.get("match_type", "")) == "exact":
        score += 2
    if _normalize(props.get("accuracy", "")) == "point":
        score += 2
    if _normalize(props.get("match_type", "")) == "fallback":
        score -= 10
    if _normalize(props.get("accuracy", "")) == "centroid":
        score -= 10

    return score


def _pick_best_candidate(
    candidates: list[dict],
    road_name: str,
    house_number: str,
    postal_code: str,
    city: str,
) -> dict:
    if not candidates:
        raise ValueError("No geocoding candidates returned.")

    scored = sorted(
        [
            (_score_candidate(f, road_name, house_number, postal_code, city), f)
            for f in candidates
        ],
        key=lambda item: item[0],
        reverse=True,
    )

    best_score, best_feature = scored[0]

    if best_score < _MIN_SCORE:
        raise ValueError(
            f"No reliable geocoding result found (best score {best_score}, need >= {_MIN_SCORE})."
        )

    if _normalize(best_feature.get("properties", {}).get("layer", "")) != "address":
        raise ValueError("Best geocoding result was not an address-level match.")

    return best_feature


def geocode_address(full_address: str) -> tuple[float, float]:
    """Geocode a full Danish address string to (latitude, longitude).

    Args:
        full_address:
            Address in the format "Road Name 12, 8000 City".
            Example: "Bjørnshøjvej 1, 8380 Trige"

    Returns:
        Tuple of (latitude, longitude).

    Raises:
        ValueError: If no reliable address-level match is found.
        requests.HTTPError: If the OpenRouteService API returns an error.
    """

    road_name, house_number, postal_code, city = parse_address(full_address)

    candidates = []
    candidates.extend(_fetch_structured_candidates(road_name, house_number, postal_code, city))
    candidates.extend(_fetch_structured_candidates(road_name, house_number, postal_code, None))
    candidates.extend(
        _fetch_text_candidates(f"{road_name} {house_number}, {postal_code} {city}, Denmark")
    )

    best = _pick_best_candidate(candidates, road_name, house_number, postal_code, city)

    lon, lat = best["geometry"]["coordinates"]

    return lat, lon
