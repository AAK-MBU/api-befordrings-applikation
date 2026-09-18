"""Staging tables for the nightly imports.

These are landing zones, not application tables. Nothing in the backend reads
or writes them — they are filled by external jobs and drained by a stored
procedure:

    Adresse_STG       <- rpa-befordring-nightly-runs, action
                         _fetch_and_upsert_addresses (raw pyodbc bulk insert
                         from LOIS.DAR.AdresseDkGeoView), merged into Adresse
                         by usp_upsert_adresser_from_stg, filtered on load_id
    Elev_Adresse_STG  <- the cpr -> adresse_id pairs from that same load
    Elev_STG          <- the data worker's nightly student import
    Foraelder_STG     <- the data worker's nightly guardian import

They are declared here so the schema is visible in the codebase, and so the
column names those external jobs depend on cannot be changed without this file
turning up in the diff. See backend/db/migrations/018_add_staging_tables.sql
for the DDL these mirror.

Core Table objects rather than ORM classes, deliberately: three of the four
have no primary key at all, and the ORM cannot map a keyless table without
inventing one. A fake key would be worse than no mapping — it would read as a
real constraint. Core Tables describe them honestly and are still usable via
select()/insert() should a future job need them.

Staging columns are almost all nullable because they hold whatever the source
produced; validation happens during the merge, not on the way in.
"""

from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    Float,
    Integer,
    String,
    Table,
    Unicode,
    text,
)
from sqlalchemy.dialects.mssql import DATETIME2, UNIQUEIDENTIFIER

from app.core.database import Base


DB_SCHEMA = "befordring"


# Address load from LOIS. The only staging table with a key, because the merge
# procedure needs a stable row identity.
adresse_stg = Table(
    "Adresse_STG",
    Base.metadata,
    Column("stage_id", BigInteger, primary_key=True, autoincrement=True),
    # One GUID per import run. The merge filters on it, so two overlapping
    # runs cannot drain each other's rows.
    Column("load_id", UNIQUEIDENTIFIER, nullable=False),
    Column("adresse_id", Unicode(36), nullable=False),
    Column("adresse_tekst", Unicode(500), nullable=True),
    Column("latitude", Float, nullable=True),
    Column("longitude", Float, nullable=True),
    # sysutcdatetime(), not the sysdatetime() used elsewhere in the schema:
    # this is a machine timestamp for the load, not a caseworker-facing one.
    Column(
        "loaded_at",
        DATETIME2(precision=0),
        nullable=False,
        server_default=text("sysutcdatetime()"),
    ),
    schema=DB_SCHEMA,
)


# Which address each student resolved to in the same load. Keyless: one row per
# (load_id, cpr) by construction, but nothing enforces it.
elev_adresse_stg = Table(
    "Elev_Adresse_STG",
    Base.metadata,
    Column("load_id", UNIQUEIDENTIFIER, nullable=False),
    Column("cpr", String(10), nullable=False),
    Column("adresse_id", Unicode(36), nullable=False),
    schema=DB_SCHEMA,
)


# Nightly student import. Mirrors Elev, with two deliberate differences: the
# source calls the name column adresselinjesnavn (Elev.adresseringsnavn), and
# adresse_id arrives as varchar rather than nvarchar.
elev_stg = Table(
    "Elev_STG",
    Base.metadata,
    Column("cpr", String(10), nullable=True),
    Column("adresselinjesnavn", String, nullable=True),
    Column("navne_adresse_beskyttelse", Boolean, nullable=True),
    Column("skoleafstand", Float, nullable=True),
    Column("klasseart", String, nullable=True),
    Column("elevklassetrin", String, nullable=True),
    Column("klassebetegnelse", String, nullable=True),
    # Renamed from sfo in migration 013 — not always an SFO.
    Column("institution", String, nullable=True),
    Column("bopaelsdistrikt", String, nullable=True),
    Column("matrikel_id", Integer, nullable=True),
    Column("ungdomsuddannelse_id", Integer, nullable=True),
    Column("skolekode", Integer, nullable=True),
    Column("kraever_genberegning", Boolean, nullable=True),
    Column("adresse_id", String(36), nullable=True),
    schema=DB_SCHEMA,
)


# Nightly guardian import. Mirrors Foraelder.
foraelder_stg = Table(
    "Foraelder_STG",
    Base.metadata,
    Column("cpr_foraelder", String(10), nullable=True),
    Column("cpr_elev", String(10), nullable=True),
    Column("adresseringsnavn", String, nullable=True),
    Column("navne_adresse_beskyttelse", Boolean, nullable=True),
    Column("maa_vide_barns_adresse", Boolean, nullable=True),
    Column("adresse_id", Unicode(36), nullable=True),
    Column("relation", String(50), nullable=True),
    schema=DB_SCHEMA,
)
