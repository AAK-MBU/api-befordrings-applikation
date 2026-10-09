/*
    How often does a bevilling's address differ from the child's registered one?

    RUN THIS BEFORE DEPLOYING the folkeregister check in
    OS2FormsService._verify_against_folkeregister. That check refuses a
    submission whose address resolves to somewhere the child is not
    registered, where the "kør til/fra en anden adresse" box was not ticked.

    It is only worth having while the stops stay rare. This measures the
    historical rate, which is the best available estimate of how many queue
    items it will stop.

    READ THE NUMBER AS AN UPPER BOUND. These rows cannot distinguish:

      - a bevilling deliberately created on an alternate address, which the
        check would skip entirely;
      - a family that moved AFTER the bevilling was created, which the check
        would never have seen;
      - a genuine mismatch, which is what the check exists to catch.

    Only the third is a stop. So a few percent here means the check is
    cheap. Ten percent or more means the alternate-address path is busier
    than expected, or Elev drifts from Bevilling for a reason worth
    understanding before adding a gate on top of it.
*/

-- ---------------------------------------------------------------------------
-- 1. The rate.
-- ---------------------------------------------------------------------------
SELECT
    COUNT(*)                                                      AS bevillinger_i_alt,
    SUM(CASE WHEN e.adresse_id IS NULL THEN 1 ELSE 0 END)          AS elev_uden_adresse,
    SUM(CASE WHEN b.adresse_id = e.adresse_id THEN 1 ELSE 0 END)   AS enige,
    SUM(CASE WHEN e.adresse_id IS NOT NULL
             AND  b.adresse_id <> e.adresse_id THEN 1 ELSE 0 END)  AS uenige
FROM       [befordring].[Bevilling] b
INNER JOIN [befordring].[Elev]      e ON e.cpr = b.cpr_elev
WHERE      b.aktiv = 1;


-- ---------------------------------------------------------------------------
-- 2. The disagreements themselves, newest first, so the reason is visible.
--
--    Read a sample. If most pairs are plainly the same family at two
--    different addresses over time, the rate is dominated by moves and the
--    check costs little. If pairs look like the SAME address written two
--    ways, the matching is still wrong somewhere and that is worth fixing
--    before gating on it.
-- ---------------------------------------------------------------------------
SELECT TOP (100)
    b.bevilling_id,
    b.cpr_elev,
    b.created_at,
    ab.adresse_tekst AS adresse_paa_bevilling,
    ae.adresse_tekst AS adresse_paa_elev
FROM       [befordring].[Bevilling] b
INNER JOIN [befordring].[Elev]      e  ON e.cpr = b.cpr_elev
LEFT  JOIN [befordring].[Adresse]   ab ON ab.adresse_id = b.adresse_id
LEFT  JOIN [befordring].[Adresse]   ae ON ae.adresse_id = e.adresse_id
WHERE      b.aktiv = 1
  AND      e.adresse_id IS NOT NULL
  AND      b.adresse_id <> e.adresse_id
ORDER BY   b.created_at DESC;
