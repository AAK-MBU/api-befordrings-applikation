"""API endpoints for Befordring functionalities."""

from datetime import datetime
from dateutil.relativedelta import relativedelta

from fastapi import APIRouter

from app.utils.database import fetch_child_distance_to_school

router = APIRouter(prefix="/os2forms/api/befordring", tags=["Befordring"])


@router.get("/get_child_distance_to_school/{cpr}/{month_year}")
def get_child_distance_to_school(cpr: str, month_year: str):
    """
    Retrieve a child's distance to school based on CPR and reporting month.
    """

    string_cpr = str(cpr)

    child_data = fetch_child_distance_to_school(
        cpr=string_cpr,
        month_year=month_year,
    )

    if child_data.empty:

        return [
            {
                "value": "Kunne ikke udregne barns distance"
            }
        ]

    distance_in_km = child_data["BevilgetKoereAfstand"].iloc[0]

    return [
        {
            "value": str(distance_in_km)
        }
    ]


@router.get("/get_reporting_months")
def get_reporting_months():
    """
    Return the current month and the previous 4 months
    for OS2Forms dropdown selection.
    """

    months = []

    month_names_da = {
        1: "Januar",
        2: "Februar",
        3: "Marts",
        4: "April",
        5: "Maj",
        6: "Juni",
        7: "Juli",
        8: "August",
        9: "September",
        10: "Oktober",
        11: "November",
        12: "December",
    }

    today = datetime.today()

    for i in range(5):

        date = today - relativedelta(months=i)

        key = date.strftime("%Y-%m")
        value = f"{month_names_da[date.month]} {date.year}"

        months.append(
            {
                "key": key,
                "value": value
            }
        )

    return months
