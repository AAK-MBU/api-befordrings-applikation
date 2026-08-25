-- Migration 003: Add Rutetype lookup table + Koersel.rutetype_id FK
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guards make it idempotent.
--
-- Context:
--   Befordring is not always between home and school; a kørsel can be a
--   different route type (e.g. home<->klub). The Rutetype lookup table
--   captures that, and Koersel.rutetype_id references it (nullable).
--
--   This schema already exists in OUR database because it was applied
--   directly when the feature was built, but it was never recorded as a
--   migration. This file formalises it so a fresh database (or a database
--   coming from a branch that lacks Rutetype) matches the ORM model.
--
--   NOTE: this migration only creates the SCHEMA. The Rutetype reference
--   rows (e.g. 'Mellem hjem og skole', 'Mellem hjem og klub') are populated
--   by the seed script for test data; production reference data must be
--   inserted separately.
--
-- After running this migration, deploy the updated backend code.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Create the Rutetype table if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.tables t
    JOIN   sys.schemas s ON s.schema_id = t.schema_id
    WHERE  s.name = N'befordring'
    AND    t.name = N'Rutetype'
)
BEGIN
    CREATE TABLE [befordring].[Rutetype] (
        rutetype_id    INT            IDENTITY(1,1) NOT NULL,
        rutetype_tekst NVARCHAR(255)  NOT NULL,
        beskrivelse    NVARCHAR(1000) NULL,
        aktiv          BIT            NOT NULL
            CONSTRAINT DF_Rutetype_aktiv DEFAULT 1,
        CONSTRAINT PK_Rutetype PRIMARY KEY CLUSTERED (rutetype_id)
    );

    PRINT 'Table [befordring].[Rutetype] created.';
END
ELSE
BEGIN
    PRINT 'Table [befordring].[Rutetype] already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Add Koersel.rutetype_id column if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Koersel]')
    AND    name      = N'rutetype_id'
)
BEGIN
    ALTER TABLE [befordring].[Koersel]
        ADD rutetype_id INT NULL;

    PRINT 'Column rutetype_id added to [befordring].[Koersel].';
END
ELSE
BEGIN
    PRINT 'Column rutetype_id already exists on [befordring].[Koersel] — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 3. Add the foreign key Koersel.rutetype_id -> Rutetype.rutetype_id
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.foreign_keys
    WHERE  name = N'FK_Koersel_Rutetype'
    AND    parent_object_id = OBJECT_ID(N'[befordring].[Koersel]')
)
BEGIN
    ALTER TABLE [befordring].[Koersel]
        ADD CONSTRAINT FK_Koersel_Rutetype
            FOREIGN KEY (rutetype_id)
            REFERENCES [befordring].[Rutetype] (rutetype_id);

    PRINT 'FK_Koersel_Rutetype added.';
END
ELSE
BEGIN
    PRINT 'FK_Koersel_Rutetype already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 4. Verify
-- -----------------------------------------------------------------------
SELECT
    c.name          AS column_name,
    t.name          AS data_type,
    c.max_length,
    c.is_nullable
FROM
    sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE
    c.object_id = OBJECT_ID(N'[befordring].[Rutetype]')
ORDER BY
    c.column_id;

SELECT
    fk.name             AS foreign_key,
    OBJECT_NAME(fk.parent_object_id)      AS from_table,
    OBJECT_NAME(fk.referenced_object_id)  AS to_table
FROM
    sys.foreign_keys fk
WHERE
    fk.name = N'FK_Koersel_Rutetype';
GO
