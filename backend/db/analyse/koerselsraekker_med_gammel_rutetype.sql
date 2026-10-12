/* ============================================================
   Kørselsrækker der stadig står med en gammel rutetype

   Migration 032 tilføjede de fire nye "Fra ... til ..."-typer uden at røre
   en eneste række. Det er med vilje: "Til hjem" kan blive både "Fra skole
   til hjem" og "Fra klub til hjem", og rækken siger ikke hvilken. Et gæt
   ender i et afgørelsesbrev.

   Så rækkerne flyttes i hånden. Det her er listen.

   UDLØBNE bevillinger er filtreret fra — MED ÉN UNDTAGELSE. En afsluttet
   sag har ingen fremtidig kørsel at rette rutetypen for, så den er ikke
   sagsbehandlerens bord. Men en udløbet bevilling med en EGEN BEFORDRING-
   række er det stadig: rpa-upload-egenbefordring-til-sharepoint validerer
   indberetninger mod bevillingen, også efter den er udløbet, fordi forældre
   indberetter bagud for perioder, der allerede er kørt. Står rutetypen
   forkert dér, fejler valideringen på en indberetning, der er helt i orden.

   Når del 1 returnerer nul rækker, kan de gamle typer sættes aktiv = 0 i en
   senere migration, og tidspunkt kan begynde at udgå.

   Kun læsning.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;


-- ---------------------------------------------------------------------------
-- 1. Rækkerne, med forslag hvor det er entydigt.
--
--    foreslaaet_rutetype er kun udfyldt, hvor der ikke er noget at vælge
--    imellem. "Til hjem" står tom med vilje — sagsbehandleren ved, om barnet
--    køres hjem fra skole eller fra klub; databasen gør ikke.
--
--    koersel_til_institution er taget med som fingerpeg: feltet udfyldes kun
--    på de fire taxa-kørselstyper, og siger om eftermiddagsturen går til
--    institutionen. Hvor det står 1 på en "Til hjem"-række, peger det mod
--    "Fra klub til hjem". Det er et fingerpeg, ikke et svar.
--
--    Kun AKTIVE bevillinger og rækker: en afsluttet bevilling beholder den
--    rutetype, den blev skrevet med, og skal ikke rettes bagud.
-- ---------------------------------------------------------------------------
SELECT
    e.cpr,
    e.adresseringsnavn,
    b.bevilling_id,
    b.loebenummer,
    st.status_tekst             AS bevilling_status,
    k.koersel_id,
    k.gyldig_fra,
    k.gyldig_til,
    bt.befordringstype_tekst    AS koerselstype,
    t.tidspunkt_tekst           AS tidspunkt,
    r.rutetype_tekst            AS nuvaerende_rutetype,
    k.koersel_til_institution,
    CASE r.rutetype_tekst
        WHEN N'Til skole' THEN N'Fra hjem til skole'
        WHEN N'Til klub'  THEN N'Fra skole til klub'
        ELSE NULL                       -- Til hjem og de to udgåede: vælges manuelt
    END                         AS foreslaaet_rutetype,
    k.final                     AS raekke_laast
FROM       [befordring].[Koersel]          k
INNER JOIN [befordring].[Bevilling]        b  ON b.bevilling_id   = k.bevilling_id
                                              AND b.aktiv          = 1
INNER JOIN [befordring].[Elev]             e  ON e.cpr            = b.cpr_elev
INNER JOIN [befordring].[Status]           st ON st.status_id     = b.status_id
LEFT  JOIN [befordring].[Rutetype]         r  ON r.rutetype_id    = k.rutetype_id
LEFT  JOIN [befordring].[Tidspunkt]        t  ON t.tidspunkt_id   = k.tidspunkt_id
LEFT  JOIN [befordring].[Befordringstype]  bt ON bt.befordringstype_id = k.befordringstype_id
WHERE  k.aktiv = 1
  AND  (
           k.rutetype_id IS NULL          -- rutetype er nullable i dag
        OR r.sorteringsorden IS NULL      -- = ikke en af de seks, se migration 032
       )
  AND  (
           st.status_tekst <> N'Udløbet'
        OR bt.befordringstype_tekst = N'Egen befordring'
       )
ORDER BY st.status_tekst, e.adresseringsnavn, b.loebenummer, k.gyldig_fra;


-- ---------------------------------------------------------------------------
-- 2. Hvor stor er bunken, og hvor meget af den er entydig?
--
--    Entydige rækker kan rettes i ét hug, hvis I vil have en UPDATE i stedet
--    for håndarbejde. Kun "Til hjem" og de to udgåede kræver en beslutning.
-- ---------------------------------------------------------------------------
SELECT
    ISNULL(r.rutetype_tekst, N'(ingen rutetype)')                AS nuvaerende_rutetype,
    COUNT(*)                                                     AS antal_raekker,
    COUNT(DISTINCT b.bevilling_id)                               AS antal_bevillinger,
    SUM(CASE WHEN k.final = 1 THEN 1 ELSE 0 END)                 AS heraf_laaste,
    SUM(CASE WHEN k.koersel_til_institution = 1 THEN 1 ELSE 0 END) AS heraf_til_institution,
    CASE ISNULL(r.rutetype_tekst, N'')
        WHEN N'Til skole' THEN N'Entydig -> Fra hjem til skole'
        WHEN N'Til klub'  THEN N'Entydig -> Fra skole til klub'
        WHEN N'Til hjem'  THEN N'KRAEVER VALG: skole eller klub?'
        WHEN N''          THEN N'KRAEVER VALG: ingen rutetype sat'
        ELSE                   N'KRAEVER VALG: udgaaet type uden erstatning'
    END                                                          AS handling
FROM       [befordring].[Koersel]         k
INNER JOIN [befordring].[Bevilling]       b  ON b.bevilling_id = k.bevilling_id AND b.aktiv = 1
INNER JOIN [befordring].[Status]          st ON st.status_id   = b.status_id
LEFT  JOIN [befordring].[Rutetype]        r  ON r.rutetype_id  = k.rutetype_id
LEFT  JOIN [befordring].[Befordringstype] bt ON bt.befordringstype_id = k.befordringstype_id
WHERE  k.aktiv = 1
  AND  (k.rutetype_id IS NULL OR r.sorteringsorden IS NULL)
  -- Samme afgrænsning som del 1, ellers tæller de to forskellige bunker.
  AND  (st.status_tekst <> N'Udløbet' OR bt.befordringstype_tekst = N'Egen befordring')
GROUP BY r.rutetype_tekst
ORDER BY antal_raekker DESC;


-- ---------------------------------------------------------------------------
-- 3. Kontroltal — så "nul rækker" kan skelnes fra en forkert forespørgsel.
-- ---------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM [befordring].[Koersel] k
     INNER JOIN [befordring].[Bevilling] b ON b.bevilling_id = k.bevilling_id AND b.aktiv = 1
     WHERE k.aktiv = 1)                                              AS aktive_raekker_i_alt,

    -- Udeladt af del 1 og 2: udløbet bevilling UDEN egen befordring. De
    -- beholder deres gamle rutetype, og det er med vilje — ingen fremtidig
    -- kørsel, og ingen indberetninger at validere imod.
    (SELECT COUNT(*)
     FROM       [befordring].[Koersel]         k
     INNER JOIN [befordring].[Bevilling]       b  ON b.bevilling_id = k.bevilling_id AND b.aktiv = 1
     INNER JOIN [befordring].[Status]          st ON st.status_id   = b.status_id
     LEFT  JOIN [befordring].[Rutetype]        r  ON r.rutetype_id  = k.rutetype_id
     LEFT  JOIN [befordring].[Befordringstype] bt ON bt.befordringstype_id = k.befordringstype_id
     WHERE  k.aktiv = 1
       AND  (k.rutetype_id IS NULL OR r.sorteringsorden IS NULL)
       AND  st.status_tekst = N'Udløbet'
       AND  ISNULL(bt.befordringstype_tekst, N'') <> N'Egen befordring')
                                                                     AS udeladt_udloebet_uden_egenbefordring,

    (SELECT COUNT(*) FROM [befordring].[Rutetype] WHERE sorteringsorden IS NOT NULL)
                                                                     AS rutetyper_med_sortering,
    (SELECT COUNT(*) FROM [befordring].[Rutetype] WHERE sorteringsorden IS NULL AND aktiv = 1)
                                                                     AS gamle_typer_stadig_aktive;
