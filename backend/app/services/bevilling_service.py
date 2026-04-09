# app/services/bevilling_service.py

from backend.app.utils import database


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

    def get_koerselsraekker(self, bevilling_id: int):

        sql = """
            SELECT
                [koerselsraekke_id],
                [bevilling_id],
                [tidspunkt],
                [koerselstype],
                [koerselstype_tillaeg],
                [bevilget_koereafstand_pr_vej],
                [dage],
                [bevilling_fra],
                [bevilling_til],
                [taxa_id],
                [kommentar]
            FROM
                [befordring_app].[befordring].[Koerselsraekke]
            WHERE
                bevilling_id = :bevilling_id
            ORDER BY
                tidspunkt DESC
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
                [bevilling_id],
                [barnets_fulde_navn],
                [barnets_cpr],
                [status],
                [sagsbehandlingsdato],
                [adresse_for_bevilling],
                [skole],
                [gaaafstand_km],
                [hjaelpemidler],
                [afstandskriterie_dato],
                [afstandskriterie_klassetrin],
                [ansoeger_relation],
                [revurdering],
                [befordringsudvalg],
                [hjemmel],
                [afgoerelsesbrev],
                [sagsbehandler],
                [ppr_ansvarlig]
            FROM
                [befordring_app].[befordring].[Bevilling]
            WHERE
                barnets_cpr = :cpr
            ORDER BY
                status ASC,
                sagsbehandlingsdato DESC
        """

        df = database.read_sql(
            query=sql,
            params={"cpr": cpr},
            conn_string=self.conn_string
        )

        return df.to_dict("records")

    def create_koerselsraekke(self, bevilling_id: int, new_koerselsraekke_data: dict):

        insert_sql = """
            INSERT INTO [befordring_app].[befordring].[Koerselsraekke] (

                bevilling_id,
                tidspunkt,
                koerselstype,
                koerselstype_tillaeg,
                bevilget_koereafstand_pr_vej,
                dage,
                bevilling_fra,
                bevilling_til,
                taxa_id,
                kommentar

            )
            VALUES (

                :bevilling_id,
                :tidspunkt,
                :koerselstype,
                :koerselstype_tillaeg,
                :bevilget_koereafstand_pr_vej,
                :dage,
                :bevilling_fra,
                :bevilling_til,
                :taxa_id,
                :kommentar

            )
        """

        params = {
            "bevilling_id": bevilling_id,
            "tidspunkt": new_koerselsraekke_data.get("tidspunkt"),
            "koerselstype": new_koerselsraekke_data.get("koerselstype"),
            "koerselstype_tillaeg": new_koerselsraekke_data.get("koerselstype_tillaeg"),
            "bevilget_koereafstand_pr_vej": new_koerselsraekke_data.get("bevilget_koereafstand_pr_vej"),
            "dage": new_koerselsraekke_data.get("dage"),
            "bevilling_fra": new_koerselsraekke_data.get("bevilling_fra"),
            "bevilling_til": new_koerselsraekke_data.get("bevilling_til"),
            "taxa_id": new_koerselsraekke_data.get("taxa_id"),
            "kommentar": new_koerselsraekke_data.get("kommentar"),
        }

        # 🔹 1. Insert
        database.execute_sql(
            query=insert_sql,
            params=params,
            conn_string=self.conn_string
        )

        # 🔹 2. Fetch newest row
        select_sql = """
            SELECT TOP 1 *
            FROM [befordring_app].[befordring].[Koerselsraekke]
            WHERE bevilling_id = :bevilling_id
            ORDER BY koerselsraekke_id DESC
        """

        df = database.read_sql(
            query=select_sql,
            params={"bevilling_id": bevilling_id},
            conn_string=self.conn_string
        )

        # 🔹 3. Return clean object
        if df.empty:
            return None

        return df.iloc[0].to_dict()

    def create_bevilling(self, cpr: str, new_bevilling_data: dict):

        insert_sql = """
            INSERT INTO [befordring_app].[befordring].[Bevilling] (

                barnets_fulde_navn,
                barnets_cpr,
                status,
                sagsbehandlingsdato,
                adresse_for_bevilling,
                skole,
                gaaafstand_km,
                hjaelpemidler,
                afstandskriterie_dato,
                afstandskriterie_klassetrin,
                ansoeger_relation,
                revurdering,
                befordringsudvalg,
                hjemmel,
                afgoerelsesbrev,
                sagsbehandler,
                ppr_ansvarlig

            )
            VALUES (

                :barnets_fulde_navn,
                :barnets_cpr,
                :status,
                GETDATE(),
                :adresse_for_bevilling,
                :skole,
                :gaaafstand_km,
                :hjaelpemidler,
                :afstandskriterie_dato,
                :afstandskriterie_klassetrin,
                :ansoeger_relation,
                :revurdering,
                :befordringsudvalg,
                :hjemmel,
                :afgoerelsesbrev,
                :sagsbehandler,
                :ppr_ansvarlig

            )
        """

        params = {
            "barnets_fulde_navn": new_bevilling_data.get("barnets_fulde_navn"),
            "barnets_cpr": cpr,
            "status": new_bevilling_data.get("status"),
            "adresse_for_bevilling": new_bevilling_data.get("adresse_for_bevilling"),
            "skole": new_bevilling_data.get("skole"),
            "gaaafstand_km": new_bevilling_data.get("gaaafstand_km"),
            "hjaelpemidler": new_bevilling_data.get("hjaelpemidler"),
            "afstandskriterie_dato": new_bevilling_data.get("afstandskriterie_dato"),
            "afstandskriterie_klassetrin": new_bevilling_data.get("afstandskriterie_klassetrin"),
            "ansoeger_relation": new_bevilling_data.get("ansoeger_relation"),
            "revurdering": new_bevilling_data.get("revurdering"),
            "befordringsudvalg": new_bevilling_data.get("befordringsudvalg"),
            "hjemmel": new_bevilling_data.get("hjemmel"),
            "afgoerelsesbrev": new_bevilling_data.get("afgoerelsesbrev"),
            "sagsbehandler": new_bevilling_data.get("sagsbehandler"),
            "ppr_ansvarlig": new_bevilling_data.get("ppr_ansvarlig")
        }

        # 🔹 1. Insert
        database.execute_sql(
            query=insert_sql,
            params=params,
            conn_string=self.conn_string
        )

        # 🔹 2. Fetch the newest row
        select_sql = """
            SELECT TOP 1 *
            FROM [befordring_app].[befordring].[Bevilling]
            WHERE barnets_cpr = :cpr
            ORDER BY bevilling_id DESC
        """

        df = database.read_sql(
            query=select_sql,
            params={"cpr": cpr},
            conn_string=self.conn_string
        )

        # 🔹 3. Return clean object
        if df.empty:
            return None

        return df.iloc[0].to_dict()

    def update_bevilling(self, bevilling_id: int, bevilling_data: dict):

        allowed_fields = [
            "barnets_fulde_navn",
            "barnets_cpr",
            "status",
            "sagsbehandlingsdato",
            "adresse_for_bevilling",
            "skole",
            "gaaafstand_km",
            "hjaelpemidler",
            "afstandskriterie_dato",
            "afstandskriterie_klassetrin",
            "ansoeger_relation",
            "revurdering",
            "befordringsudvalg",
            "hjemmel",
            "afgoerelsesbrev",
            "sagsbehandler",
            "ppr_ansvarlig"
        ]

        # 👇 filter ONLY valid DB fields
        filtered_data = {
            key: value
            for key, value in bevilling_data.items()
            if key in allowed_fields
        }

        set_clause = ", ".join([f"{key} = :{key}" for key in filtered_data])

        sql = f"""
            UPDATE [befordring_app].[befordring].[Bevilling]
            SET {set_clause}
            WHERE bevilling_id = :bevilling_id
        """

        print(sql)

        params = {**filtered_data, "bevilling_id": bevilling_id}

        rows = database.execute_sql(sql, params, self.conn_string)

        return {"rows_updated": rows}

    def delete_bevilling(self, bevilling_id: int):

        sql = """
            begin tran
            delete
            FROM [befordring_app].[befordring].[Bevilling]

            where bevilling_id = :bevilling_id

            commit
        """

        rows = database.execute_sql(
            query=sql,
            params={"bevilling_id": bevilling_id},
            conn_string=self.conn_string
        )

        return {"rows_deleted": rows}
