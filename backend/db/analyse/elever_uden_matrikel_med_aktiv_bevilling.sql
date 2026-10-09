/* ============================================================
   Elever med en AKTIV bevilling, uden matrikel_id, hvis skolekode
   IKKE findes i Skolematrikel

   Elev.matrikel_id udledes af BEVILLINGEN af
   usp_sync_elev_matrikel_from_bevilling — ikke af elevens skolekode. Står
   den NULL, har eleven ingen skole på stamdata, og så kan gåafstanden ikke
   beregnes: den måles fra elevens adresse til skolens koordinat. Uden
   gåafstand er der intet afstandskriterie, og det er ikke synligt på sagen
   — feltet står bare tomt.

   Eleven skal have en skolekode, OG koden må ikke kunne slås op i
   Skolematrikel. Det er den delmængde, hvor rettelsen er kendt og billig:
   tilføj matriklen, så kan koden slås op. Elever hvis kode allerede findes
   mangler noget andet — se del 3, der tæller dem, og
   elever_uden_matrikel_entydig_skolekode.sql.

   Ingen aldersgrænse, og genbehandling er IKKE filtreret fra — flaget står
   som kolonne i del 1 i stedet. Sager med genbehandling ligger allerede på
   genbehandlingssiden; sager uden er dem, ingen kigger på. Begge mangler
   det samme, så forskellen kan ses frem for at være valgt på forhånd.

   "Aktiv" er status_tekst = 'Aktiv', ikke soft-delete-flaget Bevilling.aktiv
   — begge er filtreret, men de betyder ikke det samme. Vil du også have
   'Kommende' med, så udvid IN-listerne.

   Kun læsning.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;


-- ---------------------------------------------------------------------------
-- 1. Eleverne, én række pr. bevilling.
--
--    bevilling_matrikel_id er det, Elev.matrikel_id burde være udledt AF.
--    Er den udfyldt, mens elevens står tom, har synkroniseringen ikke været
--    der endnu — eller bevillingen kvalificerede ikke. Bemærk at den godt
--    kan være udfyldt her: bevillingens skole og elevens skolekode er to
--    forskellige felter, og det er koden, der mangler sin matrikel.
-- ---------------------------------------------------------------------------
SELECT
    e.cpr,
    e.adresseringsnavn,
    e.skolekode                 AS elev_skolekode,
    e.elevklassetrin,
    e.institution,
    e.bopaelsdistrikt,
    e.skoleafstand,
    e.kraever_genberegning,

    b.bevilling_id,
    b.loebenummer,
    ISNULL(b.genbehandling, 0)  AS genbehandling,
    b.genbehandling_bemaerkning,
    b.matrikel_id               AS bevilling_matrikel_id,
    b.ungdomsuddannelse_id      AS bevilling_ungdomsuddannelse_id,
    COALESCE(sm.matrikel_navn, uu.ungdomsuddannelse_navn) AS bevilling_skole,
    b.ansoegningstype
FROM       [befordring].[Elev]              e
INNER JOIN [befordring].[Bevilling]         b   ON b.cpr_elev   = e.cpr
                                                AND b.aktiv      = 1
INNER JOIN [befordring].[Status]            st  ON st.status_id = b.status_id
LEFT  JOIN [befordring].[Skolematrikel]     sm  ON sm.matrikel_id = b.matrikel_id
LEFT  JOIN [befordring].[Ungdomsuddannelse] uu  ON uu.ungdomsuddannelse_id = b.ungdomsuddannelse_id
WHERE  e.matrikel_id IS NULL
  AND  e.skolekode IS NOT NULL
  AND  e.skolekode <> 0
  AND  st.status_tekst IN (N'Aktiv')
  AND  NOT EXISTS (
           SELECT 1
           FROM   [befordring].[Skolematrikel] s
           WHERE  s.skolekode = e.skolekode
       )
ORDER BY e.skolekode, e.adresseringsnavn, b.loebenummer;


-- ---------------------------------------------------------------------------
-- 2. Pr. ukendt skolekode — det er her, rettelsen ligger.
--
--    Én manglende kode rammer typisk flere elever, og rettelsen er den
--    samme for dem alle: én ny række i Skolematrikel, se
--    tilfoej_manglende_skolematrikler.sql. Tag den med flest elever først.
--    distrikter/institutioner er fritekst fra samme indlæsning og er
--    normalt nok til at genkende skolen.
-- ---------------------------------------------------------------------------
WITH ukendte AS (
    SELECT DISTINCT
        e.cpr,
        e.skolekode,
        e.institution,
        e.bopaelsdistrikt
    FROM       [befordring].[Elev]      e
    INNER JOIN [befordring].[Bevilling] b  ON b.cpr_elev   = e.cpr AND b.aktiv = 1
    INNER JOIN [befordring].[Status]    st ON st.status_id = b.status_id
    WHERE  e.matrikel_id IS NULL
      AND  e.skolekode IS NOT NULL
      AND  e.skolekode <> 0
      AND  st.status_tekst IN (N'Aktiv')
      AND  NOT EXISTS (
               SELECT 1 FROM [befordring].[Skolematrikel] s
               WHERE  s.skolekode = e.skolekode
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
-- 3. Kontroltal, så et tomt resultat kan skelnes fra en forkert forespørgsel.
--
--    De to udeladte grupper mangler samme matrikel_id, men har hver sin
--    rettelse — og ingen af dem løses ved at tilføje en skolematrikel.
-- ---------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*)
     FROM       [befordring].[Bevilling] b
     INNER JOIN [befordring].[Status]    st ON st.status_id = b.status_id
     WHERE  b.aktiv = 1 AND st.status_tekst IN (N'Aktiv'))
        AS aktive_bevillinger_i_alt,
    (SELECT COUNT(*)
     FROM       [befordring].[Elev]      e
     INNER JOIN [befordring].[Bevilling] b  ON b.cpr_elev   = e.cpr AND b.aktiv = 1
     INNER JOIN [befordring].[Status]    st ON st.status_id = b.status_id
     WHERE  e.matrikel_id IS NULL
       AND  (e.skolekode IS NULL OR e.skolekode = 0)
       AND  st.status_tekst IN (N'Aktiv'))
        AS udeladt_uden_skolekode,
    (SELECT COUNT(*)
     FROM       [befordring].[Elev]      e
     INNER JOIN [befordring].[Bevilling] b  ON b.cpr_elev   = e.cpr AND b.aktiv = 1
     INNER JOIN [befordring].[Status]    st ON st.status_id = b.status_id
     WHERE  e.matrikel_id IS NULL
       AND  e.skolekode IS NOT NULL AND e.skolekode <> 0
       AND  st.status_tekst IN (N'Aktiv')
       AND  EXISTS (SELECT 1 FROM [befordring].[Skolematrikel] s
                    WHERE s.skolekode = e.skolekode))
        AS udeladt_kode_findes_allerede;
