-- Migration 005: Add lock flag to Bevilling
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guard makes it idempotent.
--
-- Context:
--   Koersel already has a `final` column used to mark a kørselsrække as
--   settled. Bevilling did not. This migration brings Bevilling into the same
--   pattern so a whole bevilling can be locked once its decision letter has
--   been created, and unlocked again if a caseworker needs to reopen it.
--
--   Like Koersel.final, this flag does NOT make the row read-only. It marks the
--   bevilling as settled; the application decides what to do about that.
--
--   Existing rows are back-filled with 0 (unlocked), so nothing that predates
--   this migration is retroactively treated as settled.
--
-- After running this migration, deploy the updated backend code.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Add final column if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'final'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
        ADD final BIT NOT NULL
            CONSTRAINT DF_Bevilling_final DEFAULT 0
            WITH VALUES;   -- back-fills all existing rows with 0 (unlocked)

    PRINT 'Column final added to [befordring].[Bevilling].';
END
ELSE
BEGIN
    PRINT 'Column final already exists on [befordring].[Bevilling] — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Verify
-- -----------------------------------------------------------------------
SELECT
    c.name          AS column_name,
    t.name          AS data_type,
    c.is_nullable   AS is_nullable,
    dc.definition   AS default_definition
FROM       sys.columns              AS c
JOIN       sys.types                AS t  ON t.user_type_id = c.user_type_id
LEFT JOIN  sys.default_constraints  AS dc ON dc.object_id   = c.default_object_id
WHERE      c.object_id = OBJECT_ID(N'[befordring].[Bevilling]')
AND        c.name      = N'final';
GO
