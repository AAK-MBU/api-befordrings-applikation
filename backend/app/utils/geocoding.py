"""Helper for geocoding a Danish address to latitude/longitude coordinates.

Uses the OpenRouteService Geocoding API (structured + text search with scoring).
"""

import re

import requests


_API_KEY = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImNhMGUwMDkxMTcxMDRjMWI5ODdkNzBlOWIyM2JiOTE5IiwiaCI6Im11cm11cjY0In0="
_COUNTRY_CODE = "DK"
_MIN_SCORE = 12


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
        "api_key": _API_KEY,
        "address": f"{road_name} {house_number}",
        "postalcode": postal_code,
        "boundary.country": _COUNTRY_CODE,
        "size": 10,
    }

    if city:
        params["locality"] = city

    response = requests.get(
        "https://api.openrouteservice.org/geocode/search/structured",
        params=params,
        timeout=10,
    )
    response.raise_for_status()

    return response.json().get("features", [])


def _fetch_text_candidates(full_address: str) -> list[dict]:
    response = requests.get(
        "https://api.openrouteservice.org/geocode/search",
        params={
            "api_key": _API_KEY,
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
