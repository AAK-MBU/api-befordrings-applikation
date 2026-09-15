-- Migration 013: Rename Elev.sfo to Elev.institution
-- Run once against the target database (test / prod).
-- Safe to re-run — the guards make it idempotent.
--
-- Context:
--   The column holds the institution a student is attached to, which is not
--   always an SFO: "Klubben Holme Søndergaard" is a klub, and the letter engine
--   already has to branch on that. "sfo" was therefore the wrong name for what
--   the column stores.
--
--   This is a straight rename — the application is not live yet, so there is no
--   need to add-and-backfill or keep the old name as an alias. Every writer and
--   reader is renamed in the same change:
--
--     backend   models/citizen.py, schemas/citizen.py, services/citizen_service.py
--     views     view_Stamdata, view_Letter_BevillingData
--     frontend  sag/[cpr]/+page.svelte  (label now reads "Institution")
--     rpa       rpa-afgoerelsesbreve/helpers/block_handlers.py (blok 4)
--
--   NB: only the FIELD is renamed. The VALUES are institution names from the
--   source system ("SFO - Holme Skole") and stay exactly as they are — the
--   letter engine still matches its template entries on that text.
--
-- Two external writers also send this field and must be deployed alongside:
--   * the nightly job that populates Elev for every municipal student
--   * the RPA conversion bot calling POST /citizen/create_elev, whose request
--     schema is extra="forbid" — an unrenamed payload gets a 422, not a
--     silently ignored field.
--
-- After running this migration, run the two updated view scripts.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Rename the column
-- -----------------------------------------------------------------------
IF EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Elev]')
    AND    name      = N'sfo'
)
AND NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Elev]')
    AND    name      = N'institution'
)
BEGIN
    EXEC sp_rename
        @objname = N'[befordring].[Elev].[sfo]',
        @newname = N'institution',
        @objtype = N'COLUMN';

    PRINT 'Column [befordring].[Elev].[sfo] renamed to [institution].';
END
ELSE IF EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Elev]')
    AND    name      = N'institution'
)
BEGIN
    PRINT 'Column [institution] already exists on [befordring].[Elev] — skipped.';
END
ELSE
BEGIN
    PRINT 'Neither [sfo] nor [institution] found on [befordring].[Elev] — nothing to do.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Verify
-- -----------------------------------------------------------------------

-- 2a. The column exists under its new name, and the old name is gone.
SELECT
    c.name        AS column_name,
    t.name        AS data_type,
    c.is_nullable AS is_nullable
FROM       sys.columns AS c
JOIN       sys.types   AS t ON t.user_type_id = c.user_type_id
WHERE      c.object_id = OBJECT_ID(N'[befordring].[Elev]')
AND        c.name IN (N'sfo', N'institution');

-- 2b. Values are untouched — this should still list the institution names
--     exactly as the source system supplies them.
SELECT   institution, COUNT(*) AS antal
FROM     [befordring].[Elev]
WHERE    NULLIF(LTRIM(RTRIM(institution)), '') IS NOT NULL
GROUP BY institution
ORDER BY antal DESC;
GO
