/* ============================================================
   Genbehandlingssager med KUN skolerejsekort, hvor skolekoden ikke passer

   Bestilt som udtræk: genbehandlingssager hvor bevillingen udelukkende består
   af skolerejsekort, og hvor bevillingens skole ikke er den skole, eleven
   aktuelt er registreret på.

   Udtrækket tager ALLE sager med mindst én skolerejsekort-række og lader
   kolonnen kun_skolerejsekort skelne, frem for at vælge fortolkningen på
   bestillerens vegne:

       kun_skolerejsekort = 'ja'   bevillingen består udelukkende af
                                   skolerejsekort — det bestillingen ordret
                                   beder om
       kun_skolerejsekort = 'nej'  der er også andre kørselstyper på
                                   bevillingen; hvilke står i
                                   oevrige_koerselstyper

   Sorteringen lægger 'ja' øverst, så den smalle læsning kan læses direkte, og
   den brede er der, hvis det var den, der var ment. Filtrér på kolonnen i
   Excel for kun at få den ene.

   Skolekode-uoverensstemmelsen er defineret præcis som i
   usp_recalculate_bevilling_status, så udtrækket viser de samme sager som
   Genbehandlingssiden og ikke en nabogruppe:

       b.matrikel_id IS NOT NULL
       AND ISNULL(e.skolekode, 0) <> 0
       AND e.skolekode <> sm.skolekode

   Bemærk at genbehandling også rejses af ADRESSE-uoverensstemmelse. Sager der
   kun er flaggede på adressen falder ud her, fordi der spørges til skolekoden.
   Kolonnen adresse_matcher viser, om der OGSÅ er en adresseafvigelse.

   Kun læsning.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;

SELECT
    e.adresseringsnavn                              AS elev,
    b.cpr_elev,
    b.bevilling_id,
    b.esdh_noegle                                   AS sags_id,
    s.status_tekst                                  AS bevilling_status,
    sb.sagsbehandler_tekst                          AS sagsbehandler,
    ppr.ppr_sagsbehandler_tekst                     AS ppr_ansvarlig,

    /* Hvilken skole bevillingen peger på, og hvilken eleven står på nu. */
    sm.matrikel_navn                                AS bevillingens_skole,
    sm.skolekode                                    AS bevillingens_skolekode,
    e.skolekode                                     AS elevens_skolekode,
    sm_elev.matrikel_navn                           AS elevens_skole,

    CASE WHEN k.antal_raekker = k.antal_skolerejsekort
         THEN N'ja' ELSE N'nej' END                 AS kun_skolerejsekort,
    k.antal_raekker                                 AS antal_koerselsraekker,
    k.antal_skolerejsekort,
    k.oevrige_koerselstyper,
    k.tidligste_fra,
    k.seneste_til,

    /* Er sagen også flagget på adressen? Samme definition som proceduren. */
    CASE WHEN b.adresse_id IS NOT NULL
          AND e.adresse_id IS NOT NULL
          AND b.adresse_id <> e.adresse_id
         THEN N'nej - adressen afviger også'
         ELSE N'ja' END                             AS adresse_matcher,

    b.genbehandling_bemaerkning,
    CASE WHEN ISNULL(b.genbehandling_haandteret, 0) = 1
         THEN N'markeret håndteret' ELSE N'åben' END AS haandtering

FROM       [befordring].[Bevilling]           b
INNER JOIN [befordring].[Elev]                e   ON e.cpr                    = b.cpr_elev
INNER JOIN [befordring].[Status]              s   ON s.status_id              = b.status_id
INNER JOIN [befordring].[Skolematrikel]       sm  ON sm.matrikel_id           = b.matrikel_id
LEFT  JOIN [befordring].[Skolematrikel]       sm_elev ON sm_elev.matrikel_id  = e.matrikel_id
LEFT  JOIN [befordring].[Sagsbehandler]       sb  ON sb.sagsbehandler_id      = b.sagsbehandler_id
LEFT  JOIN [befordring].[PPR_Sagsbehandler]   ppr ON ppr.ppr_sagsbehandler_id = b.ppr_sagsbehandler_id

/* Kørselsrækkerne samlet pr. bevilling. CROSS APPLY frem for et join med
   GROUP BY, så bevillingen ikke multipliceres af sine rækker. */
CROSS APPLY (
    SELECT
        COUNT(*)                                                     AS antal_raekker,
        /* Sammenlignes uden mellemrum — opslaget er ikke konsekvent med dem. */
        SUM(CASE WHEN REPLACE(bt.befordringstype_tekst, ' ', '') = 'Skolerejsekort'
                 THEN 1 ELSE 0 END)                                  AS antal_skolerejsekort,
        MIN(kk.gyldig_fra)                                           AS tidligste_fra,
        MAX(kk.gyldig_til)                                           AS seneste_til,
        /* Hvad der ELLERS er på bevillingen. DISTINCT via en undertabel,
           fordi STRING_AGG ikke kan tage det selv — ellers ville to
           rutekørselsrækker stå to gange. */
        (
            SELECT STRING_AGG(t.befordringstype_tekst, ', ')
            FROM (
                SELECT DISTINCT bt2.befordringstype_tekst
                FROM       [befordring].[Koersel]         k2
                INNER JOIN [befordring].[Befordringstype] bt2
                           ON bt2.befordringstype_id = k2.befordringstype_id
                WHERE  k2.bevilling_id = b.bevilling_id
                AND    k2.aktiv = 1
                AND    REPLACE(bt2.befordringstype_tekst, ' ', '') <> 'Skolerejsekort'
            ) t
        )                                                            AS oevrige_koerselstyper
    FROM       [befordring].[Koersel]          kk
    INNER JOIN [befordring].[Befordringstype]  bt ON bt.befordringstype_id = kk.befordringstype_id
    WHERE  kk.bevilling_id = b.bevilling_id
    AND    kk.aktiv = 1
) k

WHERE  b.aktiv = 1
AND    b.genbehandling = 1

/* Mindst én skolerejsekort-række. Om den er den ENESTE kørselstype afgøres
   af kolonnen kun_skolerejsekort, ikke her. */
AND    k.antal_skolerejsekort > 0

/* Skolekoden passer ikke. Samme tre betingelser som proceduren bruger. */
AND    ISNULL(e.skolekode, 0) <> 0
AND    e.skolekode <> sm.skolekode

ORDER BY
    /* Den snævre læsning først. */
    CASE WHEN k.antal_raekker = k.antal_skolerejsekort THEN 0 ELSE 1 END,
    e.adresseringsnavn;
