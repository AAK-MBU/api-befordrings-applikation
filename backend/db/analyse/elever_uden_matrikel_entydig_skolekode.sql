/* ============================================================
   Elever hvor matrikel_id kunne udledes entydigt af skolekoden

   usp_sync_elev_matrikel_from_bevilling udleder Elev.matrikel_id af elevens
   BEVILLING. En elev uden bevilling — eller med en bevilling der ikke
   kvalificerer — får derfor NULL, også når deres skolekode kun peger på én
   eneste matrikel og valget dermed er entydigt. Så er der ingen gåafstand.

   Scriptet tæller, hvor stor den gruppe er, og om den overhovedet kan
   beregnes: en matrikel uden koordinat kan ikke måles til, uanset hvad.

   Kun læsning.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;

WITH kandidater AS (
    SELECT
        e.cpr,
        e.adresseringsnavn,
        e.skolekode,
        m.antal_matrikler,
        m.eneste_matrikel_id,
        sm.matrikel_navn,
        sm.latitude,
        /* Beregnes her, fordi SQL Server ikke tillader en subquery i GROUP BY. */
        CASE WHEN EXISTS (
                 SELECT 1 FROM [befordring].[Bevilling] b
                 WHERE b.cpr_elev = e.cpr AND b.aktiv = 1
             ) THEN N'har bevilling' ELSE N'ingen bevilling' END  AS bevillingsstatus,
        CASE WHEN sm.latitude IS NULL
             THEN N'matrikel mangler koordinat'
             ELSE N'kan beregnes' END                             AS koordinat
    FROM       [befordring].[Elev] e
    CROSS APPLY (
        SELECT COUNT(*) AS antal_matrikler, MIN(matrikel_id) AS eneste_matrikel_id
        FROM   [befordring].[Skolematrikel] s
        WHERE  s.skolekode = e.skolekode
    ) m
    LEFT JOIN  [befordring].[Skolematrikel] sm ON sm.matrikel_id = m.eneste_matrikel_id
    WHERE  e.matrikel_id IS NULL
    AND    ISNULL(e.skolekode, 0) <> 0
)

/* --- 1: hvor mange, og kan de beregnes --- */
SELECT
    CASE WHEN antal_matrikler = 1 THEN N'entydig (1 matrikel)'
         WHEN antal_matrikler = 0 THEN N'skolekode findes ikke i Skolematrikel'
         ELSE N'flertydig (flere matrikler)' END  AS skolekode_opslag,
    bevillingsstatus,
    MAX(koordinat)                                AS koordinat,
    COUNT(*)                                      AS antal_elever
FROM   kandidater
GROUP BY
    CASE WHEN antal_matrikler = 1 THEN N'entydig (1 matrikel)'
         WHEN antal_matrikler = 0 THEN N'skolekode findes ikke i Skolematrikel'
         ELSE N'flertydig (flere matrikler)' END,
    bevillingsstatus
ORDER BY antal_elever DESC;
