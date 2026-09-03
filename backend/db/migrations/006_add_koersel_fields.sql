-- Migration 006: Add taxa- and egenbefordring-specific fields to Koersel
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guards make it idempotent.
--
-- Context:
--   Kørselsrækker already carried type-specific values: bevilget_koereafstand_pr_vej
--   for egenbefordring, transporttid_i_bus and skift_med_bus for skolerejsekort.
--   This migration adds the same idea for the remaining two tracks:
--
--     koersel_til_institution          taxa (Rutekørsel, Skånekørsel,
--     max_minutter_i_transport         Solo kørsel, Variabel kørsel)
--
--     koerselsgodtgoerelse_modtager_id egenbefordring — which Part receives
--                                      the kilometre reimbursement
--
--   All three are nullable: a kørselsrække only fills the fields belonging to
--   its kørselstype, and the frontend nulls the others when the type changes.
--
--   NOTE: these columns ALREADY EXIST in the shared database — they were added
--   while the feature was being built, and the shared server means every
--   environment pointed at it already has them. This file is the record, and
--   the guards make running it a no-op. It still matters for any database
--   built from scratch.
--
--   The matching view change (view_Bevilling_Koerselsraekker must select the
--   three columns, or the API cannot read them back) is NOT repeated here.
--   The current definition lives in backend/db/seed/view_Bevilling_Koerselsraekker.sql
--   and already exposes them; keeping one copy avoids the drift that has
--   already bitten the other views. Run that file after this one on a fresh
--   database.
--
-- After running this migration, deploy the updated backend and frontend.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Taxa: was the kørsel granted to an institution?
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Koersel]')
    AND    name      = N'koersel_til_institution'
)
BEGIN
    ALTER TABLE [befordring].[Koersel]
        ADD koersel_til_institution BIT NULL;

    PRINT 'Column koersel_til_institution added to [befordring].[Koersel].';
END
ELSE
BEGIN
    PRINT 'Column koersel_til_institution already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Taxa: maximum minutes the student may spend in transport
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Koersel]')
    AND    name      = N'max_minutter_i_transport'
)
BEGIN
    ALTER TABLE [befordring].[Koersel]
        ADD max_minutter_i_transport INT NULL;

    PRINT 'Column max_minutter_i_transport added to [befordring].[Koersel].';
END
ELSE
BEGIN
    PRINT 'Column max_minutter_i_transport already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 3. Egenbefordring: the Part receiving the kilometre reimbursement
-- -----------------------------------------------------------------------
--   References Part rather than Foraelder. Parties are the only source the
--   dropdown reads today; forældremyndige are a known follow-up.
--   Part rows are soft-deleted (aktiv = 0) rather than removed, so this
--   reference stays resolvable after a party is deleted from the case.
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Koersel]')
    AND    name      = N'koerselsgodtgoerelse_modtager_id'
)
BEGIN
    ALTER TABLE [befordring].[Koersel]
        ADD koerselsgodtgoerelse_modtager_id INT NULL
            CONSTRAINT FK_Koersel_KoerselsgodtgoerelseModtager
            REFERENCES [befordring].[Part](part_id);

    PRINT 'Column koerselsgodtgoerelse_modtager_id added to [befordring].[Koersel].';
END
ELSE
BEGIN
    PRINT 'Column koerselsgodtgoerelse_modtager_id already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 4. Verify
-- -----------------------------------------------------------------------
SELECT
    c.name          AS column_name,
    t.name          AS data_type,
    c.is_nullable   AS is_nullable
FROM      sys.columns AS c
JOIN      sys.types   AS t ON t.user_type_id = c.user_type_id
WHERE     c.object_id = OBJECT_ID(N'[befordring].[Koersel]')
AND       c.name IN (
              N'koersel_til_institution',
              N'max_minutter_i_transport',
              N'koerselsgodtgoerelse_modtager_id'
          )
ORDER BY  c.name;
GO
