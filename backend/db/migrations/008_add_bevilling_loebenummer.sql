-- Migration 008: Per-child bevilling number (løbenummer)
-- Run once against the target database (test / prod).
-- Safe to re-run — every step is guarded.
--
-- Context:
--   bevilling_id is a global identity column. A child whose bevillinger happen
--   to be #1, #13 and #19 looks, to a caseworker, like a child with sixteen
--   bevillinger they cannot see. This adds a second number that counts within
--   the child: 1, 2, 3.
--
--   bevilling_id remains the real key. Everything internal — API routes, audit
--   log, foreign keys, support conversations — keeps using it. loebenummer is
--   a display identifier only.
--
--   Existing rows are left without a number on purpose: the UI falls back to
--   "Bevilling #<bevilling_id>" when loebenummer is NULL, and back-filling
--   would invent numbers nobody has ever referenced.
--
--   Rules that make it trustworthy:
--     * assigned once, at creation, and NEVER reassigned
--     * soft-deleted rows keep their number, so the gap stays visible
--     * unique per (cpr_elev, loebenummer), enforced by an index
--
--   A gap (1, 2, 4) therefore means "one was deleted here", which is true and
--   useful. Renumbering would silently invalidate every note and conversation
--   that referenced the old number, which is the thing we are trying to fix.
--
-- After running this migration, deploy the updated backend code and the
-- refreshed views (backend/db/views/).

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Add the column
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'loebenummer'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
        ADD loebenummer INT NULL;

    PRINT 'Column loebenummer added to [befordring].[Bevilling].';
END
ELSE
BEGIN
    PRINT 'Column loebenummer already exists on [befordring].[Bevilling] — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Enforce uniqueness within the child
--
--    This is the backstop behind the application's assignment logic: if two
--    bevillinger for the same child ever race to the same number, the second
--    insert fails loudly instead of quietly duplicating a reference number.
--
--    Not filtered on aktiv — soft-deleted rows keep their number and must keep
--    reserving it.
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.indexes
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'UQ_Bevilling_cpr_elev_loebenummer'
)
BEGIN
    CREATE UNIQUE INDEX UQ_Bevilling_cpr_elev_loebenummer
        ON [befordring].[Bevilling] (cpr_elev, loebenummer)
        WHERE loebenummer IS NOT NULL;   -- filtered: tolerates a NULL mid-migration

    PRINT 'Unique index UQ_Bevilling_cpr_elev_loebenummer created.';
END
ELSE
BEGIN
    PRINT 'Unique index UQ_Bevilling_cpr_elev_loebenummer already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 3. Verify
-- -----------------------------------------------------------------------

-- 3a. Rows without a number. Existing rows are NOT back-filled — they keep
--     the "Bevilling #<id>" fallback in the UI until they are next saved, and
--     the unique index below is filtered so NULLs never collide.
SELECT bevilling_id, cpr_elev, created_at
FROM   [befordring].[Bevilling]
WHERE  loebenummer IS NULL;

-- 3b. Any child with a duplicate number? Should return nothing.
SELECT   cpr_elev, loebenummer, COUNT(*) AS antal
FROM     [befordring].[Bevilling]
GROUP BY cpr_elev, loebenummer
HAVING   COUNT(*) > 1;

-- 3c. Spot-check the children with the most bevillinger.
SELECT TOP 20
    b.cpr_elev,
    COUNT(*)              AS antal_bevillinger,
    MIN(b.loebenummer)    AS laveste,
    MAX(b.loebenummer)    AS hoejeste
FROM     [befordring].[Bevilling] b
GROUP BY b.cpr_elev
ORDER BY COUNT(*) DESC;
GO
