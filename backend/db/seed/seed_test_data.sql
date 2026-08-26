/* ============================================================
   Test-data reset + seed for the befordring dev database.

   NOTE: Revurdering is a FLAG on Bevilling (revurdering bit), not a
   status. The reassessment test cases (Rikke, Rasmus, Thomas) are
   seeded as Aktiv bevillinger with revurdering = 1 (see the UPDATE
   after the Bevilling inserts). Requires migrations 0005–0007 applied.

   NOTE: sagsbehandlingsdato is not inserted directly. It is stamped when
   a letter is created, so it is backfilled from each bevilling's
   'Brev oprettet' Sagsaktivitet (see the UPDATE near the end).

   Runs inside a transaction that ROLLBACKs by default — change the
   final ROLLBACK to COMMIT once the previewed data looks correct.
   ============================================================ */

USE [Befordringssystemet];

SET XACT_ABORT ON;

BEGIN TRANSACTION;


DELETE FROM [befordring].[Koersel_KoerselstypeTillaeg_LINK];
DELETE FROM [befordring].[Koersel_Ugedag_LINK];
DELETE FROM [befordring].[Bevilling_Hjaelpemiddel_LINK];

DELETE FROM [befordring].[Koersel];

DELETE FROM [befordring].[Bevilling];

DELETE FROM [befordring].[Foraelder];
DELETE FROM [befordring].[Part];
DELETE FROM [befordring].[Elev];

DELETE FROM [befordring].[Afgoerelsesbrev];
DELETE FROM [befordring].[Befordringstype];
DELETE FROM [befordring].[Hjaelpemiddel];
DELETE FROM [befordring].[Hjemmel];
DELETE FROM [befordring].[KoerselstypeTillaeg];
DELETE FROM [befordring].[PPR_Sagsbehandler];
DELETE FROM [befordring].[Rutetype];
DELETE FROM [befordring].[Sagsbehandler];
DELETE FROM [befordring].[Sagsaktivitet];
DELETE FROM [befordring].[Skolematrikel];
DELETE FROM [befordring].[Status];
DELETE FROM [befordring].[Tidspunkt];
DELETE FROM [befordring].[Ugedag];
DELETE FROM [befordring].[Ungdomsuddannelse];



DBCC CHECKIDENT ('[befordring].[Koersel]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Bevilling]', RESEED, 0);

DBCC CHECKIDENT ('[befordring].[Afgoerelsesbrev]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Befordringstype]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Hjaelpemiddel]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Hjemmel]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[KoerselstypeTillaeg]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[PPR_Sagsbehandler]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Sagsbehandler]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Sagsaktivitet]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Skolematrikel]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Status]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Tidspunkt]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Ugedag]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Ungdomsuddannelse]', RESEED, 0);
DBCC CHECKIDENT ('[befordring].[Rutetype]', RESEED, 0);


PRINT 'Starting test data insert';
PRINT '';

/* ============================================================
   Lookup tables
============================================================ */

INSERT INTO [befordring].[Status]
    (status_tekst, beskrivelse, aktiv)
VALUES
    ('Ny',          'Ny ansøgning',                  1),
    ('Påbegyndt',   'Påbegyndt',                     1),
    ('Afslag',      'Afslag',                        1),
    ('Aktiv',       'Aktiv bevilling eller koersel',  1),
    ('Kommende',    'Kommende',                      1),
    ('Udløbet',     'Udløbet',                       1),
    ('Fejlet',      'Fejlet',                        1),
    ('Ophørt',      'Ophørt',                        1);


INSERT INTO [befordring].[Sagsbehandler]
    (sagsbehandler_tekst, beskrivelse, aktiv)
VALUES
    ('Sofie', '', 1),
    ('Nina',  '', 1);


INSERT INTO [befordring].[PPR_Sagsbehandler]
    (ppr_sagsbehandler_tekst, beskrivelse, aktiv)
VALUES
    ('Hans',    '', 1),
    ('Kirsten', '', 1);


INSERT INTO [befordring].[Skolematrikel]
    (matrikel_navn, matrikel_adresse, skolekode, er_matrikel_hovedadresse, latitude, longitude)
VALUES
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
    ('Åby Skole',                           'Åbyvej 80, 8230 Åbyhøj',                          751054, 1, 56.150634, 10.164975);


INSERT INTO [befordring].[Ungdomsuddannelse]
    (ungdomsuddannelse_navn, ungdomsuddannelse_adresse, latitude, longitude)
VALUES
    ('Dansk Brand og sikringsteknisk Institut, Aarhus', 'Runetoften 16, 8210 Aarhus V',          56.175306, 10.141596),
    ('Diakonhøjskolen, Social- og Sundhedsudd.',        'Lyseng Allé 15H, 8270 Højbjerg',         56.110066, 10.202479),
    ('Egå Gymnasium',                                   'Mejlbyvej 4, 8250 Egå',                  56.211969, 10.271199),
    ('Erhvervsgrunduddannelsen i Århus',                'Olof Palmes Allé 39, 8200 Aarhus N',     56.189424, 10.181944),
    ('International Training Academy ApS, Beauty & Style', 'Søndergade 45, 8000 Aarhus C',       56.153779, 10.206135);


INSERT INTO [befordring].[Hjaelpemiddel]
    (hjaelpemiddel_tekst, beskrivelse, aktiv)
VALUES
    ('Magnetsele',  '', 1),
    ('Selekappe',   '', 1),
    ('Krampeplan',  '', 1),
    ('Kørestol',    '', 1),
    ('Krykker',     '', 1),
    ('Autostol',    '', 1);


INSERT INTO [befordring].[Hjemmel]
    (hjemmel_tekst, beskrivelse, aktiv)
VALUES
    ('§ 26, stk. 1 afstand',               '', 1),
    ('§ 26, stk. 2 sygdom',                '', 1),
    ('§ 26, stk. 1 og 2',                  '', 1),
    ('§ 36, stk. 3 frit skolevalg',		   '', 1),
    ('§ 36, stk. 4 retten til at forblive','', 1),
    ('§ 9,  stk. 4 UngiAarhus',             '', 1),
    ('§ 10 (brækket ben)',				   '', 1);


INSERT INTO [befordring].[Afgoerelsesbrev]
    (afgoerelsesbrev_tekst, beskrivelse, aktiv)
VALUES
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
    ('Midlertidig kørsel afslag: § 10 (brækket ben ungdomssuddannelse)',         '', 1);


INSERT INTO [befordring].[KoerselstypeTillaeg]
    (tillaeg_tekst, beskrivelse, aktiv)
VALUES
    ('Fast forsæde',  '', 1),
    ('Co-driver',     '', 1),
    ('Egen ledsager', '', 1),
    ('Fast sæde',     '', 1);


INSERT INTO [befordring].[Befordringstype]
    (befordringstype_tekst, beskrivelse, aktiv)
VALUES
    ('Rutekørsel',                       '', 1),
    ('Skånekørsel',                      '', 1),
    ('Solokørsel',                       '', 1),
    ('Variabel kørsel',                  '', 1),
    ('Skolerejsekort',                   '', 1),
    ('Skolebus',                         '', 1),
    ('Egen befordring',                  '', 1),
    ('Cykelbus',                         '', 1),
    ('Gåbus',                            '', 1);


INSERT INTO [befordring].[Tidspunkt]
    (tidspunkt_tekst, beskrivelse, aktiv)
VALUES
    ('Morgen',                '', 1),
    ('Eftermiddag',           '', 1),
    ('Morgen og eftermiddag', '', 1);


INSERT INTO [befordring].[Rutetype]
    (rutetype_tekst, beskrivelse, aktiv)
VALUES
    ('Mellem hjem og skole',    '', 1),
    ('Mellem hjem og klub',     '', 1),
    ('Mellem skole og klub',    '', 1),
    ('Hjem til skole',          '', 1),
    ('Hjem til klub',           '', 1),
    ('Skole til hjem',          '', 1),
    ('Skole til klub',          '', 1),
    ('Klub til hjem',           '', 1),
    ('Klub til skole',          '', 1);


INSERT INTO [befordring].[Ugedag]
    (dag_tekst, beskrivelse, aktiv)
VALUES
    ('Mandag',  NULL,            1),
    ('Tirsdag', NULL,            1),
    ('Onsdag',  NULL,            1),
    ('Torsdag', NULL,            1),
    ('Fredag',  NULL,            1),
    ('Alle',    'Alle hverdage', 1);


/* ============================================================
   Save lookup IDs
============================================================ */

-- Status
DECLARE @status_ny          int = (SELECT TOP 1 status_id FROM [befordring].[Status] WHERE status_tekst = 'Ny'          ORDER BY status_id DESC);
DECLARE @status_paabegundt  int = (SELECT TOP 1 status_id FROM [befordring].[Status] WHERE status_tekst = 'Påbegyndt'   ORDER BY status_id DESC);
DECLARE @status_afslag      int = (SELECT TOP 1 status_id FROM [befordring].[Status] WHERE status_tekst = 'Afslag'      ORDER BY status_id DESC);
DECLARE @status_aktiv       int = (SELECT TOP 1 status_id FROM [befordring].[Status] WHERE status_tekst = 'Aktiv'       ORDER BY status_id DESC);
DECLARE @status_kommende    int = (SELECT TOP 1 status_id FROM [befordring].[Status] WHERE status_tekst = 'Kommende'    ORDER BY status_id DESC);
DECLARE @status_udloebet    int = (SELECT TOP 1 status_id FROM [befordring].[Status] WHERE status_tekst = 'Udløbet'     ORDER BY status_id DESC);
DECLARE @status_fejlet      int = (SELECT TOP 1 status_id FROM [befordring].[Status] WHERE status_tekst = 'Fejlet'      ORDER BY status_id DESC);
DECLARE @status_ophoert     int = (SELECT TOP 1 status_id FROM [befordring].[Status] WHERE status_tekst = 'Ophørt'      ORDER BY status_id DESC);

-- Sagsbehandlere
DECLARE @sagsbehandler_1 int = (SELECT TOP 1 sagsbehandler_id FROM [befordring].[Sagsbehandler] WHERE sagsbehandler_tekst = 'Sofie' ORDER BY sagsbehandler_id DESC);
DECLARE @sagsbehandler_2 int = (SELECT TOP 1 sagsbehandler_id FROM [befordring].[Sagsbehandler] WHERE sagsbehandler_tekst = 'Nina'  ORDER BY sagsbehandler_id DESC);

-- PPR
DECLARE @ppr_1 int = (SELECT TOP 1 ppr_sagsbehandler_id FROM [befordring].[PPR_Sagsbehandler] WHERE ppr_sagsbehandler_tekst = 'Hans'    ORDER BY ppr_sagsbehandler_id DESC);
DECLARE @ppr_2 int = (SELECT TOP 1 ppr_sagsbehandler_id FROM [befordring].[PPR_Sagsbehandler] WHERE ppr_sagsbehandler_tekst = 'Kirsten' ORDER BY ppr_sagsbehandler_id DESC);

-- Skolematrikler
DECLARE @matrikel_1  int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Bakkegårdsskolen'              ORDER BY matrikel_id DESC);
DECLARE @matrikel_2  int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Bavnehøj Skole'                ORDER BY matrikel_id DESC);
DECLARE @matrikel_3  int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Stensagerskolen (Janesvej)'    ORDER BY matrikel_id DESC);
DECLARE @matrikel_4  int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Stensagerskolen (Stensagervej)'ORDER BY matrikel_id DESC);
DECLARE @matrikel_5  int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Engdalskolen'                  ORDER BY matrikel_id DESC);
DECLARE @matrikel_6  int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Solbjergskolen'                ORDER BY matrikel_id DESC);
DECLARE @matrikel_7  int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Samsøgades Skole'              ORDER BY matrikel_id DESC);
DECLARE @matrikel_8  int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Frederiksbjerg skole'          ORDER BY matrikel_id DESC);
DECLARE @matrikel_9  int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Risskov Skole'                 ORDER BY matrikel_id DESC);
DECLARE @matrikel_10 int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Skovvangskolen'                ORDER BY matrikel_id DESC);
DECLARE @matrikel_11 int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Gammelgaardsskolen'            ORDER BY matrikel_id DESC);
DECLARE @matrikel_12 int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Højvangskolen'                 ORDER BY matrikel_id DESC);
DECLARE @matrikel_13 int = (SELECT TOP 1 matrikel_id FROM [befordring].[Skolematrikel] WHERE matrikel_navn = 'Holme Skole'                   ORDER BY matrikel_id DESC);

-- Ungdomsuddannelser
DECLARE @ungdomsuddannelse_1 int = (SELECT TOP 1 ungdomsuddannelse_id FROM [befordring].[Ungdomsuddannelse] WHERE ungdomsuddannelse_navn = 'Egå Gymnasium'                             ORDER BY ungdomsuddannelse_id DESC);
DECLARE @ungdomsuddannelse_2 int = (SELECT TOP 1 ungdomsuddannelse_id FROM [befordring].[Ungdomsuddannelse] WHERE ungdomsuddannelse_navn = 'Diakonhøjskolen, Social- og Sundhedsudd.' ORDER BY ungdomsuddannelse_id DESC);

-- Hjemler
DECLARE @hjemmel_1 int = (SELECT TOP 1 hjemmel_id FROM [befordring].[Hjemmel] WHERE hjemmel_tekst = '§ 26, stk. 1 afstand'               ORDER BY hjemmel_id DESC);
DECLARE @hjemmel_2 int = (SELECT TOP 1 hjemmel_id FROM [befordring].[Hjemmel] WHERE hjemmel_tekst = '§ 26, stk. 2 sygdom'                ORDER BY hjemmel_id DESC);
DECLARE @hjemmel_3 int = (SELECT TOP 1 hjemmel_id FROM [befordring].[Hjemmel] WHERE hjemmel_tekst = '§ 26, stk. 1 og 2'                  ORDER BY hjemmel_id DESC);
DECLARE @hjemmel_4 int = (SELECT TOP 1 hjemmel_id FROM [befordring].[Hjemmel] WHERE hjemmel_tekst = '§ 36, stk. 3 frit skolevalg'        ORDER BY hjemmel_id DESC);
DECLARE @hjemmel_5 int = (SELECT TOP 1 hjemmel_id FROM [befordring].[Hjemmel] WHERE hjemmel_tekst = '§ 36, stk. 4 retten til at forblive'ORDER BY hjemmel_id DESC);
DECLARE @hjemmel_6 int = (SELECT TOP 1 hjemmel_id FROM [befordring].[Hjemmel] WHERE hjemmel_tekst = '§ 9, stk. 4 UngiAarhus'             ORDER BY hjemmel_id DESC);

-- Afgørelsesbreve
DECLARE @afgoerelsesbrev_1  int = (SELECT TOP 1 afgoerelsesbrev_id FROM [befordring].[Afgoerelsesbrev] WHERE afgoerelsesbrev_tekst = 'Afslag: § 9, stk. 4 (UngiAarhus)'                                ORDER BY afgoerelsesbrev_id DESC);
DECLARE @afgoerelsesbrev_2  int = (SELECT TOP 1 afgoerelsesbrev_id FROM [befordring].[Afgoerelsesbrev] WHERE afgoerelsesbrev_tekst = 'Afslag: § 26, stk. 1, nr. 1 (afstand)'                           ORDER BY afgoerelsesbrev_id DESC);
DECLARE @afgoerelsesbrev_3  int = (SELECT TOP 1 afgoerelsesbrev_id FROM [befordring].[Afgoerelsesbrev] WHERE afgoerelsesbrev_tekst = 'Afslag: § 26, stk. 1, nr. 2 (farlig skolevej)'                   ORDER BY afgoerelsesbrev_id DESC);
DECLARE @afgoerelsesbrev_4  int = (SELECT TOP 1 afgoerelsesbrev_id FROM [befordring].[Afgoerelsesbrev] WHERE afgoerelsesbrev_tekst = 'Afslag: § 26, stk. 6, § 36, stk. 3 (frit skolevalg)'            ORDER BY afgoerelsesbrev_id DESC);
DECLARE @afgoerelsesbrev_5  int = (SELECT TOP 1 afgoerelsesbrev_id FROM [befordring].[Afgoerelsesbrev] WHERE afgoerelsesbrev_tekst = 'Afslag: § 33, stk. 3 (ungdomsskolen)'                            ORDER BY afgoerelsesbrev_id DESC);
DECLARE @afgoerelsesbrev_6  int = (SELECT TOP 1 afgoerelsesbrev_id FROM [befordring].[Afgoerelsesbrev] WHERE afgoerelsesbrev_tekst = 'Bevilling: § 26, stk. 1, nr. 1 (afstand)'                        ORDER BY afgoerelsesbrev_id DESC);
DECLARE @afgoerelsesbrev_7  int = (SELECT TOP 1 afgoerelsesbrev_id FROM [befordring].[Afgoerelsesbrev] WHERE afgoerelsesbrev_tekst = 'Bevilling: § 26, stk. 1, nr. 2 (farlig skolevej)'                ORDER BY afgoerelsesbrev_id DESC);
DECLARE @afgoerelsesbrev_8  int = (SELECT TOP 1 afgoerelsesbrev_id FROM [befordring].[Afgoerelsesbrev] WHERE afgoerelsesbrev_tekst = 'Bevilling: § 26, stk. 2 (sygdom)'                                ORDER BY afgoerelsesbrev_id DESC);
DECLARE @afgoerelsesbrev_9  int = (SELECT TOP 1 afgoerelsesbrev_id FROM [befordring].[Afgoerelsesbrev] WHERE afgoerelsesbrev_tekst = 'Bevilling: § 26, stk. 2, § 36, stk. 3 (frit skolevalg)'         ORDER BY afgoerelsesbrev_id DESC);
DECLARE @afgoerelsesbrev_10 int = (SELECT TOP 1 afgoerelsesbrev_id FROM [befordring].[Afgoerelsesbrev] WHERE afgoerelsesbrev_tekst = 'Bevilling: § 26, stk. 2, § 36, stk. 4 (retten til at forblive)' ORDER BY afgoerelsesbrev_id DESC);

-- Hjælpemidler
DECLARE @hjaelpemiddel_koerestol  int = (SELECT TOP 1 hjaelpemiddel_id FROM [befordring].[Hjaelpemiddel] WHERE hjaelpemiddel_tekst = 'Kørestol'   ORDER BY hjaelpemiddel_id DESC);
DECLARE @hjaelpemiddel_krykker    int = (SELECT TOP 1 hjaelpemiddel_id FROM [befordring].[Hjaelpemiddel] WHERE hjaelpemiddel_tekst = 'Krykker'    ORDER BY hjaelpemiddel_id DESC);
DECLARE @hjaelpemiddel_magnetsele int = (SELECT TOP 1 hjaelpemiddel_id FROM [befordring].[Hjaelpemiddel] WHERE hjaelpemiddel_tekst = 'Magnetsele' ORDER BY hjaelpemiddel_id DESC);
DECLARE @hjaelpemiddel_krampeplan int = (SELECT TOP 1 hjaelpemiddel_id FROM [befordring].[Hjaelpemiddel] WHERE hjaelpemiddel_tekst = 'Krampeplan' ORDER BY hjaelpemiddel_id DESC);
DECLARE @hjaelpemiddel_selekappe  int = (SELECT TOP 1 hjaelpemiddel_id FROM [befordring].[Hjaelpemiddel] WHERE hjaelpemiddel_tekst = 'Selekappe'  ORDER BY hjaelpemiddel_id DESC);
DECLARE @hjaelpemiddel_autostol   int = (SELECT TOP 1 hjaelpemiddel_id FROM [befordring].[Hjaelpemiddel] WHERE hjaelpemiddel_tekst = 'Autostol'   ORDER BY hjaelpemiddel_id DESC);

-- Tidspunkter
DECLARE @tidspunkt_morgen      int = (SELECT TOP 1 tidspunkt_id FROM [befordring].[Tidspunkt] WHERE tidspunkt_tekst = 'Morgen'                ORDER BY tidspunkt_id DESC);
DECLARE @tidspunkt_eftermiddag int = (SELECT TOP 1 tidspunkt_id FROM [befordring].[Tidspunkt] WHERE tidspunkt_tekst = 'Eftermiddag'           ORDER BY tidspunkt_id DESC);
DECLARE @tidspunkt_begge       int = (SELECT TOP 1 tidspunkt_id FROM [befordring].[Tidspunkt] WHERE tidspunkt_tekst = 'Morgen og eftermiddag' ORDER BY tidspunkt_id DESC);

-- Befordringstyper
DECLARE @befordringstype_rute      int = (SELECT TOP 1 befordringstype_id FROM [befordring].[Befordringstype] WHERE befordringstype_tekst = 'Rutekørsel'     ORDER BY befordringstype_id DESC);
DECLARE @befordringstype_egen      int = (SELECT TOP 1 befordringstype_id FROM [befordring].[Befordringstype] WHERE befordringstype_tekst = 'Egen befordring'  ORDER BY befordringstype_id DESC);
DECLARE @befordringstype_skaane    int = (SELECT TOP 1 befordringstype_id FROM [befordring].[Befordringstype] WHERE befordringstype_tekst = 'Skånekørsel'     ORDER BY befordringstype_id DESC);
DECLARE @befordringstype_rejsekort int = (SELECT TOP 1 befordringstype_id FROM [befordring].[Befordringstype] WHERE befordringstype_tekst = 'Skolerejsekort'  ORDER BY befordringstype_id DESC);
DECLARE @befordringstype_variabel  int = (SELECT TOP 1 befordringstype_id FROM [befordring].[Befordringstype] WHERE befordringstype_tekst = 'Variabel kørsel' ORDER BY befordringstype_id DESC);

-- Rutetyper
DECLARE @rutetype_skole int = (SELECT TOP 1 rutetype_id FROM [befordring].[Rutetype] WHERE rutetype_tekst = 'Mellem hjem og skole' ORDER BY rutetype_id DESC);
DECLARE @rutetype_klub  int = (SELECT TOP 1 rutetype_id FROM [befordring].[Rutetype] WHERE rutetype_tekst = 'Mellem hjem og klub'  ORDER BY rutetype_id DESC);

-- Tillaeg
DECLARE @tillaeg_fast_forsaede int = (SELECT TOP 1 tillaeg_id FROM [befordring].[KoerselstypeTillaeg] WHERE tillaeg_tekst = 'Fast forsæde'  ORDER BY tillaeg_id DESC);
DECLARE @tillaeg_co_driver     int = (SELECT TOP 1 tillaeg_id FROM [befordring].[KoerselstypeTillaeg] WHERE tillaeg_tekst = 'Co-driver'     ORDER BY tillaeg_id DESC);
DECLARE @tillaeg_egen_ledsager int = (SELECT TOP 1 tillaeg_id FROM [befordring].[KoerselstypeTillaeg] WHERE tillaeg_tekst = 'Egen ledsager' ORDER BY tillaeg_id DESC);
DECLARE @tillaeg_fast_saede    int = (SELECT TOP 1 tillaeg_id FROM [befordring].[KoerselstypeTillaeg] WHERE tillaeg_tekst = 'Fast sæde'     ORDER BY tillaeg_id DESC);

-- Ugedage
DECLARE @dag_mandag  int = (SELECT TOP 1 dag_id FROM [befordring].[Ugedag] WHERE dag_tekst = 'Mandag'  ORDER BY dag_id DESC);
DECLARE @dag_tirsdag int = (SELECT TOP 1 dag_id FROM [befordring].[Ugedag] WHERE dag_tekst = 'Tirsdag' ORDER BY dag_id DESC);
DECLARE @dag_onsdag  int = (SELECT TOP 1 dag_id FROM [befordring].[Ugedag] WHERE dag_tekst = 'Onsdag'  ORDER BY dag_id DESC);
DECLARE @dag_torsdag int = (SELECT TOP 1 dag_id FROM [befordring].[Ugedag] WHERE dag_tekst = 'Torsdag' ORDER BY dag_id DESC);
DECLARE @dag_fredag  int = (SELECT TOP 1 dag_id FROM [befordring].[Ugedag] WHERE dag_tekst = 'Fredag'  ORDER BY dag_id DESC);
DECLARE @dag_alle    int = (SELECT TOP 1 dag_id FROM [befordring].[Ugedag] WHERE dag_tekst = 'Alle'    ORDER BY dag_id DESC);


/* ============================================================
   Elev  (14 total)
   1  Kasper Søndergaard   — Aktiv
   2  Kristian Holm        — Aktiv
   3  Rikke Nørgaard       — Aktiv (revurdering)  (adressebeskyttelse)
   4  Rasmus Bjerrum       — Aktiv (revurdering)
   5  Janni Højgaard       — Ny
   6  Jakob Friis          — Ny  (ungdomsuddannelse)
   7  Laura Bech           — Påbegyndt
   8  Martin Kjeldsen      — Afslag
   9  Sofie Lund           — Kommende
   10 Peter Møller         — Udløbet
   11 Emma Grønberg        — Fejlet
   12 Anders Dalsgaard     — Ophørt
   13 Mette Christensen    — Aktiv  (ungdomsuddannelse)
   14 Thomas Vestergaard   — Aktiv (revurdering)
============================================================ */

INSERT INTO [befordring].[Elev]
    (cpr, adresseringsnavn, navne_adresse_beskyttelse, adresse_id,
     skoleafstand, klasseart, elevklassetrin, klassebetegnelse,
     sfo, bopaelsdistrikt, matrikel_id, ungdomsuddannelse_id, skolekode)
VALUES
(
    '0101101234', 'Kasper Søndergaard', 0, '000021C5-E9EE-411D-B2D8-EC9161780CCD',
    4.2, 'Normalklasse', '1', '1A',
    'SFO - Bakkegårdsskolen', 'Bakkegårdsskolen',
    @matrikel_1, NULL, 751002
),
(
    '0202101234', 'Kristian Holm', 0, '00002732-733C-433A-A5DA-A7D428A980CF',
    4.2, 'Normalklasse', '2', '2B',
    'SFO - Bavnehøj Skole', 'Bavnehøj Skole',
    @matrikel_2, NULL, 751016
),
(
    '0303101234', 'Rikke Nørgaard', 1, '00002EC8-9A05-423C-ABF2-3D0F4CCB03E0',
    2.1, 'Modtageklasse', '3', '3C',
    'SFO - Stensagerskolen', 'Stensagerskolen',
    @matrikel_3, NULL, 751903
),
(
    '0404101234', 'Rasmus Bjerrum', 0, '000059B7-1FE6-4ED2-8386-D9578B2A8859',
    2.9, 'Normalklasse', '4', '4D',
    'SFO - Stensagerskolen', 'Stensagerskolen',
    @matrikel_4, NULL, 751903
),
(
    '0505101234', 'Janni Højgaard', 0, '0000670C-4F89-4C07-B77B-F9B82AF01C80',
    6.8, 'Specialklasse', '5', '5E',
    'SFO - Engdalskolen', 'Engdalskolen',
    @matrikel_5, NULL, 751008
),
(
    '0606101234', 'Jakob Friis', 0, '00009B67-504C-4FE0-B1D1-39126722DF0F',
    6.8, 'Normalklasse', '10', '10A',
    '', '',
    NULL, @ungdomsuddannelse_1, ''
),
-- 7: Laura Bech — Påbegyndt
(
    '0707101234', 'Laura Bech', 0, '00009E24-9877-4F17-8020-04A0B29E704F',
    1.8, 'Normalklasse', '2', '2C',
    'SFO - Samsøgades Skole', 'Samsøgades Skole',
    @matrikel_7, NULL, 751036
),
-- 8: Martin Kjeldsen — Afslag
(
    '0808101234', 'Martin Kjeldsen', 0, '0000BF23-21F1-4FBB-85AE-3089BC6CF623',
    0.9, 'Normalklasse', '3', '3A',
    'SFO - Frederiksbjerg skole', 'Frederiksbjerg skole',
    @matrikel_8, NULL, 751027
),
-- 9: Sofie Lund — Kommende
(
    '0909101234', 'Sofie Lund', 0, '0000C127-AB48-48C7-9770-EDA49D39EB5A',
    5.2, 'Normalklasse', '5', '5B',
    'SFO - Risskov Skole', 'Risskov Skole',
    @matrikel_9, NULL, 751032
),
-- 10: Peter Møller — Udløbet
(
    '1010101234', 'Peter Møller', 0, '0000E92C-BB46-4745-A0AE-90950142AF79',
    3.4, 'Normalklasse', '7', '7D',
    '', 'Skovvangskolen',
    @matrikel_10, NULL, 751038
),
-- 11: Emma Grønberg — Fejlet
(
    '1111101234', 'Emma Grønberg', 0, '0000EE38-A966-4A72-9C34-19B0A32AD367',
    0.6, 'Specialklasse', '1', '1A',
    'SFO - Gammelgaardsskolen', 'Gammelgaardsskolen',
    @matrikel_11, NULL, 751013
),
-- 12: Anders Dalsgaard — Ophørt
(
    '1212101234', 'Anders Dalsgaard', 0, '0000F131-D663-4434-A585-D30CA601B571',
    8.4, 'Normalklasse', '8', '8E',
    '', 'Højvangskolen',
    @matrikel_12, NULL, 751018
),
-- 13: Mette Christensen — Aktiv (ungdomsuddannelse)
(
    '1313101234', 'Mette Christensen', 0, '0000F5F4-9278-43A5-9BA8-24C21D76610C',
    12.1, 'Normalklasse', '10', '10B',
    '', '',
    NULL, @ungdomsuddannelse_2, ''
),
-- 14: Thomas Vestergaard — Aktiv (revurdering)
(
    '1414101234', 'Thomas Vestergaard', 0, '0000AAF0-826F-4458-B26F-4317AD2A4979',
    6.7, 'Normalklasse', '6', '6C',
    'SFO - Holme Skole', 'Holme Skole',
    @matrikel_13, NULL, 751017
);


/* ============================================================
   Foraelder  (14 total — one per elev)
============================================================ */

INSERT INTO [befordring].[Foraelder]
    (cpr_foraelder, cpr_elev, adresseringsnavn, adresse_id,
     navne_adresse_beskyttelse, relation, maa_vide_barns_adresse)
VALUES
('1111111111', '0101101234', 'Jeppe Søndergaard',  '000021C5-E9EE-411D-B2D8-EC9161780CCD', 0, 'Mor', 1),
('2222222222', '0202101234', 'Maja Holm',          '00002732-733C-433A-A5DA-A7D428A980CF', 0, 'Mor', 0),
('3333333333', '0303101234', 'Nadia Nørgaard',     '00002EC8-9A05-423C-ABF2-3D0F4CCB03E0', 0, 'Mor', 0),
('4444444444', '0404101234', 'Brian Bjerrum',      '000059B7-1FE6-4ED2-8386-D9578B2A8859', 0, 'Tante', 0),
('5555555555', '0505101234', 'Hanne Højgaard',     '0000670C-4F89-4C07-B77B-F9B82AF01C80', 0, 'Mor', 1),
('6666666666', '0606101234', 'Torben Friis',       '00009B67-504C-4FE0-B1D1-39126722DF0F', 0, 'Far', 0),
('7777777777', '0707101234', 'Lotte Bech',         '00009E24-9877-4F17-8020-04A0B29E704F', 0, 'Far', 1),
('8888888888', '0808101234', 'Kim Kjeldsen',       '0000BF23-21F1-4FBB-85AE-3089BC6CF623', 0, 'Mor', 1),
('9999999999', '0909101234', 'Anni Lund',          '0000C127-AB48-48C7-9770-EDA49D39EB5A', 0, 'Mor', 1),
('1010101010', '1010101234', 'Henrik Møller',      '0000E92C-BB46-4745-A0AE-90950142AF79', 0, 'Mor', 1),
('1111111110', '1111101234', 'Gitte Grønberg',     '0000EE38-A966-4A72-9C34-19B0A32AD367', 0, 'Mor', 0),
('1212121212', '1212101234', 'Søren Dalsgaard',    '0000F131-D663-4434-A585-D30CA601B571', 0, 'Mor', 1),
('1313131313', '1313101234', 'Dorthe Christensen', '0000F5F4-9278-43A5-9BA8-24C21D76610C', 0, 'Mor', 1),
('1414141414', '1414101234', 'Kurt Vestergaard',   '0000AAF0-826F-4458-B26F-4317AD2A4979', 0, 'Mor', 1);


/* ============================================================
   Bevilling
============================================================ */

-- 1: Kasper — Aktiv
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '0101101234', '000021C5-E9EE-411D-B2D8-EC9161780CCD', @status_aktiv, @matrikel_1, NULL,
    @hjemmel_1, @afgoerelsesbrev_6, '2027-06-30', '2027-06-20',
    'ESDH-TEST-001', @sagsbehandler_1, @ppr_1,
    '2026-01-01', NULL, 'Forældremyndighed',
    '2026-02-01', 'Kørsel',
    '2027-06-30', 2,
    'Sygdom', 'test_seed', 'test_seed', 1
);
DECLARE @bevilling_1 int = SCOPE_IDENTITY();


-- 2: Kristian — Aktiv
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '0202101234', '00002732-733C-433A-A5DA-A7D428A980CF', @status_aktiv, @matrikel_2, NULL,
    @hjemmel_2, @afgoerelsesbrev_8, '2027-06-30', '2027-06-20',
    'ESDH-TEST-002', @sagsbehandler_2, @ppr_2,
    '2026-02-01', NULL, 'Forældremyndighed',
    '2026-03-01', 'Kørsel',
    '2027-06-30', 3,
    'Farlig trafikvej', 'test_seed', 'test_seed', 1
);
DECLARE @bevilling_2 int = SCOPE_IDENTITY();


-- 3: Rikke — Aktiv (flagged for revurdering below)
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '0303101234', '00002EC8-9A05-423C-ABF2-3D0F4CCB03E0', @status_aktiv, @matrikel_3,
    @hjemmel_3, @afgoerelsesbrev_7, '2026-05-30', '2026-05-15',
    'ESDH-TEST-003', @sagsbehandler_1, @ppr_1,
    '2025-06-01', NULL, 'Forældremyndighed',
    '2025-08-01', 'Kørsel',
    '2026-06-30', 4,
    'Afstand', 'test_seed', 'test_seed', 1
);
DECLARE @bevilling_3 int = SCOPE_IDENTITY();


-- 4: Rasmus — Aktiv (flagged for revurdering below)
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '0404101234', '000059B7-1FE6-4ED2-8386-D9578B2A8859', @status_aktiv, @matrikel_4, NULL,
    @hjemmel_4, @afgoerelsesbrev_4, '2026-06-30', '2026-06-15',
    'ESDH-TEST-004', @sagsbehandler_2, @ppr_2,
    '2025-12-01', NULL, 'Værge',
    '2026-01-01', 'Kørsel',
    '2026-06-30', 4,
    'Afstand', 'test_seed', 'test_seed', 1
);
DECLARE @bevilling_4 int = SCOPE_IDENTITY();


-- 5: Janni — Ny
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '0505101234', '0000670C-4F89-4C07-B77B-F9B82AF01C80', @status_ny, @matrikel_5, NULL,
    NULL, NULL, NULL, NULL,
    'ESDH-TEST-005', NULL, NULL,
    '2026-05-10', NULL, 'Forældremyndighed',
    '2026-08-01', 'Kørsel',
    NULL, NULL,
    'Afstand', 'test_seed', 'test_seed', 1
);


-- 6: Jakob — Ny
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '0606101234', '00009B67-504C-4FE0-B1D1-39126722DF0F', @status_ny, NULL, @ungdomsuddannelse_1,
    NULL, NULL, NULL, NULL,
    'ESDH-TEST-006', NULL, NULL,
    '2026-05-25', NULL, 'Forældremyndighed',
    '2026-06-01', 'Midlertidig kørsel',
    NULL, NULL,
    'Sygdom', 'test_seed', 'test_seed', 1
);


-- 7: Laura — Påbegyndt
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '0707101234', '00009E24-9877-4F17-8020-04A0B29E704F', @status_paabegundt, @matrikel_7, NULL,
    @hjemmel_1, NULL, '2027-06-30', NULL,
    'ESDH-TEST-007', @sagsbehandler_1, @ppr_1,
    '2026-05-01', NULL, 'Mor',
    '2026-08-01', 'Kørsel',
    '2027-06-30', 2,
    'Afstand', 'test_seed', 'test_seed', 1
);


-- 8: Martin — Afslag
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '0808101234', '0000BF23-21F1-4FBB-85AE-3089BC6CF623', @status_afslag, @matrikel_8, NULL,
    @hjemmel_1, @afgoerelsesbrev_2, NULL, NULL,
    'ESDH-TEST-008', @sagsbehandler_2, @ppr_1,
    '2025-11-01', NULL, 'Far',
    NULL, 'Kørsel',
    NULL, 3,
    'Afstand', 'test_seed', 'test_seed', 1
);


-- 9: Sofie — Kommende
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '0909101234', '0000C127-AB48-48C7-9770-EDA49D39EB5A', @status_kommende, @matrikel_9, NULL,
    @hjemmel_1, @afgoerelsesbrev_6, '2027-06-30', NULL,
    'ESDH-TEST-009', @sagsbehandler_1, @ppr_2,
    '2026-04-15', NULL, 'Mor',
    '2026-08-10', 'Kørsel',
    '2027-06-30', 5,
    'Afstand', 'test_seed', 'test_seed', 1
);
DECLARE @bevilling_9 int = SCOPE_IDENTITY();


-- 10: Peter — Udløbet
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '1010101234', '0000E92C-BB46-4745-A0AE-90950142AF79', @status_udloebet, @matrikel_10, NULL,
    @hjemmel_2, @afgoerelsesbrev_8, '2025-06-30', '2025-06-10',
    'ESDH-TEST-010', @sagsbehandler_2, @ppr_1,
    '2024-05-01', NULL, 'Far',
    '2024-08-01', 'Kørsel',
    '2025-06-30', 7,
    'Sygdom', 'test_seed', 'test_seed', 1
);
DECLARE @bevilling_10 int = SCOPE_IDENTITY();


-- 11: Emma — Fejlet
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '1111101234', '0000EE38-A966-4A72-9C34-19B0A32AD367', @status_fejlet, @matrikel_11, NULL,
    @hjemmel_2, NULL, NULL, NULL,
    'ESDH-TEST-011', @sagsbehandler_1, NULL,
    '2026-04-01', NULL, 'Mor',
    '2026-05-01', 'Kørsel',
    NULL, 1,
    'Sygdom', 'test_seed', 'test_seed', 1
);


-- 12: Anders — Ophørt
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '1212101234', '0000F131-D663-4434-A585-D30CA601B571', @status_ophoert, @matrikel_12, NULL,
    @hjemmel_1, @afgoerelsesbrev_6, '2025-06-30', NULL,
    'ESDH-TEST-012', @sagsbehandler_2, @ppr_2,
    '2023-08-01', NULL, 'Far',
    '2023-08-15', 'Kørsel',
    '2025-06-30', 8,
    'Afstand', 'test_seed', 'test_seed', 1
);
DECLARE @bevilling_12 int = SCOPE_IDENTITY();


-- 13: Mette — Aktiv
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '1313101234', '0000F5F4-9278-43A5-9BA8-24C21D76610C', @status_aktiv, NULL, @ungdomsuddannelse_2,
    @hjemmel_2, @afgoerelsesbrev_8, '2027-06-30', NULL,
    'ESDH-TEST-013', @sagsbehandler_1, @ppr_2,
    '2025-12-01', NULL, 'Mor',
    '2026-02-01', 'Midlertidig kørsel',
    '2027-06-30', 10,
    'Sygdom', 'test_seed', 'test_seed', 1
);
DECLARE @bevilling_13 int = SCOPE_IDENTITY();


-- 14: Thomas — Aktiv (flagged for revurdering below)
INSERT INTO [befordring].[Bevilling]
    (cpr_elev, adresse_id, status_id, matrikel_id, ungdomsuddannelse_id,
     hjemmel_id, afgoerelsesbrev_id, revurderingsdato, befordringsudvalg,
     esdh_noegle, sagsbehandler_id, ppr_sagsbehandler_id,
     ansoegningsdato, sagsbehandlingsdato, relation_til_barnet,
     foerste_koersel_dato, ansoegningstype,
     afstandskriterie_dato, afstandskriterie_klassetrin,
     begrundelse_fra_formular, created_by, updated_by, aktiv)
VALUES
(
    '1414101234', '0000AAF0-826F-4458-B26F-4317AD2A4979', @status_aktiv, @matrikel_13, NULL,
    @hjemmel_1, @afgoerelsesbrev_6, '2026-05-31', '2026-05-20',
    'ESDH-TEST-014', @sagsbehandler_2, @ppr_1,
    '2025-03-01', NULL, 'Far',
    '2025-04-01', 'Kørsel',
    '2026-06-30', 6,
    'Afstand', 'test_seed', 'test_seed', 1
);
DECLARE @bevilling_14 int = SCOPE_IDENTITY();


/* ============================================================
   Revurdering flag (Revurdering is a flag now, not a status).
   Rikke, Rasmus, Thomas are active bevillinger flagged for
   reassessment. Their kørsler are active (see Koersel below) and
   revurderingsdato is approaching, so they would also be flagged
   by usp_recalculate_bevilling_status if it is run.
============================================================ */

UPDATE [befordring].[Bevilling]
SET revurdering = 1
WHERE cpr_elev IN ('0303101234', '0404101234', '1414101234');


/* ============================================================
   Bevilling_Hjaelpemiddel_LINK
============================================================ */

INSERT INTO [befordring].[Bevilling_Hjaelpemiddel_LINK] (bevilling_id, hjaelpemiddel_id)
VALUES
-- Kasper: kørestol + co-driver selepakke
(@bevilling_1,  @hjaelpemiddel_koerestol),
-- Kristian: krykker
(@bevilling_2,  @hjaelpemiddel_krykker),
-- Rikke: magnetsele + krampeplan
(@bevilling_3,  @hjaelpemiddel_magnetsele),
(@bevilling_3,  @hjaelpemiddel_krampeplan),
-- Emma: autostol (årsag til specialkørselsbehov)
-- bevilling_11 har ikke SCOPE_IDENTITY, indsæt via subquery
((SELECT TOP 1 bevilling_id FROM [befordring].[Bevilling] WHERE cpr_elev = '1111101234' ORDER BY bevilling_id DESC), @hjaelpemiddel_autostol),
-- Mette: selekappe
(@bevilling_13, @hjaelpemiddel_selekappe);


/* ============================================================
   Koersel
============================================================ */

-- Kasper: aktiv rutekørsel begge tidspunkter
INSERT INTO [befordring].[Koersel]
    (bevilling_id, gyldig_fra, gyldig_til, tidspunkt_id, befordringstype_id,
     bevilget_koereafstand_pr_vej, taxa_id, kommentar, final, rutetype_id)
VALUES (@bevilling_1, '2026-02-01', '2027-07-01', @tidspunkt_begge, @befordringstype_rute, NULL, 'TAXA-001', 'Rutekørsel begge tidspunkter.', 1, @rutetype_skole);
DECLARE @koersel_1 int = SCOPE_IDENTITY();

-- Kristian: aktiv skånekørsel begge tidspunkter
INSERT INTO [befordring].[Koersel]
    (bevilling_id, gyldig_fra, gyldig_til, tidspunkt_id, befordringstype_id,
     bevilget_koereafstand_pr_vej, taxa_id, kommentar, final, rutetype_id)
VALUES (@bevilling_2, '2026-03-01', '2027-07-01', @tidspunkt_begge, @befordringstype_skaane, NULL, 'TAXA-002', 'Skånekørsel begge tidspunkter.', 1, @rutetype_klub);
DECLARE @koersel_2 int = SCOPE_IDENTITY();

-- Rikke: egenbefordring begge tidspunkter (aktiv — revurdering)
INSERT INTO [befordring].[Koersel]
    (bevilling_id, gyldig_fra, gyldig_til, tidspunkt_id, befordringstype_id,
     bevilget_koereafstand_pr_vej, taxa_id, kommentar, final, rutetype_id)
VALUES (@bevilling_3, '2025-08-01', '2027-07-01', @tidspunkt_begge, @befordringstype_egen, 6.1, NULL, 'Egen befordring begge tidspunkter.', 0, @rutetype_skole);
DECLARE @koersel_3 int = SCOPE_IDENTITY();

-- Rasmus: rutekørsel alle dage (aktiv — revurdering)
INSERT INTO [befordring].[Koersel]
    (bevilling_id, gyldig_fra, gyldig_til, tidspunkt_id, befordringstype_id,
     bevilget_koereafstand_pr_vej, taxa_id, kommentar, final, rutetype_id)
VALUES (@bevilling_4, '2026-01-01', '2027-07-01', @tidspunkt_begge, @befordringstype_rute, NULL, 'TAXA-003', 'Rutekørsel alle dage.', 0, @rutetype_skole);
DECLARE @koersel_4 int = SCOPE_IDENTITY();

-- Sofie: kommende skolerejsekort (starter næste skoleår, ikke finaliseret endnu)
INSERT INTO [befordring].[Koersel]
    (bevilling_id, gyldig_fra, gyldig_til, tidspunkt_id, befordringstype_id,
     bevilget_koereafstand_pr_vej, taxa_id, kommentar, final, rutetype_id)
VALUES (@bevilling_9, '2026-08-10', '2027-07-01', @tidspunkt_morgen, @befordringstype_rejsekort, NULL, NULL, 'Skolerejsekort morgen.', 0, @rutetype_skole);
DECLARE @koersel_9 int = SCOPE_IDENTITY();

-- Peter: udløbet rutekørsel (forrige skoleår)
INSERT INTO [befordring].[Koersel]
    (bevilling_id, gyldig_fra, gyldig_til, tidspunkt_id, befordringstype_id,
     bevilget_koereafstand_pr_vej, taxa_id, kommentar, final, rutetype_id)
VALUES (@bevilling_10, '2024-08-01', '2025-07-01', @tidspunkt_begge, @befordringstype_rute, NULL, 'TAXA-010', 'Udløbet rutekørsel.', 1, @rutetype_skole);
DECLARE @koersel_10 int = SCOPE_IDENTITY();

-- Anders: ophørt rutekørsel (afsluttet da eleven skiftede distrikt)
INSERT INTO [befordring].[Koersel]
    (bevilling_id, gyldig_fra, gyldig_til, tidspunkt_id, befordringstype_id,
     bevilget_koereafstand_pr_vej, taxa_id, kommentar, final, rutetype_id)
VALUES (@bevilling_12, '2023-08-15', '2025-01-15', @tidspunkt_begge, @befordringstype_rute, NULL, 'TAXA-012', 'Ophørt rutekørsel.', 1, @rutetype_skole);
DECLARE @koersel_12 int = SCOPE_IDENTITY();

-- Mette: aktiv egenbefordring til ungdomsuddannelse
INSERT INTO [befordring].[Koersel]
    (bevilling_id, gyldig_fra, gyldig_til, tidspunkt_id, befordringstype_id,
     bevilget_koereafstand_pr_vej, taxa_id, kommentar, final, rutetype_id)
VALUES (@bevilling_13, '2026-02-01', '2027-07-01', @tidspunkt_morgen, @befordringstype_egen, 12.1, NULL, 'Egen befordring morgen til Diakonhøjskolen.', 1, @rutetype_skole);
DECLARE @koersel_13 int = SCOPE_IDENTITY();

-- Thomas: rutekørsel (aktiv — revurdering)
INSERT INTO [befordring].[Koersel]
    (bevilling_id, gyldig_fra, gyldig_til, tidspunkt_id, befordringstype_id,
     bevilget_koereafstand_pr_vej, taxa_id, kommentar, final, rutetype_id)
VALUES (@bevilling_14, '2025-04-01', '2027-07-01', @tidspunkt_begge, @befordringstype_rute, NULL, 'TAXA-014', 'Rutekørsel begge tidspunkter — bevilling under revurdering.', 0, @rutetype_skole);
DECLARE @koersel_14 int = SCOPE_IDENTITY();


/* ============================================================
   Koersel_KoerselstypeTillaeg_LINK
============================================================ */

INSERT INTO [befordring].[Koersel_KoerselstypeTillaeg_LINK] (koersel_id, tillaeg_id)
VALUES
(@koersel_1,  @tillaeg_fast_forsaede),
(@koersel_1,  @tillaeg_co_driver),
(@koersel_2,  @tillaeg_egen_ledsager),
(@koersel_4,  @tillaeg_fast_saede),
(@koersel_10, @tillaeg_fast_forsaede),
(@koersel_14, @tillaeg_fast_saede);


/* ============================================================
   Koersel_Ugedag_LINK
============================================================ */

INSERT INTO [befordring].[Koersel_Ugedag_LINK] (koersel_id, dag_id)
VALUES
-- Kasper: alle dage
(@koersel_1,  @dag_alle),

-- Kristian: man, ons, fre
(@koersel_2,  @dag_mandag),
(@koersel_2,  @dag_onsdag),
(@koersel_2,  @dag_fredag),

-- Rikke: tirs + tors
(@koersel_3,  @dag_tirsdag),
(@koersel_3,  @dag_torsdag),

-- Rasmus: alle dage
(@koersel_4,  @dag_alle),

-- Sofie: alle dage (skolerejsekort)
(@koersel_9,  @dag_alle),

-- Peter: alle dage (historisk)
(@koersel_10, @dag_alle),

-- Anders: alle dage (historisk)
(@koersel_12, @dag_alle),

-- Mette: man–fre morgen
(@koersel_13, @dag_mandag),
(@koersel_13, @dag_tirsdag),
(@koersel_13, @dag_onsdag),
(@koersel_13, @dag_torsdag),
(@koersel_13, @dag_fredag),

-- Thomas: alle dage
(@koersel_14, @dag_alle);



/* ============================================================
   Sagsaktivitet  (case-activity audit log → "Sagsforløb" feed)

   Mirrors the event types the application itself writes so the
   test feed looks like real usage:
     Bevilling oprettet · Sagsbehandler opdateret ·
     PPR ansvarlig opdateret · PPR/BR Revurderet ·
     Status sat til <status> · Brev oprettet · Kommentar

   udfoert_af = 'System' for automated/SP-driven events,
   or a caseworker name for manual actions.

   Timestamps are explicit so the feed renders in a realistic
   chronological order.
============================================================ */

INSERT INTO [befordring].[Sagsaktivitet]
    (cpr, aktivitetstype, kommentar, udfoert_af, oprettet_tidspunkt, relateret_bevilling_id)
VALUES
-- Kasper (Aktiv) — full happy-path lifecycle
('0101101234', 'Bevilling oprettet',       CONCAT('Bevilling ID: ', @bevilling_1, ' — Status: Ny'), 'System', '2026-01-01T09:15:00', @bevilling_1),
('0101101234', 'Sagsbehandler opdateret',  'Sagsbehandler sat til Sofie',               'Sofie',  '2026-01-10T10:00:00', @bevilling_1),
('0101101234', 'PPR ansvarlig opdateret',  'PPR ansvarlig sat til Hans',                'Sofie',  '2026-01-10T10:05:00', @bevilling_1),
('0101101234', 'Status sat til Påbegyndt', 'Sagsbehandler tilføjet',                    'System', '2026-01-10T10:05:30', @bevilling_1),
('0101101234', 'Status sat til Aktiv',     'Bevillingsperioden er startet',             'System', '2026-02-01T06:00:00', @bevilling_1),
('0101101234', 'Kommentar',                'Forælder har bekræftet taxaordningen.',     'Sofie',  '2026-02-15T13:20:00', @bevilling_1),

-- Laura (Påbegyndt)
('0707101234', 'Bevilling oprettet',       'Bevilling oprettet fra ansøgning.',         'System', '2026-05-01T08:30:00', (SELECT TOP 1 bevilling_id FROM [befordring].[Bevilling] WHERE cpr_elev = '0707101234' ORDER BY bevilling_id DESC)),
('0707101234', 'Sagsbehandler opdateret',  'Sagsbehandler sat til Sofie',               'Sofie',  '2026-05-15T09:00:00', (SELECT TOP 1 bevilling_id FROM [befordring].[Bevilling] WHERE cpr_elev = '0707101234' ORDER BY bevilling_id DESC)),
('0707101234', 'Status sat til Påbegyndt', 'Sagsbehandler tilføjet',                    'System', '2026-05-15T09:00:30', (SELECT TOP 1 bevilling_id FROM [befordring].[Bevilling] WHERE cpr_elev = '0707101234' ORDER BY bevilling_id DESC)),

-- Sofie Lund (Kommende)
('0909101234', 'Bevilling oprettet',       CONCAT('Bevilling ID: ', @bevilling_9, ' — Status: Ny'), 'System', '2026-04-15T11:00:00', @bevilling_9),
('0909101234', 'Sagsbehandler opdateret',  'Sagsbehandler sat til Sofie',               'Sofie',  '2026-05-01T09:30:00', @bevilling_9),
('0909101234', 'Status sat til Kommende',  'Bevillingsperioden er endnu ikke startet',  'System', '2026-05-01T09:30:30', @bevilling_9),

-- Rikke (revurdering) — PPR reviewed, awaiting BR
('0303101234', 'Bevilling oprettet',       CONCAT('Bevilling ID: ', @bevilling_3, ' — Status: Ny'), 'System', '2025-06-01T08:00:00', @bevilling_3),
('0303101234', 'Sagsbehandler opdateret',  'Sagsbehandler sat til Sofie',               'Sofie',  '2025-06-10T10:00:00', @bevilling_3),
('0303101234', 'Status sat til Aktiv',     'Bevillingsperioden er startet',             'System', '2025-08-01T06:00:00', @bevilling_3),
('0303101234', 'PPR Revurderet',           NULL,                                        'Sofie',  '2026-05-02T14:00:00', @bevilling_3),
('0303101234', 'Kommentar',                'Afventer BR-gennemgang pga. adressebeskyttelse.', 'Sofie', '2026-05-15T15:10:00', @bevilling_3),

-- Rasmus (revurdering)
('0404101234', 'Bevilling oprettet',       CONCAT('Bevilling ID: ', @bevilling_4, ' — Status: Ny'), 'System', '2025-12-01T09:00:00', @bevilling_4),
('0404101234', 'Sagsbehandler opdateret',  'Sagsbehandler sat til Nina',                'Nina',   '2025-12-10T10:30:00', @bevilling_4),
('0404101234', 'PPR Revurderet',           NULL,                                        'Nina',   '2026-06-15T13:45:00', @bevilling_4),

-- Thomas (revurdering) — PPR done, forwarded to BR
('1414101234', 'Bevilling oprettet',       CONCAT('Bevilling ID: ', @bevilling_14, ' — Status: Ny'), 'System', '2025-03-01T08:15:00', @bevilling_14),
('1414101234', 'Sagsbehandler opdateret',  'Sagsbehandler sat til Nina',                'Nina',   '2025-03-15T11:00:00', @bevilling_14),
('1414101234', 'Status sat til Aktiv',     'Bevillingsperioden er startet',             'System', '2025-04-01T06:00:00', @bevilling_14),
('1414101234', 'PPR Revurderet',           NULL,                                        'Nina',   '2026-05-20T14:20:00', @bevilling_14),
('1414101234', 'Kommentar',                'PPR har vurderet sagen; videresendt til BR.', 'Nina', '2026-05-21T09:05:00', @bevilling_14),

-- Martin (Afslag) — with letter
('0808101234', 'Bevilling oprettet',       'Bevilling oprettet fra ansøgning.',         'System', '2025-11-01T08:00:00', (SELECT TOP 1 bevilling_id FROM [befordring].[Bevilling] WHERE cpr_elev = '0808101234' ORDER BY bevilling_id DESC)),
('0808101234', 'Status sat til Afslag',    'Afstandskriterie ikke opfyldt.',            'Nina',   '2025-11-20T13:00:00', (SELECT TOP 1 bevilling_id FROM [befordring].[Bevilling] WHERE cpr_elev = '0808101234' ORDER BY bevilling_id DESC)),
('0808101234', 'Brev oprettet',            'Afslag: § 26, stk. 1, nr. 1 (afstand)',     'Nina',   '2025-11-21T10:30:00', (SELECT TOP 1 bevilling_id FROM [befordring].[Bevilling] WHERE cpr_elev = '0808101234' ORDER BY bevilling_id DESC)),

-- Peter (Udløbet) — historical lifecycle
('1010101234', 'Bevilling oprettet',       CONCAT('Bevilling ID: ', @bevilling_10, ' — Status: Ny'), 'System', '2024-05-01T08:00:00', @bevilling_10),
('1010101234', 'Status sat til Aktiv',     'Bevillingsperioden er startet',             'System', '2024-08-01T06:00:00', @bevilling_10),
('1010101234', 'Status sat til Udløbet',   'Bevillingsperioden er udløbet',             'System', '2025-07-01T06:00:00', @bevilling_10);


/* ============================================================
   Brev oprettet — decision letters.

   sagsbehandlingsdato is stamped automatically when the caseworker
   creates the letter (see create_letter / set_sagsbehandlingsdato in
   the backend). So every bevilling that reached a decision — Aktiv,
   Udløbet, Ophørt or Afslag — has a 'Brev oprettet' activity, and the
   UPDATE below backfills sagsbehandlingsdato to match each letter's date.
   The kommentar mirrors each bevilling's assigned afgørelsesbrev.
   (Martin's afslag letter is already inserted in the block above.)
============================================================ */

INSERT INTO [befordring].[Sagsaktivitet]
    (cpr, aktivitetstype, kommentar, udfoert_af, oprettet_tidspunkt, relateret_bevilling_id)
VALUES
('0101101234', 'Brev oprettet', 'Bevilling: § 26, stk. 1, nr. 1 (afstand)',            'Sofie', '2026-01-15T11:00:00', @bevilling_1),
('0202101234', 'Brev oprettet', 'Bevilling: § 26, stk. 2 (sygdom)',                    'Nina',  '2026-02-10T10:30:00', @bevilling_2),
('0303101234', 'Brev oprettet', 'Bevilling: § 26, stk. 1, nr. 2 (farlig skolevej)',    'Sofie', '2025-06-20T13:15:00', @bevilling_3),
('0404101234', 'Brev oprettet', 'Afslag: § 26, stk. 6, § 36, stk. 3 (frit skolevalg)', 'Nina',  '2025-12-20T09:45:00', @bevilling_4),
('1010101234', 'Brev oprettet', 'Bevilling: § 26, stk. 2 (sygdom)',                    'Nina',  '2024-06-01T09:30:00', @bevilling_10),
('1212101234', 'Brev oprettet', 'Bevilling: § 26, stk. 1, nr. 1 (afstand)',            'Nina',  '2023-08-05T08:30:00', @bevilling_12),
('1313101234', 'Brev oprettet', 'Bevilling: § 26, stk. 2 (sygdom)',                    'Sofie', '2025-12-20T14:00:00', @bevilling_13),
('1414101234', 'Brev oprettet', 'Bevilling: § 26, stk. 1, nr. 1 (afstand)',            'Nina',  '2025-03-20T10:00:00', @bevilling_14);


/* ============================================================
   Backfill sagsbehandlingsdato from each bevilling's letter date.
   Mirrors the runtime behaviour: the case is processed on the day its
   decision letter is created. Uses the latest 'Brev oprettet' activity
   per bevilling (there is one each here).
============================================================ */

UPDATE b
SET b.sagsbehandlingsdato = CONVERT(date, la.letter_dato)
FROM [befordring].[Bevilling] b
INNER JOIN (
    SELECT
        relateret_bevilling_id,
        MAX(oprettet_tidspunkt) AS letter_dato
    FROM [befordring].[Sagsaktivitet]
    WHERE aktivitetstype = 'Brev oprettet'
      AND relateret_bevilling_id IS NOT NULL
    GROUP BY relateret_bevilling_id
) la ON la.relateret_bevilling_id = b.bevilling_id;


/* ============================================================
   Quick test selects
============================================================ */

PRINT '';
PRINT 'Inserted test data. Previewing views...';
PRINT '';

SELECT * FROM [befordring].[view_Stamdata];
SELECT * FROM [befordring].[view_Student_Bevillinger];
SELECT * FROM [befordring].[view_Bevilling_Koerselsraekker];
SELECT * FROM [befordring].[view_All_Active_Bevillinger];
SELECT * FROM [befordring].[view_New_Applications];
SELECT * FROM [befordring].[view_Revurderinger];
SELECT * FROM [befordring].[Sagsaktivitet] ORDER BY cpr, oprettet_tidspunkt;

PRINT '';
PRINT 'ROLLBACK is active. Change to COMMIT when the data looks correct.';
PRINT '';

PRINT 'hello';

ROLLBACK TRANSACTION;
