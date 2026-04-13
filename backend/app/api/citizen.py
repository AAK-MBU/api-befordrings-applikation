"""API endpoints for Citizen functionalities."""

from fastapi import APIRouter

from app.services.citizen_service import CitizenService

router = APIRouter(prefix="/citizen", tags=["Citizen"])


@router.get("/stamdata/{cpr}")
def get_stamdata(cpr: str):
    """
    Retrieve stamdata (master data) for a specific citizen.

    This endpoint returns the stamdata associated with a given CPR
    number. Stamdata represents the core citizen information used
    throughout the application, such as name, address, school,
    and other identifying details.

    The data returned by this endpoint is typically used to populate
    the "Stamdata" section of a citizen's case page in the application.

    Parameters
    ----------
    cpr : str
        CPR number identifying the citizen whose stamdata should
        be retrieved.

    Returns
    -------
    list[dict]
        A list containing the citizen stamdata record.

        Example response:

        [
            {
                "cpr": "2301155000",
                "navn": "Kasper Hansentest",
                "adresse": "Gade 1, 8000 Aarhus C",
                "skole": "Langagerskolen",
                "klassetrin": 3
            }
        ]

    Example request
    ---------------
    GET /citizen/stamdata/2301155000
    """

    service = CitizenService()

    return service.get_stamdata(cpr=cpr)


@router.get("/stamdata/{cpr}/parents")
def get_parent_data(cpr: str):
    """
    Endpoint to retrieve information regarding a child's parents
    """

    service = CitizenService()

    return service.get_parent_data(cpr=cpr)


@router.put("/stamdata/{cpr}")
def update_citizen_stamdata(cpr: str, stamdata: dict):
    """
    Update stamdata (master data) for a citizen identified by CPR.

    This endpoint performs a dynamic SQL UPDATE on the citizen_stamdata table.
    Any fields included in the request body will be updated in the database.
    The keys in the request JSON must correspond to column names in the
    citizen_stamdata table.

    The CPR number used to locate the record is provided as a path parameter,
    while the fields to update are provided in the request body.

    The SQL statement is constructed dynamically so that only the supplied
    fields are updated. For example, if the request body contains "address"
    and "phone", the resulting SQL will look like:

        UPDATE citizen_stamdata
        SET address = :address,
            phone = :phone
        WHERE cpr = :cpr

    Parameters
    ----------
    cpr : str
        CPR number identifying the citizen record to update.

    stamdata : dict
        JSON body containing one or more stamdata fields to update.
        Keys must match column names in the citizen_stamdata table.

    Returns
    -------
    dict
        A dictionary containing the number of rows updated, e.g.:

        {"rows_updated": 1}

    Example request
    ---------------
    PUT /citizens/stamdata/2301155000

    Body:
    {
        "address": "New street 12, 8000 Aarhus C",
        "phone": "12345678",
        "city": "Aarhus"
    }

    Example result
    --------------
    {
        "rows_updated": 1
    }
    """

    service = CitizenService()

    service.update_citizen_stamdata(cpr=cpr, stamdata=stamdata)
