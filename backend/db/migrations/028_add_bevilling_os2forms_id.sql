-- Migration 028: Add os2forms_id to Bevilling
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guards make it idempotent.
--
-- Context:
--   A bevilling created from an OS2Forms submission carries nothing that says
--   WHICH submission it came from, so the question "has this application
--   already produced a bevilling?" cannot be asked at all.
--
--   That question is the one everything else depends on:
--
--     * POST /os2forms/create_bevilling/{cpr} creates unconditionally today.
--       Any retry — a manual re-drive of a journalized form, a reconciler run
--       that overlaps its predecessor — makes a second bevilling for the same
--       family, and nothing notices.
--     * the planned reconciliation job exists to find journalized submissions
--       with no bevilling. Without this column there is no join to make.
--
--   Why not an existing column:
--
--     * esdh_noegle is the PPR case key, and one case legitimately holds
--       SEVERAL bevillinger — that is exactly what defeated the conversion
--       bot's resume logic. It cannot identify a submission.
--     * cpr_elev + ansoegningsdato is not unique either: a family can apply
--       twice on the same day, for two different kinds of kørsel.
--
--   The value is the OS2Forms submission id, as [RPA].[journalizing].[Forms]
--   holds it — a UUID, e.g. 'f10e7cec-778d-429e-9675-71ebd8440f06'. Stored as
--   NVARCHAR(36) rather than UNIQUEIDENTIFIER so it compares as the string it
--   arrives as, with no casting on either side of the join.
--
--   NULLable: every existing row has none, and a bevilling created by a
--   caseworker in the UI never will. Only submissions carry one.
--
--   The UNIQUE index is FILTERED on NOT NULL — without the filter, the second
--   hand-made bevilling would collide with the first on NULL. It is the real
--   guard: the application check in os2forms_service has a window between
--   looking and inserting, and two overlapping reconciler runs sit exactly in
--   it. The index closes it.
--
-- After running this migration, redeploy the backend code (the model declares
-- the column). No view needs changing — nothing displays it.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Add os2forms_id if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'os2forms_id'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
        ADD [os2forms_id] NVARCHAR(36) NULL;

    PRINT 'Added Bevilling.os2forms_id.';
END
ELSE
BEGIN
    PRINT 'Bevilling.os2forms_id already exists — nothing to do.';
END
GO

-- -----------------------------------------------------------------------
-- 2. One bevilling per submission, enforced by the database
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.indexes
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'UX_Bevilling_os2forms_id'
)
BEGIN
    /* If this fails, duplicates already exist. Find them with:

           SELECT os2forms_id, COUNT(*)
           FROM   [befordring].[Bevilling]
           WHERE  os2forms_id IS NOT NULL
           GROUP  BY os2forms_id
           HAVING COUNT(*) > 1;

       Soft-deleted rows count too — the index covers aktiv = 0 as well,
       deliberately: a deleted bevilling still means that submission was
       handled, and recreating it on the next reconciler run would undo a
       caseworker's deletion. */
    CREATE UNIQUE NONCLUSTERED INDEX UX_Bevilling_os2forms_id
        ON [befordring].[Bevilling] ([os2forms_id])
        WHERE [os2forms_id] IS NOT NULL;

    PRINT 'Created UX_Bevilling_os2forms_id.';
END
ELSE
BEGIN
    PRINT 'UX_Bevilling_os2forms_id already exists — nothing to do.';
END
GO

-- -----------------------------------------------------------------------
-- 3. Verify
-- -----------------------------------------------------------------------
SELECT c.name       AS kolonne,
       t.name       AS datatype,
       c.max_length AS max_length_bytes,
       c.is_nullable
FROM   sys.columns c
JOIN   sys.types   t ON t.user_type_id = c.user_type_id
WHERE  c.object_id = OBJECT_ID(N'[befordring].[Bevilling]')
AND    c.name = N'os2forms_id';

SELECT i.name AS indeks, i.is_unique, i.has_filter, i.filter_definition
FROM   sys.indexes i
WHERE  i.object_id = OBJECT_ID(N'[befordring].[Bevilling]')
AND    i.name = N'UX_Bevilling_os2forms_id';
