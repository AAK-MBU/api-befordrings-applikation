"""Service layer for bevilling-related database operations.

This service contains the database logic for:

- Reading bevillinger
- Creating bevillinger
- Updating bevillinger
- Creating and updating kørselsrækker
- Updating many-to-many link tables

The API layer should stay thin and mostly handle request/response concerns.
This service contains the business/database rules.
"""

import pandas as pd

from fastapi import HTTPException

from app.utils import database


class BevillingService:
    """Service for bevilling and kørselsrække operations."""

    def __init__(self):
        """Initialize the database connection string."""

        self.conn_string = database.get_db_connection_string()

    # -----------------------------
    # Shared helpers
    # -----------------------------

    def _records_from_dataframe(self, df):
        """Convert a dataframe to JSON-safe records.

        Pandas uses NaN for missing values. FastAPI/JSON does not handle NaN
        well, so missing values are converted to None before returning records.

        Parameters
        ----------
        df : pandas.DataFrame
            Dataframe returned by database.read_sql.

        Returns
        -------
        list[dict]
            JSON-safe records.
        """

        df = df.astype(object).where(pd.notnull(df), None)

        return df.to_dict("records")

    def _validate_int_list(self, values: list[int], field_name: str):
        """Validate and deduplicate a list of integer IDs.

        Parameters
        ----------
        values : list[int]
            IDs to validate.

        field_name : str
            Name used in error messages.

        Returns
        -------
        list[int]
            Deduplicated list of IDs.

        Raises
        ------
        HTTPException
            Raised if one or more values are not integers.
        """

        unique_values = list(dict.fromkeys(values))

        if any(not isinstance(value, int) for value in unique_values):
            raise HTTPException(
                status_code=400,
                detail=f"All {field_name} must be integers"
            )

        return unique_values

    def _insert_and_return_id(
        self,
        table_name: str,
        data: dict,
        id_column: str
    ):
        """Insert a row and return the inserted ID.

        This helper is only intended for hardcoded table/column names from
        service methods. Do not pass user input as table or column names.

        Parameters
        ----------
        table_name : str
            Fully qualified table name.

        data : dict
            Column/value pairs to insert.

        id_column : str
            Identity column returned through OUTPUT INSERTED.

        Returns
        -------
        int
            Newly inserted identity value.
        """

        columns = ", ".join(data.keys())
        values = ", ".join(
            f":{key}"
            for key in data.keys()
        )

        sql = f"""
            INSERT INTO {table_name}
                ({columns})
            OUTPUT INSERTED.{id_column}
            VALUES
                ({values})
        """

        created = database.read_sql(
            query=sql,
            params=data,
            conn_string=self.conn_string
        )

        return int(created.iloc[0][id_column])

    def _replace_link_rows(
        self,
        table_name: str,
        parent_column: str,
        child_column: str,
        parent_id: int,
        child_ids: list[int],
        child_field_name: str
    ):
        """Replace all rows in a many-to-many link table.

        Existing rows for the parent ID are deleted. New rows are then inserted
        for each supplied child ID.

        This pattern is used for:

        - Bevilling -> Hjælpemiddel
        - Koersel -> KørselstypeTillæg
        - Koersel -> Ugedag

        Parameters
        ----------
        table_name : str
            Fully qualified link table name.

        parent_column : str
            Column name containing the parent ID.

        child_column : str
            Column name containing the linked child ID.

        parent_id : int
            ID of the parent record.

        child_ids : list[int]
            New complete list of child IDs.

        child_field_name : str
            Name used in validation errors.

        Returns
        -------
        dict
            Metadata about the replacement operation.
        """

        unique_child_ids = self._validate_int_list(
            values=child_ids,
            field_name=child_field_name
        )

        delete_sql = f"""
            DELETE FROM
                {table_name}
            WHERE
                {parent_column} = :parent_id
        """

        database.execute_sql(
            query=delete_sql,
            params={"parent_id": parent_id},
            conn_string=self.conn_string
        )

        inserted_rows = 0

        for child_id in unique_child_ids:
            insert_sql = f"""
                INSERT INTO {table_name}
                (
                    {parent_column},
                    {child_column}
                )
                VALUES
                (
                    :parent_id,
                    :child_id
                )
            """

            inserted_rows += database.execute_sql(
                query=insert_sql,
                params={
                    "parent_id": parent_id,
                    "child_id": child_id
                },
                conn_string=self.conn_string
            )

        return {
            "parent_id": parent_id,
            child_field_name: unique_child_ids,
            "rows_inserted": inserted_rows
        }

    def get_default_status_id(self):
        """Return the status_id for active status.

        Used when creating a kørselsrække without an explicit status_id.

        Returns
        -------
        int
            The status_id where status_tekst is "Aktiv".

        Raises
        ------
        ValueError
            Raised if no active "Aktiv" status exists.
        """

        sql = """
            SELECT TOP 1
                status_id
            FROM
                [befordring_app].[befordring].[Status]
            WHERE
                LOWER(status_tekst) = 'aktiv'
                AND aktiv = 1
        """

        df = database.read_sql(
            query=sql,
            params={},
            conn_string=self.conn_string
        )

        if df.empty:
            raise ValueError("Could not find default status 'Aktiv'")

        return int(df.iloc[0]["status_id"])

    # -----------------------------
    # Reads
    # -----------------------------

    def get_bevillinger(
        self,
        view_name: str,
        status: str | None = None,
        exclude_status: str | None = None,
        cpr: str | None = None,
        order_by: dict | None = None
    ):
        """Retrieve bevillinger from an allowed view.

        Parameters
        ----------
        view_name : str
            Fully qualified view name. Must be one of the allowed views.

        status : str | None
            Optional exact status filter.

        exclude_status : str | None
            Optional status value to exclude.

        cpr : str | None
            Optional CPR filter.

        order_by : dict | None
            Optional ordering config, for example:

            {
                "key": "created_at",
                "order_direction": "DESC"
            }

        Returns
        -------
        list[dict]
            Bevilling records.
        """

        allowed_views = {
            "[befordring_app].[befordring].[view_All_Bevillinger]",
            "[befordring_app].[befordring].[view_All_Active_Bevillinger]",
            "[befordring_app].[befordring].[view_Student_Bevillinger]",
        }

        if view_name not in allowed_views:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid bevilling view: {view_name}"
            )

        sql = f"""
            SELECT
                *
            FROM
                {view_name}
            WHERE
                1 = 1
        """

        params = {}

        if status:
            sql += " AND status_tekst = :status"
            params["status"] = status

        if exclude_status:
            sql += " AND status_tekst <> :exclude_status"
            params["exclude_status"] = exclude_status

        if cpr:
            sql += " AND cpr_elev = :cpr"
            params["cpr"] = cpr

        if order_by:
            allowed_columns = {
                "status_tekst",
                "cpr_elev",
                "created_at",
                "updated_at"
            }

            allowed_directions = {
                "ASC",
                "DESC"
            }

            key = order_by.get("key")
            direction = order_by.get("order_direction", "ASC").upper()

            if key not in allowed_columns:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid order_by column"
                )

            if direction not in allowed_directions:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid order direction"
                )

            sql += f" ORDER BY {key} {direction}"

        df = database.read_sql(
            query=sql,
            params=params,
            conn_string=self.conn_string
        )

        return self._records_from_dataframe(df)

    def get_bevilling(self, bevilling_id: int):
        """Retrieve a single bevilling by ID.

        Parameters
        ----------
        bevilling_id : int
            Unique ID of the bevilling.

        Returns
        -------
        dict | None
            Matching bevilling record, or None if not found.
        """

        sql = """
            SELECT
                *
            FROM
                [befordring_app].[befordring].[view_All_Bevillinger]
            WHERE
                bevilling_id = :bevilling_id
        """

        df = database.read_sql(
            query=sql,
            params={"bevilling_id": bevilling_id},
            conn_string=self.conn_string
        )

        records = self._records_from_dataframe(df)

        if not records:
            return None

        return records[0]

    def get_student_bevillinger(self, cpr: str):
        """Retrieve all bevillinger for a citizen.

        Parameters
        ----------
        cpr : str
            CPR number identifying the citizen.

        Returns
        -------
        list[dict]
            Bevillinger connected to the citizen.
        """

        sql = """
            SELECT
                *
            FROM
                [befordring_app].[befordring].[view_Student_Bevillinger]
            WHERE
                cpr = :cpr
            ORDER BY
                status_tekst ASC,
                sagsbehandlingsdato DESC
        """

        df = database.read_sql(
            query=sql,
            params={"cpr": cpr},
            conn_string=self.conn_string
        )

        return self._records_from_dataframe(df)

    def get_bevilling_koerselsraekker(self, bevilling_id: int):
        """Retrieve kørselsrækker for a bevilling.

        Parameters
        ----------
        bevilling_id : int
            Unique ID of the bevilling.

        Returns
        -------
        list[dict]
            Kørselsrækker connected to the bevilling.
        """

        sql = """
            SELECT
                *
            FROM
                [befordring_app].[befordring].[view_Bevilling_Koerselsraekker]
            WHERE
                bevilling_id = :bevilling_id
            ORDER BY
                tidspunkt_tekst DESC
        """

        df = database.read_sql(
            query=sql,
            params={"bevilling_id": bevilling_id},
            conn_string=self.conn_string
        )

        return self._records_from_dataframe(df)

    # -----------------------------
    # Creates
    # -----------------------------

    def create_bevilling(self, cpr: str, new_bevilling_data: dict):
        """Create a new bevilling.

        Parameters
        ----------
        cpr : str
            CPR number identifying the citizen.

        new_bevilling_data : dict
            Data used to create the bevilling. The optional
            hjaelpemiddel_ids list is removed from the main insert and handled
            through the link table after creation.

        Returns
        -------
        dict
            Metadata about the inserted bevilling.
        """

        hjaelpemiddel_ids = new_bevilling_data.pop("hjaelpemiddel_ids", [])

        allowed_fields = {
            "adresse_for_bevilling",
            "status_id",
            "matrikel_id",
            "hjemmel_id",
            "afgoerelsesbrev_id",
            "revurderingsdato",
            "befordringsudvalg",
            "esdh_noegle",
            "sagsbehandler_id",
            "ppr_sagsbehandler_id",
            "ansoegningsdato",
            "sagsbehandlingsdato",
            "relation_til_barnet",
            "foerste_koersel_dato",
            "ansoegningstype",
            "afstandskriterie_dato",
            "afstandskriterie_klassetrin",
            "begrundelse_fra_formular",
            "noter",
        }

        filtered_data = {
            key: value
            for key, value in new_bevilling_data.items()
            if key in allowed_fields
        }

        filtered_data["cpr_elev"] = cpr
        filtered_data["aktiv"] = 1
        filtered_data["created_by"] = "system"
        filtered_data["updated_by"] = "system"

        bevilling_id = self._insert_and_return_id(
            table_name="[befordring_app].[befordring].[Bevilling]",
            data=filtered_data,
            id_column="bevilling_id"
        )

        if hjaelpemiddel_ids:
            self.update_bevilling_hjaelpemidler(
                bevilling_id=bevilling_id,
                hjaelpemiddel_ids=hjaelpemiddel_ids
            )

        return {
            "bevilling_id": bevilling_id,
            "rows_inserted": 1
        }

    def create_koerselsraekke(
        self,
        bevilling_id: int,
        new_koerselsraekke_data: dict
    ):
        """Create a new kørselsrække for a bevilling.

        Parameters
        ----------
        bevilling_id : int
            ID of the bevilling the kørselsrække belongs to.

        new_koerselsraekke_data : dict
            Data used to create the Koersel row. Optional tillaeg_ids and
            dag_ids are handled through link tables after the row is created.

        Returns
        -------
        dict
            Metadata about the inserted kørselsrække.

        Raises
        ------
        ValueError
            Raised if required fields are missing.
        """

        tillaeg_ids = new_koerselsraekke_data.pop("tillaeg_ids", [])
        dag_ids = new_koerselsraekke_data.pop("dag_ids", [])

        required_fields = [
            "gyldig_fra",
            "gyldig_til",
            "tidspunkt_id",
            "befordringstype_id",
            "bevilget_koereafstand_pr_vej",
        ]

        missing_fields = [
            field
            for field in required_fields
            if field not in new_koerselsraekke_data
            or new_koerselsraekke_data[field] is None
        ]

        if missing_fields:
            raise ValueError(
                f"Missing required fields: {', '.join(missing_fields)}"
            )

        allowed_fields = {
            "gyldig_fra",
            "gyldig_til",
            "tidspunkt_id",
            "befordringstype_id",
            "bevilget_koereafstand_pr_vej",
            "taxa_id",
            "kommentar",
            "status_id",
            "final",
        }

        filtered_data = {
            key: value
            for key, value in new_koerselsraekke_data.items()
            if key in allowed_fields
        }

        filtered_data["bevilling_id"] = bevilling_id

        if "status_id" not in filtered_data:
            filtered_data["status_id"] = self.get_default_status_id()

        if "kommentar" not in filtered_data:
            filtered_data["kommentar"] = ""

        if "final" not in filtered_data:
            filtered_data["final"] = 0

        koersel_id = self._insert_and_return_id(
            table_name="[befordring_app].[befordring].[Koersel]",
            data=filtered_data,
            id_column="koersel_id"
        )

        if tillaeg_ids:
            self.update_koerselsraekke_tillaeg(
                koersel_id=koersel_id,
                tillaeg_ids=tillaeg_ids
            )

        if dag_ids:
            self.update_koerselsraekke_dage(
                koersel_id=koersel_id,
                dag_ids=dag_ids
            )

        return {
            "koersel_id": koersel_id,
            "rows_inserted": 1
        }

    # -----------------------------
    # Updates
    # -----------------------------

    def update_bevilling(self, bevilling_id: int, bevilling_data: dict):
        """Update editable fields on a bevilling.

        Parameters
        ----------
        bevilling_id : int
            Unique ID of the bevilling.

        bevilling_data : dict
            Fields and values to update.

        Returns
        -------
        dict
            Update metadata.

        Raises
        ------
        HTTPException
            Raised if no fields are provided or if a field is not allowed.
        """

        if not bevilling_data:
            raise HTTPException(
                status_code=400,
                detail="No fields provided for update"
            )

        allowed_fields = {
            "status_id": "status_id",
            "matrikel_id": "matrikel_id",
            "sagsbehandlingsdato": "sagsbehandlingsdato",
            "adresse_for_bevilling": "adresse_for_bevilling",
            "afstandskriterie_dato": "afstandskriterie_dato",
            "afstandskriterie_klassetrin": "afstandskriterie_klassetrin",
            "relation_til_barnet": "relation_til_barnet",
            "revurderingsdato": "revurderingsdato",
            "befordringsudvalg": "befordringsudvalg",
            "hjemmel_id": "hjemmel_id",
            "afgoerelsesbrev_id": "afgoerelsesbrev_id",
            "sagsbehandler_id": "sagsbehandler_id",
            "ppr_sagsbehandler_id": "ppr_sagsbehandler_id",
        }

        updates = {}

        for frontend_key, value in bevilling_data.items():
            if frontend_key not in allowed_fields:
                raise HTTPException(
                    status_code=400,
                    detail=f"Field cannot be updated on bevilling: {frontend_key}"
                )

            database_column = allowed_fields[frontend_key]
            updates[database_column] = value

        set_clause = ", ".join(
            f"{column} = :{column}"
            for column in updates
        )

        sql = f"""
            UPDATE
                [befordring_app].[befordring].[Bevilling]
            SET
                {set_clause},
                updated_at = SYSDATETIME(),
                updated_by = :updated_by
            WHERE
                bevilling_id = :bevilling_id
        """

        params = {
            **updates,
            "bevilling_id": bevilling_id,
            "updated_by": "frontend"
        }

        rows_updated = database.execute_sql(
            query=sql,
            params=params,
            conn_string=self.conn_string
        )

        return {
            "rows_updated": rows_updated,
            "updated_fields": list(bevilling_data.keys())
        }

    def update_koerselsraekke(
        self,
        koersel_id: int,
        koerselsraekke_data: dict
    ):
        """Update editable fields on a kørselsrække.

        Parameters
        ----------
        koersel_id : int
            Unique ID of the Koersel row.

        koerselsraekke_data : dict
            Fields and values to update.

        Returns
        -------
        dict
            Update metadata.
        """

        allowed_fields = {
            "tidspunkt_id",
            "befordringstype_id",
            "bevilget_koereafstand_pr_vej",
            "gyldig_fra",
            "gyldig_til",
            "taxa_id",
            "kommentar",
        }

        invalid_fields = [
            key
            for key in koerselsraekke_data
            if key not in allowed_fields
        ]

        if invalid_fields:
            raise HTTPException(
                status_code=400,
                detail=f"Fields cannot be updated on koerselsraekke: {invalid_fields}"
            )

        if not koerselsraekke_data:
            return {
                "koersel_id": koersel_id,
                "rows_updated": 0,
                "updated_fields": []
            }

        set_clause = ", ".join(
            f"{column} = :{column}"
            for column in koerselsraekke_data
        )

        sql = f"""
            UPDATE
                [befordring_app].[befordring].[Koersel]
            SET
                {set_clause}
            WHERE
                koersel_id = :koersel_id
        """

        params = {
            **koerselsraekke_data,
            "koersel_id": koersel_id
        }

        rows_updated = database.execute_sql(
            query=sql,
            params=params,
            conn_string=self.conn_string
        )

        return {
            "koersel_id": koersel_id,
            "rows_updated": rows_updated,
            "updated_fields": list(koerselsraekke_data.keys())
        }

    # -----------------------------
    # Link table updates
    # -----------------------------

    def update_bevilling_hjaelpemidler(
        self,
        bevilling_id: int,
        hjaelpemiddel_ids: list[int]
    ):
        """Replace all hjælpemiddel links for a bevilling.

        Parameters
        ----------
        bevilling_id : int
            Unique ID of the bevilling.

        hjaelpemiddel_ids : list[int]
            Complete list of selected hjælpemiddel IDs.

        Returns
        -------
        dict
            Link-table update metadata.
        """

        result = self._replace_link_rows(
            table_name="[befordring_app].[befordring].[Bevilling_Hjaelpemiddel_LINK]",
            parent_column="bevilling_id",
            child_column="hjaelpemiddel_id",
            parent_id=bevilling_id,
            child_ids=hjaelpemiddel_ids,
            child_field_name="hjaelpemiddel_ids"
        )

        return {
            "bevilling_id": bevilling_id,
            "hjaelpemiddel_ids": result["hjaelpemiddel_ids"],
            "rows_inserted": result["rows_inserted"]
        }

    def update_koerselsraekke_tillaeg(
        self,
        koersel_id: int,
        tillaeg_ids: list[int]
    ):
        """Replace all tillæg links for a kørselsrække.

        Parameters
        ----------
        koersel_id : int
            Unique ID of the Koersel row.

        tillaeg_ids : list[int]
            Complete list of selected tillæg IDs.

        Returns
        -------
        dict
            Link-table update metadata.
        """

        result = self._replace_link_rows(
            table_name="[befordring_app].[befordring].[Koersel_KoerselstypeTillaeg_LINK]",
            parent_column="koersel_id",
            child_column="tillaeg_id",
            parent_id=koersel_id,
            child_ids=tillaeg_ids,
            child_field_name="tillaeg_ids"
        )

        return {
            "koersel_id": koersel_id,
            "tillaeg_ids": result["tillaeg_ids"],
            "rows_inserted": result["rows_inserted"]
        }

    def update_koerselsraekke_dage(
        self,
        koersel_id: int,
        dag_ids: list[int]
    ):
        """Replace all weekday links for a kørselsrække.

        Parameters
        ----------
        koersel_id : int
            Unique ID of the Koersel row.

        dag_ids : list[int]
            Complete list of selected weekday IDs.

        Returns
        -------
        dict
            Link-table update metadata.
        """

        result = self._replace_link_rows(
            table_name="[befordring_app].[befordring].[Koersel_Ugedag_LINK]",
            parent_column="koersel_id",
            child_column="dag_id",
            parent_id=koersel_id,
            child_ids=dag_ids,
            child_field_name="dag_ids"
        )

        return {
            "koersel_id": koersel_id,
            "dag_ids": result["dag_ids"],
            "rows_inserted": result["rows_inserted"]
        }

    # -----------------------------
    # Deletes
    # -----------------------------

    def delete_bevilling(self, bevilling_id: int):
        """Delete a bevilling by ID.

        Parameters
        ----------
        bevilling_id : int
            Unique ID of the bevilling to delete.

        Returns
        -------
        dict
            Delete metadata.
        """

        sql = """
            DELETE FROM
                [befordring_app].[befordring].[Bevilling]
            WHERE
                bevilling_id = :bevilling_id
        """

        rows_deleted = database.execute_sql(
            query=sql,
            params={"bevilling_id": bevilling_id},
            conn_string=self.conn_string
        )

        return {
            "rows_deleted": rows_deleted
        }
