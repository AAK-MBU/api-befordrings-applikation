/* ============================================================
   Clear every bevilling, leaving the platform ready to convert into.

   Narrower than reset_lookup_data.sql: that one also wipes the lookup tables
   and needs seed_lookup_data.sql run afterwards. This one touches only the
   bevilling side, so the database stays immediately usable — nothing has to
   be re-seeded when it finishes.

   Use it to re-run a conversion from scratch.

   WHAT IS CLEARED

     Bevilling                    and everything that hangs off it:
     Koersel                        FK_koersel_bevilling
     Brev                           FK_Brev_Bevilling
     Bevilling_Hjaelpemiddel_LINK   FK_Bevilling_Hjaelpemiddel_LINK_Koersel
     Koersel_Ugedag_LINK          } via Koersel
     Koersel_KoerselstypeTillaeg_LINK

     Sagsaktivitet rows that       Sagsaktivitet.relateret_bevilling_id is a
     reference a bevilling         plain nullable int, NOT a foreign key, so
                                   nothing stops these outliving the bevilling
                                   they point at. A "Brev oprettet" entry
                                   citing bevilling 42 after 42 is gone is
                                   noise in the sagsforløb and breaks the
                                   bevilling filter on that page. Comments not
                                   tied to a bevilling are left alone.

   WHAT IS KEPT

     Elev, Foraelder, Adresse     maintained by the nightly imports.
     Part                         parties belong to the case, not to a
                                  bevilling — clearing them would throw away
                                  hand-entered data a conversion cannot
                                  recreate.
     all lookup data              untouched, so no re-seed is needed.
     Sagsbehandler,               real people.
     PPR_Sagsbehandler
     *_STG                        owned by the nightly jobs.

   ONE CONSEQUENCE WORTH KNOWING

   Elev.matrikel_id and Elev.ungdomsuddannelse_id are derived from the
   student's bevillinger by usp_sync_elev_matrikel_from_bevilling, so once the
   bevillinger are gone they describe a school nothing supports any more. They
   are set to NULL here rather than left to go stale — which is exactly what
   that procedure would do on the next nightly run, since it clears both when
   no bevilling qualifies.

   Elev.skoleafstand is left as it is. It is a measured distance, not a
   reference, and the next walking-distance run recomputes it once the
   converted bevillinger give the student a school again.

   Elev.skolekode is left alone too: it comes from the data worker, not from
   anything cleared here.

   Runs inside a transaction that ROLLBACKs by default — change the final
   ROLLBACK to COMMIT once the previewed counts look correct.
   ============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;

-- Any error aborts the batch and rolls back, so a failure part-way cannot
-- leave bevillinger half-deleted with their kørselsrækker already gone.
SET XACT_ABORT ON;

BEGIN TRANSACTION;


PRINT 'Rows before:';

SELECT 'Bevilling'      AS tabel, COUNT(*) AS antal_rows FROM [befordring].[Bevilling]
UNION ALL SELECT 'Koersel',       COUNT(*) FROM [befordring].[Koersel]
UNION ALL SELECT 'Sagsaktivitet (bevilling-related)', COUNT(*)
          FROM [befordring].[Sagsaktivitet] WHERE relateret_bevilling_id IS NOT NULL
UNION ALL SELECT '-- kept: Elev', COUNT(*) FROM [befordring].[Elev]
UNION ALL SELECT '-- kept: Part', COUNT(*) FROM [befordring].[Part]
ORDER BY tabel;


/* ------------------------------------------------------------
   1. Innermost references first
------------------------------------------------------------ */

DELETE FROM [befordring].[Koersel_KoerselstypeTillaeg_LINK];
DELETE FROM [befordring].[Koersel_Ugedag_LINK];
DELETE FROM [befordring].[Bevilling_Hjaelpemiddel_LINK];

-- Brev arrives in migration 014; guarded so this still runs on a database
-- where that has not been applied.
IF OBJECT_ID('[befordring].[Brev]', 'U') IS NOT NULL
    DELETE FROM [befordring].[Brev];

DELETE FROM [befordring].[Koersel];

PRINT 'Cleared kørselsrækker, breve and link rows.';


/* ------------------------------------------------------------
   2. Activity tied to a bevilling

   Before the bevillinger themselves, so the rows can still be identified by
   the reference they carry.
------------------------------------------------------------ */

DELETE FROM [befordring].[Sagsaktivitet]
WHERE  relateret_bevilling_id IS NOT NULL;

PRINT CONCAT('Cleared ', @@ROWCOUNT, ' bevilling-related sagsaktivitet row(s).');


/* ------------------------------------------------------------
   3. The bevillinger
------------------------------------------------------------ */

DELETE FROM [befordring].[Bevilling];

PRINT CONCAT('Cleared ', @@ROWCOUNT, ' bevilling(er).');


/* ------------------------------------------------------------
   4. Release the school each student inherited from a bevilling

   See the header: these are derived, and the derivation no longer has
   anything to derive from.
------------------------------------------------------------ */

UPDATE [befordring].[Elev]
SET    matrikel_id          = NULL,
       ungdomsuddannelse_id = NULL
WHERE  matrikel_id IS NOT NULL
OR     ungdomsuddannelse_id IS NOT NULL;

PRINT CONCAT('Released derived school on ', @@ROWCOUNT, ' elev(er).');


/* ============================================================
   Verify — every table in the schema, with its row count

   Built dynamically from sys.tables so a table added later shows up without
   anyone remembering to add it here, and COUNT(*) rather than the row counts
   in sys.partitions: this runs inside the open transaction, and those cached
   counts are approximate and would not reliably show uncommitted deletes.

   CHAR(39) is a single quote. Building the literals that way avoids nesting
   four quote characters deep, which is where this kind of dynamic SQL usually
   goes wrong.

   The note column marks what this script touches, so a 0 against a table it
   never touches reads as "was already empty" rather than "just cleared".
============================================================ */

DECLARE @count_sql NVARCHAR(MAX);

SELECT @count_sql = STRING_AGG(
    CAST(
        'SELECT ' + CHAR(39) + t.name + CHAR(39) + ' AS tabel'
        + ', COUNT(*) AS antal_rows'
        + ', ' + CHAR(39)
              + CASE WHEN t.name IN (N'Bevilling', N'Koersel', N'Brev',
                                    N'Bevilling_Hjaelpemiddel_LINK',
                                    N'Koersel_Ugedag_LINK',
                                    N'Koersel_KoerselstypeTillaeg_LINK',
                                    N'Sagsaktivitet')
                     THEN 'cleared here' ELSE '' END
              + CHAR(39) + ' AS note'
        + ' FROM [befordring].' + QUOTENAME(t.name)
        AS NVARCHAR(MAX)
    ),
    -- N'...' to match the nvarchar(max) expression above. A varchar separator
    -- against an nvarchar expression is Msg 8116.
    N' UNION ALL '
)
FROM      sys.tables  t
JOIN      sys.schemas s ON s.schema_id = t.schema_id
WHERE     s.name = N'befordring';

-- Assigned rather than passed as an expression: sp_executesql takes an
-- nvarchar variable or literal, not a concatenation.
SET @count_sql = @count_sql + N' ORDER BY tabel';

IF @count_sql IS NOT NULL
    EXEC sp_executesql @count_sql;


PRINT '';
PRINT 'ROLLBACK is active. Change to COMMIT when the counts look correct.';
PRINT 'No re-seed needed — lookup data is untouched.';
PRINT '';

ROLLBACK TRANSACTION;
