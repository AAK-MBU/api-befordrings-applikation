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


    def create_elev(self, elev_data: dict) -> dict:
        """Create an Elev record for a citizen if one does not exist.

        Args:
            elev_data:
                Dictionary matching ElevCreateRequest fields.

        Returns:
            {"cpr": str, "created": bool} — created=False if the Elev already existed.

        Notes:
            adresse_id is the LOIS AdresseId (DAR GUID). The caller (RPA
            conversion bot) resolves it via LOIS at queue time — see
            queue_handler.py — and ensures the corresponding Adresse row
            exists via POST /adresse/create before calling this endpoint.
            No address record is created here.
        """
        existing = self.db.get(Elev, elev_data["cpr"])
        if existing:
            return {"cpr": existing.cpr, "created": False}

        elev = Elev(
            cpr=elev_data["cpr"],
            adresseringsnavn=elev_data["adresseringsnavn"],
            navne_adresse_beskyttelse=elev_data.get("navne_adresse_beskyttelse", False),
            adresse_id=elev_data.get("adresse_id"),
            matrikel_id=elev_data.get("matrikel_id"),
            skolekode=elev_data.get("skolekode", 0),
            skoleafstand=elev_data.get("skoleafstand", 0.0),
            klasseart=elev_data.get("klasseart", ""),
            elevklassetrin=elev_data.get("elevklassetrin", ""),
            klassebetegnelse=elev_data.get("klassebetegnelse", ""),
            sfo=elev_data.get("sfo", ""),
            bopaelsdistrikt=elev_data.get("bopaelsdistrikt", ""),
        )
        self.db.add(elev)
        self.db.commit()

        return {"cpr": elev.cpr, "created": True}


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
