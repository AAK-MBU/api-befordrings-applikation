/* ============================================================
   De 22 ungdomsuddannelser fra kildesystemets liste, som
   Ungdomsuddannelse mangler

   Tabellen holdt fem rækker; kildelisten har 27. De 22 herunder findes ikke i
   dag, så en bevilling til en af dem kan ikke slå en uddannelse op.

   HVORFOR IKKE BARE KØRE seed_lookup_data.sql:
   Det script sletter og genskaber hele tabellen og nulstiller identiteten.
   Bevilling.ungdomsuddannelse_id har en fremmednøgle hertil, så en DELETE
   enten fejler med Msg 547 eller — hvis den slipper igennem — omnummererer
   alle rækker og peger eksisterende bevillinger på de forkerte uddannelser.
   seed-scriptet er til en tom database. Dette er til en, der kører.

   ADRESSERNE ER PLACEHOLDERE og skal rettes, før scriptet køres med COMMIT.
   Adressen trykkes i afgørelsesbrevet, så en forkert adresse er værre end en
   åbenlyst manglende.

   KOORDINATERNE ER MED VILJE NULL — ikke 0, ikke et gæt. Gåafstanden måles
   til uddannelsens koordinat, og både nattekørslen og genberegn_skole
   springer en uddannelse uden koordinat over:

       AND COALESCE(sm.latitude, uu.latitude) IS NOT NULL

   så eleven beholder kraever_genberegning = 1 og dukker op igen, så snart
   koordinatet er sat. Et placeholder-koordinat ville give en afstand, der ser
   rigtig ud og er forkert — og afstanden afgør afstandskriteriet.

   Tallet efter hver række er institutionsnummeret fra kildelisten. Tabellen
   har ingen kolonne til det; det står her, så rækken kan spores tilbage.

   Idempotent: matcher på navn, så gentagne kørsler indsætter ingenting.
============================================================ */

USE [Befordringssystemet];

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

INSERT INTO [befordring].[Ungdomsuddannelse]
    (ungdomsuddannelse_navn, ungdomsuddannelse_adresse, latitude, longitude)
SELECT v.ungdomsuddannelse_navn, v.ungdomsuddannelse_adresse, v.latitude, v.longitude
FROM (VALUES
    ('Dansk Brand og sikringsteknisk Institut, Aarhus',   'Runetoften 16, 8210 Aarhus V',           56.175306, 10.141596),
    ('Diakonhøjskolen, Social- og Sundhedsudd.',          'Lyseng Allé 15H, 8270 Højbjerg',         56.110066, 10.202479),
    ('Egå Gymnasium',                                     'Mejlbyvej 4, 8250 Egå',                  56.211969, 10.271199),
    ('Erhvervsgrunduddannelsen i Århus',                  'Olof Palmes Allé 39, 8200 Aarhus N',     56.189424, 10.181944),
    ('International Training Academy ApS, Beauty & Style','Søndergade 45, 8000 Aarhus C',           56.153779, 10.206135),
    ('Jordbrugets UddannelsesCenter, Beder',              'Damgårds Allé 5, 8330 Beder',            56.058613, 10.200661),
    ('Jordbrugets UddannelsesCenter, Bredballegård',      'Nymarksvej 65, 8320 Mårslet',            56.050581, 10.167725),
    ('Marselisborg Gymnasium',                            'Birketinget 9B, 8000 Aarhus C',          56.139194, 10.200802),
    ('Risskov Gymnasium',                                 'Tranekærvej 70, 8240 Risskov',           56.194389, 10.209748),
    ('Rudolf Steiner-Skolen i Aarhus',                    'Strandvejen 102, 8000 Aarhus C',         56.135886, 10.207846),
    ('SOSU Østjylland, Aarhus',                           'Hedeager 33, 8200 Aarhus N',             56.193212, 10.178706),
    ('UCplus A/S, Højbjerg',                              'Øster Parkvej 15, 8270 Højbjerg',        56.104056, 10.148375),
    ('UCplus Højbjerg',                                   'Øster Parkvej 15, 8270 Højbjerg',        56.104056, 10.148375),
    ('Viby Gymnasium',                                    'Søndervangs Allé 45, 8260 Viby J',       56.112858, 10.152582),
    ('Århus Akademi',                                     'Gøteborg Allé 2-4, 8200 Aarhus N',       56.183016, 10.195658),
    ('Aarhus Business College, EUX-gymnasiet',            'Sønderhøj 28, 8260 Viby J',              56.119221, 10.157318),
    ('Aarhus Business College, Handelsfagskolen i Skåde', 'Skåde Skovvej 2, 8270 Højbjerg',         56.097051, 10.218747),
    ('Aarhus Business College, HHX-gymnasiet i Risskov',  'Vejlby Centervej 50, 8240 Risskov',      56.194126, 10.204940),
    ('Aarhus Business College, HHX-gymnasiet i Viby',     'Viemosevej 1, 8260 Viby J',              56.129307, 10.153977),
    ('AARHUS GYMNASIUM, Tilst',                           'Kileparken 25, 8381 Tilst',              56.185741, 10.111676),
    ('AARHUS GYMNASIUM, Viby',                            'Hasselager Allé 10, 8260 Viby J',        56.115676, 10.122718),
    ('AARHUS GYMNASIUM, Aarhus C',                        'Dollerupvej 2, 8000 Aarhus C',           56.156053, 10.187526),
    ('Aarhus Katedralskole',                              'Skolegyde 1, 8000 Aarhus C',             56.156620, 10.211963),
    ('Århus Statsgymnasium',                              'Fenrisvej 33, 8210 Aarhus V',            56.161895, 10.171398),
    ('AARHUS TECH, Viby',                                 'Hasselager Allé 2, 8260 Viby J',         56.113751, 10.124950),
    ('AARHUS TECH, Aarhus C',                             'Dollerupvej 4, 8000 Aarhus C',           56.155449, 10.187265),
    ('AARHUS TECH, Aarhus N',                             'Halmstadgade 6, 8200 Aarhus N',          56.184376, 10.191661)
) AS v (ungdomsuddannelse_navn, ungdomsuddannelse_adresse, latitude, longitude)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Ungdomsuddannelse] t
    WHERE LTRIM(RTRIM(t.ungdomsuddannelse_navn)) = LTRIM(RTRIM(v.ungdomsuddannelse_navn))
);
PRINT CONCAT('Ungdomsuddannelse: ', @@ROWCOUNT, ' row(s) inserted.');


/* ------------------------------------------------------------
   Kontrol — hele tabellen, så det er til at se hvad der mangler
------------------------------------------------------------ */

SELECT ungdomsuddannelse_id,
       ungdomsuddannelse_navn,
       ungdomsuddannelse_adresse,
       latitude,
       longitude,
       CASE
           WHEN ungdomsuddannelse_adresse = 'UDFYLD ADRESSE' THEN 'MANGLER ADRESSE'
           WHEN latitude IS NULL OR longitude IS NULL        THEN 'MANGLER KOORDINAT'
           ELSE 'OK'
       END AS status
FROM   [befordring].[Ungdomsuddannelse]
ORDER  BY status DESC, ungdomsuddannelse_navn;

PRINT '';
PRINT 'ROLLBACK er aktiv. Ret adresserne, saet koordinaterne, og skift til COMMIT.';
PRINT '';

ROLLBACK TRANSACTION;
