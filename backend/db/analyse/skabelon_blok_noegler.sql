/* ============================================================
   Entry-nøglerne i brevskabelonen, blok for blok

   Brevteksterne er for store til at kopiere ud i ét stykke (den fulde
   workbook_json er over 64 KB og bliver klippet over). Her hentes kun NØGLERNE,
   som er dem der afgør, om et afgørelsesbrev rammer en tekst eller falder
   igennem.

   Hvorfor det betyder noget: blok 5 og 8 slår op på afgoerelsesbrev_decision
   — delen FØR kolon, fx "Påtænkt bevilling" — med et eksakt match efter
   normalisering. Findes nøglen ikke, bliver blokken udeladt uden fejl.
============================================================ */

USE [RPA];   -- skift hvis rpa.Templates ligger i en anden db

SET NOCOUNT ON;

WITH seneste AS (
    SELECT TOP 1 workbook_json
    FROM   rpa.Templates
    WHERE  process_name = 'afgoerelsesbreve'
    ORDER BY last_updated DESC
)
SELECT
    JSON_VALUE(b.value, '$.block_id')                       AS block_id,
    LEFT(JSON_VALUE(b.value, '$.title'), 60)                AS titel,
    JSON_VALUE(b.value, '$.mapping')                        AS mapping,
    e.[key]                                                 AS entry_noegle
FROM       seneste s
CROSS APPLY OPENJSON(s.workbook_json)             b
CROSS APPLY OPENJSON(b.value, '$.entries')        e
ORDER BY
    /* Numerisk-ish sortering, så 10 ikke står før 2. */
    LEN(JSON_VALUE(b.value, '$.block_id')),
    JSON_VALUE(b.value, '$.block_id'),
    e.[key];
