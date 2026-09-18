-- Migration 021: Make the Elev foreign keys trusted, and name the
--                Koersel -> Part foreign key
-- Run once against the target database (test / prod).
-- Safe to re-run — both steps are guarded on the current state.
--
-- Context:
--   Two leftovers found by diffing the dev and prod creation scripts once the
--   two databases had otherwise converged. Each database has one of them, so
--   this migration is written to be a no-op on whichever already agrees.
--
--   1. PROD: Elev's three foreign keys were added WITH NOCHECK.
--
--      That adds the constraint without validating the rows already in the
--      table. The ALTER TABLE ... CHECK CONSTRAINT that follows re-enables it
--      for future writes but never goes back over the existing rows, so SQL
--      Server flags the constraint is_not_trusted. Two costs: the constraint
--      is not proof that the data satisfies it, and the optimiser will not use
--      it to simplify plans.
--
--      Verified clean before writing this — all three orphan counts are 0:
--          Elev -> Adresse             0
--          Elev -> Skolematrikel       0
--          Elev -> Ungdomsuddannelse   0
--      so the revalidation below has nothing to reject. If it throws on a
--      future database, that database genuinely has orphan rows and they must
--      be resolved rather than the constraint re-suppressed.
--
--   2. DEV: the Koersel -> Part foreign key has no name.
--
--      Migration 006 creates it as FK_Koersel_KoerselsgodtgoerelseModtager.
--      Dev's was created by hand before 006 existed, so SQL Server generated
--      something like FK__Koersel__koersel__5FB337D6. Renaming rather than
--      dropping and recreating: a rename is metadata only, where a recreate
--      would revalidate every row for no reason.
--
-- After running this migration, no code deploy is needed — nothing here
-- changes a column, a type or a value.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Revalidate Elev's foreign keys
--
--    "WITH CHECK CHECK CONSTRAINT" is not a typo: the first CHECK is the
--    validation option, the second names the action being performed.
-- -----------------------------------------------------------------------
DECLARE @fk sysname;
DECLARE @sql nvarchar(max);

DECLARE fk_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT fk.name
    FROM   sys.foreign_keys fk
    WHERE  fk.parent_object_id = OBJECT_ID(N'[befordring].[Elev]')
    AND    (fk.is_not_trusted = 1 OR fk.is_disabled = 1);

OPEN fk_cursor;
FETCH NEXT FROM fk_cursor INTO @fk;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER TABLE [befordring].[Elev] WITH CHECK CHECK CONSTRAINT ['
             + @fk + N'];';

    EXEC sp_executesql @sql;

    PRINT CONCAT('Revalidated ', @fk, ' on [befordring].[Elev].');

    FETCH NEXT FROM fk_cursor INTO @fk;
END

CLOSE fk_cursor;
DEALLOCATE fk_cursor;

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE  parent_object_id = OBJECT_ID(N'[befordring].[Elev]')
    AND    (is_not_trusted = 1 OR is_disabled = 1)
)
BEGIN
    PRINT 'All foreign keys on [befordring].[Elev] are trusted and enabled.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Name the Koersel -> Part foreign key
--
--    Located by what it does (the column it sits on and the table it points
--    at) rather than by its current name, which is server-generated and
--    therefore different on every database that has this problem.
-- -----------------------------------------------------------------------
DECLARE @old sysname = (
    SELECT TOP 1 fk.name
    FROM   sys.foreign_keys        fk
    JOIN   sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
    JOIN   sys.columns             c   ON c.object_id = fkc.parent_object_id
                                      AND c.column_id = fkc.parent_column_id
    WHERE  fk.parent_object_id     = OBJECT_ID(N'[befordring].[Koersel]')
    AND    fk.referenced_object_id = OBJECT_ID(N'[befordring].[Part]')
    AND    c.name                  = N'koerselsgodtgoerelse_modtager_id'
    AND    fk.name <> N'FK_Koersel_KoerselsgodtgoerelseModtager'
);

IF @old IS NULL
BEGIN
    PRINT 'Koersel -> Part foreign key is already named FK_Koersel_KoerselsgodtgoerelseModtager (or absent) — skipped.';
END
ELSE IF EXISTS (
    SELECT 1 FROM sys.objects
    WHERE name = N'FK_Koersel_KoerselsgodtgoerelseModtager'
)
BEGIN
    -- Both a correctly named constraint and a stray one exist. Renaming would
    -- collide, and guessing which to drop is not this migration's call.
    THROW 50021,
        'Both FK_Koersel_KoerselsgodtgoerelseModtager and an unnamed Koersel -> Part foreign key exist — resolve by hand.',
        1;
END
ELSE
BEGIN
    DECLARE @from nvarchar(400) = N'befordring.' + @old;

    EXEC sp_rename
        @objname = @from,
        @newname = N'FK_Koersel_KoerselsgodtgoerelseModtager',
        @objtype = 'OBJECT';

    PRINT CONCAT('Renamed ', @old, ' to FK_Koersel_KoerselsgodtgoerelseModtager.');
END
GO

-- -----------------------------------------------------------------------
-- 3. Verify
-- -----------------------------------------------------------------------

-- 3a. Every Elev foreign key: is_not_trusted and is_disabled must both be 0.
SELECT
    fk.name           AS foreign_key,
    fk.is_not_trusted,
    fk.is_disabled
FROM
    sys.foreign_keys fk
WHERE
    fk.parent_object_id = OBJECT_ID(N'[befordring].[Elev]')
ORDER BY
    fk.name;

-- 3b. The Koersel -> Part foreign key, by name.
SELECT
    fk.name           AS foreign_key,
    fk.is_not_trusted,
    fk.is_disabled
FROM
    sys.foreign_keys fk
WHERE
    fk.parent_object_id     = OBJECT_ID(N'[befordring].[Koersel]')
    AND fk.referenced_object_id = OBJECT_ID(N'[befordring].[Part]');
GO
