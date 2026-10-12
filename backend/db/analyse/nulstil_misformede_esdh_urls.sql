/* ============================================================
   Nulstil esdh_url der indeholder en given tekst

   Teksten sættes i @url_tekst nedenfor. Den matches som ren tekst, ikke
   som mønster, så den kan være hvad som helst:

     - et fragment, fx  &CcmNoRedirect=true
       -> rammer ALLE bevillinger, hvis URL indeholder det
     - en hel URL, kopieret fra en konkret bevilling
       -> rammer kun den ene

   Udgangspunktet er &CcmNoRedirect=true. Den parameter hører ikke hjemme
   i det link, der gemmes på bevillingen, og et link med den i åbner ikke
   sagen rigtigt i GO.

   Rettelsen er at sætte esdh_url = NULL frem for at forsøge at klippe
   parameteren væk: rpa-befordring-kontrol slår alligevel linket op igen.
   Dens kø-forespørgsel (BevillingService.get_bevillinger_uden_esdh) tager
   enhver aktiv bevilling, hvor esdh_noegle ELLER esdh_url er tom —

       NULLIF(LTRIM(RTRIM(b.esdh_url)), '') IS NULL

   — så en nulstillet URL er nok til, at rækken kommer med i næste kørsel.
   esdh_noegle røres IKKE: den er rigtig, og den er det, RPA'en slår op på.

   Scriptet ROLLBACKER. Skift ROLLBACK til COMMIT nederst, når del 1 ser
   rigtig ud — det er det manuelle skridt, der ændrer noget.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* ---------------------------------------------------------------------
   SÆT TEKSTEN HER. Alt andet i scriptet læser den.
   --------------------------------------------------------------------- */
DECLARE @url_tekst nvarchar(500) = N'&CcmNoRedirect=true';


/* Matchet er CHARINDEX og ikke LIKE, netop fordi feltet ovenfor er rå
   tekst: en URL kan indeholde % (procent-kodning), _ og [, og LIKE ville
   læse dem som jokertegn. CHARINDEX tager strengen, som den står.

   Tom tekst ville ramme hver eneste bevilling med en URL — CHARINDEX('')
   giver 1 — så den mulighed lukkes her frem for i tre WHERE-sætninger. */
IF NULLIF(LTRIM(RTRIM(@url_tekst)), N'') IS NULL
BEGIN
    RAISERROR(N'@url_tekst er tom — saet den til det, der skal soeges efter.', 16, 1);
    RETURN;
END


BEGIN TRANSACTION;

/* ------------------------------------------------------------
   1. Hvad bliver nulstillet — før
------------------------------------------------------------ */
SELECT
    STUFF(b.cpr_elev, 7, 0, '-')  AS cpr,
    e.adresseringsnavn,
    b.bevilling_id,
    b.loebenummer,
    st.status_tekst               AS bevilling_status,
    b.esdh_noegle,
    b.esdh_url
FROM       [befordring].[Bevilling] b
LEFT  JOIN [befordring].[Elev]      e  ON e.cpr        = b.cpr_elev
LEFT  JOIN [befordring].[Status]    st ON st.status_id = b.status_id
WHERE  b.aktiv = 1
  AND  CHARINDEX(@url_tekst, b.esdh_url) > 0
ORDER BY b.bevilling_id;


/* ------------------------------------------------------------
   2. Nulstillingen
------------------------------------------------------------ */
UPDATE [befordring].[Bevilling]
SET    esdh_url = NULL
WHERE  aktiv = 1
  AND  CHARINDEX(@url_tekst, esdh_url) > 0;

PRINT CONCAT('Bevilling: ', @@ROWCOUNT, ' esdh_url nulstillet.');


/* ------------------------------------------------------------
   3. Kontrol

   fundet_tilbage bør være 0. venter_paa_rpa er hele køen, RPA'en
   samler op næste gang den kører — altså inklusive dem, der i forvejen
   manglede nøgle eller link.
------------------------------------------------------------ */
SELECT
    (SELECT COUNT(*) FROM [befordring].[Bevilling]
     WHERE aktiv = 1 AND CHARINDEX(@url_tekst, esdh_url) > 0)      AS fundet_tilbage,
    (SELECT COUNT(*) FROM [befordring].[Bevilling]
     WHERE aktiv = 1
       AND (NULLIF(LTRIM(RTRIM(esdh_noegle)), '') IS NULL
         OR NULLIF(LTRIM(RTRIM(esdh_url)), '') IS NULL))           AS venter_paa_rpa;


PRINT '';
PRINT 'ROLLBACK er aktiv — intet er aendret. Skift til COMMIT for at gennemfoere.';
PRINT '';

ROLLBACK TRANSACTION;
