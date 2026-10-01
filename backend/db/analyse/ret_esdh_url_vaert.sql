/* ============================================================
   Ret værtsnavnet i esdh_url

   Linkene blev bygget af GO's API-vært i stedet for den sagsbehandlerne
   bruger:

       forkert   https://ad.go.aarhuskommune.dk/cases/PPR01/PPR-2026-123456/SitePages/Home.aspx
       rigtig    https://go.aarhuskommune.dk/cases/PPR01/PPR-2026-123456/SitePages/Home.aspx

   ad.go er API'et — RPA'ens konto kan nå den, en sagsbehandler kan ikke. Stien
   er den samme på begge værter, så det er kun værtsnavnet der skal skiftes.
   Det per-sag-system-id (PPR01) bevares, og ingen sag slås op igen.

   Det natlige job retter dem ikke selv: det udfylder kun rækker hvor esdh_url
   er NULL, og rører aldrig en der allerede har en værdi.

   Del 1 læser kun. Del 2 skriver, i en transaktion der ROLLBACK'er som
   standard.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @forkert NVARCHAR(100) = N'https://ad.go.aarhuskommune.dk/';
DECLARE @rigtig  NVARCHAR(100) = N'https://go.aarhuskommune.dk/';

/* Hvor mange må rettes i denne kørsel.

   1 = prøve: ret ét link, åbn det i browseren som sagsbehandler, og kør igen.
   NULL = ingen grænse.

   Grænsen gælder både forhåndsvisningen og rettelsen, og begge sorterer ens,
   så den række man kigger på ER den der bliver rettet. Rækker der allerede er
   rettet, matcher ikke mere, så en gentagen kørsel tager den næste. */
DECLARE @maks_antal INT = 1;        -- sæt til NULL når prøven ser rigtig ud


/* ============================================================
   1. Hvor mange, og hvordan ser de ud
============================================================ */

SELECT COUNT(*) AS med_forkert_vaert
FROM   [befordring].[Bevilling]
WHERE  aktiv = 1 AND esdh_url LIKE @forkert + N'%';

SELECT TOP (ISNULL(@maks_antal, 20))
       bevilling_id,
       esdh_noegle,
       esdh_url                                   AS nuvaerende,
       REPLACE(esdh_url, @forkert, @rigtig)       AS bliver_til
FROM   [befordring].[Bevilling]
WHERE  aktiv = 1 AND esdh_url LIKE @forkert + N'%'
ORDER  BY bevilling_id;

/* Skal give NUL rækker: andre værter end de to kendte. Kommer der noget her,
   så se på dem før del 2 køres — de bliver ikke rettet. */
SELECT bevilling_id, esdh_url
FROM   [befordring].[Bevilling]
WHERE  aktiv = 1
AND    esdh_url IS NOT NULL
AND    esdh_url NOT LIKE @forkert + N'%'
AND    esdh_url NOT LIKE @rigtig  + N'%';


/* ============================================================
   2. Rettelsen — ROLLBACK som standard
============================================================ */

BEGIN TRANSACTION;

    PRINT CASE
              WHEN @maks_antal IS NULL
              THEN 'Kører UDEN graense — alle forkerte links rettes.'
              ELSE CONCAT('PROEVEKOERSEL — hoejst ', @maks_antal, ' link(s) rettes.')
          END;

    /* Samme udvalg og samme sortering som forhåndsvisningen ovenfor. */
    IF OBJECT_ID('tempdb..#rettes') IS NOT NULL DROP TABLE #rettes;

    SELECT TOP (ISNULL(@maks_antal, 2147483647)) bevilling_id
    INTO   #rettes
    FROM   [befordring].[Bevilling]
    WHERE  aktiv = 1 AND esdh_url LIKE @forkert + N'%'
    ORDER  BY bevilling_id;

    UPDATE b
    SET    b.esdh_url   = REPLACE(b.esdh_url, @forkert, @rigtig),
           b.updated_by = 'ret_esdh_url_vaert',
           b.updated_at = GETDATE()
    FROM   [befordring].[Bevilling] b
    JOIN   #rettes r ON r.bevilling_id = b.bevilling_id;

    PRINT CONCAT('Rettet: ', @@ROWCOUNT, ' link(s).');

    /* Kontrol inde i transaktionen */
    SELECT b.bevilling_id, b.esdh_noegle, b.esdh_url
    FROM   [befordring].[Bevilling] b
    JOIN   #rettes r ON r.bevilling_id = b.bevilling_id
    ORDER  BY b.bevilling_id;

    DROP TABLE #rettes;

    SELECT COUNT(*) AS tilbage_med_forkert_vaert
    FROM   [befordring].[Bevilling]
    WHERE  aktiv = 1 AND esdh_url LIKE @forkert + N'%';

PRINT '';
PRINT 'ROLLBACK er aktiv. Skift til COMMIT naar del 1 og kontrollen ser rigtige ud.';
PRINT '';

ROLLBACK TRANSACTION;
