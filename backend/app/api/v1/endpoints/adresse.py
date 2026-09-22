"""API router for address operations.

Endpoints:

- GET  /adresse/search?q=        Frontend combobox — prefix LIKE search.
                                  Optional postnummer= narrows to one postcode,
                                  limit= caps the rows (default 100).
- GET  /adresse/{adresse_id}     RPA / internal — look up a single address by GUID PK.
- GET  /adresse/by-tekst?tekst=  RPA / testing — exact-match lookup by full address string.
- POST /adresse/create           RPA — idempotently create an address record
                                  resolved from LOIS at queue time.

adresse_id is the LOIS AdresseId (DAR GUID), e.g.
"0A3F50C2-633E-32B8-E044-0003BA298018". Rows are populated either by the
nightly SAS address register sync, or directly by the RPA conversion bot via
POST /adresse/create when an address resolved from LOIS does not yet exist.
"""

from fastapi import APIRouter, HTTPException, Query

from app.api.dependencies import DbSession, RequireEdit
from app.models.adresse import Adresse
from app.schemas.adresse import AdresseCreateRequest, AdresseCreateResponse, AdresseSearchResult


router = APIRouter(prefix="/adresse", tags=["Adresse"])


@router.get("/search", response_model=list[AdresseSearchResult])
def search_adresser(
    db: DbSession,
    q: str = Query(..., min_length=2, description="Search term — minimum 2 characters"),
    postnummer: str | None = Query(
        None,
        min_length=4,
        max_length=4,
        description="Narrow the search to one postcode. Recommended for any "
                    "non-interactive caller — see the note on truncation.",
    ),
    limit: int = Query(100, ge=1, le=200, description="Maximum rows to return"),
):
    """Search addresses by prefix (starts-with) match.

    Performs a LIKE 'q%' query against adresse_tekst, ordered alphabetically.

    IMPORTANT: this deliberately uses a prefix match ('q%'), NOT a contains
    match ('%q%'). The Adresse table holds ~4 million rows with a supporting
    index (IX_Adresse_adresse_tekst); a leading-wildcard/contains query cannot
    use that index and forces a full scan on every keystroke. Keep it as 'q%'.

    TRUNCATION, and why postnummer exists:

    The table is the whole of Denmark — the nightly import reads
    LOIS.DAR.AdresseDkGeoView with no municipality filter — so a street name
    that exists in several towns has a row per town. Ordering is alphabetical
    on a string whose next characters are the POSTCODE, so the rows that fall
    off the end of the limit are the ones with the HIGHEST postcodes. For a
    caller in Aarhus that is precisely the rows it wanted: "Bøgebakken 2,"
    returns Greve, Roskilde and Køge, and 8462 Harlev J never appears.

    A human typing in the combobox notices an address missing and types more.
    A robot does not — it records "no match" and moves on. Any non-interactive
    caller should therefore pass postnummer.

    The filter is a contains match, but it runs on top of the prefix seek, so
    it only touches rows the index already narrowed to.

    Args:
        q:
            The search string. Must be at least 2 characters.

        postnummer:
            Optional four-digit postcode. Only addresses in it are returned.

        limit:
            Maximum rows to return.

            Raised from 15 to 100 after "Bøgebakken 2," was found to have 26
            rows nationally, with the wanted Aarhus one 21st. 15 returned
            nothing but Lejre, Gilleleje and Kalundborg. A street name common
            across Denmark needs far more headroom than a combobox suggests,
            and a truncated result is indistinguishable from an absent one.

    Returns:
        A list of matching addresses with their adresse_id and adresse_tekst.
    """

    query = db.query(Adresse).filter(Adresse.adresse_tekst.like(f"{q}%"))

    if postnummer:
        # The postcode always follows ", " — it is the last component of
        # adresse_tekst, after street and any floor or place name.
        query = query.filter(Adresse.adresse_tekst.like(f"%, {postnummer} %"))

    return (
        query
        .order_by(Adresse.adresse_tekst)
        .limit(limit)
        .all()
    )


@router.get("/by-tekst", response_model=AdresseSearchResult | None)
def get_adresse_by_tekst(
    db: DbSession,
    tekst: str = Query(..., description="Full address string for exact match"),
):
    """Look up a single address by its exact full address text.

    Used by the RPA conversion bot and for testing address resolution.
    The match is exact (case-sensitive) against adresse_tekst.

    Args:
        tekst:
            Full address string, e.g. "Grøndalsvej 1, 8260 Viby J".

    Returns:
        The matching address record, or null if not found.
    """

    return db.query(Adresse).filter(Adresse.adresse_tekst == tekst).one_or_none()


@router.post("/create", response_model=AdresseCreateResponse, dependencies=[RequireEdit])
def create_adresse(
    request: AdresseCreateRequest,
    db: DbSession,
):
    """Idempotently create an Adresse record.

    Used by the RPA conversion bot when the address resolved from LOIS at
    queue time does not yet exist in the nightly-synced Adresse table.

    Args:
        request:
            AdresseCreateRequest containing the LOIS adresse_id, address text,
            and coordinates.

    Returns:
        {"adresse_id": str, "created": bool} — created=False if the address
        already existed (no changes made).
    """

    existing = db.get(Adresse, request.adresse_id)

    if existing is not None:
        return AdresseCreateResponse(adresse_id=existing.adresse_id, created=False)

    adresse = Adresse(**request.model_dump())
    db.add(adresse)
    db.commit()

    return AdresseCreateResponse(adresse_id=adresse.adresse_id, created=True)


@router.get("/{adresse_id}", response_model=AdresseSearchResult)
def get_adresse_by_id(
    adresse_id: str,
    db: DbSession,
):
    """Look up a single address by its primary key.

    Used by the RPA conversion bot to retrieve coordinates for skoleafstand
    calculation after adresse_id has been resolved at queue time.

    Args:
        adresse_id:
            The LOIS AdresseId / DAR GUID (PK of the Adresse table).

    Returns:
        The address record, or 404 if not found.
    """

    adresse = db.get(Adresse, adresse_id)

    if adresse is None:
        raise HTTPException(status_code=404, detail=f"Adresse {adresse_id} not found.")

    return adresse
