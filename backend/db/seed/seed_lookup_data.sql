/* ============================================================
   Lookup / reference data for the befordring schema.

   Everything the application needs in order to run, and nothing about any
   individual citizen: statuses, kørselstyper, hjemler, afgørelsesbreve,
   skolematrikler, ugedage and so on. No Elev, Foraelder, Part, Bevilling,
   Koersel, Sagsaktivitet or Brev rows are created here — for those, see
   seed_test_data.sql, which is test data and is NOT for a real environment.

   Use this to bring a fresh database (or a real one that is missing a lookup
   table's rows) up to a working state.

   Idempotent by design. Every insert is guarded by NOT EXISTS on the row's
   natural key — the human-meaningful text, not the identity column, compared
   with surrounding whitespace stripped from BOTH sides so a row already
   stored as 'Egen befordring ' still counts as present. So:
     * running it twice inserts nothing the second time
     * running it against a populated database tops up only what is missing
     * existing identity values are never disturbed, so foreign keys held by
       Bevilling and Koersel keep pointing at the same rows

   That last point is why this script does NOT delete or reseed identities.
   It only ever adds.

   It also does not UPDATE. If a row exists under the same natural key but
   with a different beskrivelse or coordinate, it is left alone — changing
   reference data under a live system is a migration, not a seed.

   ALL OR NOTHING. The inserts run in one transaction, so a failure part-way
   through leaves the database exactly as it was rather than half-seeded with
   some lookup tables populated and others empty. To preview without writing,
   change COMMIT TRANSACTION near the bottom to ROLLBACK TRANSACTION: the
   PRINTed counts still tell you what would have been inserted.

   Requires migrations 001-019 (Rutetype arrives in 003).
============================================================ */

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

SET NOCOUNT ON;

-- Any error aborts the batch and rolls back, rather than leaving a doomed
-- transaction open for the CATCH to inherit.
SET XACT_ABORT ON;
GO

PRINT 'Seeding lookup data...';
PRINT '';
GO


BEGIN TRY
    BEGIN TRANSACTION;

-- Status  (8 rows)
INSERT INTO [befordring].[Status] (status_tekst, beskrivelse, aktiv)
SELECT v.status_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    ('Ny',          'Ny ansøgning',                  1),
    ('Påbegyndt',   'Påbegyndt',                     1),
    ('Afslag',      'Afslag',                        1),
    ('Aktiv',       'Aktiv bevilling eller koersel',  1),
    ('Kommende',    'Kommende',                      1),
    ('Udløbet',     'Udløbet',                       1),
    ('Fejlet',      'Fejlet',                        1),
    ('Ophørt',      'Ophørt',                        1)
) AS v (status_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Status] t
    WHERE LTRIM(RTRIM(t.status_tekst)) = LTRIM(RTRIM(v.status_tekst))
);
PRINT CONCAT('Status: ', @@ROWCOUNT, ' row(s) inserted.');


-- Sagsbehandler  (2 rows)
INSERT INTO [befordring].[Sagsbehandler] (sagsbehandler_tekst, beskrivelse, aktiv)
SELECT v.sagsbehandler_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    ('Sofie', '', 1),
    ('Nina',  '', 1)
) AS v (sagsbehandler_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Sagsbehandler] t
    WHERE LTRIM(RTRIM(t.sagsbehandler_tekst)) = LTRIM(RTRIM(v.sagsbehandler_tekst))
);
PRINT CONCAT('Sagsbehandler: ', @@ROWCOUNT, ' row(s) inserted.');


-- PPR_Sagsbehandler  (2 rows)
INSERT INTO [befordring].[PPR_Sagsbehandler] (ppr_sagsbehandler_tekst, beskrivelse, aktiv)
SELECT v.ppr_sagsbehandler_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    ('Hans',    '', 1),
    ('Kirsten', '', 1)
) AS v (ppr_sagsbehandler_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[PPR_Sagsbehandler] t
    WHERE LTRIM(RTRIM(t.ppr_sagsbehandler_tekst)) = LTRIM(RTRIM(v.ppr_sagsbehandler_tekst))
);
PRINT CONCAT('PPR_Sagsbehandler: ', @@ROWCOUNT, ' row(s) inserted.');


-- Skolematrikel  (55 rows)
INSERT INTO [befordring].[Skolematrikel] (matrikel_navn, matrikel_adresse, skolekode, er_matrikel_hovedadresse, latitude, longitude)
SELECT v.matrikel_navn, v.matrikel_adresse, v.skolekode, v.er_matrikel_hovedadresse, v.latitude, v.longitude
FROM (VALUES
    ('Bakkegårdsskolen',                    'Bjørnshøjvej 1, 8380 Trige',                      751002, 1, 56.253285, 10.149081),
    ('Bavnehøj Skole',                      'Koltvej 19, 21, 8361 Hasselager',                 751016, 1, 56.106589, 10.095978),
    ('Beder Skole',                         'Skoleparken 6, 8330 Beder',                       751004, 1, 56.061574, 10.211609),
    ('Elev Skole',                          'Høvej 10, 8520 Lystrup',                          751006, 1, 56.241190, 10.199622),
    ('Ellevangskolen',                      'Jellebakken 17, 8240 Risskov',                    751003, 1, 56.202644, 10.218707),
    ('Elsted Skole',                        'Elsted Skolevej 6, 8520 Lystrup',                 751007, 1, 56.241526, 10.228948),
    ('Engdalskolen',                        'Hovedgaden 5, 8220 Brabrand',                     751008, 1, 56.152602, 10.109452),
    ('Frederiksbjerg skole',                'Ingerslevs Boulevard 2, 8000 Aarhus C',            751027, 1, 56.145005, 10.197084),
    ('Gammelgaardsskolen',                  'Carit Etlars Vej 31, 8230 Åbyhøj',                751013, 1, 56.159329, 10.157079),
    ('Hasle Skole',                         'Herredsvej 15, 8210 Aarhus V',                    751015, 1, 56.169300, 10.163680),
    ('Holme Skole',                         'Mølleskovvej 11, 8270 Højbjerg',                  751017, 1, 56.116237, 10.178254),
    ('Højvangskolen',                       'Klokkeskovvej 1, 8260 Viby J',                    751018, 1, 56.129903, 10.115003),
    ('Hårup Skole',                         'Salonikivej 14, 8530 Hjortshøj',                  751046, 1, 56.288342, 10.216692),
    ('Kaløvigskolen (Sanatorievej)',         'Sanatorievej 38, 8541 Skødstrup',                 751020, 1, 56.260172, 10.342974),
    ('Kaløvigskolen (Skovager)',             'Skovager 4, 8530 Hjortshøj',                     751020, 0, 56.245661, 10.273222),
    ('Katrinebjergskolen',                  'Katrinebjergvej 60, 8200 Aarhus N',               751019, 1, 56.173827, 10.196322),
    ('Kløverskolen',                        'Karen Blixens Boulevard 59, 8220 Brabrand',       281401, 1, 56.153100, 10.105700),
    ('Kragelundskolen',                     'Aage Jedichs Vej 3, 8270 Højbjerg',               751021, 1, 56.114507, 10.200129),
    ('Langagerskolen (Bøgeskov Høvej)',      'Bøgeskov Høvej 10, 8260 Viby J',                 751090, 1, 56.118367, 10.133548),
    ('Langagerskolen (Kolt Østervej)',       'Kolt Østervej 45, 8361 Hasselager',              751090, 0, 56.109433, 10.075118),
    ('Lisbjergskolen',                      'Jørgen Clevins Gade 31, 8200 Aarhus N',           751022, 1, 56.218634, 10.157948),
    ('Lystrup Skole',                       'Lystrupvej 256, 8520 Lystrup',                    751066, 1, 56.237290, 10.229867),
    ('Læssøesgades skole',                  'Læssøesgade 24, 8000 Aarhus C',                   751023, 1, 56.146377, 10.188354),
    ('Malling Skole',                       'Lundshøjgårdsvej 19, 8340 Malling',               751024, 1, 56.039315, 10.198617),
    ('Møllevangskolen',                     'Møllevangs Allé 20, 8210 Aarhus V',               751025, 1, 56.164825, 10.184485),
    ('Mårslet Skole',                       'Testrupvej 4, 8320 Mårslet',                      751026, 1, 56.068830, 10.155902),
    ('Netværksskolen',                      'Randersvej 302, 8200 Aarhus N',                   751221, 1, 56.213263, 10.171948),
    ('Næshøjskolen',                        'Gammel Stillingvej 424, 8462 Harlev J',           751055, 1, 56.145839,  9.999646),
    ('Risskov Skole',                       'Vestre Strandallé 97, 8240 Risskov',              751032, 1, 56.192986, 10.229468),
    ('Rosenvangskolen',                     'Rosenvangs Allé 49, 8260 Viby J',                 751033, 1, 56.131271, 10.183323),
    ('Rundhøjskolen',                       'Holmevej 200, 8270 Højbjerg',                     751034, 1, 56.118412, 10.178171),
    ('Sabro-Korsvejskolen',                 'Sabro Skolevej 4, 8471 Sabro',                    751035, 1, 56.211678, 10.025800),
    ('Samsøgades Skole',                    'Ny Munkegade 17, 8000 Aarhus C',                  751036, 1, 56.162449, 10.202540),
    ('Skjoldhøjskolen',                     'Skjoldhøjvej 11, 8381 Tilst',                     751065, 1, 56.174108, 10.113792),
    ('Skovvangskolen',                      'Skovvangsvej 150, 8200 Aarhus N',                 751038, 1, 56.175534, 10.208733),
    ('Skæring Skole',                       'Skæring Skolevej 200, 8250 Egå',                  751056, 1, 56.226157, 10.298083),
    ('Skødstrup Skole',                     'Rosenbakken 4, 8541 Skødstrup',                   751039, 1, 56.271534, 10.308426),
    ('Skåde Skole',                         'Mantziusvej 5, 8270 Højbjerg',                    751040, 1, 56.104037, 10.207346),
    ('Solbjergskolen',                      'Kærgårdsvej 4, 8355 Solbjerg',                    751041, 1, 56.042553, 10.084737),
    ('Stensagerskolen (Janesvej)',           'Janesvej 2, 8220 Brabrand',                       751903, 1, 56.166770, 10.137611),
    ('Stensagerskolen (Stensagervej)',       'Stensagervej 11, 8260 Viby J',                   751903, 0, 56.131239, 10.146707),
    ('Strandskolen',                        'Nellikevej 1, 8240 Risskov',                      751042, 1, 56.200330, 10.245746),
    ('Sygehusundervisning',                 'Palle Juul-Jensens Boulevard 175, 8200 Aarhus N', 751107, 1, 56.190967, 10.165825),
    ('Sødalskolen',                         'Louisevej 29, 8220 Brabrand',                     751014, 1, 56.150375, 10.136786),
    ('Sølystskolen',                        'Egå Havvej 5, 8250 Egå',                          751043, 1, 56.212247, 10.281777),
    ('Søndervangskolen',                    'Søndervangs Allé 40, 8260 Viby J',                751044, 1, 56.111261, 10.149489),
    ('Tilst Skole',                         'Tåstumvænget 8, 8381 Tilst',                      751045, 1, 56.189515, 10.113195),
    ('Tranbjergskolen (Grønløkke Allé)',     'Grønløkke Allé 9, 8310 Tranbjerg J',             280458, 1, 56.094176, 10.124531),
    ('Tranbjergskolen (Kirketorvet)',        'Kirketorvet 22, 8310 Tranbjerg J',                280458, 0, 56.090076, 10.140480),
    ('Vestergårdsskolen (Nordbyvej)',        'Nordbyvej 25, 8260 Viby J',                      751050, 1, 56.129377, 10.156499),
    ('Vestergårdsskolen (Stensagervej)',     'Stensagervej 10, 8260 Viby J',                   751050, 0, 56.130530, 10.148991),
    ('Viby Skole',                          'Kirkevej 2, 8260 Viby J',                         751051, 1, 56.127557, 10.164857),
    ('Virupskolen',                         'Virupvej 75, 8530 Hjortshøj',                     751052, 1, 56.243340, 10.271937),
    ('Vorrevangskolen',                     'Vorregårds Allé 109, 8200 Aarhus N',              751053, 1, 56.185948, 10.199095),
    ('Åby Skole',                           'Åbyvej 80, 8230 Åbyhøj',                          751054, 1, 56.150634, 10.164975)
) AS v (matrikel_navn, matrikel_adresse, skolekode, er_matrikel_hovedadresse, latitude, longitude)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Skolematrikel] t
    WHERE LTRIM(RTRIM(t.matrikel_navn)) = LTRIM(RTRIM(v.matrikel_navn))
);
PRINT CONCAT('Skolematrikel: ', @@ROWCOUNT, ' row(s) inserted.');


-- Ungdomsuddannelse  (5 rows)
INSERT INTO [befordring].[Ungdomsuddannelse] (ungdomsuddannelse_navn, ungdomsuddannelse_adresse, latitude, longitude)
SELECT v.ungdomsuddannelse_navn, v.ungdomsuddannelse_adresse, v.latitude, v.longitude
FROM (VALUES
    ('Dansk Brand og sikringsteknisk Institut, Aarhus', 'Runetoften 16, 8210 Aarhus V',          56.175306, 10.141596),
    ('Diakonhøjskolen, Social- og Sundhedsudd.',        'Lyseng Allé 15H, 8270 Højbjerg',         56.110066, 10.202479),
    ('Egå Gymnasium',                                   'Mejlbyvej 4, 8250 Egå',                  56.211969, 10.271199),
    ('Erhvervsgrunduddannelsen i Århus',                'Olof Palmes Allé 39, 8200 Aarhus N',     56.189424, 10.181944),
    ('International Training Academy ApS, Beauty & Style', 'Søndergade 45, 8000 Aarhus C',       56.153779, 10.206135)
) AS v (ungdomsuddannelse_navn, ungdomsuddannelse_adresse, latitude, longitude)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Ungdomsuddannelse] t
    WHERE LTRIM(RTRIM(t.ungdomsuddannelse_navn)) = LTRIM(RTRIM(v.ungdomsuddannelse_navn))
);
PRINT CONCAT('Ungdomsuddannelse: ', @@ROWCOUNT, ' row(s) inserted.');


-- Hjaelpemiddel  (6 rows)
INSERT INTO [befordring].[Hjaelpemiddel] (hjaelpemiddel_tekst, beskrivelse, aktiv)
SELECT v.hjaelpemiddel_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    ('Magnetsele',  '', 1),
    ('Selekappe',   '', 1),
    ('Krampeplan',  '', 1),
    ('Kørestol',    '', 1),
    ('Krykker',     '', 1),
    ('Autostol',    '', 1)
) AS v (hjaelpemiddel_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Hjaelpemiddel] t
    WHERE LTRIM(RTRIM(t.hjaelpemiddel_tekst)) = LTRIM(RTRIM(v.hjaelpemiddel_tekst))
);
PRINT CONCAT('Hjaelpemiddel: ', @@ROWCOUNT, ' row(s) inserted.');


-- Hjemmel  (8 rows)
INSERT INTO [befordring].[Hjemmel] (hjemmel_tekst, beskrivelse, aktiv)
SELECT v.hjemmel_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    ('§ 26, stk. 1 afstand',               '', 1),
    ('§ 26, stk. 2 sygdom',                '', 1),
    ('§ 26, stk. 1 og 2',                  '', 1),
    ('§ 33, stk. 3 (ungdomsskolen)',	   '', 1),
    ('§ 36, stk. 3 frit skolevalg',		   '', 1),
    ('§ 36, stk. 4 retten til at forblive','', 1),
    ('§ 9,  stk. 4 UngiAarhus',            '', 1),
    ('§ 10 (brækket ben)',				   '', 1)
) AS v (hjemmel_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Hjemmel] t
    WHERE LTRIM(RTRIM(t.hjemmel_tekst)) = LTRIM(RTRIM(v.hjemmel_tekst))
);
PRINT CONCAT('Hjemmel: ', @@ROWCOUNT, ' row(s) inserted.');


-- Afgoerelsesbrev  (18 rows)
INSERT INTO [befordring].[Afgoerelsesbrev] (afgoerelsesbrev_tekst, beskrivelse, aktiv)
SELECT v.afgoerelsesbrev_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    ('Afslag: § 9, stk. 4 (UngiAarhus)',										 '', 1),
    ('Afslag: § 26, stk. 1, nr. 1 (afstand)',									 '', 1),
    ('Afslag: § 26, stk. 1, nr. 2 (farlig skolevej)',							 '', 1),
    ('Afslag: § 26, stk. 6, § 36, stk. 3 (frit skolevalg)',						 '', 1),
    ('Afslag: § 33, stk. 3 (ungdomsskolen)',									 '', 1),
    ('Bevilling: § 26, stk. 1, nr. 1 (afstand)',								 '', 1),
    ('Bevilling: § 26, stk. 1, nr. 2 (farlig skolevej)',						 '', 1),
    ('Bevilling: § 26, stk. 2 (sygdom)',										 '', 1),
    ('Bevilling: § 26, stk. 2, § 36, stk. 3 (frit skolevalg)',					 '', 1),
    ('Bevilling: § 26, stk. 2, § 36, stk. 4 (retten til at forblive)',			 '', 1),
    ('Påtænkt afslag: § 26, stk. 1, nr. 2 (farlig skolevej)',                    '', 1),
    ('Påtænkt afslag: § 26, stk. 2 (sygdom)',                                    '', 1),
    ('Påtænkt afslag: § 26, stk. 2, § 36, stk. 4 (retten til at forblive)',      '', 1),
    ('Påtænkt ophør: § 26, stk. 2 (sygdom)',                                     '', 1),
    ('Midlertidig kørsel bevilling: § 26, stk. 2 (brækket ben folkeskole)',      '', 1),
    ('Midlertidig kørsel afslag: § 26, stk. 2 (brækket ben folkeskole)',         '', 1),
    ('Midlertidig kørsel bevilling: § 10 (brækket ben ungdomssuddannelse)',      '', 1),
    ('Midlertidig kørsel afslag: § 10 (brækket ben ungdomssuddannelse)',         '', 1)
) AS v (afgoerelsesbrev_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Afgoerelsesbrev] t
    WHERE LTRIM(RTRIM(t.afgoerelsesbrev_tekst)) = LTRIM(RTRIM(v.afgoerelsesbrev_tekst))
);
PRINT CONCAT('Afgoerelsesbrev: ', @@ROWCOUNT, ' row(s) inserted.');


-- KoerselstypeTillaeg  (4 rows)
INSERT INTO [befordring].[KoerselstypeTillaeg] (tillaeg_tekst, beskrivelse, aktiv)
SELECT v.tillaeg_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    ('Fast forsæde',  '', 1),
    ('Co-driver',     '', 1),
    ('Egen ledsager', '', 1),
    ('Fast sæde',     '', 1)
) AS v (tillaeg_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[KoerselstypeTillaeg] t
    WHERE LTRIM(RTRIM(t.tillaeg_tekst)) = LTRIM(RTRIM(v.tillaeg_tekst))
);
PRINT CONCAT('KoerselstypeTillaeg: ', @@ROWCOUNT, ' row(s) inserted.');


-- Befordringstype  (9 rows)
INSERT INTO [befordring].[Befordringstype] (befordringstype_tekst, beskrivelse, aktiv)
SELECT v.befordringstype_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    ('Rutekørsel',                       '', 1),
    ('Skånekørsel',                      '', 1),
    ('Solokørsel',                       '', 1),
    ('Variabel kørsel',                  '', 1),
    ('Skolerejsekort',                   '', 1),
    ('Skolebus',                         '', 1),
    ('Egen befordring',                  '', 1),
    ('Cykelbus',                         '', 1),
    ('Gåbus',                            '', 1)
) AS v (befordringstype_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Befordringstype] t
    WHERE LTRIM(RTRIM(t.befordringstype_tekst)) = LTRIM(RTRIM(v.befordringstype_tekst))
);
PRINT CONCAT('Befordringstype: ', @@ROWCOUNT, ' row(s) inserted.');


-- Tidspunkt  (3 rows)
INSERT INTO [befordring].[Tidspunkt] (tidspunkt_tekst, beskrivelse, aktiv)
SELECT v.tidspunkt_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    ('Morgen',                '', 1),
    ('Eftermiddag',           '', 1),
    ('Morgen og eftermiddag', '', 1)
) AS v (tidspunkt_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Tidspunkt] t
    WHERE LTRIM(RTRIM(t.tidspunkt_tekst)) = LTRIM(RTRIM(v.tidspunkt_tekst))
);
PRINT CONCAT('Tidspunkt: ', @@ROWCOUNT, ' row(s) inserted.');


-- Rutetype  (10 rows)
INSERT INTO [befordring].[Rutetype] (rutetype_tekst, beskrivelse, aktiv)
SELECT v.rutetype_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    ('Mellem hjem og skole',    '', 1),
    ('Mellem hjem og klub',     '', 1),
    ('Mellem skole og klub',    '', 1),
    ('Mellem skole, klub, og hjem', '', 1),
    ('Hjem til skole',          '', 1),
    ('Hjem til klub',           '', 1),
    ('Skole til hjem',          '', 1),
    ('Skole til klub',          '', 1),
    ('Klub til hjem',           '', 1),
    ('Klub til skole',          '', 1)
) AS v (rutetype_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Rutetype] t
    WHERE LTRIM(RTRIM(t.rutetype_tekst)) = LTRIM(RTRIM(v.rutetype_tekst))
);
PRINT CONCAT('Rutetype: ', @@ROWCOUNT, ' row(s) inserted.');


-- Ugedag  (6 rows)
INSERT INTO [befordring].[Ugedag] (dag_tekst, beskrivelse, aktiv)
SELECT v.dag_tekst, v.beskrivelse, v.aktiv
FROM (VALUES
    ('Mandag',  NULL,            1),
    ('Tirsdag', NULL,            1),
    ('Onsdag',  NULL,            1),
    ('Torsdag', NULL,            1),
    ('Fredag',  NULL,            1),
    ('Alle',    'Alle hverdage', 1)
) AS v (dag_tekst, beskrivelse, aktiv)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[Ugedag] t
    WHERE LTRIM(RTRIM(t.dag_tekst)) = LTRIM(RTRIM(v.dag_tekst))
);
PRINT CONCAT('Ugedag: ', @@ROWCOUNT, ' row(s) inserted.');

    COMMIT TRANSACTION;

    PRINT '';
    PRINT 'Lookup seed committed.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT '';
    PRINT 'Lookup seed FAILED and was rolled back — nothing was written.';

    -- Re-raise with the original error number, severity and line, so the
    -- caller sees the real cause rather than a generic failure.
    THROW;
END CATCH
GO


/* ============================================================
   Verify — row counts per lookup table
============================================================ */

SELECT 'Status'              AS lookup_table, COUNT(*) AS antal_rows FROM [befordring].[Status]
UNION ALL SELECT 'Sagsbehandler',       COUNT(*) FROM [befordring].[Sagsbehandler]
UNION ALL SELECT 'PPR_Sagsbehandler',   COUNT(*) FROM [befordring].[PPR_Sagsbehandler]
UNION ALL SELECT 'Skolematrikel',       COUNT(*) FROM [befordring].[Skolematrikel]
UNION ALL SELECT 'Ungdomsuddannelse',   COUNT(*) FROM [befordring].[Ungdomsuddannelse]
UNION ALL SELECT 'Hjaelpemiddel',       COUNT(*) FROM [befordring].[Hjaelpemiddel]
UNION ALL SELECT 'Hjemmel',             COUNT(*) FROM [befordring].[Hjemmel]
UNION ALL SELECT 'Afgoerelsesbrev',     COUNT(*) FROM [befordring].[Afgoerelsesbrev]
UNION ALL SELECT 'KoerselstypeTillaeg', COUNT(*) FROM [befordring].[KoerselstypeTillaeg]
UNION ALL SELECT 'Befordringstype',     COUNT(*) FROM [befordring].[Befordringstype]
UNION ALL SELECT 'Tidspunkt',           COUNT(*) FROM [befordring].[Tidspunkt]
UNION ALL SELECT 'Rutetype',            COUNT(*) FROM [befordring].[Rutetype]
UNION ALL SELECT 'Ugedag',              COUNT(*) FROM [befordring].[Ugedag]
ORDER BY lookup_table;
GO


/* ============================================================
   Safety check — duplicate natural keys

   Should return NO rows. Anything here means a lookup table holds two rows
   with the same human-meaningful value, which makes the dropdowns ambiguous
   and means some bevilling is pointing at one of them arbitrarily. This
   script cannot create such a row, but it will surface one that already
   exists (for example from an older non-guarded seed run).
============================================================ */

SELECT 'Status' AS lookup_table, LTRIM(RTRIM(status_tekst)) AS value, COUNT(*) AS antal
FROM [befordring].[Status] GROUP BY LTRIM(RTRIM(status_tekst)) HAVING COUNT(*) > 1
UNION ALL SELECT 'Sagsbehandler',       LTRIM(RTRIM(sagsbehandler_tekst)),     COUNT(*) FROM [befordring].[Sagsbehandler]       GROUP BY LTRIM(RTRIM(sagsbehandler_tekst))     HAVING COUNT(*) > 1
UNION ALL SELECT 'PPR_Sagsbehandler',   LTRIM(RTRIM(ppr_sagsbehandler_tekst)), COUNT(*) FROM [befordring].[PPR_Sagsbehandler]   GROUP BY LTRIM(RTRIM(ppr_sagsbehandler_tekst)) HAVING COUNT(*) > 1
UNION ALL SELECT 'Skolematrikel',       LTRIM(RTRIM(matrikel_navn)),           COUNT(*) FROM [befordring].[Skolematrikel]       GROUP BY LTRIM(RTRIM(matrikel_navn))           HAVING COUNT(*) > 1
UNION ALL SELECT 'Ungdomsuddannelse',   LTRIM(RTRIM(ungdomsuddannelse_navn)),  COUNT(*) FROM [befordring].[Ungdomsuddannelse]   GROUP BY LTRIM(RTRIM(ungdomsuddannelse_navn))  HAVING COUNT(*) > 1
UNION ALL SELECT 'Hjaelpemiddel',       LTRIM(RTRIM(hjaelpemiddel_tekst)),     COUNT(*) FROM [befordring].[Hjaelpemiddel]       GROUP BY LTRIM(RTRIM(hjaelpemiddel_tekst))     HAVING COUNT(*) > 1
UNION ALL SELECT 'Hjemmel',             LTRIM(RTRIM(hjemmel_tekst)),           COUNT(*) FROM [befordring].[Hjemmel]             GROUP BY LTRIM(RTRIM(hjemmel_tekst))           HAVING COUNT(*) > 1
UNION ALL SELECT 'Afgoerelsesbrev',     LTRIM(RTRIM(afgoerelsesbrev_tekst)),   COUNT(*) FROM [befordring].[Afgoerelsesbrev]     GROUP BY LTRIM(RTRIM(afgoerelsesbrev_tekst))   HAVING COUNT(*) > 1
UNION ALL SELECT 'KoerselstypeTillaeg', LTRIM(RTRIM(tillaeg_tekst)),           COUNT(*) FROM [befordring].[KoerselstypeTillaeg] GROUP BY LTRIM(RTRIM(tillaeg_tekst))           HAVING COUNT(*) > 1
UNION ALL SELECT 'Befordringstype',     LTRIM(RTRIM(befordringstype_tekst)),   COUNT(*) FROM [befordring].[Befordringstype]     GROUP BY LTRIM(RTRIM(befordringstype_tekst))   HAVING COUNT(*) > 1
UNION ALL SELECT 'Tidspunkt',           LTRIM(RTRIM(tidspunkt_tekst)),         COUNT(*) FROM [befordring].[Tidspunkt]           GROUP BY LTRIM(RTRIM(tidspunkt_tekst))         HAVING COUNT(*) > 1
UNION ALL SELECT 'Rutetype',            LTRIM(RTRIM(rutetype_tekst)),          COUNT(*) FROM [befordring].[Rutetype]            GROUP BY LTRIM(RTRIM(rutetype_tekst))          HAVING COUNT(*) > 1
UNION ALL SELECT 'Ugedag',              LTRIM(RTRIM(dag_tekst)),               COUNT(*) FROM [befordring].[Ugedag]              GROUP BY LTRIM(RTRIM(dag_tekst))               HAVING COUNT(*) > 1;
GO

PRINT '';
PRINT 'Lookup seed complete.';
GO
