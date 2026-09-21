-- Migration 016: Add the revurdering flag to Bevilling
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guard makes it idempotent.
--
-- Context:
--   Revurdering used to be a STATUS ('Revurdering' in the Status table), which
--   meant a bevilling under reassessment stopped counting as Aktiv — including
--   for the "one active bevilling per citizen" rule. It is now a FLAG on the
--   bevilling, so the real status is preserved while it is being reassessed.
--
--   usp_recalculate_bevilling_status writes this column (needs_revurdering),
--   and view_Revurderinger filters on it:
--       WHERE b.aktiv = 1 AND b.revurdering = 1
--   Without the column both fail outright, so this migration must run before
--   the SP and views are redeployed.
--
--   Nullable with no default, matching dev: NULL and 0 both mean "not under
--   reassessment", and the SP overwrites the column on every run anyway —
--   which is also why no back-fill is needed. Existing rows are left NULL and
--   the first recalculation sets them correctly.
--
--   Like Part, this exists in dev but was never captured as a migration.
--
-- After running this migration, redeploy usp_recalculate_bevilling_status and
-- the views, then the backend code.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Add revurdering column if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'revurdering'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
        ADD revurdering BIT NULL;

    PRINT 'Column revurdering added to [befordring].[Bevilling].';
END
ELSE
BEGIN
    PRINT 'Column revurdering already exists on [befordring].[Bevilling] — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Verify
-- -----------------------------------------------------------------------
SELECT
    c.name          AS column_name,
    t.name          AS data_type,
    c.is_nullable,
    (SELECT COUNT(*) FROM [befordring].[Bevilling] WHERE revurdering = 1)           AS flagged_rows,
    (SELECT COUNT(*) FROM [befordring].[Bevilling] WHERE ISNULL(revurdering,0) = 0) AS unflagged_rows
FROM
    sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE
    c.object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND c.name = N'revurdering';

-- Any bevilling left on the retired 'Revurdering' STATUS. Not back-filled:
-- the next usp_recalculate_bevilling_status run recomputes both the status and
-- the flag from scratch, so these resolve themselves.
SELECT
    b.bevilling_id,
    s.status_tekst
FROM
    [befordring].[Bevilling] b
    JOIN [befordring].[Status] s ON s.status_id = b.status_id
WHERE
    s.status_tekst = N'Revurdering';
GO
