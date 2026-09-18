-- Migration 018: Add the nightly-import staging tables
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guards make it idempotent.
--
-- Context:
--   The nightly jobs do not write Elev / Foraelder / Adresse directly. They
--   bulk-load into a _STG table first and then merge, so a partial or failed
--   import never leaves the live tables half-updated.
--
--     Adresse_STG        <- LOIS address register (rpa-befordring-nightly-runs,
--                           action _fetch_and_upsert_addresses), merged by
--                           usp_upsert_adresser_from_stg using load_id
--     Elev_Adresse_STG   <- the cpr -> adresse_id pairs from the same load
--     Elev_STG           <- the data worker's nightly student import
--     Foraelder_STG      <- the data worker's nightly guardian import
--
--   None of these were ever captured as migrations, so a database built from
--   this folder alone cannot run the nightly jobs at all. Dev is missing
--   Elev_STG and Foraelder_STG outright, which is why the student/guardian
--   import path cannot be exercised there today.
--
--   Staging tables intentionally have no keys, no FKs and mostly nullable
--   columns: they hold whatever the source produced, and validation happens
--   during the merge. Elev_STG mirrors Elev's shape including `institution`
--   (see migration 013) — note its source column is `adresselinjesnavn`,
--   not Elev's `adresseringsnavn`.
--
-- After running this migration, no code deploy is needed — the jobs read
-- these tables directly.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Adresse_STG — LOIS address load
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = N'befordring' AND t.name = N'Adresse_STG'
)
BEGIN
    CREATE TABLE [befordring].[Adresse_STG](
        [stage_id]      BIGINT IDENTITY(1,1) NOT NULL,

        -- One GUID per import run. The merge procedure filters on it, so two
        -- overlapping runs cannot merge each other's rows.
        [load_id]       UNIQUEIDENTIFIER NOT NULL,

        [adresse_id]    NVARCHAR(36)  NOT NULL,
        [adresse_tekst] NVARCHAR(500) NULL,
        [latitude]      FLOAT         NULL,
        [longitude]     FLOAT         NULL,
        -- sysutcdatetime(), not the sysdatetime() used elsewhere in the
        -- schema: a machine timestamp for the load, not a caseworker-facing one.
        [loaded_at]     DATETIME2(0)  NOT NULL
            CONSTRAINT [DF_Adresse_Stage_loaded_at] DEFAULT (SYSUTCDATETIME()),

        PRIMARY KEY CLUSTERED ([stage_id] ASC)
    );

    PRINT 'Table [befordring].[Adresse_STG] created.';
END
ELSE
BEGIN
    PRINT 'Table [befordring].[Adresse_STG] already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Elev_Adresse_STG — cpr -> adresse_id pairs from the same load
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = N'befordring' AND t.name = N'Elev_Adresse_STG'
)
BEGIN
    CREATE TABLE [befordring].[Elev_Adresse_STG](
        [load_id]    UNIQUEIDENTIFIER NOT NULL,
        [cpr]        VARCHAR(10)      NOT NULL,
        [adresse_id] NVARCHAR(36)     NOT NULL
    );

    PRINT 'Table [befordring].[Elev_Adresse_STG] created.';
END
ELSE
BEGIN
    PRINT 'Table [befordring].[Elev_Adresse_STG] already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 3. Elev_STG — nightly student import
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = N'befordring' AND t.name = N'Elev_STG'
)
BEGIN
    CREATE TABLE [befordring].[Elev_STG](
        [cpr]                       VARCHAR(10)   NULL,

        -- Source calls it adresselinjesnavn; it lands in Elev.adresseringsnavn.
        [adresselinjesnavn]         VARCHAR(MAX)  NULL,

        [navne_adresse_beskyttelse] BIT           NULL,
        [skoleafstand]              FLOAT         NULL,
        [klasseart]                 VARCHAR(MAX)  NULL,
        [elevklassetrin]            VARCHAR(MAX)  NULL,
        [klassebetegnelse]          VARCHAR(MAX)  NULL,

        -- Renamed from sfo in migration 013 — not always an SFO.
        [institution]               VARCHAR(MAX)  NULL,

        [bopaelsdistrikt]           VARCHAR(MAX)  NULL,
        [matrikel_id]               INT           NULL,
        [ungdomsuddannelse_id]      INT           NULL,
        [skolekode]                 INT           NULL,
        [kraever_genberegning]      BIT           NULL,

        -- varchar here, nvarchar on Elev.adresse_id — kept as the source
        -- delivers it; the merge converts.
        [adresse_id]                VARCHAR(36)   NULL
    );

    PRINT 'Table [befordring].[Elev_STG] created.';
END
ELSE
BEGIN
    PRINT 'Table [befordring].[Elev_STG] already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 4. Foraelder_STG — nightly guardian import
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = N'befordring' AND t.name = N'Foraelder_STG'
)
BEGIN
    CREATE TABLE [befordring].[Foraelder_STG](
        [cpr_foraelder]             VARCHAR(10)   NULL,
        [cpr_elev]                  VARCHAR(10)   NULL,
        [adresseringsnavn]          VARCHAR(MAX)  NULL,
        [navne_adresse_beskyttelse] BIT           NULL,
        [maa_vide_barns_adresse]    BIT           NULL,
        [adresse_id]                NVARCHAR(36)  NULL,
        [relation]                  VARCHAR(50)   NULL
    );

    PRINT 'Table [befordring].[Foraelder_STG] created.';
END
ELSE
BEGIN
    PRINT 'Table [befordring].[Foraelder_STG] already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 5. Verify — all four must be present
-- -----------------------------------------------------------------------
SELECT
    t.name                                        AS table_name,
    (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS column_count
FROM
    sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE
    s.name = N'befordring'
    AND t.name IN (N'Adresse_STG', N'Elev_Adresse_STG', N'Elev_STG', N'Foraelder_STG')
ORDER BY
    t.name;
GO
