"""API endpoints for bevilling related operations.

This module exposes endpoints used to retrieve, create, and manage
bevilling records for citizens. A bevilling represents a decision or
grant related to transport assistance (e.g., school transport).

The endpoints in this router provide functionality to:

- Retrieve all bevillinger for a given citizen
- Retrieve a specific bevilling
- Create a new bevilling for a citizen

All endpoints interact with the database through the shared
database utility module.
"""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter
from fastapi import Query

from app.services.citizen_service import CitizenService
from app.services.bevilling_service import BevillingService
from app.utils import helper_functions

router = APIRouter(prefix="/bevilling", tags=["Bevilling"])

TEST_CITIZEN_DATA = {
    "barnets_fulde_navn": "Kasper Hansentest",

    "barnets_cpr": "230115-5000",

    "status": "aktiv",

    "folkeregisteradresse": "Gade 1, 8000 Aarhus C",

    "skole": "Langagerskolen",

    "skolematrikel": "Kolt Østervej 45",

    "gaaafstand_km": "10",

    "klasseart": "modtagerklasse",

    "klassebetegnelse": "M1",

    "personligt_klassetrin": "2",

    "sfo": "SFO - Holme skole",

    "bopaelsdistrikt": "Holme skole",

    "sagsbehandlingsdato": "26-11-2025",

    "adresse_for_bevilling": "Gade 1, 8000 Aarhus C",

    "hjaelpemidler": "Kørestol, Magnetsele",

    "afstandskriterie_dato": "01-07-2026",

    "afstandskriterie_klassetrin": "3",

    "ansoeger_relation": "Forældremyndighed",

    "revurdering": "30-06-2026",

    "befordringsudvalg": "20-06-2026",

    "hjemmel": "§ 26, stk. 1 afstand",

    "afgoerelsesbrev": "Bevilling: § 26, stk. 1, nr. 1 (afstand)",

    "sagsbehandler": "Sofie Elrum",

    "ppr_ansvarlig": "Klaus",

    "koerselsraekker": {
        "rutekoersel": {
            "tidspunkt": "Morgen",
            "koerselstype_tillaeg": "Fast forsæde",
            "bevilget_koereafstand_pr_vej": "10",
            "dage": "Alle",
            "bevilling_fra": "01-01-2026",
            "bevilling_til": "01-01-2027",
            "taxa_id": "",
        },
        "skolerejsekort": {
            "tidspunkt": "Eftermiddag",
            "koerselstype_tillaeg": "Co-driver, Fast sæde",
            "bevilget_koereafstand_pr_vej": "10",
            "dage": "Alle",
            "bevilling_fra": "01-01-2026",
            "bevilling_til": "01-01-2027",
            "taxa_id": "",
        },
        # "test": {
        #     "tidspunkt": "morgen",
        #     "koerselstype_tillaeg": [""],
        #     "bevilget_koereafstand_pr_vej": "10",
        #     "dage": "tirsdag",
        #     "bevilling_fra": "01-01-2026",
        #     "bevilling_til": "01-01-2027",
        #     "taxa_id": "",
        # },
    },

    "modtagelsesdato": "21-11-2025"
}


@router.post("/create_letter/{cpr}/{bevilling_id}")
def create_letter(cpr: str, bevilling_id: int, letter_data: dict):
    """
    Create new letter
    """

    cpr = cpr.replace("-", "")

    ### !!! REMOVE !!! ###
    citizen_data = TEST_CITIZEN_DATA
    bevilling_data = {}
    ### !!! REMOVE !!! ###

    current_timestamp = datetime.now().strftime("%Y-%m-%d_%H_%M_%S")

    bevilling_service = BevillingService()
    citizen_service = CitizenService()

    # citizen_data = citizen_service.get_stamdata(cpr=cpr)
    # bevilling_data = bevilling_service.get_bevilling(bevilling_id=bevilling_id)

    ref = f"{cpr}_{current_timestamp}".replace(" ", "_").replace("-", "_").replace(".", "_").replace(":", "_")

    merged_data = {
        "data": {
            **letter_data,
            **(citizen_data if citizen_data else {}),
            **(bevilling_data if bevilling_data else {})
        },
        "reference": ref
    }

    ats_workqueue = helper_functions.fetch_workqueue(workqueue_name="bur.befordring.afgoerelsesbreve")

    data = {
        "item": merged_data,
    }

    ats_workqueue.add_item(data=data, reference=ref)

    return {
        "status": "queued",
        "reference": ref
    }


@router.get("/get_bevillinger")
def get_bevillinger(
    status: Optional[str] = Query(None),
    created_at: Optional[str] = Query(None),
    cpr: Optional[str] = Query(None),
    bevilling_til: Optional[str] = Query(None),
    bevilling_fra: Optional[str] = Query(None),
    order_by: Optional[str] = Query(None)
):
    """
    Retrieve all bevillinger.

    This endpoint returns all bevillinger records.

    Parameters
    ----------
    None

    Returns
    -------
    list[dict]
        A list containing all bevillinger

        Example response:
        [
            {
                "bevilling_id": 42,
                "status": "Aktiv",
                "skole": "Langagerskolen",
                "sagsbehandler": "Sofie Elrum"
            },
            {
                "bevilling_id": 43,
                "status": "Aktiv",
                "skole": "Stensagerskolen",
                "sagsbehandler": "Sofie Elrum"
            },
        ]

    Example request
    ---------------
    GET /bevilling/get_bevillinger
    """

    service = BevillingService()

    return service.get_bevillinger(
        status=status,
        created_at=created_at,
        cpr=cpr,
        bevilling_til=bevilling_til,
        bevilling_fra=bevilling_fra,
        order_by=order_by
    )


@router.get("/get_bevilling/{bevilling_id}")
def get_bevilling(bevilling_id: int):
    """
    Retrieve a specific bevilling.

    This endpoint returns a single bevilling record identified by
    the bevilling ID.

    Parameters
    ----------
    bevilling_id : str
        Unique identifier of the bevilling record.

    Returns
    -------
    list[dict]
        A list containing the bevilling record matching the
        specified identifier.

        Example response:
        [
            {
                "bevilling_id": 42,
                "status": "Aktiv",
                "skole": "Langagerskolen",
                "sagsbehandler": "Sofie Elrum"
            }
        ]

    Example request
    ---------------
    GET /bevilling/get_bevilling/42
    """

    service = BevillingService()

    return service.get_bevilling(bevilling_id=bevilling_id)


@router.get("/get_citizen_bevillinger/{cpr}")
def get_citizen_bevillinger(cpr: str):
    """
    Retrieve all bevillinger for a specific citizen.

    This endpoint returns all bevilling records associated with a
    given CPR number. Each bevilling represents a decision regarding
    transport eligibility for the citizen.

    Parameters
    ----------
    cpr : str
        CPR number identifying the citizen.

    Returns
    -------
    list[dict]
        A list of bevilling records belonging to the citizen.

        Example response:
        [
            {
                "bevilling_id": 42,
                "status": "Aktiv",
                "skole": "Langagerskolen",
                "gaaafstand": 6
            },
            ...
        ]

    Example request
    ---------------
    GET /bevilling/get_citizen_bevillinger/2301155000
    """

    service = BevillingService()

    bevillinger = service.get_citizen_bevillinger(cpr=cpr)

    for bev in bevillinger:
        koerselsraekker = service.get_koerselsraekker(bevilling_id=bev["bevilling_id"])

        bev["koerselsraekker"] = koerselsraekker

    return bevillinger


@router.post("/create_koerselsraekke/{bevilling_id}")
def create_koerselsraekke(bevilling_id: str, new_koerselsraekke_data: dict):
    """
    """

    service = BevillingService()

    return service.create_koerselsraekke(bevilling_id=bevilling_id, new_koerselsraekke_data=new_koerselsraekke_data)


@router.post("/create_bevilling/{cpr}")
def create_bevilling(cpr: str, new_bevilling_data: dict):
    """
    Create a new bevilling for a citizen.

    This endpoint inserts a new bevilling record into the database
    for the specified CPR number. The request body should contain
    all fields required to create a bevilling.

    The exact fields depend on the underlying database schema.

    Parameters
    ----------
    cpr : str
        CPR number identifying the citizen for whom the bevilling
        should be created.

    new_bevilling_data : dict
        JSON body containing the data required to create the new
        bevilling record.

    Returns
    -------
    dict
        A dictionary indicating how many rows were inserted.

        Example:
        {
            "rows_inserted": 1
        }

    Example request
    ---------------
    POST /bevilling/create_bevilling/2301155000

    Body:
    {
        "status": "Aktiv",
        "sagsbehandlingsdato": "2025-11-26",
        "skole": "Langagerskolen",
        "gaaafstand": 6
    }

    Example response
    ----------------
    {
        "rows_inserted": 1
    }
    """

    service = BevillingService()

    return service.create_bevilling(cpr=cpr, new_bevilling_data=new_bevilling_data)


@router.put("/{bevilling_id}")
def update_bevilling(bevilling_id: int, bevilling_data: dict):
    """
    Update an existing bevilling.

    This endpoint updates fields for a specific bevilling record. The bevilling
    is identified by its unique bevilling_id, which is provided as a path
    parameter.

    The request body must contain one or more fields to update. The keys in the
    JSON body must correspond to column names in the bevilling table.

    The SQL UPDATE statement is constructed dynamically so that only the fields
    provided in the request body are updated.

    Example generated SQL if the request body contains "status" and
    "sagsbehandlingsdato":

        UPDATE bevillinger
        SET status = :status,
            sagsbehandlingsdato = :sagsbehandlingsdato
        WHERE bevilling_id = :bevilling_id

    Parameters
    ----------
    bevilling_id : int
        Unique identifier for the bevilling to update.

    bevilling_data : dict
        JSON body containing one or more fields to update. Keys must match
        column names in the bevillinger table.

    Returns
    -------
    dict
        A dictionary containing the number of rows updated.

        Example:
        {"rows_updated": 1}

    Example request
    ---------------
    PUT /bevilling/123

    Body:
    {
        "status": "Aktiv",
        "sagsbehandlingsdato": "2025-11-26",
        "skole": "Langagerskolen",
        "gaaafstand": 6
    }

    Example response
    ----------------
    {
        "rows_updated": 1
    }
    """

    service = BevillingService()

    return service.update_bevilling(bevilling_id=bevilling_id, bevilling_data=bevilling_data)


@router.delete("/{bevilling_id}")
def delete_bevilling(bevilling_id: int):
    """
    Delete an existing bevilling.

    This endpoint removes a bevilling record from the database based on
    the provided bevilling_id. The bevilling_id uniquely identifies the
    bevilling entry that should be deleted.

    This operation permanently removes the bevilling from the system.
    If related records exist (e.g., kørselsrækker linked to the bevilling),
    the database must either enforce referential integrity or cascade the
    deletion depending on the schema configuration.

    Parameters
    ----------
    bevilling_id : int
        Unique identifier of the bevilling record to delete.

    Returns
    -------
    dict
        A dictionary indicating how many rows were deleted.

        Example:
        {
            "rows_deleted": 1
        }

    Example request
    ---------------
    DELETE /bevilling/123

    Example response
    ----------------
    {
        "rows_deleted": 1
    }
    """

    service = BevillingService()

    return service.delete_bevilling(bevilling_id=bevilling_id)
