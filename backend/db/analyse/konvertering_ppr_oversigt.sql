/* ============================================================
   KONVERTERING-PPR — hvad sagsbehandlerne skal se på

   Konverteringen fra [RPA].[rpa].[BefordringsData] skriver en kommentar på
   hver kørselsrække, hvor den har måttet antage, gætte eller omskrive noget.
   Hver kommentar begynder med en linje på formen

       KONVERTERING-PPR | <emne>

   og emnet siger hvilken slags beslutning det var. Kommentaren kan stå
   sammen med sagsbehandlerens egen tekst, og én kørselsrække kan have FLERE
   af dem — en klubtur på en gættet adresse har begge.

   Scriptet læser kun; det ændrer intet.

   CPR leveres med bindestreg — 010110-1234, ikke 0101101234. Uden den
   læser Excel feltet som et tal og smider det foregående nul væk, så
   0101101234 bliver til 101101234. Bindestregen gør det til tekst, og det er
   i forvejen den måde et CPR-nummer skrives på. Skal tallene bruges til et
   opslag igen, fjernes bindestregen med REPLACE(cpr, '-', '').

   Fire dele:
     1. Én linje pr. elev/sag/kategori — listen der kan deles ud
     2. Optælling pr. kategori — hvor stor hver bunke er
     3. Optælling pr. emne — det finere niveau under kategorien
     4. Kontrol: kommentarer med et emne dette script ikke kender

   Del 4 er ikke pynt. Konverteringen kan få et nyt emne uden at nogen retter
   her, og så ville de sager forsvinde ud af listen i stedet for at larme.
   Kommer der rækker i del 4, skal listen nedenfor udvides.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;


/* ------------------------------------------------------------
   Emnerne, som konverteringen skriver dem, og den bunke de hører i.

   Teksten skal matche _konverterings_note i
   rpa-befordring-konvertering-af-ppr-sager PRÆCIST — inklusive tankestreg
   (—, ikke -) og æ/ø/å. Del 4 fanger det, hvis en af dem er skrevet forkert
   her: emnet findes i databasen, men ikke i listen.
------------------------------------------------------------ */

IF OBJECT_ID('tempdb..#emner') IS NOT NULL DROP TABLE #emner;

SELECT v.emne, v.kategori, v.sortering
INTO   #emner
FROM (VALUES
    -- Klub: det gamle system havde ikke klubkørsel, så klubben er skrevet
    -- ind i felterne. Bevillingen ligger på elevens egen adresse.
    (N'klub kan indgå i befordringen',                N'1. Klubkørsel',                      1),

    -- Kommentaren nævner et hjælpemiddel eller et tillæg, som det gamle
    -- system ikke havde et felt til.
    (N'hjælpemiddel eller tillæg nævnt i kommentaren', N'2. Hjælpemiddel eller tillæg',       2),

    -- Adressen er GÆTTET: kilden passede ikke på nogen bolig, men alle
    -- boliger på vejnummeret ligger samme sted. Placeringen er rigtig,
    -- boligen skal rettes.
    (N'adresse antaget ud fra vej og postnummer',      N'3. Adresse gættet — bolig skal rettes', 3),
    (N'adresse antaget — manglende etage/dør',         N'3. Adresse gættet — bolig skal rettes', 3),

    -- Adressen er FUNDET, men ikke stavet ens. Normalisering af tegnsætning,
    -- stavemåde og etage/dør fandt den.
    (N'adressematch',                                  N'4. Adresse fundet med anden stavemåde', 4),

    -- Flere boliger passede; elevens egen registrerede adresse afgjorde det.
    (N'adresse rettet via CPR',                        N'5. Adresse afgjort via elevens CPR',  5),
    (N'adresse valgt via CPR',                         N'5. Adresse afgjort via elevens CPR',  5),
    (N'eneste adresse på vej og husnummer',            N'5. Adresse afgjort via elevens CPR',  5),

    -- Kilden havde ingen adresse, eller sagen var lukket: adressen kommer
    -- fra sagens øvrige rækker eller fra folkeregisteret.
    (N'adresse lånt fra sagen',                        N'6. Adresse hentet et andet sted fra', 6),
    (N'lukket sag — elevens nuværende adresse',        N'6. Adresse hentet et andet sted fra', 6),

    -- BevillingFra lå efter BevillingTil; datoerne er byttet om.
    (N'byttede datoer',                                N'7. Datoer byttet om',                 7),
    (N'lukket sag — byttede datoer',                   N'7. Datoer byttet om',                 7),

    -- Skolen kunne ikke udledes entydigt af rækkerne.
    (N'skole sat manuelt',                             N'8. Skole gættet eller sat manuelt',   8),
    (N'skoleafdeling gættet',                          N'8. Skole gættet eller sat manuelt',   8),

    -- Eleven fandtes ikke i elevdata; oprettet ud fra folkeregisteret med
    -- tomme skoleoplysninger.
    (N'eleven er oprettet ud fra folkeregisteret',     N'9. Elev oprettet fra folkeregister',  9)
) v (emne, kategori, sortering);


/* ------------------------------------------------------------
   Alle kørselsrækker med mindst én konverteringskommentar.

   Bevilling.aktiv = 1 og Koersel.aktiv = 1: en slettet række er væk for
   sagsbehandleren og skal ikke stå på listen.
------------------------------------------------------------ */

IF OBJECT_ID('tempdb..#raekker') IS NOT NULL DROP TABLE #raekker;

SELECT b.cpr_elev,
       b.esdh_noegle           AS ppr_sags_id,
       b.bevilling_id,
       b.loebenummer,
       s.status_tekst,
       k.koersel_id,
       k.gyldig_fra,
       k.gyldig_til,
       k.kommentar
INTO   #raekker
FROM       [befordring].[Bevilling] b
INNER JOIN [befordring].[Koersel]   k ON k.bevilling_id = b.bevilling_id
LEFT  JOIN [befordring].[Status]    s ON s.status_id    = b.status_id
WHERE b.aktiv = 1
  AND k.aktiv = 1
  AND k.kommentar LIKE N'%KONVERTERING-PPR%';


/* ============================================================
   1. Listen — én linje pr. elev, sag og kategori
============================================================ */

SELECT   STUFF(r.cpr_elev, 7, 0, '-')     AS cpr,
         r.ppr_sags_id,
         e.adresseringsnavn               AS elev_navn,
         em.kategori,
         em.emne,
         COUNT(DISTINCT r.koersel_id)     AS antal_koerselsraekker,
         COUNT(DISTINCT r.bevilling_id)   AS antal_bevillinger,
         MIN(r.gyldig_fra)                AS tidligste_fra,
         MAX(r.gyldig_til)                AS seneste_til,
         MAX(r.status_tekst)              AS status
FROM     #raekker r
JOIN     #emner   em ON r.kommentar LIKE N'%KONVERTERING-PPR | ' + em.emne + N'%'
LEFT JOIN [befordring].[Elev] e ON e.cpr = r.cpr_elev
GROUP BY r.cpr_elev, r.ppr_sags_id, e.adresseringsnavn, em.kategori, em.emne, em.sortering
ORDER BY em.sortering, em.emne, r.cpr_elev;


/* ============================================================
   2. Hvor stor er hver bunke
============================================================ */

SELECT   em.kategori,
         COUNT(DISTINCT r.cpr_elev)     AS antal_elever,
         COUNT(DISTINCT r.ppr_sags_id)  AS antal_sager,
         COUNT(DISTINCT r.bevilling_id) AS antal_bevillinger,
         COUNT(DISTINCT r.koersel_id)   AS antal_koerselsraekker
FROM     #raekker r
JOIN     #emner   em ON r.kommentar LIKE N'%KONVERTERING-PPR | ' + em.emne + N'%'
GROUP BY em.kategori, em.sortering
ORDER BY em.sortering;


/* ============================================================
   3. Det finere niveau — pr. emne
============================================================ */

SELECT   em.kategori,
         em.emne,
         COUNT(DISTINCT r.cpr_elev)   AS antal_elever,
         COUNT(DISTINCT r.koersel_id) AS antal_koerselsraekker
FROM     #raekker r
JOIN     #emner   em ON r.kommentar LIKE N'%KONVERTERING-PPR | ' + em.emne + N'%'
GROUP BY em.kategori, em.emne, em.sortering
ORDER BY em.sortering, em.emne;


/* ============================================================
   4. Kontrol — kommentarer som intet kendt emne dækker

   Skal give NUL rækker. En række her betyder enten et nyt emne i
   konverteringen, eller at et emne er stavet forkert i listen øverst. Begge
   dele ville ellers skjule sagerne for sagsbehandlerne.

   De første 200 tegn er nok til at se emnelinjen.
============================================================ */

SELECT   STUFF(r.cpr_elev, 7, 0, '-') AS cpr,
         r.ppr_sags_id,
         r.koersel_id,
         LEFT(r.kommentar, 200) AS kommentar_start
FROM     #raekker r
WHERE    NOT EXISTS (
             SELECT 1
             FROM   #emner em
             WHERE  r.kommentar LIKE N'%KONVERTERING-PPR | ' + em.emne + N'%'
         )
ORDER BY r.cpr_elev, r.koersel_id;


DROP TABLE #raekker;
DROP TABLE #emner;
