-- Migration 009: Rename ansøgningstype "Kørsel" to "Fast kørsel"
-- Run once against the target database (test / prod).
-- Safe to re-run — the UPDATE matches only the old value, so a second run
-- changes nothing.
--
-- Context:
--   The field is labelled "Kørsel" in the UI and offers two values:
--   "Fast kørsel" and "Midlertidig kørsel". It previously offered "Kørsel"
--   and "Midlertidig kørsel", which read oddly once the field itself was
--   renamed to "Kørsel" — "Kørsel: Kørsel".
--
--   ansoegningstype is stored as free text on Bevilling, not as a foreign key
--   to a lookup table, so the existing rows have to be rewritten. Without this
--   migration, bevillinger created before the change would keep displaying
--   "Kørsel" while new ones display "Fast kørsel", and the filter dropdown on
--   /nye-ansoegninger would offer both as separate options.
--
--   "Midlertidig kørsel" is unchanged. Application logic keys off that value
--   only (see frontend/src/lib/lookupFilters.ts and
--   frontend/src/lib/koerselstype.ts), so nothing branches on the value this
--   migration rewrites.
--
-- Run this together with the matching backend deploy: os2forms_mapping.py now
-- writes "Fast kørsel" for new submissions.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Before: what values exist today?
-- -----------------------------------------------------------------------
SELECT   ansoegningstype, COUNT(*) AS antal
FROM     [befordring].[Bevilling]
GROUP BY ansoegningstype
ORDER BY antal DESC;
GO

-- -----------------------------------------------------------------------
-- 2. Rewrite the value
--
--    Soft-deleted rows are included on purpose: an undeleted bevilling should
--    not come back with a value the UI no longer offers.
-- -----------------------------------------------------------------------
UPDATE [befordring].[Bevilling]
SET    ansoegningstype = N'Fast kørsel'
WHERE  ansoegningstype = N'Kørsel';

PRINT CONCAT('Updated ', @@ROWCOUNT, ' bevilling row(s) from "Kørsel" to "Fast kørsel".');
GO

-- -----------------------------------------------------------------------
-- 3. Verify
-- -----------------------------------------------------------------------

-- 3a. No row should be left on the old value.
SELECT COUNT(*) AS rows_still_on_old_value
FROM   [befordring].[Bevilling]
WHERE  ansoegningstype = N'Kørsel';

-- 3b. After: the distribution should now be "Fast kørsel" / "Midlertidig kørsel".
--     Anything else listed here is a value the UI cannot produce and is worth
--     looking at before telling the business the split is clean.
SELECT   ansoegningstype, COUNT(*) AS antal
FROM     [befordring].[Bevilling]
GROUP BY ansoegningstype
ORDER BY antal DESC;
GO
