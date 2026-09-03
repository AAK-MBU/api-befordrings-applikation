"""API router for Part (associated parties) endpoints.

A Part is a person associated with a student who is not a legal guardian but
may be informed about the child's bevillinger (e.g. a foster parent). Shown in
a separate box on the "Parter" tab, kept distinct from Foraelder.
"""

from fastapi import APIRouter, HTTPException

from app.api.dependencies import CurrentUser, DbSession, RequireEdit
from app.schemas.part import PartCreateRequest, PartResponse, PartUpdateRequest
from app.services.part_service import PartService


router = APIRouter(prefix="/part", tags=["Part"])


@router.get("/{cpr}", response_model=list[PartResponse])
def get_parts(cpr: str, db: DbSession):
    """Retrieve all active parties associated with a student."""

    return PartService(db=db).get_parts(cpr=cpr)


@router.post("/{cpr}", response_model=PartResponse, dependencies=[RequireEdit])
def create_part(
    cpr: str,
    payload: PartCreateRequest,
    db: DbSession,
    oprettet_af: CurrentUser,
):
    """Create a party for a student."""

    # Default attribution to the signed-in user unless the caller supplied one.
    payload.oprettet_af = payload.oprettet_af or oprettet_af

    return PartService(db=db).create_part(cpr=cpr, payload=payload)


@router.put("/{part_id}", response_model=PartResponse, dependencies=[RequireEdit])
def update_part(part_id: int, payload: PartUpdateRequest, db: DbSession):
    """Update a party. Only provided fields are changed."""

    part = PartService(db=db).update_part(part_id=part_id, payload=payload)

    if part is None:
        raise HTTPException(status_code=404, detail="Part ikke fundet")

    return part


@router.delete("/{part_id}", dependencies=[RequireEdit])
def delete_part(part_id: int, db: DbSession):
    """Soft-delete a party."""

    deleted = PartService(db=db).delete_part(part_id=part_id)

    if not deleted:
        raise HTTPException(status_code=404, detail="Part ikke fundet")

    return {"status": "deleted", "part_id": part_id}
