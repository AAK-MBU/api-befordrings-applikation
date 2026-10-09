/* ============================================================
   Skoler som Skolematrikel mangler

     282222   Ravnbakkeskolen
     280731   Aarhus Business College, EUD10, Sønderhøj 28
     281867   AARHUS TECH, FUTURE10
     703003   Herskindskolen                        (Skanderborg Kommune)
     715005   Hørningskolen                         (Skanderborg Kommune)
     751060   Laursens Realskole                    (privatskole, Aarhus)
     751058   Elise Smiths Skole                    (privatskole, Aarhus)

   Ingen af koderne kan slås op i dag — hverken i Skolematrikel eller i
   Ungdomsuddannelse. En elev eller en bevilling med en af dem som skolekode
   finder derfor ingen matrikel, og gåafstanden kan ikke udledes af koden.
   Se elever_med_ukendt_skolekode.sql for, hvem det rammer.

   Alle syv rækker har nu fuldstændige adresser og koordinater. Det havde de
   tre første ikke, da filen blev skrevet, og headeren advarede længe om
   placeholdere og NULL-koordinater, efter at nogen havde udfyldt dem —
   advarslen er fjernet her, fordi den ikke længere passer på dataene.

   Hvorfor koordinaterne skal være rigtige og ikke bare udfyldt: gåafstanden
   måles fra elevens adresse til skolens koordinat, og usp-forespørgslen i
   rpa-befordring-nightly-runs springer en skole uden koordinat over:

       AND COALESCE(sm.latitude, uu.latitude) IS NOT NULL

   så eleven beholder kraever_genberegning = 1 og dukker op igen, så snart
   koordinatet er sat. Et gættet koordinat ville i stedet give en afstand,
   der ser rigtig ud og er forkert — og afstanden afgør afstandskriteriet.

   Idempotent: nøglen er matrikel_navn (trimmet), samme nøgle som seedets
   egen dubletkontrol i seed_lookup_data.sql. Kører igen uden at indsætte
   noget andet gang, så rækker der allerede står der, bliver ikke rørt.

   Scriptet COMMITTER. Skift COMMIT til ROLLBACK nederst for en tørkørsel.

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
    ('Stilling Skole',                      'Gramvej 10, 8660 Skanderborg',                    745003, 1, 56.057879,  9.983251)
) AS v (matrikel_navn, matrikel_adresse, skolekode, er_matrikel_hovedadresse, latitude, longitude)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Skolematrikel] t
    WHERE LTRIM(RTRIM(t.matrikel_navn)) = LTRIM(RTRIM(v.matrikel_navn))
);
PRINT CONCAT('Skolematrikel: ', @@ROWCOUNT, ' row(s) inserted.');


ROLLBACK TRANSACTION;
