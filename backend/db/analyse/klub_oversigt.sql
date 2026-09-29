/* ============================================================
   Klub-relateret befordringsdata — overblik

   Kører mod [RPA].[rpa].[BefordringsData] (server 29), IKKE mod
   Befordringssystemet. Ren læsning, ingen ændringer.

   HVAD TÆLLES SOM KLUB

   Samme regel som konverteringen bruger — _KLUB_MARKERS og _KLUB_FELTER i
   rpa-befordring-konvertering-af-ppr-sager/processes/queue_handler.py — så
   tallene her og kørslens tal kan sammenlignes:

     felter    ElevensAdresse, SkoleNavnBefordring, Kommentar
     markører  'klub'  (fanger Klubben, klubben, ungdomsklub …)
               'Holme Søndergård' / 'Holme Søndergaard'

   'holme' ALENE er bevidst ikke en markør: Holmevej, Holme Ringvej og
   Holmesvinget er almindelige veje, og de ville trække hver eneste elev i
   Holme med ind i tallet.

   EN RÆKKE ER IKKE EN BEVILLING

   BefordringsData har ingen bevillings-entitet. Konverteringen danner
   bevillinger ved at gruppere rækker pr. sag OG periode, så antallet af
   bevillinger ligger mellem antal sager og antal rækker. Begge tælles
   nedenfor.

   Temp-tabeller frem for CTE'er med vilje: en CTE gælder kun for den ENE statement, der følger efter den, så de fire afsnit her ville ikke
   kunne dele den.
============================================================ */

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#klub')    IS NOT NULL DROP TABLE #klub;
IF OBJECT_ID('tempdb..#i_scope') IS NOT NULL DROP TABLE #i_scope;

DECLARE @graense date = DATEADD(YEAR, -2, GETDATE());


/* Klub-rækkerne, med angivelse af hvilket felt der udløste dem. */
SELECT
    d.CPR,
    d.CaseID,
    d.CaseDBID,
    d.BevillingFra,
    d.BevillingTil,
    d.ElevensAdresse,
    d.SkoleNavnBefordring,
    d.Kommentar,
    CAST(CASE WHEN d.ElevensAdresse LIKE '%klub%'
                OR d.ElevensAdresse LIKE '%Holme Søndergård%'
                OR d.ElevensAdresse LIKE '%Holme Søndergaard%'
              THEN 1 ELSE 0 END AS bit) AS i_adresse,
    CAST(CASE WHEN d.SkoleNavnBefordring LIKE '%klub%'
                OR d.SkoleNavnBefordring LIKE '%Holme Søndergård%'
                OR d.SkoleNavnBefordring LIKE '%Holme Søndergaard%'
              THEN 1 ELSE 0 END AS bit) AS i_skolenavn,
    CAST(CASE WHEN d.Kommentar LIKE '%klub%'
                OR d.Kommentar LIKE '%Holme Søndergård%'
                OR d.Kommentar LIKE '%Holme Søndergaard%'
              THEN 1 ELSE 0 END AS bit) AS i_kommentar
INTO   #klub
FROM   [RPA].[rpa].[BefordringsData] d
WHERE  d.ElevensAdresse      LIKE '%klub%'
    OR d.ElevensAdresse      LIKE '%Holme Søndergård%'
    OR d.ElevensAdresse      LIKE '%Holme Søndergaard%'
    OR d.SkoleNavnBefordring LIKE '%klub%'
    OR d.SkoleNavnBefordring LIKE '%Holme Søndergård%'
    OR d.SkoleNavnBefordring LIKE '%Holme Søndergaard%'
    OR d.Kommentar           LIKE '%klub%'
    OR d.Kommentar           LIKE '%Holme Søndergård%'
    OR d.Kommentar           LIKE '%Holme Søndergaard%';


/* Elever konverteringen overhovedet ser: mindst én bevilling inden for de
   sidste to år. Samme regel som kørslens WHERE, så tallene kan holdes op
   mod hinanden. */
SELECT DISTINCT d.CPR
INTO   #i_scope
FROM   [RPA].[rpa].[BefordringsData] d
WHERE  d.BevillingFra >= @graense
    OR d.BevillingTil >= @graense;


/* ---------- 1. Hovedtal ---------- */
PRINT 'Hovedtal';

SELECT 'Rækker med klub'               AS maal, COUNT(*)               AS antal FROM #klub
UNION ALL SELECT 'Distinkte PPR-sager',       COUNT(DISTINCT CaseID)         FROM #klub
UNION ALL SELECT 'Distinkte elever',          COUNT(DISTINCT CPR)            FROM #klub
UNION ALL SELECT '— heraf i scope (2 år)',
                 (SELECT COUNT(DISTINCT k.CPR) FROM #klub k
                  JOIN #i_scope s ON s.CPR = k.CPR)
UNION ALL SELECT '"Bevillinger" (sag + periode)',
                 (SELECT COUNT(*) FROM
                     (SELECT DISTINCT CaseID, BevillingFra, BevillingTil FROM #klub) x);


/* ---------- 2. Hvor står klubben? ---------- */
PRINT 'Fordeling på felt';

SELECT
    CASE WHEN i_adresse = 1 AND i_skolenavn = 1 THEN 'Både adresse og skolenavn'
         WHEN i_adresse = 1                     THEN 'ElevensAdresse'
         WHEN i_skolenavn = 1                   THEN 'SkoleNavnBefordring'
         ELSE                                        'Kun Kommentar'
    END                 AS felt,
    COUNT(*)            AS raekker,
    COUNT(DISTINCT CPR) AS elever
FROM   #klub
GROUP  BY
    CASE WHEN i_adresse = 1 AND i_skolenavn = 1 THEN 'Både adresse og skolenavn'
         WHEN i_adresse = 1                     THEN 'ElevensAdresse'
         WHEN i_skolenavn = 1                   THEN 'SkoleNavnBefordring'
         ELSE                                        'Kun Kommentar'
    END
ORDER  BY raekker DESC;


/* ---------- 3. Én linje pr. elev ---------- */
PRINT 'Pr. elev';

SELECT
    k.CPR,
    COUNT(*)                     AS klubraekker,
    COUNT(DISTINCT k.CaseID)     AS sager,
    MIN(k.BevillingFra)          AS tidligste,
    MAX(k.BevillingTil)          AS seneste,
    CASE WHEN MAX(CASE WHEN s.CPR IS NULL THEN 0 ELSE 1 END) = 1
         THEN 'ja' ELSE 'nej' END AS i_scope_2_aar,
    MAX(k.ElevensAdresse)        AS eksempel_adresse,
    MAX(k.SkoleNavnBefordring)   AS eksempel_skolenavn
FROM      #klub    k
LEFT JOIN #i_scope s ON s.CPR = k.CPR
GROUP  BY k.CPR
ORDER  BY klubraekker DESC, k.CPR;


/* ---------- 4. Alle rækkerne, til gennemgang ---------- */
PRINT 'Alle klub-rækker';

SELECT CaseID, CPR, BevillingFra, BevillingTil,
       ElevensAdresse, SkoleNavnBefordring, Kommentar
FROM   #klub
ORDER  BY CPR, BevillingFra;


DROP TABLE #klub;
DROP TABLE #i_scope;
