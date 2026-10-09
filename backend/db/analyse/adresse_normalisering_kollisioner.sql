/*
    Does normalised address matching risk a WRONG match?

    _resolve_adresse_id compares a submitted address to Adresse.adresse_tekst
    after collapsing full stops, commas and whitespace to a single space,
    removing leading zeros from numbers, and case folding. It accepts the
    match only when exactly one row matches, so the one way this can go wrong
    is two DIFFERENT addresses reducing to the same key — and then it refuses
    rather than guessing.

    Part 2 is the proof. Run against the register it returns four groups, and
    all four are the SAME address stored twice rather than two addresses
    colliding:

        Bavne Alle 12, 1,  /  Bavne Alle 12, 1.,     differ by a full stop
        Smedegade 30D, 1,  /  Smedegade 30D, 1.,     differ by a full stop
        Søndergade 24B, 1, /  Søndergade 24B, 1.,    differ by a full stop
        Rådhuspladsen 1,   /  Rådhuspladsen 1,       identical

    So there is no pair of distinct front doors that the rule cannot tell
    apart. The residue is a data-quality problem in Adresse — see part 4 —
    and the Rådhuspladsen pair was already ambiguous under the exact matching
    that came before, since the two rows hold the same string.

    That residue is the expected result. Anything BEYOND those four groups is
    a real collision and has to be understood before the matching is trusted.

    HISTORY — why the rule is what it is.
    The first version of this normalisation DELETED the separators instead of
    collapsing them. Running part 2 against the register rejected that
    immediately: without the separators the house number swallows the floor,
    and distinct front doors collide.

        Skovvejen 1, 1. 1  /  Skovvejen 11, 1.  /  Skovvejen 111
        Abildgade 2, 3.    /  Abildgade 23
        Anton Rosens Plads 1, b  /  Anton Rosens Plads 1B

    Keeping one space between the tokens separates all of them again without
    costing a single real match, because the MitID and DAR spellings of one
    address differ only in which separator sits between the tokens, never in
    where the token boundaries fall. Re-run this before widening the rule
    again.

    Scope is the Aarhus postcodes (8000-8399, which includes Samsø). Adresse
    holds the whole of Denmark and the LIKE is a scan, so a nationwide version
    is expensive and pointless — a bevilling address is always local.
*/

-- ---------------------------------------------------------------------------
-- 1. The submission that failed, and what the register actually holds.
--    Expect exactly one row, reading "Rosenhøj Bakke 22, 1. th, 8260 Viby J".
-- ---------------------------------------------------------------------------
SELECT adresse_id, adresse_tekst
FROM   [befordring].[Adresse]
WHERE  adresse_tekst LIKE 'Rosenhøj Bakke 22,%'
  AND  adresse_tekst LIKE '%, 8260 %'
ORDER  BY adresse_tekst;


-- ---------------------------------------------------------------------------
-- 2. Collisions: two stored addresses that normalise to the same key.
--
--    Any row returned is a pair the matching will refuse to choose between.
--    That is not a wrong match — it is a submission that stops for a
--    caseworker — but it is still a defect in the rule, so this should be
--    empty.
--
--    The zero stripping below is slightly BLUNTER than the Python: it removes
--    a leading zero from a space-delimited token whether or not a digit
--    survives it. That can only merge more strings, never fewer, so this
--    over-reports rather than under-reports. A row that appears here and not
--    in app.utils.adresse_matching is a false alarm, not a missed collision.
-- ---------------------------------------------------------------------------
WITH separatorer AS (
    -- Full stops and commas become spaces, exactly as _SEPARATORS does.
    SELECT
        adresse_tekst,
        LOWER(REPLACE(REPLACE(adresse_tekst, '.', ' '), ',', ' ')) AS tekst
    FROM [befordring].[Adresse]
    WHERE adresse_tekst LIKE '%, 8[0-3][0-9][0-9] %'
),
enkelt_mellemrum AS (
    -- Collapse any run of spaces to one. The '§~' / '~§' pair is the standard
    -- T-SQL trick: it has no REPLACE with a regex, and the pair cannot occur
    -- in an address.
    SELECT
        adresse_tekst,
        LTRIM(RTRIM(
            REPLACE(REPLACE(REPLACE(tekst, ' ', '§~'), '~§', ''), '§~', ' ')
        )) AS tekst
    FROM separatorer
),
normaliseret AS (
    -- Leading zeros, applied enough times to cover any real padding.
    SELECT
        adresse_tekst,
        REPLACE(REPLACE(REPLACE(' ' + tekst, ' 0', ' '), ' 0', ' '), ' 0', ' ')
            AS noegle
    FROM enkelt_mellemrum
)
SELECT
    noegle,
    COUNT(*)            AS antal_adresser,
    MIN(adresse_tekst)  AS eksempel_a,
    MAX(adresse_tekst)  AS eksempel_b
FROM   normaliseret
GROUP  BY noegle
HAVING COUNT(*) > 1
ORDER  BY antal_adresser DESC, noegle;


-- ---------------------------------------------------------------------------
-- 3. Does the register itself ever zero-pad a number?
--
--    Expect zero rows. If it does, part 2's blunter zero stripping is doing
--    real work rather than being a harmless over-approximation, and the two
--    implementations should be compared more carefully before trusting
--    either.
-- ---------------------------------------------------------------------------
SELECT TOP (50) adresse_id, adresse_tekst
FROM   [befordring].[Adresse]
WHERE  adresse_tekst LIKE '%, 8[0-3][0-9][0-9] %'
  AND  (adresse_tekst LIKE '% 0[0-9]%' OR adresse_tekst LIKE '%,0[0-9]%')
ORDER  BY adresse_tekst;


-- ---------------------------------------------------------------------------
-- 4. The duplicates behind part 2's residue, with their ids and coordinates.
--
--    _resolve_adresse_id refuses to choose between two rows, so a submission
--    at one of these addresses stops for a caseworker instead of resolving.
--    That is the correct behaviour for an ambiguous register, but the
--    ambiguity itself is worth removing.
--
--    Deduplicating is NOT just a DELETE: adresse_id is the FK target from
--    Elev, Foraelder and Bevilling, so a merge has to repoint those first,
--    and the nightly SAS sync will re-create the rows unless it is taught to
--    collapse them too. Treat this as a separate piece of work.
--
--    Check the coordinates before assuming the rows are interchangeable. Two
--    rows for one address should sit on the same point; if they do not, the
--    distance calculation depends on which one a bevilling happens to hold.
-- ---------------------------------------------------------------------------
WITH duplikater AS (
    SELECT
        adresse_id,
        adresse_tekst,
        latitude,
        longitude,
        COUNT(*) OVER (PARTITION BY REPLACE(adresse_tekst, '.', '')) AS antal
    FROM [befordring].[Adresse]
    WHERE adresse_tekst LIKE '%, 8[0-3][0-9][0-9] %'
)
SELECT adresse_id, adresse_tekst, latitude, longitude
FROM   duplikater
WHERE  antal > 1
ORDER  BY REPLACE(adresse_tekst, '.', ''), adresse_id;


/*
    Parts 5 and 6 cover the supplerende bynavn relaxation.

    MitID drops the component that DAR keeps, so a strict comparison fails on
    every village inside an Aarhus postcode:

        MitID     Thomas Windings Gade 52, 8200 Aarhus N
        Adresse   Thomas Windings Gade 52, Lisbjerg, 8200 Aarhus N

    _resolve_adresse_id therefore runs a SECOND pass, with the component
    removed from both sides, but only where the first pass matched nothing and
    only where exactly one row comes back.

    The component is identified by position — second-to-last, which is where
    DAR puts it — and then confirmed by content, because with three components
    the second-to-last is either the bynavn or the floor/door. The test
    demands no digits and a token of five characters or more.

    Both queries below quantify what that costs.

    NOTE the COLLATE on every bynavn test. Under the database's Danish
    collation "aa" is a single collation unit equal to "å", so it does
    not satisfy a single-character range and a run of five letters goes
    unrecognised in exactly the names that contain it: Maarup and Aakjær
    were reported as too short when Python, counting plain characters,
    correctly reads them as six. Latin1_General compares the two a's
    separately and the two implementations then agree.
*/

-- ---------------------------------------------------------------------------
-- 5. Place names the relaxation will NOT cover: a bynavn whose every token is
--    shorter than five characters, which the test cannot tell from a door.
--
--    These keep behaving exactly as they do today — the submission fails to
--    match and a caseworker sees a 422 naming the address. Nothing regresses;
--    the question is only how many addresses miss out on the fix.
--
--    Lengthening the list of exceptions is NOT the way to fix one of these.
--    The threshold leans this way on purpose: failing to strip a place name
--    costs a caseworker two minutes, while stripping a real floor or door
--    lets a submission reach the wrong flat in the right building.
-- ---------------------------------------------------------------------------
WITH komponenter AS (
    SELECT
        adresse_tekst,
        -- The text before ", postnr by".
        LEFT(adresse_tekst, LEN(adresse_tekst) - CHARINDEX(',', REVERSE(adresse_tekst))) AS hoved
    FROM [befordring].[Adresse]
    WHERE adresse_tekst LIKE '%, 8[0-3][0-9][0-9] %'
),
bynavne AS (
    SELECT
        adresse_tekst,
        LTRIM(RTRIM(
            SUBSTRING(hoved, LEN(hoved) - CHARINDEX(',', REVERSE(hoved)) + 2, LEN(hoved))
        )) AS bynavn
    FROM komponenter
    -- A second comma is what makes a middle component exist at all.
    WHERE CHARINDEX(',', hoved) > 0
)
SELECT   bynavn, COUNT(*) AS antal_adresser, MIN(adresse_tekst) AS eksempel
FROM     bynavne
WHERE    bynavn NOT LIKE '%[0-9]%'       -- a floor/door component, not a place
  AND    bynavn COLLATE Latin1_General_CI_AS NOT LIKE '%[a-zæøå][a-zæøå][a-zæøå][a-zæøå][a-zæøå]%'      -- no token reaches five characters
  AND    bynavn <> ''
GROUP BY bynavn
ORDER BY antal_adresser DESC, bynavn;


-- ---------------------------------------------------------------------------
-- 6. Addresses the relaxation makes AMBIGUOUS: the same street, number,
--    floor and door in one postcode, under two different place names.
--
--    A submission for one of these resolves only if it carries the place
--    name. Without it both rows match, and _resolve_adresse_id refuses rather
--    than choosing — which is the correct answer, but it is a stop rather
--    than a success, so it is worth knowing how many there are.
--
--    Expect few or none. Any row here is a pair where the supplerende bynavn
--    IS identifying, which is exactly why the second pass may never pick a
--    winner on its own.
-- ---------------------------------------------------------------------------
WITH komponenter AS (
    SELECT
        adresse_tekst,
        LEFT(adresse_tekst, LEN(adresse_tekst) - CHARINDEX(',', REVERSE(adresse_tekst))) AS hoved,
        SUBSTRING(adresse_tekst, LEN(adresse_tekst) - CHARINDEX(',', REVERSE(adresse_tekst)) + 1, LEN(adresse_tekst)) AS hale
    FROM [befordring].[Adresse]
    WHERE adresse_tekst LIKE '%, 8[0-3][0-9][0-9] %'
),
delt AS (
    SELECT
        adresse_tekst,
        hale,
        LEFT(hoved, LEN(hoved) - CHARINDEX(',', REVERSE(hoved)))                                   AS foran,
        LTRIM(RTRIM(SUBSTRING(hoved, LEN(hoved) - CHARINDEX(',', REVERSE(hoved)) + 2, LEN(hoved)))) AS bynavn
    FROM komponenter
    WHERE CHARINDEX(',', hoved) > 0
),
uden_bynavn AS (
    SELECT adresse_tekst, LOWER(foran + hale) AS noegle
    FROM   delt
    -- Only where the component really is a place name, matching the rule in
    -- app.utils.adresse_matching._is_supplerende_bynavn.
    WHERE  bynavn NOT LIKE '%[0-9]%'
      AND  bynavn COLLATE Latin1_General_CI_AS LIKE '%[a-zæøå][a-zæøå][a-zæøå][a-zæøå][a-zæøå]%'
)
SELECT   noegle,
         COUNT(*)           AS antal_adresser,
         MIN(adresse_tekst) AS eksempel_a,
         MAX(adresse_tekst) AS eksempel_b
FROM     uden_bynavn
GROUP BY noegle
HAVING   COUNT(*) > 1
ORDER BY antal_adresser DESC, noegle;


-- ---------------------------------------------------------------------------
-- 7. THE AUDIT: every component the relaxation will actually remove.
--
--    Part 5 lists what the bynavn test refuses to strip. This lists what it
--    DOES strip, which is the assumption that carries real risk — removing a
--    component that identifies an address is how a bevilling ends up on the
--    wrong one.
--
--    Read the list. Every row should be a recognisable place name. A floor,
--    a door, a c/o line or anything else appearing here means the test is
--    too loose and must be tightened before the second pass is trusted.
-- ---------------------------------------------------------------------------
WITH komponenter AS (
    SELECT
        adresse_tekst,
        LEFT(adresse_tekst, LEN(adresse_tekst) - CHARINDEX(',', REVERSE(adresse_tekst))) AS hoved
    FROM [befordring].[Adresse]
    WHERE adresse_tekst LIKE '%, 8[0-3][0-9][0-9] %'
),
bynavne AS (
    SELECT
        adresse_tekst,
        LTRIM(RTRIM(
            SUBSTRING(hoved, LEN(hoved) - CHARINDEX(',', REVERSE(hoved)) + 2, LEN(hoved))
        )) AS bynavn
    FROM komponenter
    WHERE CHARINDEX(',', hoved) > 0
)
SELECT   bynavn, COUNT(*) AS antal_adresser, MIN(adresse_tekst) AS eksempel
FROM     bynavne
WHERE    bynavn NOT LIKE '%[0-9]%'   -- no digits, as _is_supplerende_bynavn requires
  AND    bynavn COLLATE Latin1_General_CI_AS LIKE '%[a-zæøå][a-zæøå][a-zæøå][a-zæøå][a-zæøå]%'       -- a token of five characters or more
GROUP BY bynavn
ORDER BY bynavn;
