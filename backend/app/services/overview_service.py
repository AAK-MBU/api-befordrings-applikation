"""Service layer for overview/dashboard data.

This module contains read operations used by the overview/dashboard part of
the application.

The service is responsible for:

- Fetching active bevillinger
- Fetching non-active bevillinger
- Fetching reassessments/revurderinger
- Fetching new applications
- Fetching report data

Some overview data comes from BevillingService, while other overview data is
read directly from dedicated overview tables.
"""

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.services.bevilling_service import BevillingService


class OverviewService:
    """Service class for overview-related database reads.

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
            This helper is useful when reading from raw SQL tables/views using
            self.db.execute(text(...)).
        """

        return [dict(row) for row in result.mappings().all()]


    def _map_bevilling_overview_record(self, bevilling: dict):
        """Map a full bevilling record into a smaller overview object.

        Args:
            bevilling:
                Dictionary containing bevilling data from a SQL view.

        Returns:
            A simplified dictionary for overview/table display.

        Notes:
            The database views may return many more fields than the frontend
            needs in the overview.

            This method limits the response to the fields currently used by
            the overview UI.
        """

        return {
            "navn": bevilling.get("adresseringsnavn"),
            "cpr": bevilling.get("cpr_elev"),
            "status": bevilling.get("status_tekst"),
            "esdh_noegle": bevilling.get("esdh_noegle"),
            "sagsbehandler": bevilling.get("sagsbehandler"),
            "ppr_sagsbehandler": bevilling.get("ppr_sagsbehandler_tekst"),
        }


    def _read_overview_table(self, table_name: str):
        """Read all rows from an allowed overview table.

        Args:
            table_name:
                Fully qualified SQL Server table name.

        Returns:
            A list of table rows as dictionaries.

        Raises:
            ValueError:
                If the requested table name is not allowed.

        Notes:
            Table names cannot be safely parameterized like normal SQL values.

            Because the table name is inserted directly into the SQL string,
            it must be validated against an allow-list first.
        """

        allowed_tables = {
            "[befordring_app].[befordring].[DATA_NYE_ANSOEGNINGER]",
            "[befordring_app].[befordring].[DATA_REPORTS]",
        }

        if table_name not in allowed_tables:
            raise ValueError(f"Invalid overview table: {table_name}")

        sql = text(f"""
            SELECT
                *
            FROM
                {table_name}
        """)

        result = self.db.execute(sql)

        return self._rows_to_dicts(result)


    def get_active_bevillinger(self):
        """Get active bevillinger for the overview.

        Returns:
            A list of simplified active bevilling records.

        Notes:
            The full bevilling data is fetched through BevillingService.
            Each record is then mapped into a smaller overview format.
        """

        service = BevillingService(db=self.db)

        records = service.get_bevillinger(
            view_name="[befordring_app].[befordring].[view_All_Active_Bevillinger]",
        )

        return [
            self._map_bevilling_overview_record(record)
            for record in records
        ]


    def get_non_active_bevillinger(self):
        """Get non-active bevillinger for the overview.

        Returns:
            A list of simplified bevilling records where status is not Aktiv.
        """

        service = BevillingService(db=self.db)

        records = service.get_bevillinger(
            view_name="[befordring_app].[befordring].[view_All_Bevillinger]",
            exclude_status="Aktiv",
        )

        return [
            self._map_bevilling_overview_record(record)
            for record in records
        ]


    def get_reassessments(self):
        """Get bevillinger with status Revurdering.

        Returns:
            A list of simplified reassessment/revurdering records.

        Notes:
            This is used for the part of the overview that highlights cases
            needing reassessment.
        """

        service = BevillingService(db=self.db)

        records = service.get_bevillinger(
            view_name="[befordring_app].[befordring].[view_All_Bevillinger]",
            status="Revurdering",
        )

        return [
            self._map_bevilling_overview_record(record)
            for record in records
        ]


    def get_new_applications(self):
        """Get new applications overview data.

        Returns:
            Rows from DATA_NYE_ANSOEGNINGER as dictionaries.

        Notes:
            This reads from a dedicated overview table instead of going through
            BevillingService.
        """

        return self._read_overview_table(
            table_name="[befordring_app].[befordring].[DATA_NYE_ANSOEGNINGER]",
        )


    def get_reports(self):
        """Get report overview data.

        Returns:
            Rows from DATA_REPORTS as dictionaries.
        """

        return self._read_overview_table(
            table_name="[befordring_app].[befordring].[DATA_REPORTS]",
        )
