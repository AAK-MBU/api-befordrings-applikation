-- Migration 007: Add the "Mellem skole, klub og hjem" rutetype
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guard makes it idempotent.
--
-- Context:
--   Rutetype became a required field on kørselsrækker (see the frontend
--   validation added alongside the taxa/egenbefordring fields in migration
--   006). The lookup was missing the three-way route, so a kørsel covering
--   school, klub and home had no correct value to choose — and with the field
--   now mandatory, that is a kørselsrække nobody can save honestly.
--
--   Naming follows the convention already in the table: "Mellem X og Y" for a
--   route travelled both ways, "X til Y" for a one-way leg.
--
--   Reference data, not schema. Migration 003 created the Rutetype table and
--   deliberately left its rows to be inserted per environment; this is one of
--   those inserts.
--
-- After running this migration, no deploy is needed — the frontend reads the
-- lookup at runtime.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Insert the rutetype if it is not already there
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   [befordring].[Rutetype]
    WHERE  rutetype_tekst = N'Mellem skole, klub og hjem'
)
BEGIN
    INSERT INTO [befordring].[Rutetype]
        (rutetype_tekst, beskrivelse, aktiv)
    VALUES
        (N'Mellem skole, klub og hjem', '', 1);

    PRINT 'Rutetype "Mellem skole, klub og hjem" inserted.';
END
ELSE
BEGIN
    PRINT 'Rutetype "Mellem skole, klub og hjem" already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Verify
-- -----------------------------------------------------------------------
SELECT
    rutetype_id,
    rutetype_tekst,
    aktiv
FROM      [befordring].[Rutetype]
ORDER BY  rutetype_id;
GO
