-- Migration 019: Add the skolerejsekort bus fields to Koersel
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guards make it idempotent.
--
-- Context:
--   Two values captured on a kørselsrække when the kørselstype is
--   Skolerejsekort: how long the bus journey takes, and how many changes it
--   involves. Both are required by the form for that type
--   (validateKoerselstypeFields in KoerselsraekkeTable.svelte) and both are
--   written into the decision letter via view_Letter_Koerselsraekker.
--
--   Nullable, like every other type-specific field on Koersel (taxa_id,
--   bevilget_koereafstand_pr_vej, max_minutter_i_transport): a kørselsrække
--   that is not a skolerejsekort has no answer to give. Note that 0 is a real
--   answer for skift_med_bus — a direct route — so the app distinguishes
--   NULL from 0 and this column must stay nullable rather than default to 0.
--
--   Like Part (015) and Bevilling.revurdering (016), these exist in dev but
--   were never captured as a migration. They came to light when
--   view_Bevilling_Koerselsraekker failed to compile on prod:
--       Msg 207 ... Invalid column name 'transporttid_i_bus'.
--
--   Both views that select them — view_Bevilling_Koerselsraekker and
--   view_Letter_Koerselsraekker — must be (re)deployed after this migration.
--
-- After running this migration, redeploy the views, then the backend code.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Skolerejsekort: journey time by bus, in minutes
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Koersel]')
    AND    name      = N'transporttid_i_bus'
)
BEGIN
    ALTER TABLE [befordring].[Koersel]
        ADD transporttid_i_bus INT NULL;

    PRINT 'Column transporttid_i_bus added to [befordring].[Koersel].';
END
ELSE
BEGIN
    PRINT 'Column transporttid_i_bus already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Skolerejsekort: number of changes on the journey
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Koersel]')
    AND    name      = N'skift_med_bus'
)
BEGIN
    ALTER TABLE [befordring].[Koersel]
        ADD skift_med_bus INT NULL;

    PRINT 'Column skift_med_bus added to [befordring].[Koersel].';
END
ELSE
BEGIN
    PRINT 'Column skift_med_bus already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 3. Verify — both columns present and nullable
-- -----------------------------------------------------------------------
SELECT
    c.name        AS column_name,
    t.name        AS data_type,
    c.is_nullable
FROM
    sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE
    c.object_id = OBJECT_ID(N'[befordring].[Koersel]')
    AND c.name IN (N'transporttid_i_bus', N'skift_med_bus')
ORDER BY
    c.name;
GO
