/* ============================================================
   Kildekommentarer der handler om lige/ulige uger

   Nogle børn har én ordning i lige uger og en anden i ulige. Det kan
   BefordringsData ikke udtrykke — der er ingen kolonne til det — så
   sagsbehandleren har skrevet det i kommentaren, og konverteringen har lavet
   én kørselsrække for hele perioden.

   Dette finder dem i KILDEN og peger på den kørselsrække, de blev til, så
   rækken kan deles op i hånden.

   Ordene søges med forskellig vægt, for de er ikke lige pålidelige:

     "ulige"       næsten altid "ulige uger" — stærkt signal
     "lige uge"    det modsatte, skrevet ud
     "hver anden"  samme ordning med andre ord
     "uge"         alt andet der nævner uger ("uge 32", "ugentlig")
     "lige"        alene: STØJ. Står i mulige, forskellige, lignende,
                   dagligt, ligesom — og i ulige. Taget med fordi det blev
                   bedt om, men lagt i sin egen kategori, så det kan filtres
                   fra uden at miste de andre.

   Læser kun.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#term') IS NOT NULL DROP TABLE #term;

SELECT v.ord, v.visning, v.styrke, v.nr
INTO   #term
FROM (VALUES
    (N'ulige',      N'ulige',      N'1. staerkt',  1),
    (N'lige uge',   N'lige uge',   N'1. staerkt',  2),
    (N'lige uger',  N'lige uger',  N'1. staerkt',  3),
    (N'hver anden', N'hver anden', N'1. staerkt',  4),
    (N'uge',        N'uge',        N'2. middel',   5),
    (N'lige',       N'lige',       N'3. stoej',    6)
) AS v (ord, visning, styrke, nr);


SELECT
    d.[CaseID]                                      AS case_id,
    STUFF(b.cpr_elev, 7, 0, '-')                    AS cpr,
    e.adresseringsnavn                              AS elev_navn,
    b.bevilling_id,
    k.koersel_id,
    s.status_tekst                                  AS status,

    d.[BevillingFra]                                AS kilde_fra,
    d.[BevillingTil]                                AS kilde_til,
    d.[BevillingAfKoerselstype]                     AS kilde_koerselstype,
    d.[TidspunktForBevilling]                       AS kilde_tidspunkt,

    traef.styrkeste                                 AS signal,
    traef.ord                                       AS ord_i_kommentaren,
    ISNULL(nu.dage, '(ingen)')                      AS dage_i_dag,

    d.[Kommentar]                                   AS kilde_kommentar
FROM       [RPA].[rpa].[BefordringsData] d

-- Hvilke af ordene står i kommentaren
CROSS APPLY (
    SELECT MIN(x.styrke)                                    AS styrkeste,
           STRING_AGG(x.visning, ', ') WITHIN GROUP (ORDER BY x.nr) AS ord
    FROM (
        SELECT DISTINCT t.visning, t.styrke, t.nr
        FROM   #term t
        WHERE  d.[Kommentar] LIKE N'%' + t.ord + N'%'
    ) x
) traef

-- Bevillingen sagen blev til, og den kørselsrække rækken blev til.
-- Datoerne er dem konverteringen kopierede direkte over.
LEFT JOIN  [befordring].[Bevilling] b
           ON  b.esdh_noegle = d.[CaseID]
           AND b.aktiv = 1
LEFT JOIN  [befordring].[Elev]      e ON e.cpr       = b.cpr_elev
LEFT JOIN  [befordring].[Status]    s ON s.status_id = b.status_id
LEFT JOIN  [befordring].[Koersel]   k
           ON  k.bevilling_id = b.bevilling_id
           AND k.aktiv = 1
           AND k.gyldig_fra = d.[BevillingFra]
           AND k.gyldig_til = d.[BevillingTil]

OUTER APPLY (
    SELECT STRING_AGG(ug.dag_tekst, ', ') AS dage
    FROM   [befordring].[Koersel_Ugedag_LINK] kul
    JOIN   [befordring].[Ugedag]             ug ON ug.dag_id = kul.dag_id
    WHERE  kul.koersel_id = k.koersel_id
) nu

WHERE traef.ord IS NOT NULL
ORDER BY
    traef.styrkeste,      -- de sikre øverst, "lige"-støjen nederst
    d.[CaseID],
    d.[BevillingFra];
