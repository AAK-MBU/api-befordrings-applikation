"""API routes for dashboard/front page overview data.

This module exposes endpoints used by the application's front page
("Forside") to populate overview tables for caseworkers.

The overview currently contains:

- Active bevillinger
- Non-active bevillinger
- New applications awaiting processing
- Bevillinger pending reassessment
- Report links/data

These endpoints are intended for the internal frontend application.
"""

from fastapi import APIRouter

from app.services.bevilling_service import BevillingService
from app.utils import database


router = APIRouter(prefix="/overview", tags=["Overview"])


# -----------------------------
# Helpers
# -----------------------------

def map_bevilling_overview_record(bevilling: dict):
    """Map a raw bevilling record to the frontend overview shape.

    The views used by the overview pages contain more columns than the
    frontend currently needs. This helper keeps the returned API shape small
    and consistent across active, non-active and reassessment endpoints.

    Parameters
    ----------
    bevilling : dict
        Raw bevilling record from a database view.

    Returns
    -------
    dict
        Frontend-friendly overview record.
    """

    return {
        "navn": bevilling.get("adresseringsnavn"),
        "cpr": bevilling.get("cpr_elev"),
        "status": bevilling.get("status_tekst"),
        "esdh_noegle": bevilling.get("esdh_noegle"),
        "sagsbehandler": bevilling.get("sagsbehandler"),
        "ppr_sagsbehandler": bevilling.get("ppr_sagsbehandler_tekst"),
        "noter": bevilling.get("noter"),
    }


def read_overview_table(table_name: str):
    """Read all records from a dashboard overview table.

    This helper is used for simple dashboard tables/views where the endpoint
    does not need dynamic filtering.

    Important
    ---------
    The table name must only come from hardcoded values in this module.
    Do not pass user input into this function.

    Parameters
    ----------
    table_name : str
        Name of the database table or view to read from.

    Returns
    -------
    list[dict]
        Records from the selected table/view.
    """

    sql = f"""
        SELECT
            *
        FROM
            {table_name}
    """

    df = database.read_sql(
        query=sql,
        params={},
        conn_string=database.get_db_connection_string()
    )

    return df.to_dict("records")


# -----------------------------
# Bevilling overview endpoints
# -----------------------------

@router.get("/aktive_bevillinger")
def get_active_bevillinger():
    """Return active bevillinger for the dashboard.

    These records populate the "Overblik over aktive bevillinger" table
    on the front page.

    Returns
    -------
    list[dict]
        Active bevillinger formatted for the frontend.

        Example response:

        [
            {
                "navn": "Kasper Hansentest",
                "cpr": "2301155000",
                "status": "Aktiv",
                "esdh_noegle": "BOR-123456",
                "sagsbehandler": "Sofie Elrum",
                "ppr_sagsbehandler": "Klaus",
                "noter": "Example note"
            }
        ]

    Example request
    ---------------
    GET /overview/aktive_bevillinger
    """

    service = BevillingService()

    active_bevillinger = service.get_bevillinger(
        view_name="[befordring_app].[befordring].[view_All_Active_Bevillinger]"
    )

    return [
        map_bevilling_overview_record(bevilling)
        for bevilling in active_bevillinger
    ]


@router.get("/ikke_aktive_bevillinger")
def get_non_active_bevillinger():
    """Return non-active bevillinger for the dashboard.

    Non-active bevillinger are retrieved by reading all bevillinger and
    excluding records where status is "Aktiv".

    Returns
    -------
    list[dict]
        Non-active bevillinger formatted for the frontend.

    Example request
    ---------------
    GET /overview/ikke_aktive_bevillinger
    """

    service = BevillingService()

    non_active_bevillinger = service.get_bevillinger(
        view_name="[befordring_app].[befordring].[view_All_Bevillinger]",
        exclude_status="Aktiv"
    )

    return [
        map_bevilling_overview_record(bevilling)
        for bevilling in non_active_bevillinger
    ]


@router.get("/revurderinger")
def get_reassessments():
    """Return bevillinger pending reassessment.

    These records represent cases where the bevilling status is
    "Revurdering". They are used by the dashboard to highlight cases that
    require renewed caseworker evaluation.

    Returns
    -------
    list[dict]
        Bevillinger with status "Revurdering" formatted for the frontend.

    Example request
    ---------------
    GET /overview/revurderinger
    """

    service = BevillingService()

    reassessments = service.get_bevillinger(
        view_name="[befordring_app].[befordring].[view_All_Bevillinger]",
        status="Revurdering"
    )

    return [
        map_bevilling_overview_record(bevilling)
        for bevilling in reassessments
    ]


# -----------------------------
# Other dashboard endpoints
# -----------------------------

@router.get("/new_applications")
def get_new_applications():
    """Return new transport applications.

    These records populate the "Nye ansøgninger" table on the dashboard.
    They represent applications that have been received but not yet fully
    processed.

    Returns
    -------
    list[dict]
        New application records.

    Example request
    ---------------
    GET /overview/new_applications
    """

    return read_overview_table(
        table_name="[befordring_app].[befordring].[DATA_NYE_ANSOEGNINGER]"
    )


@router.get("/reports")
def get_reports():
    """Return available dashboard reports.

    The frontend uses this endpoint to display available report links or
    report metadata.

    Returns
    -------
    list[dict]
        Available report records.

    Example request
    ---------------
    GET /overview/reports
    """

    return read_overview_table(
        table_name="[befordring_app].[befordring].[DATA_REPORTS]"
    )
