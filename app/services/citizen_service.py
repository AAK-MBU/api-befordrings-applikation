# app/services/bevilling_service.py

from app.utils import database


class CitizenService:

    def __init__(self):
        self.conn_string = database.get_db_connection_string()

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

    def get_stamdata(self, cpr: str):

        sql = """
            SELECT
                *
            FROM
                DATA
            WHERE
                cpr = :cpr
        """

        df = database.read_sql(
            query=sql,
            params={"cpr": cpr},
            conn_string=self.conn_string
        )

        return df.to_dict("records")

    def update_citizen_stamdata(self, cpr: str, stamdata: dict):

        set_clause = ", ".join([f"{key} = :{key}" for key in stamdata])

        sql = f"""
            UPDATE citizen_stamdata
            SET {set_clause}
            WHERE cpr = :cpr
        """

        params = {**stamdata, "cpr": cpr}

        rows = database.execute_sql(
            sql,
            params,
            self.conn_string
        )

        return {"rows_updated": rows}
