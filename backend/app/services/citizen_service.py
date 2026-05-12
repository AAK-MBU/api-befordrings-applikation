"""Service layer for citizen-related business logic.

This module contains database operations related to citizens/students.

The service is responsible for:

- Fetching citizen stamdata
- Fetching parent/guardian data
- Updating editable citizen stamdata fields

The API router should stay thin and delegate this logic to CitizenService.
"""

from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.models.citizen import Elev


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
                navne_adresse_beskyttelse
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


    def update_citizen_stamdata(self, cpr: str, stamdata: dict):
        """Update editable stamdata fields for a citizen/student.

        Args:
            cpr:
                CPR number of the citizen/student.

            stamdata:
                Dictionary containing the fields that should be updated.

        Returns:
            A dictionary containing:
            - number of updated rows
            - list of updated field names

        Raises:
            HTTPException:
                404 if no citizen/student exists with the provided CPR.

        Notes:
            This updates the Elev table directly through the SQLAlchemy model.

            The router should pass a dictionary created with
            exclude_unset=True, so only fields explicitly sent by the frontend
            are updated.
        """

        # If no fields were provided, there is nothing to update.
        # This is treated as a harmless no-op.
        if not stamdata:
            return {
                "rows_updated": 0,
                "updated_fields": [],
            }

        # Fetch the Elev row by primary key.
        # This assumes CPR is the primary key on the Elev model.
        elev = self.db.get(Elev, cpr)

        if elev is None:
            raise HTTPException(
                status_code=404,
                detail=f"Citizen not found: {cpr}",
            )

        # Dynamically update only the fields provided in the request.
        #
        # Example:
        # stamdata = {"klasse": "3A", "sfo": True}
        #
        # This will update:
        # elev.klasse
        # elev.sfo
        for field_name, value in stamdata.items():
            setattr(elev, field_name, value)

        self.db.commit()

        return {
            "rows_updated": 1,
            "updated_fields": list(stamdata.keys()),
        }
