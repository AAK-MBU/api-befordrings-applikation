"""API routes for bevilling-related operations.

A bevilling represents a transport-related grant/decision for a citizen.
This router exposes endpoints used by the frontend to retrieve, create,
update and manage bevillinger and their related kørselsrækker.

The main concepts are:

- Bevilling:
    The overall grant/decision connected to a child/citizen.

- Kørselsrække:
    A transport row connected to a bevilling. It contains transport type,
    valid dates, weekdays, distance and optional additions.

- Hjælpemidler:
    A many-to-many relation between bevillinger and hjælpemidler.

- Kørselstype tillæg and dage:
    Many-to-many relations connected to individual kørselsrækker.
"""

from datetime import date, datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from app.services.bevilling_service import BevillingService
from app.services.citizen_service import CitizenService
from app.utils import helper_functions


router = APIRouter(prefix="/bevilling", tags=["Bevilling"])


# -----------------------------
# Request models
# -----------------------------

class BevillingCreateRequest(BaseModel):
    """Request body used when creating a new bevilling."""

    adresse_for_bevilling: str | None = None
    status_id: int
    matrikel_id: int | None = None
    hjemmel_id: int | None = None
    afgoerelsesbrev_id: int | None = None

    revurderingsdato: date | None = None
    befordringsudvalg: date | None = None
    esdh_noegle: str | None = None

    sagsbehandler_id: int | None = None
    ppr_sagsbehandler_id: int | None = None

    ansoegningsdato: date | None = None
    sagsbehandlingsdato: date | None = None
    relation_til_barnet: str | None = None
    foerste_koersel_dato: date | None = None
    ansoegningstype: str | None = None

    afstandskriterie_dato: date | None = None
    afstandskriterie_klassetrin: int | None = None
    begrundelse_fra_formular: str | None = None
    noter: str | None = None

    hjaelpemiddel_ids: list[int] = Field(default_factory=list)


class HjaelpemidlerUpdateRequest(BaseModel):
    """Request body used when replacing hjælpemidler for a bevilling."""

    hjaelpemiddel_ids: list[int] = Field(default_factory=list)


class KoerselsraekkeCreateRequest(BaseModel):
    """Request body used when creating a new kørselsrække."""

    gyldig_fra: date | None = None
    gyldig_til: date | None = None
    tidspunkt_id: int | None = None
    befordringstype_id: int | None = None
    bevilget_koereafstand_pr_vej: float | None = None

    taxa_id: str | None = None
    kommentar: str | None = None
    status_id: int | None = None
    final: bool = False

    tillaeg_ids: list[int] = Field(default_factory=list)
    dag_ids: list[int] = Field(default_factory=list)


class KoerselsraekkeUpdateRequest(BaseModel):
    """Request body used when updating editable fields on a kørselsrække."""

    tidspunkt_id: int | None = None
    befordringstype_id: int | None = None
    bevilget_koereafstand_pr_vej: float | None = None
    gyldig_fra: date | None = None
    gyldig_til: date | None = None
    taxa_id: str | None = None
    kommentar: str | None = None


class KoerselTillaegUpdateRequest(BaseModel):
    """Request body used when replacing tillæg for a kørselsrække."""

    tillaeg_ids: list[int] = Field(default_factory=list)


class KoerselDageUpdateRequest(BaseModel):
    """Request body used when replacing weekdays for a kørselsrække."""

    dag_ids: list[int] = Field(default_factory=list)


# -----------------------------
# Bevilling reads
# -----------------------------

@router.get("/get_bevillinger")
def get_bevillinger(
    status: Optional[str] = Query(None),
    cpr: Optional[str] = Query(None),
    order_by: Optional[str] = Query(None),
    order_direction: str = Query("ASC")
):
    """Retrieve bevillinger from the active-bevillinger view.

    This endpoint is a general read endpoint for bevillinger. Optional query
    parameters can be used to filter by status or CPR and to order the result.

    Parameters
    ----------
    status : str | None
        Optional status text to filter by, for example "Aktiv".

    cpr : str | None
        Optional CPR number to filter by.

    order_by : str | None
        Optional column to order by. Allowed columns are controlled in the
        service layer.

    order_direction : str
        Sort direction. Must be "ASC" or "DESC". Defaults to "ASC".

    Returns
    -------
    list[dict]
        Bevilling records from the active-bevillinger view.

    Example request
    ---------------
    GET /bevilling/get_bevillinger?status=Aktiv&order_by=created_at&order_direction=DESC
    """

    service = BevillingService()

    order_config = None

    if order_by:
        order_config = {
            "key": order_by,
            "order_direction": order_direction
        }

    return service.get_bevillinger(
        view_name="[befordring_app].[befordring].[view_All_Active_Bevillinger]",
        status=status,
        cpr=cpr,
        order_by=order_config
    )


@router.get("/get_bevilling/{bevilling_id}")
def get_bevilling(bevilling_id: int):
    """Retrieve a single bevilling by ID.

    Parameters
    ----------
    bevilling_id : int
        Unique ID of the bevilling.

    Returns
    -------
    dict | None
        The matching bevilling record, or None if no record exists.

    Example request
    ---------------
    GET /bevilling/get_bevilling/42
    """

    service = BevillingService()

    return service.get_bevilling(bevilling_id=bevilling_id)


@router.get("/get_student_bevillinger/{cpr}")
def get_student_bevillinger(cpr: str):
    """Retrieve all bevillinger for a specific citizen.

    Parameters
    ----------
    cpr : str
        CPR number identifying the child/citizen.

    Returns
    -------
    list[dict]
        Bevillinger belonging to the citizen.

    Example request
    ---------------
    GET /bevilling/get_student_bevillinger/0101101234
    """

    service = BevillingService()

    return service.get_student_bevillinger(cpr=cpr)


@router.get("/get_bevilling_koerselsraekker/{bevilling_id}")
def get_bevilling_koerselsraekker(bevilling_id: int):
    """Retrieve all kørselsrækker for a bevilling.

    Parameters
    ----------
    bevilling_id : int
        Unique ID of the bevilling.

    Returns
    -------
    list[dict]
        Kørselsrækker connected to the bevilling.

    Example request
    ---------------
    GET /bevilling/get_bevilling_koerselsraekker/42
    """

    service = BevillingService()

    return service.get_bevilling_koerselsraekker(
        bevilling_id=bevilling_id
    )


# -----------------------------
# Bevilling writes
# -----------------------------

@router.post("/create_bevilling/{cpr}")
def create_bevilling(cpr: str, request: BevillingCreateRequest):
    """Create a new bevilling for a citizen.

    Parameters
    ----------
    cpr : str
        CPR number identifying the child/citizen.

    request : BevillingCreateRequest
        Request body containing the fields for the new bevilling.

    Returns
    -------
    dict
        Metadata about the created bevilling.

        Example:

        {
            "bevilling_id": 123,
            "rows_inserted": 1
        }

    Example request
    ---------------
    POST /bevilling/create_bevilling/0101101234
    """

    service = BevillingService()

    return service.create_bevilling(
        cpr=cpr,
        new_bevilling_data=request.model_dump(exclude_none=True)
    )


@router.put("/{bevilling_id}")
def update_bevilling(bevilling_id: int, bevilling_data: dict):
    """Update editable fields on an existing bevilling.

    The service layer controls which fields are allowed to be updated.
    This protects the database from accidental updates to columns that should
    not be edited from the frontend.

    Parameters
    ----------
    bevilling_id : int
        Unique ID of the bevilling to update.

    bevilling_data : dict
        JSON body containing one or more editable bevilling fields.

    Returns
    -------
    dict
        Update metadata.

        Example:

        {
            "rows_updated": 1,
            "updated_fields": ["status_id", "sagsbehandlingsdato"]
        }

    Example request
    ---------------
    PUT /bevilling/42
    """

    service = BevillingService()

    return service.update_bevilling(
        bevilling_id=bevilling_id,
        bevilling_data=bevilling_data
    )


@router.delete("/{bevilling_id}")
def delete_bevilling(bevilling_id: int):
    """Delete a bevilling.

    Warning
    -------
    This is a hard delete. If related kørselsrækker or link-table records
    exist, the database must either allow cascading deletes or this operation
    will fail due to foreign key constraints.

    Parameters
    ----------
    bevilling_id : int
        Unique ID of the bevilling to delete.

    Returns
    -------
    dict
        Delete metadata.

        Example:

        {
            "rows_deleted": 1
        }
    """

    service = BevillingService()

    return service.delete_bevilling(bevilling_id=bevilling_id)


@router.put("/{bevilling_id}/hjaelpemidler")
def update_bevilling_hjaelpemidler(
    bevilling_id: int,
    request: HjaelpemidlerUpdateRequest
):
    """Replace all hjælpemidler attached to a bevilling.

    The request body must contain the complete selected list. Existing links
    are deleted and replaced with the supplied IDs.

    Parameters
    ----------
    bevilling_id : int
        Unique ID of the bevilling.

    request : HjaelpemidlerUpdateRequest
        List of selected hjælpemiddel IDs.

    Returns
    -------
    dict
        Link-table update metadata.
    """

    service = BevillingService()

    return service.update_bevilling_hjaelpemidler(
        bevilling_id=bevilling_id,
        hjaelpemiddel_ids=request.hjaelpemiddel_ids
    )


# -----------------------------
# Kørselsrække writes
# -----------------------------

@router.post("/create_koerselsraekke/{bevilling_id}")
def create_koerselsraekke(
    bevilling_id: int,
    request: KoerselsraekkeCreateRequest
):
    """Create a new kørselsrække for a bevilling.

    Parameters
    ----------
    bevilling_id : int
        Unique ID of the bevilling the kørselsrække belongs to.

    request : KoerselsraekkeCreateRequest
        Request body containing the kørselsrække fields and optional link-table
        IDs for tillæg and weekdays.

    Returns
    -------
    dict
        Metadata about the created kørselsrække.

        Example:

        {
            "koersel_id": 456,
            "rows_inserted": 1
        }
    """

    service = BevillingService()

    try:
        return service.create_koerselsraekke(
            bevilling_id=bevilling_id,
            new_koerselsraekke_data=request.model_dump(exclude_none=True)
        )

    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error)
        ) from error


@router.put("/koerselsraekke/{koersel_id}")
def update_koerselsraekke(
    koersel_id: int,
    request: KoerselsraekkeUpdateRequest
):
    """Update editable fields on a kørselsrække.

    This endpoint only updates direct columns on the Koersel table. Tillæg and
    weekdays are handled by separate endpoints because they are stored in
    link tables.

    Parameters
    ----------
    koersel_id : int
        Unique ID of the kørselsrække/Koersel row.

    request : KoerselsraekkeUpdateRequest
        Editable kørselsrække fields.

    Returns
    -------
    dict
        Update metadata.
    """

    service = BevillingService()

    return service.update_koerselsraekke(
        koersel_id=koersel_id,
        koerselsraekke_data=request.model_dump(exclude_unset=True)
    )


@router.put("/koerselsraekke/{koersel_id}/tillaeg")
def update_koerselsraekke_tillaeg(
    koersel_id: int,
    request: KoerselTillaegUpdateRequest
):
    """Replace all kørselstype-tillæg attached to a kørselsrække.

    Parameters
    ----------
    koersel_id : int
        Unique ID of the kørselsrække.

    request : KoerselTillaegUpdateRequest
        Complete list of selected tillæg IDs.

    Returns
    -------
    dict
        Link-table update metadata.
    """

    service = BevillingService()

    return service.update_koerselsraekke_tillaeg(
        koersel_id=koersel_id,
        tillaeg_ids=request.tillaeg_ids
    )


@router.put("/koerselsraekke/{koersel_id}/dage")
def update_koerselsraekke_dage(
    koersel_id: int,
    request: KoerselDageUpdateRequest
):
    """Replace all weekdays attached to a kørselsrække.

    Parameters
    ----------
    koersel_id : int
        Unique ID of the kørselsrække.

    request : KoerselDageUpdateRequest
        Complete list of selected weekday IDs.

    Returns
    -------
    dict
        Link-table update metadata.
    """

    service = BevillingService()

    return service.update_koerselsraekke_dage(
        koersel_id=koersel_id,
        dag_ids=request.dag_ids
    )


# -----------------------------
# Letter creation
# -----------------------------

@router.post("/create_letter/{cpr}/{bevilling_id}")
def create_letter(cpr: str, bevilling_id: int, letter_data: dict):
    """Queue creation of an afgørelsesbrev.

    This endpoint combines frontend letter data, citizen stamdata and bevilling
    data into one payload and sends it to the configured Automation Server
    workqueue.

    Parameters
    ----------
    cpr : str
        CPR number identifying the citizen. Hyphens are removed before use.

    bevilling_id : int
        Unique ID of the bevilling used for the letter.

    letter_data : dict
        Additional letter-specific data from the frontend.

    Returns
    -------
    dict
        Queue metadata.

        Example:

        {
            "status": "queued",
            "reference": "0101101234_2026_04_28_10_30_00"
        }
    """

    cleaned_cpr = cpr.replace("-", "")

    current_timestamp = datetime.now().strftime("%Y-%m-%d_%H_%M_%S")
    reference = f"{cleaned_cpr}_{current_timestamp}"

    citizen_service = CitizenService()
    bevilling_service = BevillingService()

    citizen_data = citizen_service.get_stamdata(cpr=cleaned_cpr)
    bevilling_data = bevilling_service.get_bevilling(bevilling_id=bevilling_id)

    merged_data = {
        "data": {
            **letter_data,
            **(citizen_data if citizen_data else {}),
            **(bevilling_data if bevilling_data else {})
        },
        "reference": reference
    }

    ats_workqueue = helper_functions.fetch_workqueue(
        workqueue_name="bur.befordring.afgoerelsesbreve"
    )

    ats_workqueue.add_item(
        data={"item": merged_data},
        reference=reference
    )

    return {
        "status": "queued",
        "reference": reference
    }
