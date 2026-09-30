-- Migration 023: Add SagsaktivitetType lookup table with FK from Sagsaktivitet
-- Run once against the target database (test / prod).
-- Safe to re-run — every step is guarded, so nothing is created or inserted twice.
--
-- Context:
--   Sagsaktivitet.aktivitetstype held free text — "Bevilling oprettet",
--   "Status sat til Aktiv", "PPR Revurderet". The Sagsforløb feed styled and
--   grouped entries by matching those strings, so renaming one in Danish
--   silently changed how the feed behaved, and a typo produced an entry that
--   fell through every branch.
--
--   This introduces a canonical set of type codes:
--     - SagsaktivitetType holds the codes, one row each, UNIQUE on type_kode
--     - Sagsaktivitet.aktivitetstype_id is a NULLABLE FK to it
--     - existing rows are back-filled from the text they already carry
--     - aktivitetstype is KEPT, for display and for rows predating this
--
--   Nullable on purpose: a row whose text matches no known code keeps NULL,
--   and the frontend falls back to the string. That is what makes this
--   deployable without a flag day.
--
-- After running this migration, also run:
--   024_add_koerselsraekke_oprettet_type.sql
--   025_add_brev_afsendt_type.sql
-- then redeploy the backend (the models declare the table and the column).

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. The lookup table
-- -----------------------------------------------------------------------
IF OBJECT_ID(N'[befordring].[SagsaktivitetType]', 'U') IS NULL
BEGIN
    CREATE TABLE [befordring].[SagsaktivitetType] (
        type_id   INT           IDENTITY(1,1) NOT NULL,
        type_kode NVARCHAR(100) NOT NULL,
        CONSTRAINT PK_SagsaktivitetType PRIMARY KEY (type_id),
        CONSTRAINT UQ_SagsaktivitetType_kode UNIQUE (type_kode)
    );

    PRINT 'Created befordring.SagsaktivitetType.';
END
ELSE
BEGIN
    PRINT 'befordring.SagsaktivitetType already exists — nothing to do.';
END
GO

-- -----------------------------------------------------------------------
-- 2. The codes
--
--    Only the missing ones, so a re-run adds nothing and an id already
--    referenced by a Sagsaktivitet row is never reassigned.
-- -----------------------------------------------------------------------
INSERT INTO [befordring].[SagsaktivitetType] (type_kode)
SELECT v.type_kode
FROM (VALUES
    (N'bevilling_oprettet'),
    (N'bevilling_slettet'),
    (N'brev_oprettet'),
    (N'status_opdateret'),
    (N'sagsbehandler_opdateret'),
    (N'ppr_ansvarlig_opdateret'),
    (N'ppr_revurderet'),
    (N'ppr_revurderet_fjernet'),
    (N'br_revurderet'),
    (N'br_revurderet_fjernet'),
    (N'bevilling_ophoert'),
    (N'koerselsraekke_slettet'),
    (N'kommentar')
) AS v (type_kode)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[SagsaktivitetType] t
    WHERE t.type_kode = v.type_kode
);
PRINT CONCAT('SagsaktivitetType: ', @@ROWCOUNT, ' code(s) inserted.');
GO

-- -----------------------------------------------------------------------
-- 3. The column on Sagsaktivitet
--
--    Column and constraint are guarded separately: a database where the
--    column was added by hand but the foreign key was not still ends up
--    correct.
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Sagsaktivitet]')
    AND    name      = N'aktivitetstype_id'
)
BEGIN
    ALTER TABLE [befordring].[Sagsaktivitet] ADD aktivitetstype_id INT NULL;

    PRINT 'Added Sagsaktivitet.aktivitetstype_id.';
END
ELSE
BEGIN
    PRINT 'Sagsaktivitet.aktivitetstype_id already exists — nothing to do.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM   sys.foreign_keys
    WHERE  name = N'FK_Sagsaktivitet_Type'
    AND    parent_object_id = OBJECT_ID(N'[befordring].[Sagsaktivitet]')
)
BEGIN
    ALTER TABLE [befordring].[Sagsaktivitet]
        ADD CONSTRAINT FK_Sagsaktivitet_Type
        FOREIGN KEY (aktivitetstype_id)
        REFERENCES [befordring].[SagsaktivitetType] (type_id);

    PRINT 'Added FK_Sagsaktivitet_Type.';
END
ELSE
BEGIN
    PRINT 'FK_Sagsaktivitet_Type already exists — nothing to do.';
END
GO

-- -----------------------------------------------------------------------
-- 4. Back-fill from the text the rows already carry
--
--    Idempotent by its own WHERE: only rows still NULL are touched, so a
--    re-run after new rows have arrived fills those and leaves the rest.
--    A text matching no code stays NULL, by design — see the header.
-- -----------------------------------------------------------------------
UPDATE sa
SET    sa.aktivitetstype_id = t.type_id
FROM       [befordring].[Sagsaktivitet]     sa
INNER JOIN [befordring].[SagsaktivitetType] t ON t.type_kode = CASE
    WHEN sa.aktivitetstype = N'Bevilling oprettet'        THEN N'bevilling_oprettet'
    WHEN sa.aktivitetstype = N'Bevilling slettet'         THEN N'bevilling_slettet'
    WHEN sa.aktivitetstype = N'Brev oprettet'             THEN N'brev_oprettet'
    WHEN sa.aktivitetstype LIKE N'Status sat til %'       THEN N'status_opdateret'
    WHEN sa.aktivitetstype = N'Sagsbehandler opdateret'   THEN N'sagsbehandler_opdateret'
    WHEN sa.aktivitetstype = N'PPR ansvarlig opdateret'   THEN N'ppr_ansvarlig_opdateret'
    WHEN sa.aktivitetstype = N'PPR Revurderet'            THEN N'ppr_revurderet'
    WHEN sa.aktivitetstype = N'PPR revurderet fjernet'    THEN N'ppr_revurderet_fjernet'
    WHEN sa.aktivitetstype = N'BR Revurderet'             THEN N'br_revurderet'
    WHEN sa.aktivitetstype = N'BR revurderet fjernet'     THEN N'br_revurderet_fjernet'
    WHEN sa.aktivitetstype = N'Bevilling sat til Ophørt'  THEN N'bevilling_ophoert'
    WHEN sa.aktivitetstype = N'Kørselsrække slettet'      THEN N'koerselsraekke_slettet'
    WHEN sa.aktivitetstype = N'Kommentar'                 THEN N'kommentar'
    ELSE NULL
END
WHERE sa.aktivitetstype_id IS NULL;
PRINT CONCAT('Back-filled aktivitetstype_id on ', @@ROWCOUNT, ' row(s).');
GO

-- -----------------------------------------------------------------------
-- 5. Verify
--
--    The second result set is the one to read: any aktivitetstype still
--    without a code. Rows there are not an error, but a large or growing
--    number means a type is being written that nothing maps.
-- -----------------------------------------------------------------------
SELECT type_id, type_kode
FROM   [befordring].[SagsaktivitetType]
ORDER  BY type_kode;

SELECT   sa.aktivitetstype, COUNT(*) AS antal_uden_kode
FROM     [befordring].[Sagsaktivitet] sa
WHERE    sa.aktivitetstype_id IS NULL
GROUP BY sa.aktivitetstype
ORDER BY antal_uden_kode DESC;
GO
