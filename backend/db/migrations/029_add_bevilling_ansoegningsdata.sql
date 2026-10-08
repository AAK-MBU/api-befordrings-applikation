-- Migration 029: Add ansoegningsdata to Bevilling
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guard makes it idempotent.
--
-- Context:
--   An OS2Forms submission states which kørselstype(r) the family asked for
--   and, for two of the three, whether they need morning, afternoon or both.
--   None of it survives: os2forms_service maps a handful of fields onto the
--   bevilling and the rest of the payload is discarded when the request ends.
--
--   So a caseworker opening "+ Ny kørselsrække" on a fresh application gets an
--   empty form, and retypes what the citizen already told us. This column
--   keeps the answer so the form can be prefilled.
--
-- Why one JSON column and not several typed ones:
--
--   The citizen may tick MORE THAN ONE kørselstype — skolerejsekort,
--   egen befordring and rutekørsel are independent checkboxes — and two of
--   them carry their own morning/afternoon pair. The value is therefore a
--   LIST of (type, tidspunkt), which columns cannot hold without a side table
--   for something only ever read as a whole.
--
--   It also means a new field costs a change to the writer and the reader and
--   no migration at all, which matters because these forms have changed shape
--   before — see the mitid/manuelt pairs in app/utils/os2forms_mapping.py.
--
-- Why a CURATED subset and not the raw form_data:
--
--   The submission carries the child's CPR, address, health grounds
--   (sygdom/funktionsnedsættelse/handicap), hjælpemidler such as Krampeplan,
--   free-text justification and attachments. Storing it whole would put a
--   second copy of a child's health record in a database whose retention
--   story was written for case administration. The original already lives in
--   [RPA].[journalizing] and in GO.
--
--   The second reason is dull but just as real: normalise on write, because
--   the writer knows which version of the form it is looking at and a reader
--   three years later does not.
--
-- Shape (see app/utils/os2forms_mapping.py for the writer):
--
--   {
--     "koerselstyper": [
--       {"befordringstype": "Skolerejsekort",  "tidspunkt": null},
--       {"befordringstype": "Egen befordring", "tidspunkt": "Morgen og eftermiddag"}
--     ],
--     "formular": "ny_ansoegning_om_koersel_af_skol",
--     "version": 1
--   }
--
--   tidspunkt is null where the form does not ask — the skolerejsekort
--   checkbox has no morning/afternoon pair. Null must stay null rather than
--   defaulting to anything, so the caseworker chooses instead of accepting a
--   value nobody stated.
--
--   NULL on the column itself means "no submission data" — every bevilling
--   created by hand, and every one created before this migration.

USE [Befordringssystemet];
GO

-- -----------------------------------------------------------------------
-- 1. Column
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND   name      = N'ansoegningsdata'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
    ADD [ansoegningsdata] NVARCHAR(MAX) NULL;

    PRINT 'Added Bevilling.ansoegningsdata.';
END
ELSE
BEGIN
    PRINT 'Bevilling.ansoegningsdata already exists — nothing to do.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Verify
-- -----------------------------------------------------------------------
SELECT c.name       AS kolonne,
       t.name       AS datatype,
       c.max_length AS max_length_bytes,
       c.is_nullable
FROM   sys.columns c
JOIN   sys.types   t ON t.user_type_id = c.user_type_id
WHERE  c.object_id = OBJECT_ID(N'[befordring].[Bevilling]')
AND    c.name = N'ansoegningsdata';
