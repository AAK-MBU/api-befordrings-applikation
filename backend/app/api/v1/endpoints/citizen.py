"""API router for citizen-related endpoints.

This module contains read-only endpoints for citizen stamdata and parent data.

Citizen stamdata and parent data are maintained by external systems and are
read-only in this application. Only GET endpoints are exposed here.
"""

from fastapi import APIRouter

from app.api.dependencies import DbSession
from app.services.citizen_service import CitizenService


# All routes in this file are grouped under /citizen.
# The tag is used by Swagger/OpenAPI to group the endpoints visually.
router = APIRouter(prefix="/citizen", tags=["Citizen"])


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
