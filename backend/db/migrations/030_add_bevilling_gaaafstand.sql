-- Migration 030: Add gaaafstand_km to Bevilling
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guard makes it idempotent.
--
-- Context:
--   Elev.skoleafstand is the walking distance from the child's CURRENT
--   folkeregisteradresse to the school their CURRENT data resolves to. That is
--   the right number for the child as they stand today, and the wrong one for
--   deciding an application.
--
--   A new application often arrives BECAUSE something changed — the family
--   moved, the child was referred elsewhere — so the bevilling carries its own
--   address and its own school, and the pair a caseworker has to judge is the
--   bevilling's, not the elev's. Until now there was no number for it, and the
--   stamdata card showed a distance belonging to a different question.
--
--   This column is that number: the walking distance from the bevilling's
--   adresse_id to its matrikel_id or ungdomsuddannelse_id.
--
-- Why walking:
--   It feeds the afstandskriterie, which is about how far the child would have
--   to walk. Matches Elev.skoleafstand, which is measured the same way.
--
-- Why it is NOT backfilled:
--   Every row would need its own OpenRouteService call. The number is only
--   needed for a case someone is handling, so it is filled when a bevilling is
--   created, when its address or school changes, and on the caseworker's
--   recalculate button — never in bulk.
--
--   NULL therefore means "not calculated", not "zero", and the UI has to say
--   so rather than printing 0 km. Every bevilling created before this
--   migration is NULL and stays that way until someone opens it.
--
-- What it decides:
--   afstandskriterie_klassetrin and afstandskriterie_dato are derived from it
--   rather than from Elev.skoleafstand — see
--   BevillingService._apply_afstandskriterie_defaults. Those two fields answer
--   "how long does this bevilling's situation meet the distance criterion",
--   so they have to be measured against this bevilling's address and school.

USE [Befordringssystemet];
GO

-- -----------------------------------------------------------------------
-- 1. Column
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND   name      = N'gaaafstand_km'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
    ADD [gaaafstand_km] FLOAT NULL;

    PRINT 'Added Bevilling.gaaafstand_km.';
END
ELSE
BEGIN
    PRINT 'Bevilling.gaaafstand_km already exists — nothing to do.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Verify
-- -----------------------------------------------------------------------
SELECT c.name       AS kolonne,
       t.name       AS datatype,
       c.is_nullable
FROM   sys.columns c
JOIN   sys.types   t ON t.user_type_id = c.user_type_id
WHERE  c.object_id = OBJECT_ID(N'[befordring].[Bevilling]')
AND    c.name = N'gaaafstand_km';
