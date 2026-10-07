/* ============================================================
   Peg esdh_url på foranstaltningsmappen i stedet for PPR-sagen

   Linket åbnede basissagens forside. Sagsbehandlerne vil ind i selve
   befordringssagen, som er UNDERsagen:

       før    https://go.aarhuskommune.dk/cases/PPR01/PPR-2025-123456/SitePages/Home.aspx
       efter  https://go.aarhuskommune.dk/cases/PPR01/PPR-2025-123456/SubNav/SubCase.aspx
              ?FilterField1=CCMSubID&FilterValue1=006&CCMSubID=006

   Undersagsnummeret står i forvejen bagerst i esdh_noegle ("...-006"), og
   stien til sagen står i den URL der allerede er gemt. Derfor slås ingen sag
   op i GO igen — det er ren strengoperation på rækker vi allerede har.

   De to RPA'er retter dem ikke selv: både rpa-befordring-kontrol og
   rpa-befordring-nightly-runs udfylder kun rækker hvor esdh_url er NULL og
   rører aldrig en der allerede har en værdi. Samme grund som
   ret_esdh_url_vaert.sql findes.

   Kør ret_esdh_url_vaert.sql FØRST hvis der stadig findes ad.go-links — dette
   script skifter kun sidedelen og lader værten være.

   Del 1 læser kun. Del 2 skriver, i en transaktion der ROLLBACK'er som
   standard.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @gammel_side NVARCHAR(100) = N'/SitePages/Home.aspx';

/* Hvor mange må rettes i denne kørsel.

   1 = prøve: ret ét link, åbn det i browseren som sagsbehandler, og kør igen.
   NULL = ingen grænse.

   Grænsen gælder både forhåndsvisningen og rettelsen, og begge sorterer ens
   (cpr_elev, og bevilling_id som tiebreak — uden den sidste er rækkefølgen
   ikke entydig for en elev med flere bevillinger, og så kunne de to dele
   ramme hver sin række). Den række man kigger på ER altså den der bliver
   rettet. Rækker der allerede er rettet, matcher ikke mere, så en gentagen
   kørsel tager den næste. */
DECLARE @maks_antal INT = 1;        -- sæt til NULL når prøven ser rigtig ud


/* Kandidaterne, og den URL de skal have.

   Undersagsnummeret hentes som teksten efter den SIDSTE bindestreg i nøglen.
   CHARINDEX på den omvendte streng er den sædvanlige måde at finde den sidste
   forekomst i T-SQL.

   Betingelserne er bevidst snævre:
     - URL'en skal slutte på den gamle side, så en allerede rettet række
       (eller en helt anden form) ikke røres;
     - nøglen skal slutte på bindestreg + tre cifre, så der aldrig gættes et
       nummer. Uden det ville RIGHT() kunne hive et årstal eller et sagsnummer
       med over i URL'en. */
WITH kandidater AS (
    SELECT
        b.cpr_elev,
        b.bevilling_id,
        b.esdh_noegle,
        b.esdh_url                                      AS url_foer,
        RIGHT(
            b.esdh_noegle,
            CHARINDEX('-', REVERSE(b.esdh_noegle)) - 1
        )                                               AS undersag
    FROM   [befordring].[Bevilling] b
    WHERE  b.aktiv = 1
    AND    b.esdh_url  LIKE N'%' + @gammel_side
    AND    b.esdh_noegle LIKE N'%-[0-9][0-9][0-9]'
)
SELECT TOP (ISNULL(@maks_antal, 2147483647))
    cpr_elev,
    bevilling_id,
    esdh_noegle,
    undersag,
    url_foer,
    LEFT(url_foer, LEN(url_foer) - LEN(@gammel_side))
        + N'/SubNav/SubCase.aspx?FilterField1=CCMSubID&FilterValue1='
        + undersag + N'&CCMSubID=' + undersag          AS url_efter
FROM   kandidater
ORDER BY cpr_elev, bevilling_id;


/* ============================================================
   Del 2 — rettelsen. ROLLBACK står som standard: skift til COMMIT når
   forhåndsvisningen ovenfor ser rigtig ud.
============================================================ */

BEGIN TRANSACTION;

WITH kandidater AS (
    SELECT
        b.cpr_elev,
        b.bevilling_id,
        b.esdh_url,
        RIGHT(
            b.esdh_noegle,
            CHARINDEX('-', REVERSE(b.esdh_noegle)) - 1
        )  AS undersag
    FROM   [befordring].[Bevilling] b
    WHERE  b.aktiv = 1
    AND    b.esdh_url  LIKE N'%' + @gammel_side
    AND    b.esdh_noegle LIKE N'%-[0-9][0-9][0-9]'
),
udvalgte AS (
    SELECT TOP (ISNULL(@maks_antal, 2147483647)) bevilling_id, undersag
    FROM   kandidater
    ORDER BY cpr_elev, bevilling_id
)
/* Opdaterer basistabellen via et join frem for gennem CTE'en selv: samme
   rækker, men der er ingen tvivl om hvilken tabel der skrives i. */
UPDATE b
SET    esdh_url =
           LEFT(b.esdh_url, LEN(b.esdh_url) - LEN(@gammel_side))
           + N'/SubNav/SubCase.aspx?FilterField1=CCMSubID&FilterValue1='
           + u.undersag + N'&CCMSubID=' + u.undersag
FROM       [befordring].[Bevilling] b
INNER JOIN udvalgte u ON u.bevilling_id = b.bevilling_id;

PRINT CONCAT('Rækker rettet: ', @@ROWCOUNT);

ROLLBACK TRANSACTION;      -- skift til COMMIT TRANSACTION når prøven er god
