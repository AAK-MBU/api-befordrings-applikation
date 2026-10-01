"""Service layer for citizen-related business logic.

This module contains database operations related to citizens/students.

The service is responsible for:

- Fetching citizen stamdata
- Fetching parent/guardian data
- Re-deriving a single student's school and walking distance on demand

Stamdata itself is maintained by external systems and is read-only here. The
two derived columns are not: matrikel_id and skoleafstand are computed by this
application's own nightly run, and genberegn_skole() is that same computation
applied to one student.
"""

from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.models.citizen import Elev
from app.utils.distance import walking_distance


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
                [befordring].[view_Stamdata]
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
            adresseringsnavn=elev_data.get("adresseringsnavn"),
            navne_adresse_beskyttelse=elev_data.get("navne_adresse_beskyttelse", False),
            adresse_id=elev_data.get("adresse_id"),
            matrikel_id=elev_data.get("matrikel_id"),
            skolekode=elev_data.get("skolekode", 0),
            skoleafstand=elev_data.get("skoleafstand", 0.0),
            klasseart=elev_data.get("klasseart", ""),
            elevklassetrin=elev_data.get("elevklassetrin", ""),
            klassebetegnelse=elev_data.get("klassebetegnelse", ""),
            institution=elev_data.get("institution", ""),
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
                relation,
                navne_adresse_beskyttelse,
                maa_vide_barns_adresse
            FROM
                [befordring].[view_ParentData]
            WHERE
                cpr_elev = :cpr
            ORDER BY
                foraelderrolle_sortering,
                adresseringsnavn
        """)

        result = self.db.execute(sql, {"cpr": cpr})

        return self._rows_to_dicts(result)


    def genberegn_skole(self, cpr: str):
        """Re-derive one student's school and walking distance, now.

        Args:
            cpr:
                CPR number of the student.

        Returns:
            A dictionary with the resulting matrikel_id, ungdomsuddannelse_id,
            skoleafstand and a Danish ``besked`` describing what happened.

        Raises:
            HTTPException:
                404 if the student is not in Elev, 502 if the distance API
                could not be reached.

        Notes:
            The same two steps the nightly run performs, in the same order:

              1. usp_sync_elev_matrikel_from_bevilling derives the school from
                 the student's bevillinger. Narrowed to this one student by
                 @cpr; the rules are the procedure's, not repeated here.

              2. The walking distance from the student's address to that
                 school, written to skoleafstand.

            Step 1 is authoritative and may CLEAR the school where no bevilling
            qualifies — a stale school being worse than none. There is then
            nothing to measure, and the caller is told so rather than being
            left with a distance to a school the child has left.

            Only after a successful measurement is kraever_genberegning
            cleared, so a student whose distance could not be calculated is
            still picked up by the nightly run.
        """

        elev = self.db.get(Elev, cpr)

        if elev is None:
            raise HTTPException(
                status_code=404,
                detail=f"Ingen elev fundet med CPR {cpr}",
            )

        # Step 1 — derive the school. Committed before the HTTP call below, so
        # no transaction is held open across a network request. That is the
        # same mistake the nightly run made against this very table, where it
        # escalated to a table lock and took the application down with it.
        self.db.execute(
            text("EXEC [befordring].[usp_sync_elev_matrikel_from_bevilling] @cpr = :cpr"),
            {"cpr": cpr},
        ).close()
        self.db.commit()

        self.db.refresh(elev)

        koordinater = self._skole_koordinater(elev)

        if koordinater is None:
            return {
                "matrikel_id": elev.matrikel_id,
                "ungdomsuddannelse_id": elev.ungdomsuddannelse_id,
                "skoleafstand": elev.skoleafstand,
                "besked": (
                    "Ingen skole kunne udledes af elevens bevillinger, "
                    "så afstanden kan ikke beregnes."
                ),
            }

        adresse = self._adresse_koordinater(elev)

        if adresse is None:
            return {
                "matrikel_id": elev.matrikel_id,
                "ungdomsuddannelse_id": elev.ungdomsuddannelse_id,
                "skoleafstand": elev.skoleafstand,
                "besked": "Elevens adresse mangler koordinater, så afstanden kan ikke beregnes.",
            }

        skole_lat, skole_lon = koordinater
        adresse_lat, adresse_lon = adresse

        # Step 2 — measure. foot-walking, because skoleafstand feeds the
        # afstandskriterie, which is about how far the child would have to walk.
        try:
            distance_km, _ = walking_distance(adresse_lat, adresse_lon, skole_lat, skole_lon)
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"Distance API error: {e}")

        elev.skoleafstand = round(distance_km, 3)
        elev.kraever_genberegning = False

        self.db.commit()
        self.db.refresh(elev)

        return {
            "matrikel_id": elev.matrikel_id,
            "ungdomsuddannelse_id": elev.ungdomsuddannelse_id,
            "skoleafstand": elev.skoleafstand,
            "besked": None,
        }


    def _skole_koordinater(self, elev: Elev):
        """Coordinates of the student's derived school, or None.

        None covers both "no school was derived" and "the school has no
        coordinates" — the Skolematrikel rows added by hand carry NULL until
        someone fills them in, and sending those to the distance API produces
        a 502 that reads like an outage.
        """

        if elev.matrikel_id is not None:
            sql = text("""
                SELECT latitude, longitude
                FROM   [befordring].[Skolematrikel]
                WHERE  matrikel_id = :id
            """)
            params = {"id": elev.matrikel_id}
        elif elev.ungdomsuddannelse_id is not None:
            sql = text("""
                SELECT latitude, longitude
                FROM   [befordring].[Ungdomsuddannelse]
                WHERE  ungdomsuddannelse_id = :id
            """)
            params = {"id": elev.ungdomsuddannelse_id}
        else:
            return None

        row = self.db.execute(sql, params).mappings().first()

        if row is None or row["latitude"] is None or row["longitude"] is None:
            return None

        return float(row["latitude"]), float(row["longitude"])


    def _adresse_koordinater(self, elev: Elev):
        """Coordinates of the student's registered address, or None."""

        if elev.adresse_id is None:
            return None

        row = self.db.execute(
            text("""
                SELECT latitude, longitude
                FROM   [befordring].[Adresse]
                WHERE  adresse_id = :id
            """),
            {"id": elev.adresse_id},
        ).mappings().first()

        if row is None or row["latitude"] is None or row["longitude"] is None:
            return None

        return float(row["latitude"]), float(row["longitude"])
