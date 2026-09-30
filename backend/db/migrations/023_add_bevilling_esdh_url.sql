-- Migration 023: Add esdh_url to Bevilling
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guard makes it idempotent.
--
-- Context:
--   esdh_noegle holds the PPR case key, e.g. "PPR-2026-123456-001". The app
--   shows it as plain text, so a caseworker who needs the case in GO has to
--   search for it by hand.
--
--   The link cannot be built from esdh_noegle alone. GO's case URL carries a
--   per-case system id that exists nowhere in this database:
--
--       https://ad.go.aarhuskommune.dk/cases/PPR01/PPR-2026-123456/SitePages/Home.aspx
--                                            ^^^^^ only GO knows this
--
--   rpa-befordring-nightly-runs reads it from
--   GET /_goapi/Cases/Metadata/<sag>, whose response carries
--   ows_CaseUrl="cases/PPR01/PPR-2026-123456", and writes the finished URL
--   here. A row with esdh_url IS NULL is one the nightly run has not resolved
--   yet — that is exactly what the step selects on.
--
--   A SEPARATE COLUMN, not esdh_noegle rewritten in place. esdh_noegle is
--   load-bearing in more places than it looks:
--
--     * view_Letter_BevillingData exposes it as sags_nummer, which is printed
--       on the afgørelsesbrev sent to the citizen. A URL there is a defect
--       nobody sees until a parent asks.
--     * the conversion RPA resumes on (esdh_noegle, foerste_koersel_dato); a
--       rewritten value makes every converted bevilling look new.
--     * the URL points at the base case, so storing it in place would destroy
--       the "-001" sub-case number permanently.
--     * six views and two API schemas read the column; each would have to
--       parse the key back out.
--
--   NULLable with no default: most rows will be NULL until the nightly run
--   catches up, and a bevilling whose key does not look like a PPR case
--   deliberately never gets one — a wrong link into a case system is worse
--   than no link.
--
-- After running this migration, redeploy:
--   backend/db/views/view_All_Bevillinger.sql
--   backend/db/views/view_Student_Bevillinger.sql
-- then the backend code (the model declares the column).

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Add esdh_url if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'esdh_url'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
        ADD [esdh_url] NVARCHAR(500) NULL;

    PRINT 'Added Bevilling.esdh_url.';
END
ELSE
BEGIN
    PRINT 'Bevilling.esdh_url already exists — nothing to do.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Verify
-- -----------------------------------------------------------------------
SELECT c.name        AS kolonne,
       t.name        AS datatype,
       c.max_length  AS max_length_bytes,
       c.is_nullable
FROM   sys.columns c
JOIN   sys.types   t ON t.user_type_id = c.user_type_id
WHERE  c.object_id = OBJECT_ID(N'[befordring].[Bevilling]')
AND    c.name IN (N'esdh_noegle', N'esdh_url')
ORDER BY c.name;
GO
