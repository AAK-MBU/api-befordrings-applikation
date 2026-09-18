-- Migration 020: Align Rutetype column types with migration 003
-- Run once against the target database (test / prod).
-- Safe to re-run — the guard checks the current type, so a second run is a
-- no-op.
--
-- Context:
--   Migration 003 creates Rutetype with NVARCHAR(255) / NVARCHAR(1000). Any
--   database built from the migration folder therefore has that shape, and
--   prod does.
--
--   Dev does not: its Rutetype was created by hand before 003 existed, using
--   the unbounded VARCHAR(MAX) that the older lookup tables use. That makes
--   dev the odd one out, and it is the wrong shape twice over:
--
--     * VARCHAR cannot store characters outside the database collation's
--       codepage. These are user-facing labels ("Skole til hjem", "Klub til
--       skole"), so æ/ø/å in a future rutetype would be mangled.
--     * VARCHAR(MAX) is stored off-row and cannot be indexed, for a column
--       that holds at most a few dozen characters.
--
--   This brings any remaining database up to the 003 shape. It is a no-op on
--   prod and on anything created from the migrations.
--
-- After running this migration, deploy the updated backend code (the model
-- declares Unicode(255) / Unicode(1000) to match).

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Safety check — refuse to truncate
--
--    Narrowing a column silently truncates nothing (SQL Server errors
--    instead), but failing here with a clear message beats failing on the
--    ALTER with "String or binary data would be truncated".
-- -----------------------------------------------------------------------
IF EXISTS (
    SELECT 1 FROM [befordring].[Rutetype]
    WHERE  LEN(rutetype_tekst) > 255
    OR     LEN(ISNULL(beskrivelse, '')) > 1000
)
BEGIN
    THROW 50020,
        'Rutetype holds a value longer than the target length — resolve it before running this migration.',
        1;
END
GO

-- -----------------------------------------------------------------------
-- 2. rutetype_tekst -> NVARCHAR(255) NOT NULL
--
--    Guarded on the current type rather than blindly altering: an ALTER
--    COLUMN rewrites the whole definition, so running it against a column
--    that is already correct is wasted work on a table other rows reference.
-- -----------------------------------------------------------------------
IF EXISTS (
    SELECT 1
    FROM   sys.columns c
    JOIN   sys.types   t ON t.user_type_id = c.user_type_id
    WHERE  c.object_id = OBJECT_ID(N'[befordring].[Rutetype]')
    AND    c.name      = N'rutetype_tekst'
    AND    (t.name <> N'nvarchar' OR c.max_length <> 510)   -- 255 * 2 bytes
)
BEGIN
    ALTER TABLE [befordring].[Rutetype]
        ALTER COLUMN rutetype_tekst NVARCHAR(255) NOT NULL;

    PRINT 'Rutetype.rutetype_tekst altered to NVARCHAR(255) NOT NULL.';
END
ELSE
BEGIN
    PRINT 'Rutetype.rutetype_tekst is already NVARCHAR(255) — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 3. beskrivelse -> NVARCHAR(1000) NULL
-- -----------------------------------------------------------------------
IF EXISTS (
    SELECT 1
    FROM   sys.columns c
    JOIN   sys.types   t ON t.user_type_id = c.user_type_id
    WHERE  c.object_id = OBJECT_ID(N'[befordring].[Rutetype]')
    AND    c.name      = N'beskrivelse'
    AND    (t.name <> N'nvarchar' OR c.max_length <> 2000)  -- 1000 * 2 bytes
)
BEGIN
    ALTER TABLE [befordring].[Rutetype]
        ALTER COLUMN beskrivelse NVARCHAR(1000) NULL;

    PRINT 'Rutetype.beskrivelse altered to NVARCHAR(1000) NULL.';
END
ELSE
BEGIN
    PRINT 'Rutetype.beskrivelse is already NVARCHAR(1000) — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 4. Verify — expect nvarchar, max_length 510 and 2000
-- -----------------------------------------------------------------------
SELECT
    c.name        AS column_name,
    t.name        AS data_type,
    c.max_length,
    c.is_nullable
FROM
    sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE
    c.object_id = OBJECT_ID(N'[befordring].[Rutetype]')
    AND c.name IN (N'rutetype_tekst', N'beskrivelse')
ORDER BY
    c.name;
GO
