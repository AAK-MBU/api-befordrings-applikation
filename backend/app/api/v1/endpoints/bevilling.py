"""API router for bevilling-related endpoints.

This module contains all HTTP endpoints related to bevillinger, koerselsraekker,
hjaelpemidler, and letter creation.

The router mostly acts as a thin layer between FastAPI and BevillingService.

General pattern in this file:

1. Receive input from the frontend or external caller.
2. Create a BevillingService using the current database session.
3. Convert Pydantic request models into dictionaries where needed.
4. Delegate business logic to the service layer.
5. Return the service result directly to the caller.

The router should ideally not contain heavy business logic. That belongs in
BevillingService or other dedicated service/helper modules.
"""

from datetime import datetime

from fastapi import APIRouter, HTTPException, Query

from app.api.dependencies import DbSession
from app.schemas.bevilling import (
    BevillingCreateRequest,
    BevillingUpdateRequest,
    HjaelpemidlerUpdateRequest,
    KoerselDageUpdateRequest,
    KoerselTillaegUpdateRequest,
    KoerselsraekkeCreateRequest,
    KoerselsraekkeUpdateRequest,
    LetterCreateRequest,
)
from app.services.bevilling_service import BevillingService
from app.utils.ats import fetch_workqueue


# All routes in this file are grouped under /bevilling.
# The tag is used by Swagger/OpenAPI to group these endpoints visually.
router = APIRouter(prefix="/bevilling", tags=["Bevilling"])


@router.get("/get_bevillinger")
def get_bevillinger(
    db: DbSession,
    status: str | None = Query(None),
    cpr: str | None = Query(None),
    order_by: str | None = Query(None),
    order_direction: str = Query("ASC"),
):
    """Get bevillinger from the active bevillinger overview view.

    This endpoint supports optional filtering and sorting.

    Args:
        db:
            The database session injected by FastAPI.

        status:
            Optional status filter, for example "Aktiv" or "Ny".

        cpr:
            Optional CPR filter. If provided, only bevillinger for this CPR
            should be returned.

        order_by:
            Optional column/key to order the result by.

        order_direction:
            Sort direction. Defaults to "ASC".

    Returns:
        A list of bevillinger from the configured database view.

    Notes:
        The actual SQL/query construction should happen inside the service
        layer. This endpoint only prepares a small order configuration object.
    """

    service = BevillingService(db=db)

    # The service expects sorting as a dictionary.
    # If no order_by value is provided, we keep it as None.
    order_config = None

    if order_by:
        order_config = {
            "key": order_by,
            "order_direction": order_direction,
        }

    return service.get_bevillinger(
        view_name="[befordring_app].[befordring].[view_All_Active_Bevillinger]",
        status=status,
        cpr=cpr,
        order_by=order_config,
    )


@router.get("/get_bevilling/{bevilling_id}")
def get_bevilling(bevilling_id: int, db: DbSession):
    """Get a single bevilling by its ID.

    Args:
        bevilling_id:
            The primary key of the bevilling.

        db:
            The database session injected by FastAPI.

    Returns:
        The matching bevilling data, if found.
    """

    service = BevillingService(db=db)

    return service.get_bevilling(bevilling_id=bevilling_id)


@router.get("/get_student_bevillinger/{cpr}")
def get_student_bevillinger(cpr: str, db: DbSession):
    """Get all bevillinger connected to a specific student/citizen.

    Args:
        cpr:
            The CPR number of the student/citizen.

        db:
            The database session injected by FastAPI.

    Returns:
        A list of bevillinger connected to the provided CPR.
    """

    service = BevillingService(db=db)

    return service.get_student_bevillinger(cpr=cpr)


@router.get("/get_bevilling_koerselsraekker/{bevilling_id}")
def get_bevilling_koerselsraekker(bevilling_id: int, db: DbSession):
    """Get all koerselsraekker connected to a bevilling.

    A koerselsraekke represents one transport row/transport setup connected
    to the overall bevilling.

    Args:
        bevilling_id:
            The ID of the bevilling.

        db:
            The database session injected by FastAPI.

    Returns:
        A list of koerselsraekker connected to the bevilling.
    """

    service = BevillingService(db=db)

    return service.get_bevilling_koerselsraekker(
        bevilling_id=bevilling_id,
    )


@router.post("/create_bevilling/{cpr}")
def create_bevilling(
    cpr: str,
    request: BevillingCreateRequest,
    db: DbSession,
    status_text: str = Query("Ny"),
):
    """Create a new bevilling for a citizen/student.

    Args:
        cpr:
            CPR number of the citizen/student.

        request:
            The request body containing the new bevilling data.

        db:
            The database session injected by FastAPI.

        status_text:
            The initial status for the new bevilling.
            Defaults to "Ny".

    Returns:
        The newly created bevilling or a status/result object from the service.

    Notes:
        exclude_none=True means fields with value None are not sent to the
        service. This is useful when optional frontend fields should not
        overwrite or pollute insert data.
    """

    service = BevillingService(db=db)

    return service.create_bevilling(
        cpr=cpr,
        new_bevilling_data=request.model_dump(exclude_none=True),
        status_text=status_text,
    )


@router.put("/{bevilling_id}")
def update_bevilling(
    bevilling_id: int,
    request: BevillingUpdateRequest,
    db: DbSession,
):
    """Update an existing bevilling.

    Args:
        bevilling_id:
            The ID of the bevilling to update.

        request:
            The request body containing the fields that should be updated.

        db:
            The database session injected by FastAPI.

    Returns:
        The updated bevilling or a result object from the service.

    Notes:
        exclude_unset=True means only fields actually provided by the caller
        are included. This prevents missing fields from being interpreted as
        values that should be changed to None.
    """

    service = BevillingService(db=db)

    return service.update_bevilling(
        bevilling_id=bevilling_id,
        bevilling_data=request.model_dump(exclude_unset=True),
    )


@router.delete("/{bevilling_id}")
def delete_bevilling(bevilling_id: int, db: DbSession):
    """Delete or deactivate a bevilling.

    Args:
        bevilling_id:
            The ID of the bevilling to delete.

        db:
            The database session injected by FastAPI.

    Returns:
        A deletion result from the service.

    Notes:
        Whether this performs a hard delete or soft delete depends on the
        implementation inside BevillingService.delete_bevilling.
    """

    service = BevillingService(db=db)

    return service.delete_bevilling(bevilling_id=bevilling_id)


@router.put("/{bevilling_id}/hjaelpemidler")
def update_bevilling_hjaelpemidler(
    bevilling_id: int,
    request: HjaelpemidlerUpdateRequest,
    db: DbSession,
):
    """Update the hjaelpemidler connected to a bevilling.

    This endpoint updates the many-to-many relation between a bevilling and
    selected hjaelpemidler.

    Args:
        bevilling_id:
            The ID of the bevilling.

        request:
            Request body containing a list of hjaelpemiddel IDs.

        db:
            The database session injected by FastAPI.

    Returns:
        A result object from the service.
    """

    service = BevillingService(db=db)

    return service.update_bevilling_hjaelpemidler(
        bevilling_id=bevilling_id,
        hjaelpemiddel_ids=request.hjaelpemiddel_ids,
    )


@router.post("/create_koerselsraekke/{bevilling_id}")
def create_koerselsraekke(
    bevilling_id: int,
    request: KoerselsraekkeCreateRequest,
    db: DbSession,
):
    """Create a new koerselsraekke for a bevilling.

    Args:
        bevilling_id:
            The ID of the bevilling that the new koerselsraekke should belong to.

        request:
            The request body containing data for the new koerselsraekke.

        db:
            The database session injected by FastAPI.

    Returns:
        The created koerselsraekke or a result object from the service.

    Raises:
        HTTPException:
            Returns HTTP 400 if the service raises a ValueError.

    Notes:
        ValueError is converted into HTTPException here because FastAPI needs
        an HTTP-aware exception to return a proper client response.
    """

    service = BevillingService(db=db)

    try:
        return service.create_koerselsraekke(
            bevilling_id=bevilling_id,
            new_koerselsraekke_data=request.model_dump(exclude_none=True),
        )

    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error


@router.put("/koerselsraekke/{koersel_id}")
def update_koerselsraekke(
    koersel_id: int,
    request: KoerselsraekkeUpdateRequest,
    db: DbSession,
):
    """Update an existing koerselsraekke.

    Args:
        koersel_id:
            The ID of the koerselsraekke to update.

        request:
            The request body containing the fields to update.

        db:
            The database session injected by FastAPI.

    Returns:
        The updated koerselsraekke or a result object from the service.
    """

    service = BevillingService(db=db)

    return service.update_koerselsraekke(
        koersel_id=koersel_id,
        koerselsraekke_data=request.model_dump(exclude_unset=True),
    )


@router.put("/koerselsraekke/{koersel_id}/tillaeg")
def update_koerselsraekke_tillaeg(
    koersel_id: int,
    request: KoerselTillaegUpdateRequest,
    db: DbSession,
):
    """Update tillaeg connected to a koerselsraekke.

    This endpoint updates the relation between a koerselsraekke and its
    selected transport additions/tillaeg.

    Args:
        koersel_id:
            The ID of the koerselsraekke.

        request:
            Request body containing selected tillaeg IDs.

        db:
            The database session injected by FastAPI.

    Returns:
        A result object from the service.
    """

    service = BevillingService(db=db)

    return service.update_koerselsraekke_tillaeg(
        koersel_id=koersel_id,
        tillaeg_ids=request.tillaeg_ids,
    )


@router.put("/koerselsraekke/{koersel_id}/dage")
def update_koerselsraekke_dage(
    koersel_id: int,
    request: KoerselDageUpdateRequest,
    db: DbSession,
):
    """Update weekdays connected to a koerselsraekke.

    This endpoint updates which days a specific koerselsraekke applies to.

    Args:
        koersel_id:
            The ID of the koerselsraekke.

        request:
            Request body containing selected day IDs.

        db:
            The database session injected by FastAPI.

    Returns:
        A result object from the service.
    """

    service = BevillingService(db=db)

    return service.update_koerselsraekke_dage(
        koersel_id=koersel_id,
        dag_ids=request.dag_ids,
    )


@router.post("/create_letter/{cpr}/{bevilling_id}")
def create_letter(
    cpr: str,
    bevilling_id: int,
    letter_data: LetterCreateRequest,
    db: DbSession,
):
    """Create and queue a letter-generation work item.

    This endpoint does not generate the final letter directly. Instead, it
    collects the relevant data and places a work item on the ATS workqueue.

    The actual letter generation is expected to happen in a separate worker
    that consumes items from the workqueue.

    Args:
        cpr:
            CPR number of the citizen/student.

        bevilling_id:
            The bevilling ID used to fetch extra letter-related data.

        letter_data:
            Request body containing letter-specific input from the frontend.

        db:
            The database session injected by FastAPI.

    Returns:
        A small status response containing the queue status and item reference.

    Notes:
        The generated reference is based on CPR and timestamp. This makes it
        easier to identify the work item later in logs, ATS, and debugging.

        letter_data.model_extra is used because LetterCreateRequest likely
        allows dynamic fields. This requires the Pydantic model to allow extra
        fields.
    """

    # Remove hyphen from CPR so the reference has a consistent format.
    cleaned_cpr = cpr.replace("-", "")

    # Create a timestamp that is safe to use in a reference string.
    # Example: 0101011234_2026-05-11_14_30_05
    current_timestamp = datetime.now().strftime("%Y-%m-%d_%H_%M_%S")
    reference = f"{cleaned_cpr}_{current_timestamp}"

    bevilling_service = BevillingService(db=db)

    # Fetch extra data from the database that is needed for the letter.
    # This keeps the frontend from having to know or send all database fields.
    bevilling_data = bevilling_service.get_letter_data(
        bevilling_id=bevilling_id,
    )

    # Merge frontend-provided letter data with database-provided bevilling data.
    #
    # The order matters:
    # - letter_data.model_extra is added first.
    # - bevilling_data is added afterwards.
    #
    # This means values from bevilling_data will overwrite duplicate keys from
    # letter_data.model_extra.
    merged_data = {
        "data": {
            **letter_data.model_extra,
            **(bevilling_data if bevilling_data else {}),
        },
        "reference": reference,
    }

    # Fetch the ATS workqueue responsible for letter generation.
    ats_workqueue = fetch_workqueue(
        workqueue_name="bur.befordring.afgoerelsesbreve",
    )

    # Add the merged data as a new ATS work item.
    #
    # The worker consuming this queue is expected to use data["item"] as the
    # actual input payload.
    ats_workqueue.add_item(
        data={"item": merged_data},
        reference=reference,
    )

    return {
        "status": "queued",
        "reference": reference,
    }
