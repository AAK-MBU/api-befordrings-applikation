# app/services/bevilling_service.py

from backend.app.utils import database


class CitizenService:

    def __init__(self):
        self.conn_string = database.get_db_connection_string()
        self.lis_conn_string = database.get_lis_db_connection_string()

    def get_sagsbehandlere(self):
        """
        Helper function to run the sql to fetch sagsbehandlere from the database
        """

        # Here we define the sql that we would otherwise simply run in SSMS
        sql = """
            SELECT
                [Sagsbehandlerkode],
                [Navn],
                [Beskrivelse],
                [Aktiv]
            FROM
                [befordring_app].[befordring].[Sagsbehandler]
        """

        # Here we call the database.py utils file, that has a read_sql() function, that runs a specified SELECT statement
        df = database.read_sql(
            query=sql,
            conn_string=self.conn_string
        )

        return df.to_dict("records")

    def get_parent_data(self, cpr: str):

        sql = """
            WITH foraeldre AS (
                SELECT
                    b.MorCPR_Nr_0,
                    b.FarCPR_Nr_0
                FROM
                    [LOIS].[CPR].[JuridiskeForaeldreView] b
                WHERE
                    b.PNR_0 = :cpr
            ),

            foraeldre_flat AS (
                SELECT
                    MorCPR_Nr_0 AS cpr,
                    'Mor' AS rolle
                FROM foraeldre

                UNION

                SELECT
                    FarCPR_Nr_0,
                    'Far'
                FROM foraeldre
            ),

            beskyttelse AS (
                SELECT
                    DISTINCT PNR_0
                FROM
                    [LOIS].[CPR].[BeskytView]
                WHERE
                    Beskyttelseskode = 1
            )

            SELECT
                ff.rolle,

                CONCAT(
                    f.Fornavn, ' ',
                    ISNULL(f.Mellemnavn + ' ', ''),
                    f.Efternavn
                ) AS navn,

                f.PNR_0 AS cpr,

                CONCAT(
                    f.Standardadresse, ', ',
                    f.Postnr, ' ',
                    f.PostDistrikt
                ) AS folkeregisteradresse,

                'Ja' AS foraeldremyndig,

                CASE
                    WHEN b.PNR_0 IS NOT NULL THEN 'Ja'
                    ELSE 'Nej'
                END AS navne_og_adressebeskyttelse

            FROM foraeldre_flat ff

            LEFT JOIN [LOIS].[CPR].[BorgerInfoKomGeoView] f
                ON f.PNR_0 = ff.cpr

            LEFT JOIN beskyttelse b
                ON b.PNR_0 = ff.cpr

            ORDER BY
                rolle DESC
        """

        df = database.read_sql(
            query=sql,
            params={"cpr": cpr},
            conn_string=self.lis_conn_string
        )

        return df.to_dict("records")

    def get_stamdata(self, cpr: str):

        sql = """
            SELECT
                [barnets_cpr],
                [navne_adresse_beskyttelse],
                [barnets_fulde_navn],
                [sags_id],
                [status],
                [folkeregisteradresse],
                [skole],
                [skolematrikel],
                [gaaafstand_km],
                [klasseart],
                [klassebetegnelse],
                [personligt_klassetrin],
                [sfo],
                [bopaelsdistrikt]
            FROM
                [befordring_app].[befordring].[Stamdata]

            WHERE
                barnets_cpr = :cpr
        """

        df = database.read_sql(
            query=sql,
            params={"cpr": cpr},
            conn_string=self.conn_string
        )

        records = df.to_dict("records")

        return records[0] if records else None

    def update_citizen_stamdata(self, cpr: str, stamdata: dict):

        set_clause = ", ".join([f"{key} = :{key}" for key in stamdata])

        sql = f"""
            UPDATE [befordring_app].[befordring].[Stamdata]
            SET {set_clause}
            WHERE barnets_cpr = :cpr
        """

        params = {**stamdata, "cpr": cpr}

        rows = database.execute_sql(
            sql,
            params,
            self.conn_string
        )

        return {"rows_updated": rows}
