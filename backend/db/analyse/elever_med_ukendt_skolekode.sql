/* ============================================================
   Elever på 14 år eller derunder, MED en ikke-udløbet bevilling,
   hvis skolekode ikke findes i Skolematrikel

   Elev.skolekode er denormaliseret ind på eleven af den natlige indlæsning.
   Den kommer udefra, mens Skolematrikel er en håndholdt liste — så en
   skolekode kan stå på en elev uden at have en matrikel at pege på.

   Når eleven samtidig har en bevilling, er det ikke kun et datahul: den
   natlige RPA sammenligner elevens skolekode med skolekoden på bevillingens
   matrikel for at opdage, at eleven har skiftet skole. Mangler koden en
   matrikel, kan den sammenligning ikke give et meningsfuldt svar, og
   gåafstanden kan ikke udledes af koden.

   Kun bevillinger der IKKE er udløbet. Status beregnes af
   usp_recalculate_bevilling_status ud fra kørselsperioderne, så "Udløbet"
   betyder, at der ikke køres længere. Bemærk at "Afslag" og "Ophørt" er lige
   så færdige og IKKE er filtreret fra her; tilføj dem til NOT IN-listen,
   hvis de heller ikke skal tælle med.

   NULL og 0 tælles IKKE med. 0 er server-default på kolonnen og det,
   create_elev sætter, når der ikke følger en kode med — begge betyder
   "ingen skolekode oplyst", ikke "ukendt skolekode". Kun det sidste kan
   løses ved at tilføje en matrikel. Del 4 tæller dem for sig.

   Kun læsning.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;

DROP TABLE IF EXISTS #kandidater;


/* ------------------------------------------------------------
   Alder udledt af CPR

   Elev.cpr er ti cifre uden bindestreg: DDMMYY + løbenummer. Århundredet
   ligger IKKE i årstallet, men i det 7. ciffer sammen med YY — det er en
   fast regel fra CPR-kontoret, ikke et skøn:

       7. ciffer 0-3                -> 1900-1999
       7. ciffer 4 eller 9, YY<=36  -> 2000-2036,  ellers 1937-1999
       7. ciffer 5-8,       YY<=57  -> 2000-2057,  ellers 1858-1899

   Uden den regel ville et barn født i 2015 ('150315-4xxx') blive læst som
   født i 1915 og falde ud af ethvert aldersfilter. Reglen er skrevet helt
   ud, selv om kun 2000-tallet kan ramme et skolebarn i dag, fordi den
   halve regel er den slags, der ser rigtig ud og tier, når den er forkert.

   Rækker med et cpr der ikke er ti cifre, eller som ikke danner en gyldig
   dato, får foedselsdato = NULL og falder ud af filteret nedenfor. Del 4
   tæller dem, så de ikke forsvinder i stilhed.
------------------------------------------------------------ */
SELECT
    e.cpr,
    e.adresseringsnavn,
    e.skolekode,
    e.elevklassetrin,
    e.institution,
    e.bopaelsdistrikt,
    e.matrikel_id,
    e.skoleafstand,
    f.foedselsdato,
    CASE WHEN f.foedselsdato IS NULL THEN NULL ELSE
        DATEDIFF(YEAR, f.foedselsdato, GETDATE())
        - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, f.foedselsdato, GETDATE()), f.foedselsdato)
                    > CAST(GETDATE() AS date)
               THEN 1 ELSE 0 END
    END AS alder
INTO   #kandidater
FROM   [befordring].[Elev] e
CROSS APPLY (
    SELECT CASE
        WHEN e.cpr IS NULL OR LEN(e.cpr) <> 10 OR e.cpr LIKE '%[^0-9]%' THEN NULL
        ELSE TRY_CONVERT(date, CONCAT(
            CASE
                WHEN SUBSTRING(e.cpr, 7, 1) IN ('0','1','2','3') THEN 1900
                WHEN SUBSTRING(e.cpr, 7, 1) IN ('4','9')
                     THEN CASE WHEN CAST(SUBSTRING(e.cpr, 5, 2) AS int) <= 36 THEN 2000 ELSE 1900 END
                ELSE CASE WHEN CAST(SUBSTRING(e.cpr, 5, 2) AS int) <= 57 THEN 2000 ELSE 1800 END
            END + CAST(SUBSTRING(e.cpr, 5, 2) AS int),
            '-', SUBSTRING(e.cpr, 3, 2),
            '-', SUBSTRING(e.cpr, 1, 2)
        ))
    END AS foedselsdato
) f
WHERE  e.skolekode IS NOT NULL
  AND  e.skolekode <> 0
  AND  NOT EXISTS (
           SELECT 1
           FROM   [befordring].[Skolematrikel] sm
           WHERE  sm.skolekode = e.skolekode
       );


-- ---------------------------------------------------------------------------
-- 1. Eleverne, én række pr. bevilling.
--
--    bevilling_skolekode er skolekoden på BEVILLINGENS matrikel — altså den
--    skole eleven rent faktisk køres til. Den er som regel svaret på, hvad
--    elevens ukendte kode burde være, og er derfor taget med ved siden af.
--    Står de to ens, findes koden simpelthen ikke i Skolematrikel endnu.
-- ---------------------------------------------------------------------------
SELECT
    k.cpr,
    k.adresseringsnavn,
    k.alder,
    k.skolekode                 AS elev_skolekode,
    k.elevklassetrin,
    k.institution,
    k.bopaelsdistrikt,
    k.matrikel_id               AS elev_matrikel_id,   -- NULL forklarer manglende gåafstand
    k.skoleafstand,

    b.bevilling_id,
    b.loebenummer,
    st.status_tekst             AS bevilling_status,
    sm_b.matrikel_navn          AS bevilling_skole,
    sm_b.skolekode              AS bevilling_skolekode
FROM       #kandidater                  k
INNER JOIN [befordring].[Bevilling]     b     ON b.cpr_elev     = k.cpr
                                             AND b.aktiv        = 1
-- INNER, ikke LEFT: filteret nedenfor er en ulighed, og den er UKENDT for
-- NULL i T-SQL. Et LEFT JOIN ville tabe rækkerne i stilhed i stedet for at
-- beholde dem.
INNER JOIN [befordring].[Status]        st    ON st.status_id   = b.status_id
LEFT  JOIN [befordring].[Skolematrikel] sm_b  ON sm_b.matrikel_id = b.matrikel_id
WHERE  st.status_tekst NOT IN (N'Udløbet')
  AND  k.alder IS NOT NULL
  AND  k.alder <= 14
ORDER BY k.skolekode, k.adresseringsnavn, b.loebenummer;


-- ---------------------------------------------------------------------------
-- 2. Pr. ukendt skolekode — det er her, rettelsen ligger.
--
--    Én manglende kode rammer typisk flere elever, og rettelsen er den samme
--    for dem alle: én ny række i Skolematrikel, se
--    tilfoej_manglende_skolematrikler.sql. Tag den med flest elever først.
--    distrikter/institutioner er fritekst fra samme indlæsning og er normalt
--    nok til at genkende skolen.
-- ---------------------------------------------------------------------------
WITH ukendte AS (
    SELECT DISTINCT k.cpr, k.skolekode, k.institution, k.bopaelsdistrikt
    FROM   #kandidater k
    WHERE  k.alder IS NOT NULL
      AND  k.alder <= 14
      AND  EXISTS (
               SELECT 1
               FROM       [befordring].[Bevilling] b
               INNER JOIN [befordring].[Status]    st ON st.status_id = b.status_id
               WHERE  b.cpr_elev = k.cpr
                 AND  b.aktiv = 1
                 AND  st.status_tekst NOT IN (N'Udløbet')
           )
),
distinkte AS (
    -- SQL Server har ikke STRING_AGG(DISTINCT ...).
    SELECT DISTINCT skolekode, bopaelsdistrikt, institution FROM ukendte
)
SELECT
    u.skolekode,
    COUNT(*) AS antal_elever,
    (SELECT STRING_AGG(d.bopaelsdistrikt, ' | ')
     FROM   distinkte d
     WHERE  d.skolekode = u.skolekode AND d.bopaelsdistrikt <> '')  AS distrikter,
    (SELECT STRING_AGG(d.institution, ' | ')
     FROM   distinkte d
     WHERE  d.skolekode = u.skolekode AND d.institution <> '')      AS institutioner
FROM     ukendte u
GROUP BY u.skolekode
ORDER BY antal_elever DESC, u.skolekode;


-- ---------------------------------------------------------------------------
-- 3. Faldet fra på alderen — altså elever der ellers opfylder alt.
--
--    Tages med, så aldersgrænsen er synlig frem for usynlig. En elev på 15+
--    med en ukendt skolekode er stadig et datahul; den er bare ikke med i
--    del 1. ukendt_foedselsdato er rækker hvor cpr ikke kunne læses.
-- ---------------------------------------------------------------------------
SELECT
    SUM(CASE WHEN k.alder > 14 THEN 1 ELSE 0 END)        AS over_14,
    SUM(CASE WHEN k.alder IS NULL THEN 1 ELSE 0 END)     AS ukendt_foedselsdato,
    MIN(k.alder)                                         AS yngste,
    MAX(k.alder)                                         AS aeldste
FROM   #kandidater k
WHERE  EXISTS (
           SELECT 1
           FROM       [befordring].[Bevilling] b
           INNER JOIN [befordring].[Status]    st ON st.status_id = b.status_id
           WHERE  b.cpr_elev = k.cpr
             AND  b.aktiv = 1
             AND  st.status_tekst NOT IN (N'Udløbet')
       );


-- ---------------------------------------------------------------------------
-- 4. Kontroltal, så et tomt resultat kan skelnes fra en forkert forespørgsel.
-- ---------------------------------------------------------------------------
WITH ikke_udloebet AS (
    SELECT DISTINCT b.cpr_elev
    FROM       [befordring].[Bevilling] b
    INNER JOIN [befordring].[Status]    st ON st.status_id = b.status_id
    WHERE  b.aktiv = 1
      AND  st.status_tekst NOT IN (N'Udløbet')
)
SELECT
    (SELECT COUNT(*) FROM ikke_udloebet)
        AS elever_med_ikke_udloebet_bevilling,
    (SELECT COUNT(*) FROM [befordring].[Elev] e
     WHERE (e.skolekode IS NULL OR e.skolekode = 0)
       AND EXISTS (SELECT 1 FROM ikke_udloebet iu WHERE iu.cpr_elev = e.cpr))
        AS heraf_helt_uden_skolekode,
    (SELECT COUNT(DISTINCT skolekode) FROM [befordring].[Skolematrikel])
        AS kendte_skolekoder;


DROP TABLE IF EXISTS #kandidater;
