/* ============================================================
   Tre skoler fra kildesystemets liste, som Skolematrikel mangler

     282222   Ravnbakkeskolen
     280731   Aarhus Business College, EUD10, Sønderhøj 28
     281867   AARHUS TECH, FUTURE10

   Ingen af de tre skolekoder findes i dag — hverken i Skolematrikel eller i
   Ungdomsuddannelse. En bevilling med et af dem som SkoleID kan derfor ikke
   slå en matrikel op, og konverteringen opretter den uden skole.

   ADRESSERNE ER PLACEHOLDERE og skal rettes før scriptet køres. Navnet på den
   ene røber sin egen adresse ("Sønderhøj 28"), men ikke postnummeret, og det
   er ikke noget at gætte på.

   KOORDINATERNE ER MED VILJE NULL — ikke 0, ikke et gæt. Gåafstanden måles
   fra elevens adresse til skolens koordinat, og usp-forespørgslen i
   rpa-befordring-nightly-runs springer en skole uden koordinat over:

       AND COALESCE(sm.latitude, uu.latitude) IS NOT NULL

   så eleven beholder kraever_genberegning = 1 og dukker op igen, så snart
   koordinatet er sat. Et placeholder-koordinat ville i stedet give en
   afstand, der ser rigtig ud og er forkert — og afstanden afgør
   afstandskriteriet.

   Idempotent: kører igen uden at indsætte noget andet gang.

   NB: de to 10.-klassestilbud (EUD10, FUTURE10) ligger på erhvervsskoler og
   hører måske hjemme i Ungdomsuddannelse i stedet. Den tabel har ingen
   skolekode, så en bevilling med SkoleID 280731 vil stadig ikke kunne slå
   noget op. Tag den beslutning, før rækkerne står der.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

INSERT INTO [befordring].[Skolematrikel]
    (matrikel_navn, matrikel_adresse, skolekode, er_matrikel_hovedadresse, latitude, longitude)
SELECT v.matrikel_navn, v.matrikel_adresse, v.skolekode, v.er_matrikel_hovedadresse, v.latitude, v.longitude
FROM (VALUES
    ('Ravnbakkeskolen',                               'Ravnbakken 10, 8200 Aarhus N, Denmark', 282222, 1, 56.233516, 10.194896),
    ('Aarhus Business College, EUD10, Sønderhøj 28',  'Sønderhøj 28, 8260 Aarhus',             280731, 1, 56.119221, 10.157318),
    ('AARHUS TECH, FUTURE10',                         'Halmstadgade 6, 8200 Aarhus N',         281867, 1, 56.184376, 10.191661)
) AS v (matrikel_navn, matrikel_adresse, skolekode, er_matrikel_hovedadresse, latitude, longitude)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Skolematrikel] t
    WHERE LTRIM(RTRIM(t.matrikel_navn)) = LTRIM(RTRIM(v.matrikel_navn))
);
PRINT CONCAT('Skolematrikel: ', @@ROWCOUNT, ' row(s) inserted.');


/* ------------------------------------------------------------
   Kontrol — de tre rækker, som de står nu
------------------------------------------------------------ */

SELECT matrikel_id, matrikel_navn, matrikel_adresse, skolekode,
       er_matrikel_hovedadresse, latitude, longitude
FROM   [befordring].[Skolematrikel]
WHERE  skolekode IN (282222, 280731, 281867)
ORDER  BY matrikel_navn;

PRINT '';
PRINT 'ROLLBACK er aktiv. Ret adresserne, saet koordinaterne, og skift til COMMIT.';
PRINT '';

ROLLBACK TRANSACTION;
