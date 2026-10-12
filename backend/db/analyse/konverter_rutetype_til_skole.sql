/* ============================================================
   Konverter "Til skole" -> "Fra hjem til skole"

   Den ene af de gamle rutetyper, der kan flyttes maskinelt. En tur TIL
   skole kan kun være begyndt hjemme, så der er ikke noget at vælge
   imellem — i modsætning til "Til hjem", der kan komme fra både skole og
   klub, og som derfor bliver stående, til en sagsbehandler har taget
   stilling. Se db/analyse/koerselsraekker_med_gammel_rutetype.sql.

   "Til klub" er lige så entydig ("Fra skole til klub"), men er bevidst
   IKKE med her. Den køres for sig, når I er klar.

   OMFANG: alle aktive kørselsrækker med "Til skole", uanset bevillingens
   status. Det er en ren omdøbning af den samme rute, så den gælder også
   bagud — og bliver de gamle rækker stående, står der to navne for den
   samme ting i systemet på ubestemt tid. Vil I hellere kun rette dem,
   sagsbehandlerne ser på listen, så sæt @kun_ikke_udloebne = 1 nedenfor.

   Soft-deletede rækker (aktiv = 0) røres ikke. De er historik, og de
   vises ingen steder.

   @antal styrer hvor mange rækker der rettes, og står på 1. Tag den ene
   først, kig på den i UI'et, og skru så op. Sæt @antal = NULL for resten.
   Udvælgelsen er sorteret på koersel_id, så del 1 viser PRÆCIS de rækker,
   del 2 retter — ikke et tilfældigt udsnit af de samme kandidater.

   Scriptet ROLLBACKER. Skift ROLLBACK til COMMIT nederst, når del 1 og 2
   ser rigtige ud — det er det manuelle skridt, der ændrer noget.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* Hvor mange rækker der rettes. 1 for en prøvetur, NULL for dem alle. */
DECLARE @antal int = 1;

/* Sæt til 1 for kun at rette rækker på bevillinger, der ikke er udløbet. */
DECLARE @kun_ikke_udloebne bit = 0;

DECLARE @fra_tekst nvarchar(255) = N'Til skole';
DECLARE @til_tekst nvarchar(255) = N'Fra hjem til skole';

DECLARE @fra_id int = (SELECT TOP 1 rutetype_id FROM [befordring].[Rutetype]
                       WHERE LTRIM(RTRIM(rutetype_tekst)) = @fra_tekst ORDER BY rutetype_id);
DECLARE @til_id int = (SELECT TOP 1 rutetype_id FROM [befordring].[Rutetype]
                       WHERE LTRIM(RTRIM(rutetype_tekst)) = @til_tekst ORDER BY rutetype_id);

/* Stop hellere end at ramme forbi: mangler måltypen, er migration 032 ikke
   kørt på denne database, og en UPDATE ville sætte rutetype_id = NULL. */
IF @til_id IS NULL
BEGIN
    RAISERROR(N'"Fra hjem til skole" findes ikke i Rutetype — kør migration 032 foerst.', 16, 1);
    RETURN;
END

IF @fra_id IS NULL
BEGIN
    PRINT '"Til skole" findes ikke i Rutetype — der er intet at konvertere.';
    RETURN;
END


BEGIN TRANSACTION;

/* ------------------------------------------------------------
   1. Hvad bliver rettet — før

   Samme TOP og samme ORDER BY som del 2, så de to ser på de samme rækker.
   Antallet af kandidater i alt står i del 3.
------------------------------------------------------------ */
SELECT TOP (ISNULL(@antal, 2147483647))
    STUFF(e.cpr, 7, 0, '-')  AS cpr,
    e.adresseringsnavn,
    b.bevilling_id,
    b.loebenummer,
    st.status_tekst          AS bevilling_status,
    k.koersel_id,
    k.gyldig_fra,
    k.gyldig_til,
    bt.befordringstype_tekst AS koerselstype,
    k.final                  AS raekke_laast
FROM       [befordring].[Koersel]          k
INNER JOIN [befordring].[Bevilling]        b  ON b.bevilling_id = k.bevilling_id AND b.aktiv = 1
INNER JOIN [befordring].[Elev]             e  ON e.cpr          = b.cpr_elev
INNER JOIN [befordring].[Status]           st ON st.status_id   = b.status_id
LEFT  JOIN [befordring].[Befordringstype]  bt ON bt.befordringstype_id = k.befordringstype_id
WHERE  k.aktiv       = 1
  AND  k.rutetype_id = @fra_id
  AND  (@kun_ikke_udloebne = 0 OR st.status_tekst <> N'Udløbet')
ORDER BY k.koersel_id;


/* ------------------------------------------------------------
   2. Rettelsen

   Bevidst UDEN hensyn til k.final: en låst kørselsrække er låst mod
   sagsbehandling, ikke mod en omdøbning af den rute, den allerede
   beskriver. Indholdet er det samme bagefter.
------------------------------------------------------------ */
WITH maal AS (
    SELECT TOP (ISNULL(@antal, 2147483647))
           k.rutetype_id
    FROM       [befordring].[Koersel]   k
    INNER JOIN [befordring].[Bevilling] b  ON b.bevilling_id = k.bevilling_id AND b.aktiv = 1
    INNER JOIN [befordring].[Status]    st ON st.status_id   = b.status_id
    WHERE  k.aktiv       = 1
      AND  k.rutetype_id = @fra_id
      AND  (@kun_ikke_udloebne = 0 OR st.status_tekst <> N'Udløbet')
    -- Samme sortering som del 1. Uden den ville TOP tage en vilkårlig
    -- delmængde, og forhåndsvisningen ville vise andre rækker end dem,
    -- der blev rettet.
    ORDER BY k.koersel_id
)
UPDATE maal
SET    rutetype_id = @til_id;

PRINT CONCAT('Koersel: ', @@ROWCOUNT, ' raekke(r) flyttet til "Fra hjem til skole".');


/* ------------------------------------------------------------
   3. Hvad står tilbage på gamle rutetyper

   Med @antal = 1 står "Til skole" stadig med resten — det er meningen.
   Tallet her er, hvad der er tilbage at køre igennem.
   "Til klub" og "Til hjem" står der stadig — den første med vilje, den
   anden fordi den kræver en beslutning.
------------------------------------------------------------ */
SELECT
    r.rutetype_tekst,
    r.aktiv,
    r.sorteringsorden,
    COUNT(k.koersel_id) AS aktive_raekker
FROM       [befordring].[Rutetype] r
LEFT  JOIN [befordring].[Koersel]  k  ON k.rutetype_id = r.rutetype_id AND k.aktiv = 1
LEFT  JOIN [befordring].[Bevilling] b ON b.bevilling_id = k.bevilling_id AND b.aktiv = 1
GROUP BY r.rutetype_tekst, r.aktiv, r.sorteringsorden
ORDER BY CASE WHEN r.sorteringsorden IS NULL THEN 1 ELSE 0 END,
         r.sorteringsorden,
         r.rutetype_tekst;


PRINT '';
PRINT 'ROLLBACK er aktiv — intet er aendret. Skift til COMMIT for at gennemfoere.';
PRINT '';

ROLLBACK TRANSACTION;
