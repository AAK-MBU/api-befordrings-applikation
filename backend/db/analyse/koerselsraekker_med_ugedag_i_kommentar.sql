/* ============================================================
   Kørselsrækker hvis kommentar nævner en ugedag

   Konverteringen satte ALLE kørselsrækker til ugedagen "Alle":
   BefordringsData har ingen ugedagskolonne, og en række uden dage kan ikke
   gemmes, når en sagsbehandler senere åbner den. "Alle" er det nærmeste
   ærlige gæt for en fast ordning — men hvor kommentaren nævner en bestemt
   dag, er ordningen smallere end det, og rækken skal rettes.

   Dette finder dem. Én linje pr. kørselsrække, med de dage kommentaren
   nævner, de dage rækken har nu, og et uddrag af kommentaren.

   Kommentaren gennemsøges HELE vejen igennem — også KONVERTERING-PPR-noterne,
   fordi klubnoten gengiver kildens egen kommentar inde i sig.

   Læser kun.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;


/* De ord der tæller som en ugedag. Stavemåder uden æ/ø/å er med, fordi
   kildedata ikke er konsekvent om dem. Forkortelser som "ons" og "fre" er
   IKKE med: de optræder inde i almindelige ord og ville larme mere end de
   hjælper. */
IF OBJECT_ID('tempdb..#ugedag') IS NOT NULL DROP TABLE #ugedag;

SELECT v.ord, v.dag, v.nr
INTO   #ugedag
FROM (VALUES
    (N'mandag',  N'Mandag',  1),
    (N'tirsdag', N'Tirsdag', 2),
    (N'onsdag',  N'Onsdag',  3),
    (N'torsdag', N'Torsdag', 4),
    (N'fredag',  N'Fredag',  5),
    (N'lørdag',  N'Lørdag',  6),
    (N'loerdag', N'Lørdag',  6),
    (N'søndag',  N'Søndag',  7),
    (N'soendag', N'Søndag',  7)
) AS v (ord, dag, nr);


SELECT
    b.bevilling_id,
    STUFF(b.cpr_elev, 7, 0, '-')                        AS cpr,
    e.adresseringsnavn                                  AS elev_navn,
    b.esdh_noegle                                       AS case_id,
    s.status_tekst                                      AS status,

    k.gyldig_fra,
    k.gyldig_til,
    bt.befordringstype_tekst                            AS koerselstype,

    -- Dage som kommentaren nævner, mod dage rækken faktisk har.
    naevnt.dage                                         AS naevnt_i_kommentar,


    LEFT(k.kommentar, 400)                              AS kommentar_uddrag
FROM        [befordring].[Koersel]          k
INNER JOIN  [befordring].[Bevilling]        b  ON b.bevilling_id       = k.bevilling_id
LEFT  JOIN  [befordring].[Elev]             e  ON e.cpr                = b.cpr_elev
LEFT  JOIN  [befordring].[Status]           s  ON s.status_id          = b.status_id
LEFT  JOIN  [befordring].[Befordringstype]  bt ON bt.befordringstype_id = k.befordringstype_id

-- Hvilke ugedage nævner kommentaren
CROSS APPLY (
    SELECT STRING_AGG(x.dag, ', ') WITHIN GROUP (ORDER BY x.nr) AS dage
    FROM (
        SELECT DISTINCT u.dag, u.nr
        FROM   #ugedag u
        WHERE  k.kommentar LIKE N'%' + u.ord + N'%'
    ) x
) naevnt

-- Hvilke dage rækken har nu
OUTER APPLY (
    SELECT STRING_AGG(ug.dag_tekst, ', ') AS dage
    FROM   [befordring].[Koersel_Ugedag_LINK] kul
    JOIN   [befordring].[Ugedag]             ug ON ug.dag_id = kul.dag_id
    WHERE  kul.koersel_id = k.koersel_id
) nu

WHERE k.aktiv = 1
  AND b.aktiv = 1
  AND naevnt.dage IS NOT NULL      -- kun rækker hvor kommentaren nævner en dag
ORDER BY
    -- Dem der stadig står på "Alle" først: det er dem der skal rettes.
    CASE WHEN ISNULL(nu.dage, '') = 'Alle' THEN 0 ELSE 1 END,
    b.cpr_elev,
    k.gyldig_fra,
    k.koersel_id;
