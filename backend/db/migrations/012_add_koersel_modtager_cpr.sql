-- Migration 012: Add koerselsgodtgoerelse_modtager_cpr to Koersel
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guard makes it idempotent.
--
-- Context:
--   Allows a forælder (from the Foraelder table) to be stored as the
--   kørselsgodtgørelse recipient without touching the Part table.
--
--   The two columns are mutually exclusive — exactly one is set on an
--   egenbefordring kørselsrække:
--     koerselsgodtgoerelse_modtager_id  → FK to Part (øvrig part, added by hand
--                                         on the Parter tab)
--     koerselsgodtgoerelse_modtager_cpr → CPR from Foraelder (legal guardian)
--
--   Keeping them in separate columns preserves the strict Foraelder/Part
--   distinction rather than copying forældre into Part just to reference them.
--
-- After running this migration, deploy the updated backend and run the updated
-- view_Bevilling_Koerselsraekker script.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Add the column if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Koersel]')
    AND    name      = N'koerselsgodtgoerelse_modtager_cpr'
)
BEGIN
    ALTER TABLE [befordring].[Koersel]
        ADD koerselsgodtgoerelse_modtager_cpr NVARCHAR(10) NULL;

    PRINT 'Column koerselsgodtgoerelse_modtager_cpr added to [befordring].[Koersel].';
END
ELSE
BEGIN
    PRINT 'Column koerselsgodtgoerelse_modtager_cpr already exists on [befordring].[Koersel] — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Verify
-- -----------------------------------------------------------------------

-- 2a. The column exists with the expected type.
SELECT
    c.name          AS column_name,
    t.name          AS data_type,
    c.max_length    AS max_length_bytes,
    c.is_nullable   AS is_nullable
FROM       sys.columns AS c
JOIN       sys.types   AS t ON t.user_type_id = c.user_type_id
WHERE      c.object_id = OBJECT_ID(N'[befordring].[Koersel]')
AND        c.name      = N'koerselsgodtgoerelse_modtager_cpr';

-- 2b. Nothing should ever carry BOTH recipient columns. Should return 0 rows —
--     the application writes one and nulls the other, and this is the check
--     that would catch it going wrong.
SELECT koersel_id, koerselsgodtgoerelse_modtager_id, koerselsgodtgoerelse_modtager_cpr
FROM   [befordring].[Koersel]
WHERE  koerselsgodtgoerelse_modtager_id  IS NOT NULL
AND    koerselsgodtgoerelse_modtager_cpr IS NOT NULL;
GO
