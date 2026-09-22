"""Afstandskriteriet — the two derived fields on a bevilling.

A Python mirror of frontend/src/lib/afstandskriterie.ts. The bands and the
30-June rule are defined there, and the two modules must be changed together.

Why it exists twice: the frontend derives these fields while a caseworker
fills in the create/edit form, so they can see and override the suggestion
before saving. That covers every bevilling made through the UI, but not one
made straight against the API — the conversion RPA posts a bevilling nobody
opens a form for, and both fields came out NULL. This module is the fallback
for that path: the API derives what the caller did not send.

Only the two derivations live here. The margin helpers in the TypeScript
module drive a hint next to the distance field and have no server-side
counterpart.
"""

from datetime import date


# (last klassetrin covered, km the student must exceed to qualify)
#
#     0.-3. klasse   > 2,5 km
#     4.-6. klasse   > 6 km
#     7.-9. klasse   > 7 km
#     10. klasse     > 9 km
AFSTANDSBAND: list[tuple[int, float]] = [
    (3, 2.5),
    (6, 6.0),
    (9, 7.0),
    (10, 9.0),
]


# Midlertidig kørsel is granted on a different basis, so the afstandskriterie
# fields do not apply to it. The frontend hides them; here they are simply not
# derived. Same string as os2forms_mapping.ansoegningstype_for_webform.
MIDLERTIDIG_KOERSEL = "Midlertidig kørsel"


def parse_klassetrin(value: str | int | None) -> int | None:
    """Read a klassetrin off the Elev record.

    elevklassetrin is a free-text column, so it can hold "1", "01", "0" — and
    for a student at an ungdomsuddannelse, nothing meaningful at all. Anything
    that is not a folkeskole klassetrin yields None, which switches both
    derivations off rather than guessing.
    """

    tekst = str(value if value is not None else "").strip()

    # Leading digits only: "9. klasse" is a 9, "ungdomsuddannelse" is nothing.
    digits = ""

    for char in tekst:
        if not char.isdigit():
            break

        digits += char

    if not digits:
        return None

    klassetrin = int(digits)

    if klassetrin < 0 or klassetrin > 10:
        return None

    return klassetrin


def _band_for_klassetrin(klassetrin: int | None) -> tuple[int, float] | None:
    """The band a klassetrin falls in, or None when it is outside folkeskolen."""

    if klassetrin is None:
        return None

    return next(
        (band for band in AFSTANDSBAND if klassetrin <= band[0]),
        None,
    )


def beregn_afstandskriterie_klassetrin(elevklassetrin: str | int | None) -> int | None:
    """The last klassetrin the student's current distance threshold covers."""

    band = _band_for_klassetrin(parse_klassetrin(elevklassetrin))

    return band[0] if band else None


def beregn_afstandskriterie_dato(
    elevklassetrin: str | int | None,
    today: date | None = None,
) -> date | None:
    """When the student's current distance threshold is replaced by the next.

    Always 30 June, because a Danish school year ends there. A school year runs
    August-June, so the year a student is currently in ends on 30 June of the
    *next* calendar year once August has passed. From there it is one 30 June
    per remaining klassetrin in the band. July counts with the year just
    finished: the Elev record still holds the klassetrin the student completed,
    not the one they are about to start.
    """

    today = today or date.today()

    klassetrin = parse_klassetrin(elevklassetrin)
    band = _band_for_klassetrin(klassetrin)

    if klassetrin is None or band is None:
        return None

    skoleaar_slutter = today.year + 1 if today.month >= 8 else today.year

    return date(skoleaar_slutter + (band[0] - klassetrin), 6, 30)
