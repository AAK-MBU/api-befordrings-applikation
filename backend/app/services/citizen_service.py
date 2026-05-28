"""Service layer for citizen-related business logic.

This module contains database operations related to citizens/students.

The service is responsible for:

- Fetching citizen stamdata
- Fetching parent/guardian data

Citizen stamdata and parent data are maintained by external systems and are
read-only in this application. No update methods should be added here.
"""

from sqlalchemy import text
from sqlalchemy.orm import Session


class CitizenService:
    """Service class for citizen-related operations.

    Args:
        db:
            SQLAlchemy database session.
    """

    def __init__(self, db: Session):
        """Initialize the service with a database session."""

        self.db = db


    def _rows_to_dicts(self, result):
        """Convert SQLAlchemy result rows into normal dictionaries.

        Args:
            result:
                SQLAlchemy result object.

        Returns:
            A list of dictionaries.

        Notes:
            This is useful when reading from SQL views using raw SQL.
        """

        return [dict(row) for row in result.mappings().all()]


    def get_stamdata(self, cpr: str):
        """Get stamdata for a citizen/student.

        Args:
            cpr:
                CPR number of the citizen/student.

        Returns:
            A dictionary containing stamdata if found.
            Otherwise None.

        Notes:
            Data is read from view_Stamdata, not directly from the Elev table.
            This means the returned object may contain joined/calculated fields
            that are not present directly on the Elev model.
        """

        sql = text("""
            SELECT
                *
            FROM
                [befordring_app].[befordring].[view_Stamdata]
            WHERE
                cpr = :cpr
        """)

        result = self.db.execute(sql, {"cpr": cpr})
        records = self._rows_to_dicts(result)

        # No stamdata was found for this CPR.
        if not records:
            return None

        # CPR should identify one citizen/student, so return the first row.
        return records[0]


    def get_parent_data(self, cpr: str):
        """Get parent/guardian data for a citizen/student.

        Args:
            cpr:
                CPR number of the citizen/student.

        Returns:
            A list of parent/guardian records.

        Notes:
            Data is read from view_ParentData.

            The result is ordered by:
            1. foraelderrolle_sortering
            2. adresseringsnavn

            This gives the frontend a stable and predictable display order.
        """

        sql = text("""
            SELECT
                adresseringsnavn,
                cpr_foraelder,
                adresse_tekst,
                foraeldremyndighed,
                navne_adresse_beskyttelse,
                maa_vide_barns_adresse
            FROM
                [befordring_app].[befordring].[view_ParentData]
            WHERE
                cpr_elev = :cpr
            ORDER BY
                foraelderrolle_sortering,
                adresseringsnavn
        """)

        result = self.db.execute(sql, {"cpr": cpr})

        return self._rows_to_dicts(result)


