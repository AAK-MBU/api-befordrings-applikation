/* ============================================================
   Reset the application's own data, ready for a clean re-seed.

   Run this, then seed_lookup_data.sql.

   The two are separate on purpose: seed_lookup_data.sql holds the 136 lookup
   rows and is the single place they are written down. Copying them into a
   second script so it could clear and insert in one pass would give two
   copies to keep in step, and they would drift the first time a kørselstype
   is added.

   WHAT IS CLEARED

     the application's own data   Bevilling, Koersel, Part, Brev,
                                  Sagsaktivitet, PortalAuditLog and the
                                  link tables
     lookup / reference data      Status, Hjemmel, Afgoerelsesbrev,
                                  Befordringstype, Tidspunkt, Rutetype,
                                  Ugedag, Hjaelpemiddel, KoerselstypeTillaeg,
                                  Skolematrikel, Ungdomsuddannelse

   WHAT IS KEPT

     Elev, Foraelder, Adresse     maintained by the nightly imports. Rebuilding
                                  them means a full LOIS run, and they are not
                                  what a reset is usually about.

     Sagsbehandler,               real people, not reference data. Not seeded
     PPR_Sagsbehandler            by seed_lookup_data.sql either, so clearing
                                  them here would leave no way to get them
                                  back.

     *_STG                        transient landing zones owned by the nightly
                                  jobs; whatever is in them belongs to a run
                                  that is either finished or in flight.

   ONE CONSEQUENCE WORTH KNOWING

   Elev.matrikel_id and Elev.ungdomsuddannelse_id are foreign keys into two
   tables this clears, so they are set to NULL first. That is the correct
   state afterwards rather than a loss: both are derived from the student's
   bevillinger (see usp_sync_elev_matrikel_from_bevilling), the bevillinger
   are being cleared too, and the identity values would not survive a re-seed
   anyway — an id kept across the reset would point at a different school.

   The next nightly run repopulates them from whatever bevillinger exist by
   then. Elev.skolekode is left alone: it comes from the data worker, not from
   here.

   Identity columns are NOT reseeded. DBCC CHECKIDENT is not transactional, so
   a reseed followed by the ROLLBACK below would leave the counter at 0 while
   the rows came back — and the next insert would collide. seed_lookup_data.sql
   matches on natural keys and never depends on a particular id, so tidy
   numbering buys nothing.

   Runs inside a transaction that ROLLBACKs by default — change the final
   ROLLBACK to COMMIT once the previewed counts look correct.
   ============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;

-- Any error aborts the batch and rolls back, so a failure part-way cannot
-- leave the database half-cleared.
SET XACT_ABORT ON;

BEGIN TRANSACTION;


PRINT 'Rows before reset:';

SELECT 'Bevilling'         AS tabel, COUNT(*) AS antal_rows FROM [befordring].[Bevilling]
UNION ALL SELECT 'Koersel',          COUNT(*) FROM [befordring].[Koersel]
UNION ALL SELECT 'Part',             COUNT(*) FROM [befordring].[Part]
UNION ALL SELECT 'Sagsaktivitet',    COUNT(*) FROM [befordring].[Sagsaktivitet]
UNION ALL SELECT 'Status',           COUNT(*) FROM [befordring].[Status]
UNION ALL SELECT 'Skolematrikel',    COUNT(*) FROM [befordring].[Skolematrikel]
UNION ALL SELECT '-- kept: Elev',    COUNT(*) FROM [befordring].[Elev]
UNION ALL SELECT '-- kept: Foraelder', COUNT(*) FROM [befordring].[Foraelder]
UNION ALL SELECT '-- kept: Adresse', COUNT(*) FROM [befordring].[Adresse]
ORDER BY tabel;


/* ------------------------------------------------------------
   1. The application's own data, innermost references first
------------------------------------------------------------ */

DELETE FROM [befordring].[Koersel_KoerselstypeTillaeg_LINK];
DELETE FROM [befordring].[Koersel_Ugedag_LINK];
DELETE FROM [befordring].[Bevilling_Hjaelpemiddel_LINK];

-- Brev arrives in migration 014; guarded so this still runs on a database
-- where that has not been applied.
IF OBJECT_ID('[befordring].[Brev]', 'U') IS NOT NULL
    DELETE FROM [befordring].[Brev];

-- Koersel before Bevilling (FK_koersel_bevilling), and before Part
-- (FK_Koersel_KoerselsgodtgoerelseModtager).
DELETE FROM [befordring].[Koersel];
DELETE FROM [befordring].[Bevilling];
DELETE FROM [befordring].[Part];

DELETE FROM [befordring].[Sagsaktivitet];
DELETE FROM [befordring].[PortalAuditLog];

PRINT 'Cleared application data.';


/* ------------------------------------------------------------
   2. Release Elev's references into the lookups about to be cleared

   FK_Elev_Skolematrikel and FK_Elev_Ungdomsuddannelse would otherwise block
   the deletes below. See the header for why NULL is the right value here
   rather than something to be preserved.
------------------------------------------------------------ */

UPDATE [befordring].[Elev]
SET    matrikel_id          = NULL,
       ungdomsuddannelse_id = NULL
WHERE  matrikel_id IS NOT NULL
OR     ungdomsuddannelse_id IS NOT NULL;

PRINT CONCAT('Released school references on ', @@ROWCOUNT, ' elev(er).');


/* ------------------------------------------------------------
   3. Lookup / reference data
------------------------------------------------------------ */

DELETE FROM [befordring].[Afgoerelsesbrev];
DELETE FROM [befordring].[Befordringstype];
DELETE FROM [befordring].[Hjaelpemiddel];
DELETE FROM [befordring].[Hjemmel];
DELETE FROM [befordring].[KoerselstypeTillaeg];
DELETE FROM [befordring].[Rutetype];
DELETE FROM [befordring].[Skolematrikel];
DELETE FROM [befordring].[Status];
DELETE FROM [befordring].[Tidspunkt];
DELETE FROM [befordring].[Ugedag];
DELETE FROM [befordring].[Ungdomsuddannelse];

PRINT 'Cleared lookup data.';


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
              + CASE WHEN t.name IN (N'Bevilling', N'Koersel', N'Brev', N'Part',
                                    N'Sagsaktivitet', N'PortalAuditLog',
                                    N'Bevilling_Hjaelpemiddel_LINK',
                                    N'Koersel_Ugedag_LINK',
                                    N'Koersel_KoerselstypeTillaeg_LINK',
                                    N'Afgoerelsesbrev', N'Befordringstype',
                                    N'Hjaelpemiddel', N'Hjemmel',
                                    N'KoerselstypeTillaeg', N'Rutetype',
                                    N'Skolematrikel', N'Status',
                                    N'Tidspunkt', N'Ugedag',
                                    N'Ungdomsuddannelse')
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
PRINT 'ROLLBACK is active. Change to COMMIT when the counts look correct,';
PRINT 'then run seed_lookup_data.sql to put the lookup data back.';
PRINT '';

ROLLBACK TRANSACTION;
