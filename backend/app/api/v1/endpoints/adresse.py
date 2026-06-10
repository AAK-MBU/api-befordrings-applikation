"""API router for address operations.

Endpoints:

- GET  /adresse/search?q=        Frontend combobox — LIKE search, capped at 15 results.
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

from app.api.dependencies import DbSession
from app.models.adresse import Adresse
from app.schemas.adresse import AdresseCreateRequest, AdresseCreateResponse, AdresseSearchResult


router = APIRouter(prefix="/adresse", tags=["Adresse"])


@router.get("/search", response_model=list[AdresseSearchResult])
def search_adresser(
    db: DbSession,
    q: str = Query(..., min_length=2, description="Search term — minimum 2 characters"),
):
    """Search addresses by partial text match.

    Performs a case-insensitive LIKE '%q%' query against adresse_tekst.
    Returns up to 15 matches ordered alphabetically.

    Args:
        q:
            The search string. Must be at least 2 characters.

    Returns:
        A list of matching addresses with their adresse_id and adresse_tekst.
    """

    return (
        db.query(Adresse)
        .filter(Adresse.adresse_tekst.ilike(f"%{q}%"))
        .order_by(Adresse.adresse_tekst)
        .limit(15)
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


@router.post("/create", response_model=AdresseCreateResponse)
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
