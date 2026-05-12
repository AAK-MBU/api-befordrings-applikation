"""Service layer for bevilling-related business logic.

This module contains the main business logic for bevillinger, koerselsraekker,
hjaelpemidler, status calculation, and letter data retrieval.

The service layer sits between the API routers and the database models/views.

General responsibilities:

- Read bevilling data from SQL views
- Create and update bevillinger
- Create and update koerselsraekker
- Update many-to-many link tables
- Calculate and update bevilling status
- Validate business rules
- Prepare letter data for the letter-generation flow

The router should stay thin and delegate most logic to this service.
"""

from datetime import date

from fastapi import HTTPException
from sqlalchemy import delete, select, text
from sqlalchemy.orm import Session

from app.models.bevilling import (
    Bevilling,
    BevillingHjaelpemiddelLink,
    Koersel,
    KoerselKoerselstypeTillaegLink,
    KoerselUgedagLink,
)
from app.models.lookup import Status


class BevillingService:
    """Service class for bevilling-related operations.

    Args:
        db:
            SQLAlchemy database session.

    Notes:
        This service owns the transaction logic for write operations.
        Most create/update methods commit directly unless they receive
        commit=False from another service method.
    """

    def __init__(self, db: Session):
        """Initialize the service with a database session."""

        self.db = db


    def _get_status_result_for_bevilling(
        self,
        rows: list[dict],
        bevilling_id: int,
    ):
        """Find the status procedure result for one specific bevilling."""

        for row in rows:
            if int(row["bevilling_id"]) == bevilling_id:
                return row

        raise HTTPException(
            status_code=404,
            detail=f"Bevilling not found in status result: {bevilling_id}",
        )


    def _execute_recalculate_status_procedure(
        self,
        bevilling_id: int | None = None,
        today: date | None = None,
        dry_run: bool = False,
    ):
        """Run the SQL Server status recalculation procedure.

        Args:
            bevilling_id:
                Optional bevilling ID.

                If provided, only that bevilling is recalculated.
                If None, all bevillinger are recalculated.

            today:
                Optional test date.

                Normally this should be None, so SQL Server uses today's date.

            dry_run:
                If True, the procedure only shows what would happen.
                If False, the procedure updates Bevilling.status_id.

        Returns:
            A list of dictionaries returned by the stored procedure.
        """

        sql = text("""
            EXEC [befordring].[usp_recalculate_bevilling_status]
                @bevilling_id = :bevilling_id,
                @today = :today,
                @dry_run = :dry_run
        """)

        result = self.db.execute(
            sql,
            {
                "bevilling_id": bevilling_id,
                "today": today,
                "dry_run": int(dry_run),
            },
        )

        return self._rows_to_dicts(result)


    def _rows_to_dicts(self, result):
        """
        Convert SQLAlchemy result rows into normal dictionaries.
        """

        return [dict(row) for row in result.mappings().all()]


    def _to_date(self, value):
        """Normalize datetime-like values to date objects.

        Notes:
            SQL Server / SQLAlchemy may return either date or datetime objects
            depending on the column type and query. This helper makes date
            comparison logic more predictable.
        """

        if value is None:
            return None

        if hasattr(value, "date"):
            return value.date()

        return value


    def _validate_int_list(self, values: list[int], field_name: str):
        """
        Validate and de-duplicate a list of integer IDs.

        Notes:
            dict.fromkeys(...) is used as a simple way to remove duplicates
            while keeping the original order.
        """

        unique_values = list(dict.fromkeys(values))

        if any(not isinstance(value, int) for value in unique_values):
            raise HTTPException(
                status_code=400,
                detail=f"All {field_name} must be integers",
            )

        return unique_values


    def _validate_koerselsraekke_dates(self, data: dict):
        """Validate that gyldig_fra is not after gyldig_til.

        Notes:
            If one of the dates is missing, validation is skipped.
            This makes the helper usable for both create and partial update.
        """

        gyldig_fra = self._to_date(data.get("gyldig_fra"))
        gyldig_til = self._to_date(data.get("gyldig_til"))

        if gyldig_fra is None or gyldig_til is None:
            return

        if gyldig_fra > gyldig_til:
            raise HTTPException(
                status_code=400,
                detail={
                    "message": "Gyldig fra kan ikke være efter gyldig til",
                },
            )


    def get_status_id_by_text(self, status_text: str):
        """Get an active status ID from its text value."""

        statement = (
            select(Status.status_id)
            .where(Status.status_tekst == status_text)
            .where(Status.aktiv == True)
        )

        status_id = self.db.execute(statement).scalar_one_or_none()

        if status_id is None:
            raise HTTPException(
                status_code=500,
                detail=f"Status does not exist: {status_text}",
            )

        return int(status_id)

    def get_bevillinger(
        self,
        view_name: str,
        status: str | None = None,
        exclude_status: str | None = None,
        cpr: str | None = None,
        order_by: dict | None = None,
    ):
        """Get bevillinger from an allowed SQL view.

        Args:
            view_name:
                Name of the SQL view to query.

            status:
                Optional status text filter.

            exclude_status:
                Optional status text to exclude.

            cpr:
                Optional CPR filter.

            order_by:
                Optional sorting config.

                Example:
                    {
                        "key": "created_at",
                        "order_direction": "DESC",
                    }

        Returns:
            A list of bevilling dictionaries.

        Raises:
            HTTPException:
                400 if the requested view, order column, or order direction is
                not allowed.

        Notes:
            The view name and ORDER BY values cannot be parameterized like
            normal SQL values. Therefore they are validated against allow-lists
            before being inserted into the SQL string.
        """

        allowed_views = {
            "[befordring_app].[befordring].[view_All_Bevillinger]",
            "[befordring_app].[befordring].[view_All_Active_Bevillinger]",
            "[befordring_app].[befordring].[view_Student_Bevillinger]",
        }

        if view_name not in allowed_views:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid bevilling view: {view_name}",
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
                "updated_at",
            }

            allowed_directions = {
                "ASC",
                "DESC",
            }

            key = order_by.get("key")
            direction = order_by.get("order_direction", "ASC").upper()

            if key not in allowed_columns:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid order_by column",
                )

            if direction not in allowed_directions:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid order direction",
                )

            sql += f" ORDER BY {key} {direction}"

        result = self.db.execute(text(sql), params)

        return self._rows_to_dicts(result)


    def get_bevilling(self, bevilling_id: int):
        """Get one bevilling by ID.

        Args:
            bevilling_id:
                ID of the bevilling.

        Returns:
            A bevilling dictionary if found.
            Otherwise None.
        """

        sql = text("""
            SELECT
                *
            FROM
                [befordring_app].[befordring].[view_All_Bevillinger]
            WHERE
                bevilling_id = :bevilling_id
        """)

        result = self.db.execute(
            sql,
            {"bevilling_id": bevilling_id},
        )

        records = self._rows_to_dicts(result)

        if not records:
            return None

        return records[0]


    def get_student_bevillinger(self, cpr: str):
        """Get all bevillinger connected to a citizen.

        Args:
            cpr:
                Citizen CPR.

        Returns:
            A list of bevillinger from view_Student_Bevillinger.
        """

        sql = text("""
            SELECT
                *
            FROM
                [befordring_app].[befordring].[view_Student_Bevillinger]
            WHERE
                cpr = :cpr
            ORDER BY
                sagsbehandlingsdato DESC,
                status_tekst ASC
        """)

        result = self.db.execute(sql, {"cpr": cpr})

        return self._rows_to_dicts(result)


    def get_bevilling_koerselsraekker(self, bevilling_id: int):
        """Get all koerselsraekker for a bevilling.

        Args:
            bevilling_id:
                ID of the bevilling.

        Returns:
            A list of koerselsraekker from view_Bevilling_Koerselsraekker.
        """

        sql = text("""
            SELECT
                *
            FROM
                [befordring_app].[befordring].[view_Bevilling_Koerselsraekker]
            WHERE
                bevilling_id = :bevilling_id
            ORDER BY
                tidspunkt_tekst DESC
        """)

        result = self.db.execute(
            sql,
            {"bevilling_id": bevilling_id},
        )

        return self._rows_to_dicts(result)


    def create_bevilling(
        self,
        cpr: str,
        new_bevilling_data: dict,
        status_text: str = "Ny",
    ):
        """Create a new bevilling.

        Args:
            cpr:
                Citizen CPR.

            new_bevilling_data:
                Dictionary with fields for the Bevilling model.

                May optionally contain hjaelpemiddel_ids. These are removed
                from the dictionary before creating the Bevilling object,
                because they belong in a link table.

            status_text:
                Initial status text. Defaults to "Ny".

        Returns:
            Dictionary containing created bevilling ID, status text, and row
            count.

        Notes:
            This method manages its own transaction.

            self.db.flush() is used before committing so SQLAlchemy generates
            the new bevilling_id. That ID is needed when inserting rows in the
            hjaelpemiddel link table.
        """

        # hjaelpemiddel_ids are not columns on Bevilling itself.
        # They are handled separately through the link table.
        hjaelpemiddel_ids = new_bevilling_data.pop("hjaelpemiddel_ids", [])

        try:
            bevilling = Bevilling(
                **new_bevilling_data,
                cpr_elev=cpr,
                status_id=self.get_status_id_by_text(status_text),
                aktiv=True,
                created_by="system",
                updated_by="system",
            )

            self.db.add(bevilling)

            # Flush so bevilling.bevilling_id is available before commit.
            self.db.flush()

            if hjaelpemiddel_ids:
                self.update_bevilling_hjaelpemidler(
                    bevilling_id=bevilling.bevilling_id,
                    hjaelpemiddel_ids=hjaelpemiddel_ids,
                    commit=False,
                )

            status_result = self.recalculate_bevilling_status(
                bevilling_id=bevilling.bevilling_id,
                commit=False,
            )

            self.db.commit()
            self.db.refresh(bevilling)

            return {
                "bevilling_id": bevilling.bevilling_id,
                "status_text": status_result["status_text"],
                "status_reason": status_result.get("status_reason"),
                "rows_inserted": 1,
                "status": status_result,
            }

        except Exception:
            self.db.rollback()
            raise


    def create_koerselsraekke(
        self,
        bevilling_id: int,
        new_koerselsraekke_data: dict,
    ):
        """Create a new koerselsraekke for a bevilling.

        Args:
            bevilling_id:
                ID of the bevilling the row belongs to.

            new_koerselsraekke_data:
                Dictionary with fields for the Koersel model.

                May optionally contain:
                - tillaeg_ids
                - dag_ids

        Returns:
            Dictionary containing created koersel_id and row count.

        Notes:
            This method also recalculates the bevilling status after creating
            the koerselsraekke.

            The link tables for tillaeg and dage are updated inside the same
            transaction by passing commit=False.
        """

        # These values belong to link tables, not directly on the Koersel model.
        tillaeg_ids = new_koerselsraekke_data.pop("tillaeg_ids", [])
        dag_ids = new_koerselsraekke_data.pop("dag_ids", [])

        self._validate_koerselsraekke_dates(new_koerselsraekke_data)

        try:
            koerselsraekke_values = {
                **new_koerselsraekke_data,
                "bevilling_id": bevilling_id,
                "kommentar": new_koerselsraekke_data.get("kommentar") or "",
                "final": new_koerselsraekke_data.get("final") or False,
            }

            koersel = Koersel(**koerselsraekke_values)

            self.db.add(koersel)

            # Flush so koersel.koersel_id is available for link-table inserts.
            self.db.flush()

            if tillaeg_ids:
                self.update_koerselsraekke_tillaeg(
                    koersel_id=koersel.koersel_id,
                    tillaeg_ids=tillaeg_ids,
                    commit=False,
                )

            if dag_ids:
                self.update_koerselsraekke_dage(
                    koersel_id=koersel.koersel_id,
                    dag_ids=dag_ids,
                    commit=False,
                )

            status_result = self.recalculate_bevilling_status(
                bevilling_id=bevilling_id,
                commit=False,
            )

            self.db.commit()
            self.db.refresh(koersel)

            return {
                "koersel_id": koersel.koersel_id,
                "rows_inserted": 1,
                "status": status_result,
            }

        except Exception:
            self.db.rollback()
            raise


    def update_bevilling(self, bevilling_id: int, bevilling_data: dict):
        """Update an existing bevilling.

        Args:
            bevilling_id:
                ID of the bevilling to update.

            bevilling_data:
                Dictionary containing only the fields that should be updated.

        Returns:
            Dictionary containing row count and updated field names.

        Raises:
            HTTPException:
                400 if no fields were provided.
                404 if the bevilling does not exist.

        Notes:
            After updating the bevilling, the status is recalculated because
            fields such as dates, sagsbehandler, or related values may affect
            the current status.
        """

        if not bevilling_data:
            raise HTTPException(
                status_code=400,
                detail="No fields provided for update",
            )

        bevilling = self.db.get(Bevilling, bevilling_id)

        if bevilling is None:
            raise HTTPException(
                status_code=404,
                detail=f"Bevilling not found: {bevilling_id}",
            )

        try:
            for field_name, value in bevilling_data.items():
                setattr(bevilling, field_name, value)

            bevilling.updated_by = "frontend"

            self.db.flush()

            status_result = self.recalculate_bevilling_status(
                bevilling_id=bevilling_id,
                commit=False,
            )

            self.db.commit()

            return {
                "rows_updated": 1,
                "updated_fields": list(bevilling_data.keys()),
                "status": status_result,
            }

        except Exception:
            self.db.rollback()
            raise


    def update_koerselsraekke(
        self,
        koersel_id: int,
        koerselsraekke_data: dict,
    ):
        """Update an existing koerselsraekke.

        Args:
            koersel_id:
                ID of the koerselsraekke to update.

            koerselsraekke_data:
                Dictionary containing only the fields to update.

        Returns:
            Dictionary containing koersel_id, row count, and updated fields.

        Raises:
            HTTPException:
                404 if the koerselsraekke does not exist.

        Notes:
            If no fields are provided, no update is performed and rows_updated
            is returned as 0.
        """

        if not koerselsraekke_data:
            return {
                "koersel_id": koersel_id,
                "rows_updated": 0,
                "updated_fields": [],
            }

        koersel = self.db.get(Koersel, koersel_id)

        if koersel is None:
            raise HTTPException(
                status_code=404,
                detail=f"Kørselsrække not found: {koersel_id}",
            )

        # Validate the final date range by combining existing dates with any
        # new date values supplied in the update payload.
        dates_to_validate = {
            "gyldig_fra": koerselsraekke_data.get("gyldig_fra", koersel.gyldig_fra),
            "gyldig_til": koerselsraekke_data.get("gyldig_til", koersel.gyldig_til),
        }

        self._validate_koerselsraekke_dates(dates_to_validate)

        try:
            for field_name, value in koerselsraekke_data.items():
                setattr(koersel, field_name, value)

            self.db.flush()

            status_result = self.recalculate_bevilling_status(
                bevilling_id=koersel.bevilling_id,
                commit=False,
            )

            self.db.commit()

            return {
                "koersel_id": koersel_id,
                "rows_updated": 1,
                "updated_fields": list(koerselsraekke_data.keys()),
                "status": status_result,
            }

        except Exception:
            self.db.rollback()
            raise


    def update_bevilling_hjaelpemidler(
        self,
        bevilling_id: int,
        hjaelpemiddel_ids: list[int],
        commit: bool = True,
    ):
        """Replace hjaelpemiddel links for a bevilling.

        Args:
            bevilling_id:
                ID of the bevilling.

            hjaelpemiddel_ids:
                New list of hjaelpemiddel IDs.

            commit:
                Whether this method should commit immediately.

        Returns:
            Dictionary containing bevilling_id, inserted IDs, and row count.

        Notes:
            This method replaces all existing links:

            1. Delete existing links for the bevilling.
            2. Insert the new set of links.

            Passing an empty list is valid and means all hjaelpemidler are
            removed from the bevilling.
        """

        unique_ids = self._validate_int_list(
            values=hjaelpemiddel_ids,
            field_name="hjaelpemiddel_ids",
        )

        self.db.execute(
            delete(BevillingHjaelpemiddelLink)
            .where(BevillingHjaelpemiddelLink.bevilling_id == bevilling_id)
        )

        for hjaelpemiddel_id in unique_ids:
            self.db.add(
                BevillingHjaelpemiddelLink(
                    bevilling_id=bevilling_id,
                    hjaelpemiddel_id=hjaelpemiddel_id,
                )
            )

        if commit:
            self.db.commit()

        return {
            "bevilling_id": bevilling_id,
            "hjaelpemiddel_ids": unique_ids,
            "rows_inserted": len(unique_ids),
        }


    def update_koerselsraekke_tillaeg(
        self,
        koersel_id: int,
        tillaeg_ids: list[int],
        commit: bool = True,
    ):
        """Replace tillaeg links for a koerselsraekke.

        Args:
            koersel_id:
                ID of the koerselsraekke.

            tillaeg_ids:
                New list of tillaeg IDs.

            commit:
                Whether this method should commit immediately.

        Returns:
            Dictionary containing koersel_id, inserted IDs, and row count.
        """

        unique_ids = self._validate_int_list(
            values=tillaeg_ids,
            field_name="tillaeg_ids",
        )

        self.db.execute(
            delete(KoerselKoerselstypeTillaegLink)
            .where(KoerselKoerselstypeTillaegLink.koersel_id == koersel_id)
        )

        for tillaeg_id in unique_ids:
            self.db.add(
                KoerselKoerselstypeTillaegLink(
                    koersel_id=koersel_id,
                    tillaeg_id=tillaeg_id,
                )
            )

        if commit:
            self.db.commit()

        return {
            "koersel_id": koersel_id,
            "tillaeg_ids": unique_ids,
            "rows_inserted": len(unique_ids),
        }


    def update_koerselsraekke_dage(
        self,
        koersel_id: int,
        dag_ids: list[int],
        commit: bool = True,
    ):
        """Replace weekday links for a koerselsraekke.

        Args:
            koersel_id:
                ID of the koerselsraekke.

            dag_ids:
                New list of weekday IDs.

            commit:
                Whether this method should commit immediately.

        Returns:
            Dictionary containing koersel_id, inserted IDs, and row count.
        """

        unique_ids = self._validate_int_list(
            values=dag_ids,
            field_name="dag_ids",
        )

        self.db.execute(
            delete(KoerselUgedagLink)
            .where(KoerselUgedagLink.koersel_id == koersel_id)
        )

        for dag_id in unique_ids:
            self.db.add(
                KoerselUgedagLink(
                    koersel_id=koersel_id,
                    dag_id=dag_id,
                )
            )

        if commit:
            self.db.commit()

        return {
            "koersel_id": koersel_id,
            "dag_ids": unique_ids,
            "rows_inserted": len(unique_ids),
        }


    def delete_bevilling(self, bevilling_id: int):
        """Delete a bevilling.

        Args:
            bevilling_id:
                ID of the bevilling to delete.

        Returns:
            Dictionary containing deleted row count.

        Raises:
            HTTPException:
                404 if the bevilling does not exist.

        Notes:
            This currently performs a hard delete using self.db.delete(...).
            If the system should keep history, this should probably be changed
            to a soft delete by setting aktiv=False instead.
        """

        bevilling = self.db.get(Bevilling, bevilling_id)

        if bevilling is None:
            raise HTTPException(
                status_code=404,
                detail=f"Bevilling not found: {bevilling_id}",
            )

        self.db.delete(bevilling)
        self.db.commit()

        return {
            "rows_deleted": 1,
        }


    def calculate_bevilling_status_id(self, bevilling_id: int):
        """Calculate the correct status ID for a bevilling using the SQL procedure."""

        if self.db.get(Bevilling, bevilling_id) is None:
            raise HTTPException(
                status_code=404,
                detail=f"Bevilling not found: {bevilling_id}",
            )

        rows = self._execute_recalculate_status_procedure(
            bevilling_id=bevilling_id,
            dry_run=True,
        )

        result = self._get_status_result_for_bevilling(
            rows=rows,
            bevilling_id=bevilling_id,
        )

        return int(result["calculated_status_id"])


    def recalculate_bevilling_status(self, bevilling_id: int, commit: bool = True,):
        """Recalculate and save the status for a bevilling.

        Notes:
            The actual status logic lives in the SQL stored procedure.

            This method is mainly responsible for:
                - calling the procedure for one bevilling
                - preserving Python-side error handling
                - optionally committing the transaction
        """

        if self.db.get(Bevilling, bevilling_id) is None:
            raise HTTPException(
                status_code=404,
                detail=f"Bevilling not found: {bevilling_id}",
            )

        try:
            rows = self._execute_recalculate_status_procedure(
                bevilling_id=bevilling_id,
                dry_run=False,
            )

            result = self._get_status_result_for_bevilling(
                rows=rows,
                bevilling_id=bevilling_id,
            )

            new_status_id = int(result["calculated_status_id"])

            if commit:
                self.db.commit()

            return {
                "bevilling_id": bevilling_id,
                "status_id": new_status_id,
                "status_text": result["calculated_status_text"],
                "status_reason": result.get("status_reason"),
                "rows_updated": int(result["status_will_change"]),

                # Optional, but useful:
                # shows other bevillinger for same CPR that were recalculated too.
                "status_results": rows,
            }

        except Exception:
            if commit:
                self.db.rollback()

            raise


    def get_letter_data(self, bevilling_id: int):
        """Get all data needed for letter generation.

        Args:
            bevilling_id:
                ID of the bevilling.

        Returns:
            A dictionary with main letter data and a nested list of
            koerselsraekker.

        Raises:
            HTTPException:
                404 if no letter data exists for the bevilling.

        Notes:
            The result is prepared for the letter-generation worker.

            The main data comes from view_Letter_BevillingData.
            The nested koerselsraekker come from view_Letter_Koerselsraekker.
        """

        main_sql = text("""
            SELECT
                *
            FROM
                [befordring_app].[befordring].[view_Letter_BevillingData]
            WHERE
                bevilling_id = :bevilling_id
        """)

        main_result = self.db.execute(
            main_sql,
            {"bevilling_id": bevilling_id},
        )

        main_records = self._rows_to_dicts(main_result)

        if not main_records:
            raise HTTPException(
                status_code=404,
                detail=f"Bevilling not found: {bevilling_id}",
            )

        letter_data = main_records[0]

        koersel_sql = text("""
            SELECT
                *
            FROM
                [befordring_app].[befordring].[view_Letter_Koerselsraekker]
            WHERE
                bevilling_id = :bevilling_id
            ORDER BY
                koersel_id
        """)

        koersel_result = self.db.execute(
            koersel_sql,
            {"bevilling_id": bevilling_id},
        )

        koersel_records = self._rows_to_dicts(koersel_result)

        # Nest the related koerselsraekker inside the main letter data object.
        # This makes the payload easier for the letter worker/template engine
        # to consume.
        letter_data["koerselsraekker"] = [
            {
                "koersel_id": row.get("koersel_id"),
                "koerselstype_key": row.get("koerselstype_key"),
                "koerselstype": row.get("koerselstype"),
                "dage": row.get("dage"),
                "taxa_id": row.get("taxa_id"),
                "tidspunkt": row.get("tidspunkt"),
                "bevilling_fra": row.get("bevilling_fra"),
                "bevilling_til": row.get("bevilling_til"),
                "koerselstype_tillaeg": row.get("koerselstype_tillaeg"),
                "bevilget_koereafstand_pr_vej": row.get("bevilget_koereafstand_pr_vej"),
            }
            for row in koersel_records
        ]

        return letter_data
