-- Migration 032: The six rutetyper, and the order they sort in
-- Run once against the target database (test / prod).
-- Safe to re-run — every step is guarded.
--
-- Context:
--   Rutetype now states where a trip starts and ends, not just which places
--   it touches. Befordring gave the six that should exist:
--
--       Mellem hjem og skole
--       Mellem skole, klub, og hjem
--       Fra hjem til skole
--       Fra skole til klub
--       Fra skole til hjem
--       Fra klub til hjem
--
--   The first two already exist and are untouched. Only the four "Fra ... til
--   ..." types are new.
--
--   NOTE on the second one: their list wrote "Mellem skole, klub og hjem"
--   without the comma before "og". Confirmed as a typo — the existing row
--   keeps its comma, so it needs no rename and no data migration.
--
-- What this migration does NOT do:
--   It does not retire the old types and it does not touch a single
--   Koersel row. Five old types remain selectable:
--
--       Mellem hjem og klub      (no replacement — deliberately dropped)
--       Mellem skole og klub     (no replacement — deliberately dropped)
--       Til skole                (-> Fra hjem til skole)
--       Til klub                 (-> Fra skole til klub)
--       Til hjem                 (-> Fra skole til hjem OR Fra klub til hjem)
--
--   "Til hjem" is why nothing is backfilled automatically: two of the six new
--   types end at home and the old value does not record where the trip
--   started. Guessing lands a wrong route in an afgørelsesbrev.
--
--   The caseworkers move the existing rækker over by hand. Their worklist is
--   db/analyse/koerselsraekker_med_gammel_rutetype.sql. Once it returns
--   nothing, a later migration can set the five old types aktiv = 0.
--
-- Why sorteringsorden is a column and not a list in code:
--   Befordring's ordering is NOT the order they listed the types in, so it
--   cannot be inferred from the name or the id — it is its own fact. It is
--   read by both the kørselsrække sort in the UI and the letter view, and two
--   hardcoded copies of a list drift. NULL sorts last, which is where the
--   retiring types belong.
--
--   It applies only as a TIE-BREAK, below the existing date ordering: it
--   decides the order of rækker whose gyldig_fra and gyldig_til are equal.

USE [Befordringssystemet];
GO

-- -----------------------------------------------------------------------
-- 1. Column
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[befordring].[Rutetype]')
    AND   name      = N'sorteringsorden'
)
BEGIN
    ALTER TABLE [befordring].[Rutetype]
    ADD [sorteringsorden] INT NULL;

    PRINT 'Added Rutetype.sorteringsorden.';
END
ELSE
BEGIN
    PRINT 'Rutetype.sorteringsorden already exists — nothing to do.';
END
GO

-- -----------------------------------------------------------------------
-- 2. The four new types
-- -----------------------------------------------------------------------
INSERT INTO [befordring].[Rutetype] (rutetype_tekst, beskrivelse, aktiv)
SELECT v.rutetype_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    (N'Fra hjem til skole', N'', 1),
    (N'Fra skole til klub', N'', 1),
    (N'Fra skole til hjem', N'', 1),
    (N'Fra klub til hjem',  N'', 1)
) AS v (rutetype_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Rutetype] t
    WHERE LTRIM(RTRIM(t.rutetype_tekst)) = LTRIM(RTRIM(v.rutetype_tekst))
);
PRINT CONCAT('Rutetype: ', @@ROWCOUNT, ' row(s) inserted.');
GO

-- -----------------------------------------------------------------------
-- 3. Sort order — the six that stay. The rest keep NULL and sort last.
-- -----------------------------------------------------------------------
UPDATE t
SET    t.sorteringsorden = v.sorteringsorden
FROM   [befordring].[Rutetype] t
JOIN (VALUES
    (N'Mellem hjem og skole',        1),
    (N'Mellem skole, klub, og hjem', 2),
    (N'Fra hjem til skole',          3),
    (N'Fra skole til klub',          4),
    (N'Fra skole til hjem',          5),
    (N'Fra klub til hjem',           6)
) AS v (rutetype_tekst, sorteringsorden)
  ON LTRIM(RTRIM(t.rutetype_tekst)) = LTRIM(RTRIM(v.rutetype_tekst))
WHERE  ISNULL(t.sorteringsorden, -1) <> v.sorteringsorden;
PRINT CONCAT('Rutetype: ', @@ROWCOUNT, ' sort order(s) set.');
GO

-- -----------------------------------------------------------------------
-- 4. Verify — the six should carry 1-6, the retiring five NULL
-- -----------------------------------------------------------------------
SELECT rutetype_id, rutetype_tekst, aktiv, sorteringsorden
FROM   [befordring].[Rutetype]
ORDER  BY CASE WHEN sorteringsorden IS NULL THEN 1 ELSE 0 END,
          sorteringsorden,
          rutetype_tekst;
