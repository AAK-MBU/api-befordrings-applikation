-- Migration 033: Make Koersel.tidspunkt_id nullable
-- Run once against the target database (test / prod).
-- Safe to re-run — the guard checks the current nullability.
--
-- Context:
--   Rutetype now states where a trip starts and ends, which makes tidspunkt
--   derivable rather than independent:
--
--       Fra hjem til skole          -> Morgen
--       Mellem hjem og skole        -> Morgen og eftermiddag
--       Fra skole til klub          -> Eftermiddag
--       Fra skole til hjem          -> Eftermiddag
--       Fra klub til hjem           -> Eftermiddag
--       Mellem skole, klub, og hjem -> Eftermiddag
--
--   Only one of the six starts at hjem in the morning, and only one covers
--   both ends of the day. Note that "Mellem skole, klub, og hjem" reads like
--   it spans the day but does not: skole -> klub -> hjem is an afternoon
--   chain.
--
--   This is the first step of removing tidspunkt. It only WIDENS the
--   constraint: every existing row keeps its value, and nothing that writes
--   a tidspunkt stops working. The seed data stops setting it from here on,
--   which is what lets a fresh dev database show what the system looks like
--   without it.
--
-- What still depends on tidspunkt, and must be dealt with before the column
-- can be dropped:
--
--   - view_Letter_Koerselsraekker exposes it, and the afgørelsesbrev
--     skabelon still reads {tidspunkt}. The view now also exposes
--     {rutetype}, lowercased, so the template can switch over.
--   - The kørselsrække form requires it, and gates "Kørsel til institution"
--     on whether the tidspunkt includes an afternoon.
--   - rpa-upload-egenbefordring-til-sharepoint derives allowed_morgen /
--     allowed_efter by string-matching the tidspunkt text. It has to learn
--     the mapping above first, or every egen befordring submission stops
--     being validated against the right half of the day.
--   - Bevilling.ansoegningsdata records the tidspunkt the CITIZEN asked for
--     on the OS2Forms submission. That is a different fact and stays.

USE [Befordringssystemet];
GO

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id   = OBJECT_ID(N'[befordring].[Koersel]')
    AND   name        = N'tidspunkt_id'
    AND   is_nullable = 0
)
BEGIN
    ALTER TABLE [befordring].[Koersel]
    ALTER COLUMN [tidspunkt_id] INT NULL;

    PRINT 'Koersel.tidspunkt_id is now nullable.';
END
ELSE
BEGIN
    PRINT 'Koersel.tidspunkt_id is already nullable — nothing to do.';
END
GO

-- Verify
SELECT c.name AS kolonne, TYPE_NAME(c.user_type_id) AS datatype, c.is_nullable
FROM   sys.columns c
WHERE  c.object_id = OBJECT_ID(N'[befordring].[Koersel]')
AND    c.name IN (N'tidspunkt_id', N'rutetype_id');
