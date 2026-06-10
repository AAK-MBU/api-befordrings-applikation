-- =============================================================================
-- Migration: change Adresse.adresse_id from INT (SAS address key) to
--            NVARCHAR(36) (LOIS AdresseId / DAR GUID), and update the
--            dependent FK columns on Elev, Foraelder and Bevilling.
--
-- Context:
--   The RPA conversion bot now resolves the student's address via
--   LOIS.CPR.PersonGeoView -> LOIS.DAR.AdresseGeoView. AdresseId there is a
--   uniqueidentifier (e.g. "0A3F50C2-633E-32B8-E044-0003BA298018"), not the
--   integer SAS address key the Adresse table previously used.
--
-- ⚠️  DESTRUCTIVE: this clears all rows from the address-dependent tables
--     (Koersel, Bevilling, Foraelder, Elev, Adresse and their link tables).
--     Any existing INT-based adresse_id values cannot be mapped to GUIDs,
--     so dependent rows are removed rather than migrated. This is intended
--     for the current test/dev environment — do NOT run against a database
--     containing data that must be preserved without first exporting it.
--
-- Run manually (no migration framework is configured for this project).
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @sql NVARCHAR(MAX);

-- ---------------------------------------------------------------------------
-- 1. Drop FK constraints that reference Adresse.adresse_id, Bevilling, Elev
--    (so we can clear data and alter column types freely).
-- ---------------------------------------------------------------------------
SELECT @sql = STRING_AGG(
    'ALTER TABLE [' + s.name + '].[' + t.name + '] DROP CONSTRAINT [' + fk.name + '];',
    CHAR(10)
)
FROM sys.foreign_keys AS fk
JOIN sys.tables AS t ON t.object_id = fk.parent_object_id
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE fk.referenced_object_id IN (
    OBJECT_ID('befordring.Adresse'),
    OBJECT_ID('befordring.Elev'),
    OBJECT_ID('befordring.Bevilling')
);

IF @sql IS NOT NULL EXEC sp_executesql @sql;

-- ---------------------------------------------------------------------------
-- 2. Clear address-dependent tables (see destructive warning above).
--    Order respects remaining FK dependencies.
-- ---------------------------------------------------------------------------
DELETE FROM [befordring].[Koersel_KoerselstypeTillaeg_LINK];
DELETE FROM [befordring].[Koersel_Ugedag_LINK];
DELETE FROM [befordring].[Koersel];
DELETE FROM [befordring].[Bevilling_Hjaelpemiddel_LINK];
DELETE FROM [befordring].[Bevilling];
DELETE FROM [befordring].[Foraelder];
DELETE FROM [befordring].[Elev];
DELETE FROM [befordring].[Adresse];

-- ---------------------------------------------------------------------------
-- 3. Drop the PK on Adresse so the column type can change.
-- ---------------------------------------------------------------------------
SELECT @sql = 'ALTER TABLE [befordring].[Adresse] DROP CONSTRAINT [' + kc.name + '];'
FROM sys.key_constraints AS kc
WHERE kc.parent_object_id = OBJECT_ID('befordring.Adresse')
  AND kc.type = 'PK';

IF @sql IS NOT NULL EXEC sp_executesql @sql;

-- ---------------------------------------------------------------------------
-- 4. Alter column types: INT -> NVARCHAR(36).
-- ---------------------------------------------------------------------------
ALTER TABLE [befordring].[Adresse]   ALTER COLUMN [adresse_id] NVARCHAR(36) NOT NULL;
ALTER TABLE [befordring].[Elev]      ALTER COLUMN [adresse_id] NVARCHAR(36) NOT NULL;
ALTER TABLE [befordring].[Foraelder] ALTER COLUMN [adresse_id] NVARCHAR(36) NOT NULL;
ALTER TABLE [befordring].[Bevilling] ALTER COLUMN [adresse_id] NVARCHAR(36) NOT NULL;

-- ---------------------------------------------------------------------------
-- 5. Recreate the PK and FK constraints.
-- ---------------------------------------------------------------------------
ALTER TABLE [befordring].[Adresse]
    ADD CONSTRAINT [PK_Adresse] PRIMARY KEY ([adresse_id]);

ALTER TABLE [befordring].[Elev]
    ADD CONSTRAINT [FK_Elev_Adresse] FOREIGN KEY ([adresse_id])
    REFERENCES [befordring].[Adresse] ([adresse_id]);

ALTER TABLE [befordring].[Foraelder]
    ADD CONSTRAINT [FK_Foraelder_Adresse] FOREIGN KEY ([adresse_id])
    REFERENCES [befordring].[Adresse] ([adresse_id]);

ALTER TABLE [befordring].[Bevilling]
    ADD CONSTRAINT [FK_Bevilling_Adresse] FOREIGN KEY ([adresse_id])
    REFERENCES [befordring].[Adresse] ([adresse_id]);

-- ---------------------------------------------------------------------------
-- 6. Recreate the FK constraints dropped in step 1 that referenced
--    Elev/Bevilling but were NOT adresse_id-related. These columns/types are
--    unaffected by the adresse_id change, so simply recreate them as-is,
--    matching the original constraint names exactly.
-- ---------------------------------------------------------------------------
ALTER TABLE [befordring].[Bevilling]
    ADD CONSTRAINT [FK_bevilling_elev_cpr] FOREIGN KEY ([cpr_elev])
    REFERENCES [befordring].[Elev] ([cpr]);

ALTER TABLE [befordring].[Foraelder]
    ADD CONSTRAINT [FK_Foraelder_Elev] FOREIGN KEY ([cpr_elev])
    REFERENCES [befordring].[Elev] ([cpr]);

ALTER TABLE [befordring].[Koersel]
    ADD CONSTRAINT [FK_koersel_bevilling] FOREIGN KEY ([bevilling_id])
    REFERENCES [befordring].[Bevilling] ([bevilling_id]);

ALTER TABLE [befordring].[Bevilling_Hjaelpemiddel_LINK]
    ADD CONSTRAINT [FK_Bevilling_Hjaelpemiddel_LINK_Koersel] FOREIGN KEY ([bevilling_id])
    REFERENCES [befordring].[Bevilling] ([bevilling_id]);

COMMIT TRANSACTION;
