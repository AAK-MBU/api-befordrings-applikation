# app/services/bevilling_service.py

from app.utils import database


class BevillingService:

    def __init__(self):
        self.conn_string = database.get_db_connection_string()

    def get_bevillinger(
        self,
        status=None,
        created_at=None,
        cpr=None,
        bevilling_til=None,
        bevilling_fra=None,
        order_by=None
    ):

        sql = """
            SELECT *
            FROM BEVILLING
            WHERE 1=1
        """

        params = {}

        # ---- Filters ----

        if status:
            sql += " AND status = :status"
            params["status"] = status

        if created_at:
            sql += " AND created_at = :created_at"
            params["created_at"] = created_at

        if cpr:
            sql += " AND CPR = :cpr"
            params["cpr"] = cpr

        if bevilling_til:
            sql += " AND bevilling_til <= :bevilling_til"
            params["bevilling_til"] = bevilling_til

        if bevilling_fra:
            sql += " AND bevilling_fra >= :bevilling_fra"
            params["bevilling_fra"] = bevilling_fra

        # ---- Order by ----

        if order_by:
            allowed_columns = {"created_at", "status", "CPR"}
            allowed_directions = {"ASC", "DESC"}

            key = order_by.get("key")
            direction = order_by.get("order_direction", "ASC").upper()

            if key not in allowed_columns:
                raise ValueError("Invalid order_by column")

            if direction not in allowed_directions:
                raise ValueError("Invalid order direction")

            sql += f" ORDER BY {key} {direction}"

        # ---- Execute ----

        df = database.read_sql(
            query=sql,
            params=params,
            conn_string=self.conn_string
        )

        return df.to_dict("records")

    def get_bevilling(self, bevilling_id: int):

        sql = """
            SELECT
                *
            FROM
                DATA
            WHERE
                AND bevilling_id = :bevilling_id
        """

        df = database.read_sql(
            query=sql,
            params={
                "bevilling_id": bevilling_id
            },
            conn_string=self.conn_string
        )

        return df.to_dict("records")

    def get_citizen_bevillinger(self, cpr: str):

        sql = """
            SELECT
                *
            FROM
                BEVILLING
            WHERE
                CPR = :cpr
        """

        df = database.read_sql(
            query=sql,
            params={"cpr": cpr},
            conn_string=self.conn_string
        )

        return df.to_dict("records")

    def create_bevilling(self, cpr: str, new_bevilling_data: dict):

        sql = """
            INSERT INTO DATA (
                col1,
                col2,
                col3,
                col4
            )
            VALUES (
                :col1,
                :col2,
                :col3,
                :col4
            )
        """

        params = {
            "col1": 1,
            "col2": 2,
            "col3": 3,
            "col4": 4
        }

        rows = database.execute_sql(
            query=sql,
            params=params,
            conn_string=self.conn_string
        )

        return {"rows_inserted": rows}

    def update_bevilling(self, bevilling_id: int, bevilling_data: dict):

        set_clause = ", ".join([f"{key} = :{key}" for key in bevilling_data])

        sql = f"""
            UPDATE bevillinger
            SET {set_clause}
            WHERE bevilling_id = :bevilling_id
        """

        params = {**bevilling_data, "bevilling_id": bevilling_id}

        rows = database.execute_sql(
            sql,
            params,
            self.conn_string
        )

        return {"rows_updated": rows}

    def delete_bevilling(self, bevilling_id: int):

        sql = """
            DELETE FROM bevillinger
            WHERE bevilling_id = :bevilling_id
        """

        rows = database.execute_sql(
            query=sql,
            params={"bevilling_id": bevilling_id},
            conn_string=self.conn_string
        )

        return {"rows_deleted": rows}
