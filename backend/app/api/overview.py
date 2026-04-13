"""API endpoints for dashboard / front page overview functionality.

This module exposes endpoints used by the application's front page
("Forside") to populate the dashboard views seen by caseworkers.

The dashboard provides quick access to:

- Active bevillinger
- New applications awaiting processing
- Cases pending reassessment (revurdering)
- Links to reports

The endpoints in this router return aggregated data structures used
to populate the tables displayed in the UI.

These endpoints are intended for internal use by the case management
application frontend.
"""

import os

from fastapi import APIRouter

from app.services.bevilling_service import BevillingService
from app.services.citizen_service import CitizenService
from app.utils import database

router = APIRouter(prefix="/overview", tags=["Overview"])

DBCONNECTIONSTRINGDEV = os.getenv("DBCONNECTIONSTRINGDEV")
DBCONNECTIONSTRINGPROD = os.getenv("DBCONNECTIONSTRINGPROD")


@router.get("/sagsbehandlere")
def get_sagsbehandlere():
    """
    Retrieve sagsbehandlere from the database
    This API endpoint initialises the CitizenService class, that auto initialises a db connection string, defined in the database.py utils file
    We simply call the class function, get_sagsbehandlere(), which auto runs the desired SQL for fetching sagsbehandlere
    """

    service = CitizenService()

    sagsbehandlere = service.get_sagsbehandlere()

    return sagsbehandlere


@router.get("/aktive_bevillinger")
def get_active_bevillinger():
    """
    Retrieve active bevillinger.

    Returns a list of bevillinger that are currently active in the
    system. These records populate the "Overblik over aktive
    bevillinger" table on the dashboard.

    Returns
    -------
    list[dict]

    Example response:

    [
        {
            "navn": "Kasper Hansentest",
            "cpr": "230115-5000",
            "status": "Aktiv",
            "sags_id": "BOR-123456",
            "sagsbehandler": "Sofie Elrum",
            "ppr_ansvarlig": "Klaus"
        }
    ]

    Example request
    ---------------
    GET /overview/aktive_bevillinger
    """

    service = BevillingService()

    active_bevillinger = service.get_bevillinger(status="Aktiv", order_by={"key": "created_at", "order_direction": "DESC"})

    return [
        {
            "Navn": bev.get("navn"),
            "CPR": bev.get("cpr"),
            "Status": bev.get("status"),
            "Sags-ID": bev.get("sags_id"),
            "Sagsbehandler": bev.get("sagsbehandler"),
            "PPR ansvarlig": bev.get("ppr_ansvarlig"),
            "Noter": bev.get("notes"),
        }
        for bev in active_bevillinger
    ]


@router.get("/new_applications")
def get_new_applications():
    """
    Retrieve new transport applications.

    Returns a list of newly submitted transport applications that
    have not yet been processed by a caseworker.

    These records populate the "Nye ansøgninger" table on the
    dashboard.

    Returns
    -------
    list[dict]

    Example response:

    [
        {
            "navn": "Ulrik Hansentest",
            "cpr": "251199-0000",
            "status": "Ny",
            "sags_id": "BOR-254692",
            "modtagelsesdato": "2025-11-21",
            "dato_for_forste_koersel": "2025-12-01",
            "ansogningstype": "Midlertidig kørsel"
        }
    ]

    Example request
    ---------------
    GET /overview/nye_ansogninger
    """

    sql = """
        SELECT
            *
        FROM
            DATA_NYE_ANSOEGNINGER
    """

    df = database.read_sql(
        query=sql,
        params={},
        conn_string=DBCONNECTIONSTRINGDEV
    )

    return df.to_dict("records")


@router.get("/revurderinger")
def get_reassessments():
    """
    Retrieve bevillinger pending reassessment.

    Returns cases where a bevilling must be reassessed
    (revurdering). These cases typically require additional
    evaluation by a caseworker.

    Returns
    -------
    list[dict]

    Example response:

    [
        {
            "navn": "Example Citizen",
            "cpr": "120345-6789",
            "status": "Revurdering",
            "sags_id": "BOR-654321"
        }
    ]

    Example request
    ---------------
    GET /overview/revurderinger
    """

    service = BevillingService()

    service.get_bevillinger(status="Revurdering")


@router.get("/reports")
def get_reports():
    """
    Retrieve reports.

    Returns a list of available reports

    Returns
    -------
    list[dict]

    Example response:

    Ringetider
    Antal skoleelever, der har befordring til buskort, taxa/minibus
    Antal buskort for skoleelever
    Antal kørsler med taxa/minibus og prisen herfor for skoleelever

    Example request
    ---------------
    GET /overview/reports
    """

    sql = """
        SELECT
            *
        FROM
            DATA_REPORTS
    """

    df = database.read_sql(
        query=sql,
        params={},
        conn_string=DBCONNECTIONSTRINGDEV
    )

    return df.to_dict("records")
