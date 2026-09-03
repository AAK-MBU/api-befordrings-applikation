"""API router for citizen-related endpoints.

This module contains read-only endpoints for citizen stamdata and parent data.

Citizen stamdata and parent data are maintained by external systems and are
read-only in this application. Only GET endpoints are exposed here.
"""

from fastapi import APIRouter

from app.api.dependencies import DbSession, RequireEdit
from app.schemas.citizen import ElevCreateRequest
from app.services.citizen_service import CitizenService


# All routes in this file are grouped under /citizen.
# The tag is used by Swagger/OpenAPI to group the endpoints visually.
router = APIRouter(prefix="/citizen", tags=["Citizen"])


@router.post("/create_elev", dependencies=[RequireEdit])
def create_elev(request: ElevCreateRequest, db: DbSession):
    """Create a new student in the Elev table if not already present.

    Used by the RPA conversion bot when migrating PPR bevillinger.
    The Adresse record is created as part of the same transaction.

    Args:
        request:
            ElevCreateRequest containing CPR, name, geocoded address, and
            optional school/class fields.

        db:
            Database session injected by FastAPI.

    Returns:
        {"cpr": str, "created": bool} — created=False if the student already existed.
    """
    service = CitizenService(db=db)
    return service.create_elev(request.model_dump())


@router.get("/stamdata/{cpr}")
def get_stamdata(cpr: str, db: DbSession):
    """Get stamdata for a citizen/student.

    Args:
        cpr:
            The CPR number of the citizen/student.

        db:
            The database session injected by FastAPI.

    Returns:
        Stamdata for the provided CPR.
    """

    service = CitizenService(db=db)

    return service.get_stamdata(cpr=cpr)


@router.get("/stamdata/{cpr}/parents")
def get_parent_data(cpr: str, db: DbSession):
    """Get parent/guardian data for a citizen/student.

    Args:
        cpr:
            The CPR number of the citizen/student.

        db:
            The database session injected by FastAPI.

    Returns:
        Parent/guardian data connected to the provided CPR.
    """

    service = CitizenService(db=db)

    return service.get_parent_data(cpr=cpr)
