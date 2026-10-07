"""Resolving a human-readable name from an OIDC principal.

The two identity providers this application runs against do NOT agree on
which claim carries a person's name:

    dev   Azure AD B2C          "name": "Daniel Dawson Jensen"
    prod  Entra ID (v2.0)       no "name" claim at all;
                                "displayname": "Daniel Dawson Jensen"

Reading only "name" therefore worked in dev and fell through to the email
address in prod — so every audit trail, every Sagsforløb entry and the user
menu showed an email where dev showed a name. The name was in the token all
along, under a different spelling.

Both are tried here, in one place, so the rule cannot drift between the user
menu and the audit attribution.
"""

from typing import Any


# Tried in order. Lower-case spellings first because that is what the prod
# token uses; the camelCase variants cost nothing and cover an IdP that
# spells it the other way.
_NAVNE_CLAIMS = (
    "name",
    "displayname",
    "displayName",
    "preferred_username",
)

# Fallback: some tokens carry only the parts.
_FORNAVN_CLAIMS = ("given_name", "givenName")
_EFTERNAVN_CLAIMS = ("family_name", "familyName", "surname")


def _claim(principal: Any, navn: str) -> str | None:
    """A claim's value, whether it is a typed attribute or only in raw."""

    vaerdi = getattr(principal, navn, None)

    if not vaerdi:
        raa = getattr(principal, "raw", None)

        if isinstance(raa, dict):
            vaerdi = raa.get(navn)

    if vaerdi is None:
        return None

    tekst = str(vaerdi).strip()

    return tekst or None


def visningsnavn(principal: Any) -> str | None:
    """The person's name, or None where the token carries no usable one.

    Args:
        principal:
            An OIDC claims object.

    Returns:
        The name, or None. Callers decide what to fall back to — the audit
        trail uses the email, which is at least an identity, rather than
        inventing a placeholder.
    """

    for claim in _NAVNE_CLAIMS:
        vaerdi = _claim(principal, claim)

        if vaerdi:
            return vaerdi

    # Neither spelling present: build it from the parts if they are there.
    fornavn = next((_claim(principal, c) for c in _FORNAVN_CLAIMS if _claim(principal, c)), None)
    efternavn = next((_claim(principal, c) for c in _EFTERNAVN_CLAIMS if _claim(principal, c)), None)

    samlet = " ".join(del_ for del_ in (fornavn, efternavn) if del_)

    return samlet or None


def samme_bruger(a: str | None, b: str | None) -> bool:
    """Whether two udfoert_af values name the same person.

    Sagsaktivitet records who acted only as a display name — there is no user
    id on the row — so "my own comment" can only be decided by comparing that
    string against the one the signed-in caller would be attributed with now.
    Both sides come from visningsnavn, so they agree for the same person.

    Trimmed and case-folded, because the two values are written at different
    times and a claim that gained or lost whitespace should not cost someone
    their own comment.

    Fails closed in two cases, both of which must never be anyone's "own":
      - a blank or missing name, which would otherwise make every row with no
        attribution deletable by every user whose name also resolved to blank;
      - "System", the attribution given to API-key callers (RPA bots), which
        no human may claim.

    Args:
        a: One udfoert_af value.
        b: The other.

    Returns:
        True if both name the same human.
    """
    venstre = (a or "").strip().casefold()
    hoejre = (b or "").strip().casefold()

    if not venstre or not hoejre:
        return False

    if venstre == "system" or hoejre == "system":
        return False

    return venstre == hoejre
