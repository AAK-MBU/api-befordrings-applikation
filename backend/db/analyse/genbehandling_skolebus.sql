/* ============================================================
   Skolebusbevillinger der står til genbehandling

   Bestilt som udtræk: alle bevillinger på Genbehandlingssiden, hvor der er
   skolebus med.

   Som i genbehandling_kun_skolerejsekort_skolekode_mismatch.sql afgøres det
   ikke på bestillerens vegne, om "skolebusbevilling" betyder udelukkende
   skolebus eller blot indeholder skolebus. Udtrækket tager alle med mindst én
   skolebusrække, og kolonnen kun_skolebus skiller dem ad:

       kun_skolebus = 'ja'   bevillingen består udelukkende af skolebus
       kun_skolebus = 'nej'  der er også andre kørselstyper; hvilke står i
                             oevrige_koerselstyper

   Genbehandling rejses af en uoverensstemmelse på enten SKOLEKODE eller
   ADRESSE mellem eleven og bevillingen. Begge dele vises, så det fremgår
   hvorfor sagen står der — en skolebusrute hænger sammen med både skole og
   bopæl, så de to årsager betyder noget forskelligt her.

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

    CASE WHEN k.antal_raekker = k.antal_skolebus
         THEN N'ja' ELSE N'nej' END                 AS kun_skolebus,
    k.antal_raekker                                 AS antal_koerselsraekker,
    k.antal_skolebus,
    k.oevrige_koerselstyper,
    k.tidligste_fra,
    k.seneste_til,

    /* Hvorfor sagen står til genbehandling. Samme to betingelser som
       usp_recalculate_bevilling_status bruger, så udtrækket viser de samme
       årsager som siden selv. */
    CASE WHEN b.matrikel_id IS NOT NULL
          AND ISNULL(e.skolekode, 0) <> 0
          AND e.skolekode <> sm.skolekode
         THEN N'ja' ELSE N'nej' END                 AS skolekode_afviger,
    CASE WHEN b.adresse_id IS NOT NULL
          AND e.adresse_id IS NOT NULL
          AND b.adresse_id <> e.adresse_id
         THEN N'ja' ELSE N'nej' END                 AS adresse_afviger,

    sm.matrikel_navn                                AS bevillingens_skole,
    sm.skolekode                                    AS bevillingens_skolekode,
    e.skolekode                                     AS elevens_skolekode,

    b.genbehandling_bemaerkning,
    CASE WHEN ISNULL(b.genbehandling_haandteret, 0) = 1
         THEN N'markeret håndteret' ELSE N'åben' END AS haandtering

FROM       [befordring].[Bevilling]          b
INNER JOIN [befordring].[Elev]               e   ON e.cpr                    = b.cpr_elev
INNER JOIN [befordring].[Status]             s   ON s.status_id              = b.status_id
LEFT  JOIN [befordring].[Skolematrikel]      sm  ON sm.matrikel_id           = b.matrikel_id
LEFT  JOIN [befordring].[Sagsbehandler]      sb  ON sb.sagsbehandler_id      = b.sagsbehandler_id

/* CROSS APPLY frem for et join med GROUP BY, så bevillingen ikke
   multipliceres af sine kørselsrækker. */
CROSS APPLY (
    SELECT
        COUNT(*)                                                     AS antal_raekker,
        /* Sammenlignes uden mellemrum — opslaget er ikke konsekvent med dem. */
        SUM(CASE WHEN REPLACE(bt.befordringstype_tekst, ' ', '') = 'Skolebus'
                 THEN 1 ELSE 0 END)                                  AS antal_skolebus,
        MIN(kk.gyldig_fra)                                           AS tidligste_fra,
        MAX(kk.gyldig_til)                                           AS seneste_til,
        /* DISTINCT via undertabel: STRING_AGG kan det ikke selv, og to
           rutekørselsrækker ville ellers stå to gange. */
        (
            SELECT STRING_AGG(t.befordringstype_tekst, ', ')
            FROM (
                SELECT DISTINCT bt2.befordringstype_tekst
                FROM       [befordring].[Koersel]         k2
                INNER JOIN [befordring].[Befordringstype] bt2
                           ON bt2.befordringstype_id = k2.befordringstype_id
                WHERE  k2.bevilling_id = b.bevilling_id
                AND    k2.aktiv = 1
                AND    REPLACE(bt2.befordringstype_tekst, ' ', '') <> 'Skolebus'
            ) t
        )                                                            AS oevrige_koerselstyper
    FROM       [befordring].[Koersel]          kk
    INNER JOIN [befordring].[Befordringstype]  bt ON bt.befordringstype_id = kk.befordringstype_id
    WHERE  kk.bevilling_id = b.bevilling_id
    AND    kk.aktiv = 1
) k

WHERE  b.aktiv = 1
AND    b.genbehandling = 1
AND    k.antal_skolebus > 0

ORDER BY
    /* Den snævre læsning først. */
    CASE WHEN k.antal_raekker = k.antal_skolebus THEN 0 ELSE 1 END,
    e.adresseringsnavn;
