-- Migration 022: Add loaded_at to Elev_Adresse_STG
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guard makes it idempotent.
--
-- Context:
--   Both staging tables the RPA owns are drained by load_id at the end of a
--   run, inside the same transaction as the upsert. That covers the normal
--   case, but not the abnormal one: a run that fails while staging never
--   reaches the upsert, so its rows are never deleted. They are invisible to
--   every consumer (all of which filter on load_id) but they accumulate, and
--   Adresse_STG stages every address in the municipality.
--
--   Adresse_STG already has loaded_at and can be reaped by age.
--   Elev_Adresse_STG has no timestamp, so it cannot — this adds one so the two
--   tables can be swept by the same rule.
--
--   sysutcdatetime() to match Adresse_STG.loaded_at, which is UTC for the same
--   reason: it is a machine timestamp for the load, not a caseworker-facing
--   one.
--
--   Existing rows are back-filled to the current time by WITH VALUES, which is
--   required for a NOT NULL column on a table with rows. That makes any
--   orphans already present look fresh for one retention window before they
--   are swept, which is harmless.
--
-- After running this migration, redeploy:
--   backend/db/seed/usp_upsert_adresser_from_stg.sql
--   backend/db/seed/usp_upsert_adresse_ids_from_stg.sql
-- then the backend code (the model declares the column).

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Add loaded_at if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Elev_Adresse_STG]')
    AND    name      = N'loaded_at'
)
BEGIN
    ALTER TABLE [befordring].[Elev_Adresse_STG]
        ADD loaded_at DATETIME2(0) NOT NULL
            CONSTRAINT DF_Elev_Adresse_STG_loaded_at DEFAULT (SYSUTCDATETIME())
            WITH VALUES;   -- back-fills existing rows with "now"

    PRINT 'Column loaded_at added to [befordring].[Elev_Adresse_STG].';
END
ELSE
BEGIN
    PRINT 'Column loaded_at already exists on [befordring].[Elev_Adresse_STG] — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Verify
-- -----------------------------------------------------------------------
SELECT
    c.name        AS column_name,
    t.name        AS data_type,
    c.is_nullable,
    dc.definition AS default_value
FROM
    sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
    LEFT JOIN sys.default_constraints dc ON dc.parent_object_id = c.object_id
                                        AND dc.parent_column_id = c.column_id
WHERE
    c.object_id = OBJECT_ID(N'[befordring].[Elev_Adresse_STG]')
ORDER BY
    c.column_id;

-- Orphaned loads still sitting in either stage. Expect none after a clean run.
SELECT 'Adresse_STG' AS stage, load_id, COUNT(*) AS antal_rows, MIN(loaded_at) AS oldest
FROM   [befordring].[Adresse_STG]      GROUP BY load_id
UNION ALL
SELECT 'Elev_Adresse_STG',             load_id, COUNT(*),       MIN(loaded_at)
FROM   [befordring].[Elev_Adresse_STG] GROUP BY load_id
ORDER BY oldest;
GO
