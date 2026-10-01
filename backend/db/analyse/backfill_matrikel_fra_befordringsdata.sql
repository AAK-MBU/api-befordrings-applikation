/* ============================================================
   Backfill Bevilling.matrikel_id fra BefordringsData

   Konverteringen slår skolen op på SkoleID alene. Hvor den kolonne er tom i
   kilden, er der ingen kandidater, og bevillingen blev oprettet HELT UDEN
   skole — uden fejl og uden kommentar, fordi matrikel_id er nullable.

   Rækkerne navngiver som regel skolen alligevel:

       SkolensAdresse       Janesvej 2
       SkoleNavnBefordring  Stensagerskolen afd. Janesvej

   Scriptet finder de bevillinger og foreslår den matrikel, rækkerne faktisk
   peger på. Det er den samme regel som _matrikler_andetsteds i
   rpa-befordring-konvertering-af-ppr-sager:

     * matriklens SKOLENAVN (det foran parentesen) skal optræde i
       SkoleNavnBefordring
     * har matriklen en AFDELING (teksten i parentesen), skal den optræde i
       SkolensAdresse eller SkoleNavnBefordring

   Begge halvdele er nødvendige. "Stensagervej" er afdeling på BÅDE
   Stensagerskolen og Vestergårdsskolen, så afdelingen alene er ikke nok; og
   "Stensagerskolen" uden afdeling passer på to matrikler, så navnet alene er
   heller ikke nok.

   KUN ENTYDIGE MATCH opdateres. Passer flere matrikler, eller passer sagens
   rækker på hver sin skole, bliver bevillingen stående uden skole og skal
   rettes i hånden — et gæt her ville sende eleven til den forkerte skole og
   måle gåafstanden derhen.

   Del 1-3 læser kun. Del 4 skriver, men i en transaktion der ROLLBACK'er som
   standard: skift den sidste linje til COMMIT, når del 3 ser rigtig ud.

   Forudsætter at [RPA] og [Befordringssystemet] ligger på samme instans.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;
SET XACT_ABORT ON;


/* ------------------------------------------------------------
   Normaliserede opslagsdata

   Samme fold som i Python: små bogstaver, mellemrum væk, æ/ø/å til ae/oe/aa.
   é tages med, fordi "Grønløkke Allé" staves begge veje.
------------------------------------------------------------ */

IF OBJECT_ID('tempdb..#matrikel') IS NOT NULL DROP TABLE #matrikel;

SELECT
    sm.matrikel_id,
    sm.matrikel_navn,
    sm.skolekode,
    -- Skolenavnet: alt foran parentesen, eller hele navnet når der ikke er en.
    LTRIM(RTRIM(
        CASE WHEN CHARINDEX('(', sm.matrikel_navn) > 0
             THEN LEFT(sm.matrikel_navn, CHARINDEX('(', sm.matrikel_navn) - 1)
             ELSE sm.matrikel_navn
        END
    ))                                                      AS skole_navn,
    -- Afdelingen: teksten i parentesen. NULL når skolen kun har én adresse.
    CASE WHEN CHARINDEX('(', sm.matrikel_navn) > 0
              AND CHARINDEX(')', sm.matrikel_navn) > CHARINDEX('(', sm.matrikel_navn)
         THEN SUBSTRING(
                  sm.matrikel_navn,
                  CHARINDEX('(', sm.matrikel_navn) + 1,
                  CHARINDEX(')', sm.matrikel_navn) - CHARINDEX('(', sm.matrikel_navn) - 1
              )
    END                                                     AS afdeling
INTO #matrikel
FROM [befordring].[Skolematrikel] sm;

ALTER TABLE #matrikel ADD skole_navn_norm NVARCHAR(200), afdeling_norm NVARCHAR(200);

UPDATE #matrikel
SET skole_navn_norm = LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        skole_navn, ' ', ''), 'æ', 'ae'), 'ø', 'oe'), 'å', 'aa'), 'é', 'e')),
    afdeling_norm   = LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        ISNULL(afdeling, ''), ' ', ''), 'æ', 'ae'), 'ø', 'oe'), 'å', 'aa'), 'é', 'e'));


/* ------------------------------------------------------------
   Bevillinger uden skole, med sagens rækker fra BefordringsData
------------------------------------------------------------ */

IF OBJECT_ID('tempdb..#uden_skole') IS NOT NULL DROP TABLE #uden_skole;

SELECT
    b.bevilling_id,
    b.cpr_elev,
    b.esdh_noegle,
    s.status_tekst,
    d.[SkoleID],
    d.[SkolensAdresse],
    d.[SkoleNavnBefordring],
    LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        ISNULL(d.[SkoleNavnBefordring], ''), ' ', ''), 'æ', 'ae'), 'ø', 'oe'), 'å', 'aa'), 'é', 'e'))
        AS navn_norm,
    LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        ISNULL(d.[SkolensAdresse], '') + ISNULL(d.[SkoleNavnBefordring], ''),
        ' ', ''), 'æ', 'ae'), 'ø', 'oe'), 'å', 'aa'), 'é', 'e'))
        AS sted_norm
INTO #uden_skole
FROM       [befordring].[Bevilling]        b
LEFT  JOIN [befordring].[Status]           s ON s.status_id = b.status_id
INNER JOIN [RPA].[rpa].[BefordringsData]   d ON d.[CaseID]  = b.esdh_noegle
WHERE b.aktiv = 1
  AND b.matrikel_id IS NULL
  AND b.ungdomsuddannelse_id IS NULL        -- en ungdomsuddannelse har ingen matrikel
  AND NULLIF(LTRIM(RTRIM(b.esdh_noegle)), '') IS NOT NULL;


/* ------------------------------------------------------------
   Hvilke matrikler passer på sagens rækker
------------------------------------------------------------ */

IF OBJECT_ID('tempdb..#match') IS NOT NULL DROP TABLE #match;

SELECT DISTINCT
    u.bevilling_id,
    m.matrikel_id,
    m.matrikel_navn
INTO #match
FROM #uden_skole u
JOIN #matrikel   m
     ON  m.skole_navn_norm <> ''
     AND CHARINDEX(m.skole_navn_norm, u.navn_norm) > 0
     AND (m.afdeling_norm = '' OR CHARINDEX(m.afdeling_norm, u.sted_norm) > 0);


/* ============================================================
   1. Hvor stort er problemet
============================================================ */

SELECT
    COUNT(DISTINCT u.bevilling_id)                                   AS bevillinger_uden_skole,
    COUNT(DISTINCT CASE WHEN NULLIF(LTRIM(RTRIM(u.[SkoleID])), '') IS NULL
                        THEN u.bevilling_id END)                     AS heraf_uden_skoleid_i_kilden,
    COUNT(DISTINCT u.cpr_elev)                                       AS elever
FROM #uden_skole u;


/* ============================================================
   2. Fordeling på udfald
============================================================ */

SELECT   x.udfald, COUNT(*) AS antal_bevillinger
FROM (
    SELECT u.bevilling_id,
           CASE COUNT(DISTINCT mt.matrikel_id)
                WHEN 0 THEN '3. intet match — rettes i hånden'
                WHEN 1 THEN '1. entydigt match — backfilles'
                ELSE        '2. flere mulige — rettes i hånden'
           END AS udfald
    FROM      #uden_skole u
    LEFT JOIN #match      mt ON mt.bevilling_id = u.bevilling_id
    GROUP BY  u.bevilling_id
) x
GROUP BY x.udfald
ORDER BY x.udfald;


/* ============================================================
   3. Linje for linje — læs denne før del 4 køres

   Én linje pr. bevilling. foreslaaet_matrikel er udfyldt netop når der er
   præcis ét match; det er dem del 4 skriver.
============================================================ */

SELECT
    u.bevilling_id,
    STUFF(u.cpr_elev, 7, 0, '-')                      AS cpr,
    u.esdh_noegle                                     AS ppr_sags_id,
    MAX(u.status_tekst)                               AS status,
    MAX(ISNULL(u.[SkoleID], '(tom)'))                 AS skoleid_i_kilden,
    MAX(ISNULL(u.[SkoleNavnBefordring], ''))          AS kilde_skolenavn,
    MAX(ISNULL(u.[SkolensAdresse], ''))               AS kilde_skoleadresse,
    COUNT(DISTINCT mt.matrikel_id)                    AS antal_match,
    CASE WHEN COUNT(DISTINCT mt.matrikel_id) = 1
         THEN MAX(mt.matrikel_navn) END               AS foreslaaet_matrikel,
    CASE WHEN COUNT(DISTINCT mt.matrikel_id) = 1
         THEN MAX(mt.matrikel_id) END                 AS foreslaaet_matrikel_id,
    CASE COUNT(DISTINCT mt.matrikel_id)
         WHEN 0 THEN 'intet match'
         WHEN 1 THEN 'backfilles'
         ELSE        'flere mulige: ' + STRING_AGG(mt.matrikel_navn, ' | ')
    END                                               AS udfald
FROM      #uden_skole u
LEFT JOIN #match      mt ON mt.bevilling_id = u.bevilling_id
GROUP BY  u.bevilling_id, u.cpr_elev, u.esdh_noegle
ORDER BY  antal_match DESC, u.bevilling_id;


/* ============================================================
   4. Selve opdateringen — ROLLBACK som standard
============================================================ */

BEGIN TRANSACTION;

    UPDATE b
    SET    b.matrikel_id = v.matrikel_id,
           b.updated_by  = 'backfill_matrikel',
           b.updated_at  = GETDATE()
    FROM   [befordring].[Bevilling] b
    JOIN (
        SELECT   mt.bevilling_id, MIN(mt.matrikel_id) AS matrikel_id
        FROM     #match mt
        GROUP BY mt.bevilling_id
        HAVING   COUNT(DISTINCT mt.matrikel_id) = 1
    ) v ON v.bevilling_id = b.bevilling_id
    WHERE  b.matrikel_id IS NULL;      -- aldrig overskrive en skole der findes

    PRINT CONCAT('Backfill: ', @@ROWCOUNT, ' bevilling(er) fik en matrikel.');

    /* Kontrol inde i transaktionen: sådan ser de ud bagefter. */
    SELECT b.bevilling_id, STUFF(b.cpr_elev, 7, 0, '-') AS cpr,
           b.esdh_noegle, sm.matrikel_navn, sm.skolekode
    FROM   [befordring].[Bevilling]      b
    JOIN   [befordring].[Skolematrikel]  sm ON sm.matrikel_id = b.matrikel_id
    WHERE  b.updated_by = 'backfill_matrikel'
    ORDER  BY b.bevilling_id;

PRINT '';
PRINT 'ROLLBACK er aktiv. Skift til COMMIT når del 3 og kontrollen ser rigtig ud.';
PRINT '';

ROLLBACK TRANSACTION;
