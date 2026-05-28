"""Helper for calculating driving distance and duration between coordinates.

Uses the OpenRouteService Directions API.
"""

import requests


_API_KEY = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImNhMGUwMDkxMTcxMDRjMWI5ODdkNzBlOWIyM2JiOTE5IiwiaCI6Im11cm11cjY0In0="
_ORS_URL = "https://api.openrouteservice.org/v2/directions/driving-car"


def driving_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> tuple[float, float]:
    """Calculate driving distance and duration between two coordinates.

    Args:
        lat1, lon1: Origin coordinates.
        lat2, lon2: Destination coordinates.

    Returns:
        Tuple of (distance_km, duration_minutes).

    Raises:
        requests.HTTPError: If the OpenRouteService API returns an error.
    """

    response = requests.post(
        _ORS_URL,
        headers={"Authorization": _API_KEY, "Content-Type": "application/json"},
        json={"coordinates": [[lon1, lat1], [lon2, lat2]]},
        timeout=10,
    )
    response.raise_for_status()

    summary = response.json()["routes"][0]["summary"]

    return summary["distance"] / 1000, summary["duration"] / 60
