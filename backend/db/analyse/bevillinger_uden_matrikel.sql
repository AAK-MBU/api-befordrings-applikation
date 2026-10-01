/* ============================================================
   Bevillinger der stadig mangler en matrikel

   Én linje pr. bevilling, med det kildedata i BefordringsData som skulle have
   udpeget skolen. Til at rydde op i hånden efter backfillen: kolonnerne er
   dem, man skal bruge for at kunne afgøre hvilken skole det er.

   Sagens rækker slås sammen, fordi de næsten altid siger det samme. Hvor de
   IKKE gør, står alle varianterne i samme felt adskilt af " | " — og så er
   uenigheden mellem rækkerne selve svaret på hvorfor den ikke kunne afgøres
   automatisk.

   Læser kun.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;

SELECT
    b.bevilling_id,
    STUFF(b.cpr_elev, 7, 0, '-')                  AS cpr,
    b.esdh_noegle                                 AS case_id,
    e.adresseringsnavn                            AS elev_navn,
    s.status_tekst                                AS status,

    -- Kilden, som den står. Tomme felter vises som (tom), så en manglende
    -- værdi ikke ser ud som en manglende række.
    ISNULL(kilde.skoleid,             '(tom)')    AS skoleid,
    ISNULL(kilde.skolenavnbefordring, '(tom)')    AS skolenavnbefordring,
    ISNULL(kilde.skolensadresse,      '(tom)')    AS skolensadresse

FROM        [befordring].[Bevilling] b
LEFT  JOIN  [befordring].[Elev]      e ON e.cpr       = b.cpr_elev
LEFT  JOIN  [befordring].[Status]    s ON s.status_id = b.status_id
OUTER APPLY (
    SELECT
        COUNT(*)                                                   AS antal_kilderaekker,
        -- Alle tre sorteres efter den SAMME nøgle. SQL Server tillader ikke
        -- flere ordered aggregates med hver sin ORDER BY i samme scope
        -- (Msg 8711), og nøglen holder rækkefølgen ens på tværs af de tre
        -- kolonner, så felt nr. 2 i den ene svarer til felt nr. 2 i de andre.
        STRING_AGG(d.[SkoleID], ' | ')             WITHIN GROUP (ORDER BY d.sorteringsnoegle)
                                                                   AS skoleid,
        STRING_AGG(d.[SkoleNavnBefordring], ' | ') WITHIN GROUP (ORDER BY d.sorteringsnoegle)
                                                                   AS skolenavnbefordring,
        STRING_AGG(d.[SkolensAdresse], ' | ')      WITHIN GROUP (ORDER BY d.sorteringsnoegle)
                                                                   AS skolensadresse
    FROM (
        -- DISTINCT først: en sag har typisk flere rækker med de samme
        -- skolekolonner, og den samme tekst gentaget fem gange gør kun
        -- linjen ulæselig. 
        SELECT DISTINCT
            NULLIF(LTRIM(RTRIM(bd.[SkoleID])), '')             AS [SkoleID],
            NULLIF(LTRIM(RTRIM(bd.[SkoleNavnBefordring])), '') AS [SkoleNavnBefordring],
            NULLIF(LTRIM(RTRIM(bd.[SkolensAdresse])), '')      AS [SkolensAdresse],
            -- Udledt af de samme tre kolonner, så DISTINCT giver præcis de
            -- samme rækker som uden den.
            CONCAT(
                ISNULL(LTRIM(RTRIM(bd.[SkoleNavnBefordring])), ''), '~',
                ISNULL(LTRIM(RTRIM(bd.[SkolensAdresse])), ''),      '~',
                ISNULL(LTRIM(RTRIM(bd.[SkoleID])), '')
            )                                                  AS sorteringsnoegle
        FROM [RPA].[rpa].[BefordringsData] bd
        WHERE bd.[CaseID] = b.esdh_noegle
    ) d
) kilde
WHERE b.aktiv = 1
  AND b.matrikel_id IS NULL
  AND b.ungdomsuddannelse_id IS NULL    -- ungdomsuddannelser har ingen matrikel
ORDER BY
    -- Dem uden kildedata overhovedet øverst: de kan ikke løses herfra og
    -- skal findes et andet sted.
    CASE WHEN kilde.antal_kilderaekker IS NULL THEN 0 ELSE 1 END,
    kilde.skolenavnbefordring,
    b.bevilling_id;
