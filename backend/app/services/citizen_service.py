"""Service layer for citizen-related database operations.

The CitizenService handles retrieval and updates of citizen data used by the
frontend citizen case page.

The service currently works with:

- view_Stamdata
- view_ParentData
- Elev

The frontend mostly reads from views, while editable stamdata fields are written
back to the underlying Elev table.
"""

from fastapi.exceptions import HTTPException

from app.utils import database


class CitizenService:
    """Service for retrieving and updating citizen data."""

    def __init__(self):
        """Initialize database connection strings.

        Attributes
        ----------
        conn_string : str
            Connection string for the main befordring database.

        lis_conn_string : str
            Connection string for LIS/masterdata. It is currently not used in
            this service, but is kept available in case future citizen data
            needs to be fetched from LIS.
        """

        self.conn_string = database.get_db_connection_string()
        self.lis_conn_string = database.get_lis_db_connection_string()

    def get_stamdata(self, cpr: str):
        """Retrieve stamdata for a citizen.

        Stamdata is read from the `view_Stamdata` database view. The view
        combines citizen, school, status and case-related information into one
        frontend-friendly record.

        Parameters
        ----------
        cpr : str
            CPR number identifying the citizen.

        Returns
        -------
        dict | None
            The stamdata record if one exists. If no matching CPR is found,
            None is returned.

        Notes
        -----
        The API endpoint expects one citizen record, so this method returns the
        first matching record rather than a list.
        """

        sql = """
            SELECT
                *
            FROM
                [befordring_app].[befordring].[view_Stamdata]
            WHERE
                cpr = :cpr
        """

        df = database.read_sql(
            query=sql,
            params={"cpr": cpr},
            conn_string=self.conn_string
        )

        records = df.to_dict("records")

        if not records:
            return None

        return records[0]

    def get_parent_data(self, cpr: str):
        """Retrieve parent/guardian data for a child.

        Parent data is read from `view_ParentData`. The result is ordered so
        the most relevant parent/guardian roles are shown first, followed by
        name.

        Parameters
        ----------
        cpr : str
            CPR number identifying the child.

        Returns
        -------
        list[dict]
            Parent/guardian records connected to the child.

            Each record contains:

            - adresseringsnavn
            - cpr_foraelder
            - adresse_tekst
            - foraeldremyndighed
            - navne_adresse_beskyttelse
        """

        sql = """
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
        """

        df = database.read_sql(
            query=sql,
            params={"cpr": cpr},
            conn_string=self.conn_string
        )

        return df.to_dict("records")

    def update_citizen_stamdata(self, cpr: str, stamdata: dict):
        """Update editable stamdata fields for a citizen.

        The frontend sends field names based on `view_Stamdata`, but the actual
        update is performed on the underlying `Elev` table.

        To avoid accidental or unsafe updates, this method uses an explicit
        allowlist. Only fields listed in `allowed_elev_fields` can be updated.

        Parameters
        ----------
        cpr : str
            CPR number identifying the citizen/elev record to update.

        stamdata : dict
            Dictionary of fields and values to update.

            Example:

            {
                "skoleafstand": 5.7,
                "klasseart": "Specialklasse",
                "elevklassetrin": 4
            }

        Returns
        -------
        dict
            Result metadata from the update operation.

            Example:

            {
                "rows_updated": 1,
                "updated_fields": [
                    "skoleafstand",
                    "klasseart",
                    "elevklassetrin"
                ]
            }

        Raises
        ------
        HTTPException
            Raised with status code 400 if the frontend attempts to update a
            field that is not explicitly allowed.
        """

        allowed_elev_fields = {
            "skoleafstand": "skoleafstand",
            "klasseart": "klasseart",
            "elevklassetrin": "elevklassetrin",
            "klassebetegnelse": "klassebetegnelse",
            "sfo": "sfo",
            "bopaelsdistrikt": "bopaelsdistrikt",
        }

        elev_updates = {}

        for frontend_key, value in stamdata.items():
            if frontend_key not in allowed_elev_fields:
                raise HTTPException(
                    status_code=400,
                    detail=f"Field cannot be updated through stamdata: {frontend_key}"
                )

            database_column = allowed_elev_fields[frontend_key]
            elev_updates[database_column] = value

        if not elev_updates:
            return {
                "rows_updated": 0,
                "updated_fields": []
            }

        set_clause = ", ".join(
            f"{column} = :{column}"
            for column in elev_updates
        )

        sql = f"""
            UPDATE
                [befordring_app].[befordring].[Elev]
            SET
                {set_clause}
            WHERE
                cpr = :cpr
        """

        params = {
            **elev_updates,
            "cpr": cpr
        }

        rows_updated = database.execute_sql(
            query=sql,
            params=params,
            conn_string=self.conn_string
        )

        return {
            "rows_updated": rows_updated,
            "updated_fields": list(stamdata.keys())
        }
