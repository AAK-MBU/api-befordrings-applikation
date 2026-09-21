-- Migration 015: Add the Part table
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guards make it idempotent.
--
-- Context:
--   "Parter" are the other people on a case beyond the registered guardians:
--   a stepparent, a grandparent, a contact person at an institution. They are
--   entered by hand rather than arriving from the nightly CPR sync, which is
--   why the table has oprettet_af / oprettet_tidspunkt and its own aktiv flag.
--
--   The table exists in dev but was never captured as a migration, so a
--   database built from this folder alone would not have it — and prod does
--   not. This backfills that gap; it creates exactly the shape dev already
--   has, so it is a no-op there.
--
--   A part can also be the recipient of kørselsgodtgørelse — see
--   Koersel.koerselsgodtgoerelse_modtager_id (migration 006) and
--   view_Koerselsgodtgoerelse_Modtagere.
--
-- After running this migration, deploy the updated backend code.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Create the table if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.tables t
    JOIN   sys.schemas s ON s.schema_id = t.schema_id
    WHERE  s.name = N'befordring'
    AND    t.name = N'Part'
)
BEGIN
    CREATE TABLE [befordring].[Part](
        [part_id]            INT IDENTITY(1,1) NOT NULL,

        -- The child the part is attached to. Parter are per-case, not global.
        [cpr_elev]           VARCHAR(10)   NOT NULL,

        [fulde_navn]         NVARCHAR(200) NULL,

        -- Nullable: a part is not always a person with a CPR (an institution
        -- contact, say), and the caseworker may not have it to hand.
        [cpr_nummer]         VARCHAR(10)   NULL,

        [relation]           NVARCHAR(50)  NULL,
        [telefonnummer]      VARCHAR(20)   NULL,

        [oprettet_tidspunkt] DATETIME2(7)  NOT NULL
            CONSTRAINT [DF_Part_oprettet] DEFAULT (SYSDATETIME()),
        [oprettet_af]        NVARCHAR(100) NULL,

        -- Soft delete, same pattern as Bevilling and Koersel.
        [aktiv]              BIT           NOT NULL
            CONSTRAINT [DF_Part_aktiv] DEFAULT (1),

        [adresse_id]         NVARCHAR(36)  NULL,

        CONSTRAINT [PK_Part] PRIMARY KEY CLUSTERED ([part_id] ASC)
    );

    PRINT 'Table [befordring].[Part] created.';
END
ELSE
BEGIN
    PRINT 'Table [befordring].[Part] already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Foreign keys, guarded separately so a half-applied run can be repaired
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_Part_Adresse'
    AND   parent_object_id = OBJECT_ID(N'[befordring].[Part]')
)
BEGIN
    ALTER TABLE [befordring].[Part] WITH CHECK
        ADD CONSTRAINT [FK_Part_Adresse] FOREIGN KEY ([adresse_id])
        REFERENCES [befordring].[Adresse] ([adresse_id]);

    PRINT 'FK_Part_Adresse added.';
END
ELSE
BEGIN
    PRINT 'FK_Part_Adresse already exists — skipped.';
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_Part_Elev'
    AND   parent_object_id = OBJECT_ID(N'[befordring].[Part]')
)
BEGIN
    ALTER TABLE [befordring].[Part] WITH CHECK
        ADD CONSTRAINT [FK_Part_Elev] FOREIGN KEY ([cpr_elev])
        REFERENCES [befordring].[Elev] ([cpr]);

    PRINT 'FK_Part_Elev added.';
END
ELSE
BEGIN
    PRINT 'FK_Part_Elev already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 3. Verify
-- -----------------------------------------------------------------------
SELECT
    c.name                AS column_name,
    t.name                AS data_type,
    c.max_length,
    c.is_nullable,
    dc.definition         AS default_value
FROM
    sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
    LEFT JOIN sys.default_constraints dc ON dc.parent_object_id = c.object_id
                                        AND dc.parent_column_id = c.column_id
WHERE
    c.object_id = OBJECT_ID(N'[befordring].[Part]')
ORDER BY
    c.column_id;

SELECT
    fk.name               AS foreign_key,
    fk.is_disabled,
    fk.is_not_trusted
FROM
    sys.foreign_keys fk
WHERE
    fk.parent_object_id = OBJECT_ID(N'[befordring].[Part]');
GO
