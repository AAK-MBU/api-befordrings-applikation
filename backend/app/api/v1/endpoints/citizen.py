"""API router for citizen-related endpoints.

This module contains endpoints for retrieving and updating citizen stamdata.

The router acts as a thin FastAPI layer between the HTTP request and the
CitizenService.

General pattern in this file:

1. Receive input from the frontend or another caller.
2. Create a CitizenService using the current database session.
3. Pass relevant parameters to the service layer.
4. Return the service result directly.

The router should not contain heavy business logic. Any database access,
validation, transformation, or update logic should live in CitizenService
or deeper repository/helper layers.
"""

from fastapi import APIRouter

from app.api.dependencies import DbSession
from app.schemas.citizen import CitizenStamdataUpdateRequest
from app.services.citizen_service import CitizenService


# All routes in this file are grouped under /citizen.
# The tag is used by Swagger/OpenAPI to group the endpoints visually.
router = APIRouter(prefix="/citizen", tags=["Citizen"])


@router.get("/stamdata/{cpr}")
def get_stamdata(cpr: str, db: DbSession):
    """Get stamdata for a citizen/student.

    Stamdata is the basic master data connected to a citizen/student.

    This could include information such as name, address, school data,
    class level, SFO information, and other base information depending on
    what CitizenService.get_stamdata returns.

    Args:
        cpr:
            The CPR number of the citizen/student.

        db:
            The database session injected by FastAPI.

    Returns:
        Stamdata for the provided CPR.

        The exact response shape is controlled by
        CitizenService.get_stamdata.
    """

    service = CitizenService(db=db)

    return service.get_stamdata(cpr=cpr)


@router.get("/stamdata/{cpr}/parents")
def get_parent_data(cpr: str, db: DbSession):
    """Get parent/guardian data for a citizen/student.

    This endpoint fetches parent-related data based on the citizen/student CPR.

    Args:
        cpr:
            The CPR number of the citizen/student.

        db:
            The database session injected by FastAPI.

    Returns:
        Parent/guardian data connected to the provided CPR.

        The exact response shape is controlled by
        CitizenService.get_parent_data.
    """

    service = CitizenService(db=db)

    return service.get_parent_data(cpr=cpr)


@router.patch("/stamdata/{cpr}")
def update_citizen_stamdata(
    cpr: str,
    request: CitizenStamdataUpdateRequest,
    db: DbSession,
):
    """Update stamdata for a citizen/student.

    This endpoint updates only the fields provided in the request body.

    Args:
        cpr:
            The CPR number of the citizen/student whose stamdata should be
            updated.

        request:
            The request body containing the stamdata fields that should be
            updated.

        db:
            The database session injected by FastAPI.

    Returns:
        The updated citizen stamdata or a result object from the service.

    Notes:
        exclude_unset=True means only fields actually sent by the caller are
        included in the update payload.

        This is important for PATCH endpoints because missing fields should
        usually mean "do not change this field", not "set this field to None".
    """

    service = CitizenService(db=db)

    # Convert the Pydantic model into a dictionary containing only fields
    # that were explicitly provided in the request.
    stamdata = request.model_dump(exclude_unset=True)

    return service.update_citizen_stamdata(
        cpr=cpr,
        stamdata=stamdata,
    )
