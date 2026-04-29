"""Service layer for lookup/dropdown data.

The LookupService contains read-only helper methods for fetching values
used by frontend dropdowns.

All public methods return the same simple shape:

[
    {
        "id": 1,
        "label": "Display text"
    }
]

Keeping this shape consistent makes the Svelte components simpler,
because all lookup lists can be rendered the same way.
"""

from app.utils import database


class LookupService:
    """Service for retrieving lookup values from the database.

    The service reads from small lookup/reference tables in the
    befordring schema. These tables are used to populate dropdowns in the
    frontend when creating or editing bevillinger and kørselsrækker.
    """

    def __init__(self):
        """Initialize database connection strings.

        Attributes
        ----------
        conn_string : str
            Connection string for the main befordring database.

        lis_conn_string : str
            Connection string for LIS/masterdata. It is currently not used
            in this service, but is kept here in case future lookup data
            needs to come from LIS.
        """

        self.conn_string = database.get_db_connection_string()
        self.lis_conn_string = database.get_lis_db_connection_string()

    def _get_lookup_records(
        self,
        table_name: str,
        id_column: str,
        label_column: str,
        only_active: bool = True,
        order_by: str | None = None
    ):
        """Fetch generic lookup records from a lookup table.

        This helper prevents repeated SQL boilerplate across all lookup
        methods. The method expects a table name and the columns that
        should be returned as `id` and `label`.

        Parameters
        ----------
        table_name : str
            Fully qualified SQL table name, for example:
            "[befordring_app].[befordring].[Status]".

        id_column : str
            Name of the ID column in the lookup table.

        label_column : str
            Name of the display text column in the lookup table.

        only_active : bool, optional
            If True, the query adds `WHERE aktiv = 1`.
            Defaults to True.

        order_by : str | None, optional
            Column used for ordering. If omitted, the label column is used.

        Returns
        -------
        list[dict]
            A list of lookup records formatted as:

            [
                {
                    "id": <id value>,
                    "label": <label value>
                }
            ]
        """

        order_column = order_by or label_column

        where_clause = ""

        if only_active:
            where_clause = "WHERE aktiv = 1"

        sql = f"""
            SELECT
                {id_column} AS id,
                {label_column} AS label
            FROM
                {table_name}
            {where_clause}
            ORDER BY
                {order_column}
        """

        df = database.read_sql(
            query=sql,
            params={},
            conn_string=self.conn_string
        )

        return df.to_dict("records")

    def get_hjemler(self):
        """Return active hjemmel options.

        Hjemler represent the legal basis/home authority connected to a
        bevilling.

        Returns
        -------
        list[dict]
            Active hjemler formatted as:

            [
                {
                    "id": hjemmel_id,
                    "label": hjemmel_tekst
                }
            ]
        """

        return self._get_lookup_records(
            table_name="[befordring_app].[befordring].[Hjemmel]",
            id_column="hjemmel_id",
            label_column="hjemmel_tekst"
        )

    def get_afgoerelsesbreve(self):
        """Return active afgørelsesbrev options.

        Afgørelsesbreve represent the decision-letter templates that can
        be attached to a bevilling.

        Returns
        -------
        list[dict]
            Active afgørelsesbreve formatted as:

            [
                {
                    "id": afgoerelsesbrev_id,
                    "label": afgoerelsesbrev_tekst
                }
            ]
        """

        return self._get_lookup_records(
            table_name="[befordring_app].[befordring].[Afgoerelsesbrev]",
            id_column="afgoerelsesbrev_id",
            label_column="afgoerelsesbrev_tekst"
        )

    def get_sagsbehandlere(self):
        """Return active sagsbehandler options.

        Used for selecting the primary caseworker on a bevilling.

        Returns
        -------
        list[dict]
            Active sagsbehandlere formatted as:

            [
                {
                    "id": sagsbehandler_id,
                    "label": sagsbehandler_tekst
                }
            ]
        """

        return self._get_lookup_records(
            table_name="[befordring_app].[befordring].[Sagsbehandler]",
            id_column="sagsbehandler_id",
            label_column="sagsbehandler_tekst"
        )

    def get_ppr_sagsbehandlere(self):
        """Return active PPR sagsbehandler options.

        Used for selecting the PPR responsible caseworker on a bevilling.

        Returns
        -------
        list[dict]
            Active PPR sagsbehandlere formatted as:

            [
                {
                    "id": ppr_sagsbehandler_id,
                    "label": ppr_sagsbehandler_tekst
                }
            ]
        """

        return self._get_lookup_records(
            table_name="[befordring_app].[befordring].[PPR_Sagsbehandler]",
            id_column="ppr_sagsbehandler_id",
            label_column="ppr_sagsbehandler_tekst"
        )

    def get_status(self):
        """Return active status options.

        Status values are used for bevillinger and may also be used
        internally for kørselsrækker.

        Returns
        -------
        list[dict]
            Active statuses formatted as:

            [
                {
                    "id": status_id,
                    "label": status_tekst
                }
            ]
        """

        return self._get_lookup_records(
            table_name="[befordring_app].[befordring].[Status]",
            id_column="status_id",
            label_column="status_tekst"
        )

    def get_skolematrikel(self):
        """Return skolematrikel options.

        Skolematrikler represent the school/matrikel connected to a
        bevilling.

        Unlike most lookup tables, this method does not filter on
        `aktiv = 1`, because the current Skolematrikel table is used as a
        full reference list.

        Returns
        -------
        list[dict]
            Skolematrikler formatted as:

            [
                {
                    "id": matrikel_id,
                    "label": matrikel_navn
                }
            ]
        """

        return self._get_lookup_records(
            table_name="[befordring_app].[befordring].[Skolematrikel]",
            id_column="matrikel_id",
            label_column="matrikel_navn",
            only_active=False
        )

    def get_hjaelpemidler(self):
        """Return active hjælpemiddel options.

        Hjælpemidler can be attached to bevillinger through the
        Bevilling_Hjaelpemiddel link table.

        Returns
        -------
        list[dict]
            Active hjælpemidler formatted as:

            [
                {
                    "id": hjaelpemiddel_id,
                    "label": hjaelpemiddel_tekst
                }
            ]
        """

        return self._get_lookup_records(
            table_name="[befordring_app].[befordring].[Hjaelpemiddel]",
            id_column="hjaelpemiddel_id",
            label_column="hjaelpemiddel_tekst"
        )

    def get_tidspunkter(self):
        """Return active tidspunkt options.

        Tidspunkter describe when a kørselsrække applies, for example
        morning, afternoon, or both.

        Returns
        -------
        list[dict]
            Active tidspunkter formatted as:

            [
                {
                    "id": tidspunkt_id,
                    "label": tidspunkt_tekst
                }
            ]
        """

        return self._get_lookup_records(
            table_name="[befordring_app].[befordring].[Tidspunkt]",
            id_column="tidspunkt_id",
            label_column="tidspunkt_tekst"
        )

    def get_koerselstyper(self):
        """Return active kørselstype options.

        Kørselstyper describe the transport type on a kørselsrække.

        Returns
        -------
        list[dict]
            Active kørselstyper formatted as:

            [
                {
                    "id": befordringstype_id,
                    "label": befordringstype_tekst
                }
            ]
        """

        return self._get_lookup_records(
            table_name="[befordring_app].[befordring].[Befordringstype]",
            id_column="befordringstype_id",
            label_column="befordringstype_tekst"
        )

    def get_koerselstype_tillaeg(self):
        """Return active kørselstype-tillæg options.

        Kørselstype-tillæg can be attached to kørselsrækker through the
        Koersel_KoerselstypeTillaeg_LINK table.

        Returns
        -------
        list[dict]
            Active tillæg formatted as:

            [
                {
                    "id": tillaeg_id,
                    "label": tillaeg_tekst
                }
            ]
        """

        return self._get_lookup_records(
            table_name="[befordring_app].[befordring].[KoerselstypeTillaeg]",
            id_column="tillaeg_id",
            label_column="tillaeg_tekst"
        )

    def get_dage(self):
        """Return active weekday options.

        Weekdays can be attached to kørselsrækker through the
        Koersel_Ugedag_LINK table.

        Returns
        -------
        list[dict]
            Active weekdays formatted as:

            [
                {
                    "id": dag_id,
                    "label": dag_tekst
                }
            ]
        """

        return self._get_lookup_records(
            table_name="[befordring_app].[befordring].[Ugedag]",
            id_column="dag_id",
            label_column="dag_tekst"
        )
