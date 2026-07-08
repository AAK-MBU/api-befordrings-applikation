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


    def _read_overview_table(self, table_name: str, order_direction: str = "ASC"):
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
            "[befordring].[view_New_Applications]",
        }

        if table_name not in allowed_tables:
            raise ValueError(f"Invalid overview table: {table_name}")

        sql = text(f"""
            SELECT
                *
            FROM
                {table_name}
            ORDER BY
                ansoegningsdato {order_direction}
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
            view_name="[befordring].[view_All_Active_Bevillinger]",
        )

        return [
            self._map_bevilling_overview_record(record)
            for record in records
        ]


    def get_fejlede_bevillinger(self):
        """Get bevillinger with status Fejlet for the overview.

        Returns:
            A list of simplified bevilling records where status is Fejlet.
        """

        service = BevillingService(db=self.db)

        records = service.get_bevillinger(
            view_name="[befordring].[view_All_Bevillinger]",
            status="Fejlet",
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
            view_name="[befordring].[view_All_Bevillinger]",
            status="Revurdering",
        )

        return [
            self._map_bevilling_overview_record(record)
            for record in records
        ]


    def search_bevillinger(self, q: str):
        """Search bevillinger by CPR or name (partial match).

        Args:
            q:
                Search string. Must be at least 2 characters.

        Returns:
            Up to 20 unique citizen records matching the query, each with
            ``cpr_elev``, ``adresseringsnavn``, and ``bevilling_count``.
        """

        if not q or len(q.strip()) < 2:
            return []

        like_q = f"%{q.strip()}%"

        # Search view_Stamdata so citizens without any bevillinger are still found.
        # LEFT JOIN Bevilling to count each citizen's bevillinger (0 if none).
        sql = text("""
            SELECT TOP 20
                s.cpr         AS cpr_elev,
                s.adresseringsnavn,
                COUNT(b.bevilling_id) AS bevilling_count
            FROM
                [befordring].[view_Stamdata] s
            LEFT JOIN
                [befordring].[Bevilling] b
                ON b.cpr_elev = s.cpr
            WHERE
                s.cpr LIKE :q
                OR s.adresseringsnavn LIKE :q
            GROUP BY
                s.cpr,
                s.adresseringsnavn
            ORDER BY
                s.adresseringsnavn
        """)

        result = self.db.execute(sql, {"q": like_q})

        return self._rows_to_dicts(result)


    def get_revurderinger(self):
        """Get bevillinger with status Revurdering, with nested koerselsraekker.

        Returns:
            List of bevilling dicts, each with a 'koerselsraekker' key containing
            a list of that bevilling's koersel rows.
        """

        bev_sql = text("""
            SELECT
                *
            FROM
                [befordring].[view_Revurderinger]
            ORDER BY
                revurderingsdato ASC
        """)

        bevillinger = self._rows_to_dicts(self.db.execute(bev_sql))

        if not bevillinger:
            return []

        koersel_sql = text("""
            SELECT
                vbk.*,
                k.final
            FROM
                [befordring].[view_Bevilling_Koerselsraekker] vbk
            INNER JOIN
                [befordring].[Koersel] k
                ON k.koersel_id = vbk.koersel_id
            INNER JOIN
                [befordring].[Bevilling] b
                ON b.bevilling_id = vbk.bevilling_id
            INNER JOIN
                [befordring].[Status] s
                ON s.status_id = b.status_id
            WHERE
                s.status_tekst = N'Revurdering'
            ORDER BY
                vbk.bevilling_id,
                vbk.gyldig_til DESC
        """)

        koersler = self._rows_to_dicts(self.db.execute(koersel_sql))

        koersel_map: dict = {}
        for k in koersler:
            bid = k["bevilling_id"]
            koersel_map.setdefault(bid, []).append(k)

        for b in bevillinger:
            b["koerselsraekker"] = koersel_map.get(b.get("bevilling_id"), [])

        return bevillinger


    def get_new_applications(self):
        """Get new applications overview data.

        Returns:
            Rows from DATA_NYE_ANSOEGNINGER as dictionaries.

        Notes:
            This reads from a dedicated overview table instead of going through
            BevillingService.
        """

        return self._read_overview_table(
            table_name="[befordring].[view_New_Applications]",
            order_direction="ASC"
        )


    def get_reports(self):
        """Get report overview data.

        Returns:
            Rows from DATA_REPORTS as dictionaries.
        """

        return self._read_overview_table(
            table_name="[befordring].[DATA_REPORTS]",
        )
