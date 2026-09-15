-- Migration 014: Add Brev table
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guards make it idempotent.
--
-- Context:
--   Creating a decision letter queues an ATS work item and returns a
--   reference, but nothing was persisted: the reference was handed to the
--   browser and dropped, and the only trace was a free-text "Brev oprettet"
--   row in Sagsaktivitet written by the frontend.
--
--   That left nothing to mark as sent. Generating a letter is not the same as
--   posting it to the parents, and caseworkers need a worklist of letters that
--   exist but have not gone out — the new "Forsendelse" page.
--
--   One row per letter created. A bevilling legitimately has several over
--   time (påtænkt afslag, then the final afslag; or a bevilling followed by an
--   ophør letter), which is why this is its own table rather than a pair of
--   columns on Bevilling.
--
--   afgoerelsesbrev_tekst is a SNAPSHOT, deliberately not a foreign key: the
--   letter said what it said. If the bevilling's afgørelsesbrev is changed
--   afterwards, Forsendelse must still show what actually went out.
--
--   reference is the ATS work-item reference. Nothing reads it yet; it is
--   stored so the page can later show whether the RPA actually produced the
--   document, without needing another migration.
--
-- No backfill: the application is not live, so the table starts empty and
-- letters created from here on are tracked.
--
-- After running this migration, deploy the updated backend and frontend.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Create the table if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.tables
    WHERE  object_id = OBJECT_ID(N'[befordring].[Brev]')
)
BEGIN
    CREATE TABLE [befordring].[Brev] (
        brev_id                 INT IDENTITY(1,1) NOT NULL,

        bevilling_id            INT           NOT NULL,
        cpr_elev                VARCHAR(10)   NOT NULL,

        -- ATS work-item reference, e.g. "0101101234_2026-09-15_14_30_05".
        reference               NVARCHAR(100) NULL,

        -- Snapshots taken at creation time — see the note above.
        afgoerelsesbrev_tekst   NVARCHAR(500) NULL,
        brev_i_forbindelse_med  NVARCHAR(100) NULL,

        oprettet_tidspunkt      DATETIME2(7)  NOT NULL
            CONSTRAINT DF_Brev_oprettet_tidspunkt DEFAULT sysdatetime(),
        oprettet_af             NVARCHAR(200) NULL,

        afsendt                 BIT           NOT NULL
            CONSTRAINT DF_Brev_afsendt DEFAULT 0,
        afsendt_tidspunkt       DATETIME2(7)  NULL,
        afsendt_af              NVARCHAR(200) NULL,

        -- Soft delete, matching the rest of the schema.
        aktiv                   BIT           NOT NULL
            CONSTRAINT DF_Brev_aktiv DEFAULT 1,

        CONSTRAINT PK_Brev PRIMARY KEY (brev_id),

        CONSTRAINT FK_Brev_Bevilling FOREIGN KEY (bevilling_id)
            REFERENCES [befordring].[Bevilling] (bevilling_id)
    );

    PRINT 'Table [befordring].[Brev] created.';
END
ELSE
BEGIN
    PRINT 'Table [befordring].[Brev] already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Index for the Forsendelse worklist
--
--    The page asks one question — "which letters are not sent yet?" — so the
--    index is filtered on exactly that, keeping it small however many letters
--    accumulate over the years.
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE  object_id = OBJECT_ID(N'[befordring].[Brev]')
    AND    name      = N'IX_Brev_ikke_afsendt'
)
BEGIN
    CREATE INDEX IX_Brev_ikke_afsendt
        ON [befordring].[Brev] (oprettet_tidspunkt DESC)
        INCLUDE (bevilling_id, cpr_elev, afgoerelsesbrev_tekst, brev_i_forbindelse_med, oprettet_af)
        WHERE afsendt = 0 AND aktiv = 1;

    PRINT 'Index IX_Brev_ikke_afsendt created.';
END
ELSE
BEGIN
    PRINT 'Index IX_Brev_ikke_afsendt already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 3. Verify
-- -----------------------------------------------------------------------

-- 3a. Columns.
SELECT c.name AS column_name, t.name AS data_type, c.is_nullable
FROM       sys.columns AS c
JOIN       sys.types   AS t ON t.user_type_id = c.user_type_id
WHERE      c.object_id = OBJECT_ID(N'[befordring].[Brev]')
ORDER BY   c.column_id;

-- 3b. A sent letter must always carry who and when. Should return 0 rows.
SELECT brev_id, afsendt, afsendt_tidspunkt, afsendt_af
FROM   [befordring].[Brev]
WHERE  afsendt = 1
AND   (afsendt_tidspunkt IS NULL OR afsendt_af IS NULL);
GO
