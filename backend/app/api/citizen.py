"""API routes for citizen-related data.

This module exposes endpoints for retrieving and updating citizen data used
on the concrete citizen case page.

The routes primarily handle:

- Stamdata for a child/citizen
- Parent/guardian information
- Editable stamdata fields stored on the Elev table
"""

from fastapi import APIRouter

from app.services.citizen_service import CitizenService


router = APIRouter(prefix="/citizen", tags=["Citizen"])


@router.get("/stamdata/{cpr}")
def get_stamdata(cpr: str):
    """Retrieve stamdata for a specific citizen.

    Stamdata is the core data shown on the citizen case page. It contains
    the child's identifying and case-relevant information, for example name,
    CPR, address, school, class data, school distance and mirrored status.

    Parameters
    ----------
    cpr : str
        CPR number identifying the citizen whose stamdata should be retrieved.

    Returns
    -------
    dict | None
        The citizen stamdata record if found. If no record exists for the CPR,
        None is returned.

        Example response:

        {
            "cpr": "0101101234",
            "adresseringsnavn": "Test Barnesen",
            "adresse_tekst": "Testvej 1, 8000 Aarhus C",
            "skolematrikel": "Langagerskolen",
            "skoleafstand": 6.2,
            "status_tekst": "Aktiv"
        }

    Example request
    ---------------
    GET /citizen/stamdata/0101101234
    """

    service = CitizenService()

    return service.get_stamdata(cpr=cpr)


@router.get("/stamdata/{cpr}/parents")
def get_parent_data(cpr: str):
    """Retrieve parent/guardian information for a child.

    This endpoint returns parent data connected to the supplied child CPR.
    The data is used in the "Oplysninger om forældre" table on the citizen
    case page.

    Parameters
    ----------
    cpr : str
        CPR number identifying the child whose parent data should be retrieved.

    Returns
    -------
    list[dict]
        A list of parent/guardian records.

        Example response:

        [
            {
                "adresseringsnavn": "Parent Name",
                "cpr_foraelder": "0101701234",
                "adresse_tekst": "Parent Address",
                "foraeldremyndighed": true,
                "navne_adresse_beskyttelse": false
            }
        ]

    Example request
    ---------------
    GET /citizen/stamdata/0101101234/parents
    """

    service = CitizenService()

    return service.get_parent_data(cpr=cpr)


@router.patch("/stamdata/{cpr}")
def update_citizen_stamdata(cpr: str, stamdata: dict):
    """Update editable stamdata fields for a citizen.

    The frontend sends field names from the stamdata view. The service maps
    those fields to the actual database columns on the Elev table.

    Only explicitly allowed fields can be updated through this endpoint.
    Unknown or disallowed fields return HTTP 400.

    Parameters
    ----------
    cpr : str
        CPR number identifying the citizen to update.

    stamdata : dict
        JSON body containing the stamdata fields to update.

        Example body:

        {
            "skoleafstand": 5.7,
            "klasseart": "Specialklasse",
            "elevklassetrin": 4
        }

    Returns
    -------
    dict
        Information about the update operation.

        Example response:

        {
            "rows_updated": 1,
            "updated_fields": [
                "skoleafstand",
                "klasseart",
                "elevklassetrin"
            ]
        }

    Example request
    ---------------
    PATCH /citizen/stamdata/0101101234
    """

    service = CitizenService()

    return service.update_citizen_stamdata(
        cpr=cpr,
        stamdata=stamdata
    )
