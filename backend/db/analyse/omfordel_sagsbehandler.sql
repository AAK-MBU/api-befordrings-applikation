/* ============================================================
   Flyt bevillinger fra én sagsbehandler til en anden

   FRA: sagsbehandler_id 56, eller en sagsbehandler hvis navn starter med
        "Morten"
   TIL: sagsbehandler_id 59, som skal være den der hedder "Sofie…"

   Både id og navn er med, fordi de to kan være ude af trit: står der mere end
   én Morten i tabellen, eller er 56 en helt anden end forventet, skal det ses
   FØR der skrives — ikke opdages bagefter. Del 1 viser hvem de to numre rent
   faktisk er, og del 2 viser hvad der ville blive flyttet.

   Del 1-2 læser kun. Del 3 skriver, i en transaktion der ROLLBACK'er som
   standard: skift den sidste linje til COMMIT, når del 1 og 2 ser rigtige ud.

   Bemærk: den her vej uden om applikationen skriver IKKE et sagsforløb, som
   en sagsbehandler der retter feltet i brugerfladen ville. Del 3 gør det
   derfor selv, så historikken ikke tier om en masseflytning.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;
SET XACT_ABORT ON;


/* ------------------------------------------------------------
   Hvor mange må flyttes i denne kørsel

   1 = prøvekørsel: flyt én bevilling, kig på den i brugerfladen, og kør
   igen. Scriptet rører aldrig en bevilling der allerede står på 59, så
   gentagne kørsler tager den næste og ikke den samme.

   NULL = ingen grænse, flyt dem alle.

   Grænsen gælder BÅDE del 2 (hvad ville blive flyttet) og del 3, så
   forhåndsvisningen viser præcis den række der bliver rørt.
------------------------------------------------------------ */

DECLARE @maks_antal INT = NULL;     -- 1 for en prøvekørsel, NULL for alle


/* ============================================================
   1. Hvem er de to numre — og er der flere Morten'er?
============================================================ */

SELECT   sb.sagsbehandler_id,
         sb.sagsbehandler_tekst,
         sb.aktiv,
         CASE
             WHEN sb.sagsbehandler_id = 56                  THEN 'FRA (id 56)'
             WHEN sb.sagsbehandler_id = 59                  THEN 'TIL (id 59)'
             WHEN sb.sagsbehandler_tekst LIKE 'Morten%'     THEN 'FRA (navn Morten%)'
             WHEN sb.sagsbehandler_tekst LIKE 'Sofie%'      THEN 'TIL (navn Sofie%)'
         END                                                AS rolle,
         (SELECT COUNT(*)
          FROM   [befordring].[Bevilling] b
          WHERE  b.sagsbehandler_id = sb.sagsbehandler_id
          AND    b.aktiv = 1)                               AS antal_bevillinger
FROM     [befordring].[Sagsbehandler] sb
WHERE    sb.sagsbehandler_id IN (56, 59)
OR       sb.sagsbehandler_tekst LIKE 'Morten%'
OR       sb.sagsbehandler_tekst LIKE 'Sofie%'
ORDER BY rolle, sb.sagsbehandler_tekst;


/* ============================================================
   2. Hvad bliver flyttet
============================================================ */

SELECT   TOP (ISNULL(@maks_antal, 2147483647))
         b.bevilling_id,
         STUFF(b.cpr_elev, 7, 0, '-')      AS cpr,
         e.adresseringsnavn                AS elev_navn,
         b.esdh_noegle                     AS sags_nummer,
         s.status_tekst                    AS status,
         fra.sagsbehandler_id              AS fra_id,
         fra.sagsbehandler_tekst           AS fra_navn
FROM        [befordring].[Bevilling]      b
INNER JOIN  [befordring].[Sagsbehandler]  fra ON fra.sagsbehandler_id = b.sagsbehandler_id
LEFT  JOIN  [befordring].[Elev]           e   ON e.cpr       = b.cpr_elev
LEFT  JOIN  [befordring].[Status]         s   ON s.status_id = b.status_id
WHERE b.aktiv = 1
  AND (b.sagsbehandler_id = 56 OR fra.sagsbehandler_tekst LIKE 'Morten%')
  AND b.sagsbehandler_id <> 59          -- rør ikke dem der allerede er flyttet
-- Samme sortering som del 3, ellers kan TOP (1) vise én række og flytte en anden.
ORDER BY b.bevilling_id;


/* ============================================================
   3. Selve flytningen — ROLLBACK som standard
============================================================ */

BEGIN TRANSACTION;

    PRINT CASE
              WHEN @maks_antal IS NULL
              THEN 'Kører UDEN graense — alle matchende bevillinger flyttes.'
              ELSE CONCAT('PRØVEKØRSEL — højst ', @maks_antal, ' bevilling(er) flyttes.')
          END;

    /* Modtageren skal findes, og id 59 skal være den Sofie der menes.
       Uden det her ville en forkert antagelse flytte alt til et id, der
       måske slet ikke er hende. */
    IF NOT EXISTS (
        SELECT 1 FROM [befordring].[Sagsbehandler]
        WHERE  sagsbehandler_id = 59 AND sagsbehandler_tekst LIKE 'Sofie%'
    )
    BEGIN
        ROLLBACK TRANSACTION;

        RAISERROR(
            N'STOPPET: sagsbehandler_id 59 findes ikke, eller hedder ikke noget med Sofie. Se del 1 og ret id''et i scriptet.',
            16, 1
        );

        RETURN;
    END;

    /* Rækkerne der flyttes, gemt først: efter UPDATE kan de ikke findes igen,
       og sagsforløbet nedenfor skal vide hvem de var. */
    IF OBJECT_ID('tempdb..#flyttes') IS NOT NULL DROP TABLE #flyttes;

    SELECT      TOP (ISNULL(@maks_antal, 2147483647))
                b.bevilling_id, b.cpr_elev, fra.sagsbehandler_tekst AS fra_navn
    INTO        #flyttes
    FROM        [befordring].[Bevilling]     b
    INNER JOIN  [befordring].[Sagsbehandler] fra ON fra.sagsbehandler_id = b.sagsbehandler_id
    WHERE  b.aktiv = 1
      AND (b.sagsbehandler_id = 56 OR fra.sagsbehandler_tekst LIKE 'Morten%')
      AND  b.sagsbehandler_id <> 59
    ORDER BY b.bevilling_id;        -- samme rækkefølge som del 2

    UPDATE b
    SET    b.sagsbehandler_id = 59,
           b.updated_by       = 'omfordel_sagsbehandler',
           b.updated_at       = GETDATE()
    FROM   [befordring].[Bevilling] b
    JOIN   #flyttes f ON f.bevilling_id = b.bevilling_id;

    PRINT CONCAT('Flyttet: ', @@ROWCOUNT, ' bevilling(er).');

    /* Sagsforløb, som applikationen selv ville have skrevet.
       aktivitetstype_id slås op, så rækkerne ser ud som dem brugerfladen
       laver; findes koden ikke (migration 023 ikke kørt), bliver den NULL og
       feedet falder tilbage på teksten. */
    INSERT INTO [befordring].[Sagsaktivitet]
        (cpr, aktivitetstype, aktivitetstype_id, kommentar, udfoert_af,
         oprettet_tidspunkt, relateret_bevilling_id)
    SELECT f.cpr_elev,
           N'Sagsbehandler opdateret',
           (SELECT type_id FROM [befordring].[SagsaktivitetType]
            WHERE  type_kode = N'sagsbehandler_opdateret'),
           CONCAT(N'Sagsbehandler ændret fra ', f.fra_navn, N' til ',
                  (SELECT sagsbehandler_tekst FROM [befordring].[Sagsbehandler]
                   WHERE sagsbehandler_id = 59)),
           N'System',
           GETDATE(),
           f.bevilling_id
    FROM   #flyttes f;

    PRINT CONCAT('Sagsforløb: ', @@ROWCOUNT, ' række(r) skrevet.');

    /* Kontrol inde i transaktionen */
    SELECT b.bevilling_id, STUFF(b.cpr_elev, 7, 0, '-') AS cpr,
           f.fra_navn, sb.sagsbehandler_tekst AS til_navn
    FROM   #flyttes f
    JOIN   [befordring].[Bevilling]     b  ON b.bevilling_id    = f.bevilling_id
    JOIN   [befordring].[Sagsbehandler] sb ON sb.sagsbehandler_id = b.sagsbehandler_id
    ORDER  BY b.bevilling_id;

    DROP TABLE #flyttes;

PRINT '';
PRINT 'ROLLBACK er aktiv. Skift til COMMIT når del 1, 2 og kontrollen ser rigtige ud.';
PRINT '';

ROLLBACK TRANSACTION;
