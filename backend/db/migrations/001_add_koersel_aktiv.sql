-- Migration 001: Add soft-delete flag to Koersel
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guard makes it idempotent.
--
-- Context:
--   Bevilling already has an `aktiv` column used for soft-delete.
--   Koersel did not. This migration brings Koersel into the same pattern
--   so that individual kørselsrækker can be soft-deleted without losing
--   history. Soft-deleted rows are invisible to the application but can
--   be queried directly in the database for audit purposes.
--
-- After running this migration, deploy the updated backend code.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Add aktiv column if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Koersel]')
    AND    name      = N'aktiv'
)
BEGIN
    ALTER TABLE [befordring].[Koersel]
        ADD aktiv BIT NOT NULL
            CONSTRAINT DF_Koersel_aktiv DEFAULT 1
            WITH VALUES;   -- back-fills all existing rows with 1 (active)

    PRINT 'Column aktiv added to [befordring].[Koersel].';
END
ELSE
BEGIN
    PRINT 'Column aktiv already exists on [befordring].[Koersel] — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Verify
-- -----------------------------------------------------------------------
SELECT
    c.name                              AS column_name,
    t.name                              AS data_type,
    c.is_nullable,
    dc.definition                       AS default_value,
    (SELECT COUNT(*) FROM [befordring].[Koersel] WHERE aktiv = 1) AS active_rows,
    (SELECT COUNT(*) FROM [befordring].[Koersel] WHERE aktiv = 0) AS deleted_rows
FROM
    sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
    LEFT JOIN sys.default_constraints dc ON dc.parent_object_id = c.object_id
                                        AND dc.parent_column_id = c.column_id
WHERE
    c.object_id = OBJECT_ID(N'[befordring].[Koersel]')
    AND c.name = N'aktiv';
GO