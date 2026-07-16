/* ============================================================
   0006 — Rewrite usp_recalculate_bevilling_status.

   "Revurdering" is no longer a status. The proc now:
     - computes the real status normally (no Revurdering branch);
     - computes a parallel `needs_revurdering` bit using the same
       triggers the old Revurdering status used (approaching
       revurderingsdato / skolekode-mismatch / adresse-mismatch,
       plus "stay until PPR or BR signs off" — now keyed off the
       current `revurdering` flag instead of the current status);
     - writes b.revurdering, and resets revurderet_af_ppr/_br when
       a NEW reassessment cycle begins;
     - broadens the final UPDATE so flag-only changes persist.
   ============================================================ */

USE [Befordringssystemet];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [befordring].[usp_recalculate_bevilling_status]
    @bevilling_id INT = NULL,
    @today DATE = NULL,
    @dry_run BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @today IS NULL
    BEGIN
        SET @today = CONVERT(DATE, GETDATE());
    END;

    DECLARE
        @target_cpr NVARCHAR(50),
        @fejlet_status_id INT;

    SELECT
        @fejlet_status_id = s.status_id
    FROM
        [befordring].[Status] s
    WHERE
        s.status_tekst = N'Fejlet'
        AND s.aktiv = 1;

    IF @fejlet_status_id IS NULL
    BEGIN
        THROW 50003, 'Status does not exist: Fejlet.', 1;
    END;

    IF @bevilling_id IS NOT NULL
    BEGIN
        SELECT
            @target_cpr = b.cpr_elev
        FROM
            [befordring].[Bevilling] b
        WHERE
            b.bevilling_id = @bevilling_id;

        IF @target_cpr IS NULL
            AND NOT EXISTS (
                SELECT 1
                FROM [befordring].[Bevilling]
                WHERE bevilling_id = @bevilling_id
            )
        BEGIN
            THROW 50001, 'Bevilling not found.', 1;
        END;
    END;

    ;WITH target_bevillinger AS (
        SELECT
            b.bevilling_id,
            b.cpr_elev,
            b.status_id AS current_status_id,
            s.status_tekst AS current_status_text,
            b.sagsbehandler_id,
            CONVERT(DATE, b.revurderingsdato) AS revurderingsdato,
            b.revurderet_af_ppr,
            b.revurderet_af_br,
            b.revurdering AS current_revurdering,
            CASE
                WHEN b.matrikel_id IS NOT NULL
                    AND ISNULL(e.skolekode, 0) <> 0
                    AND e.skolekode <> sm.skolekode
                THEN 1
                ELSE 0
            END AS skolekode_mismatch,
            CASE
                WHEN b.adresse_id IS NOT NULL
                    AND e.adresse_id IS NOT NULL
                    AND b.adresse_id <> e.adresse_id
                THEN 1
                ELSE 0
            END AS adresse_mismatch
        FROM
            [befordring].[Bevilling] b
        LEFT JOIN [befordring].[Status] s ON s.status_id = b.status_id
        LEFT JOIN [befordring].[Elev] e ON e.cpr = b.cpr_elev
        LEFT JOIN [befordring].[Skolematrikel] sm ON sm.matrikel_id = b.matrikel_id
        WHERE
            (
                @bevilling_id IS NOT NULL
                AND (
                    b.bevilling_id = @bevilling_id
                    OR (@target_cpr IS NOT NULL AND b.cpr_elev = @target_cpr)
                )
            )
            OR
            (
                @bevilling_id IS NULL
                AND LOWER(ISNULL(s.status_tekst, '')) NOT IN (N'udløbet', N'udgået')
            )
    ),

    koersel_flags AS (
        SELECT
            tb.*,
            COALESCE(kf.complete_koersel_count, 0) AS complete_koersel_count,
            COALESCE(kf.invalid_date_range_count, 0) AS invalid_date_range_count,
            COALESCE(kf.has_active_koersel, 0) AS has_active_koersel,
            COALESCE(kf.has_future_koersel, 0) AS has_future_koersel,
            COALESCE(kf.has_past_koersel, 0) AS has_past_koersel
        FROM
            target_bevillinger tb
        OUTER APPLY (
            SELECT
                COUNT(*) AS complete_koersel_count,
                SUM(CASE WHEN CONVERT(DATE, k.gyldig_fra) > CONVERT(DATE, k.gyldig_til) THEN 1 ELSE 0 END) AS invalid_date_range_count,
                MAX(CASE WHEN @today BETWEEN CONVERT(DATE, k.gyldig_fra) AND CONVERT(DATE, k.gyldig_til) THEN 1 ELSE 0 END) AS has_active_koersel,
                MAX(CASE WHEN CONVERT(DATE, k.gyldig_fra) > @today THEN 1 ELSE 0 END) AS has_future_koersel,
                MAX(CASE WHEN CONVERT(DATE, k.gyldig_til) < @today THEN 1 ELSE 0 END) AS has_past_koersel
            FROM [befordring].[Koersel] k
            WHERE
                k.bevilling_id = tb.bevilling_id
                AND k.gyldig_fra IS NOT NULL
                AND k.gyldig_til IS NOT NULL
        ) kf
    ),

    calculated AS (
        SELECT
            kf.bevilling_id,
            kf.current_status_id,
            kf.current_status_text,
            kf.skolekode_mismatch,
            kf.adresse_mismatch,
            -- Real status: NO Revurdering branch anymore.
            CASE
                WHEN LOWER(ISNULL(kf.current_status_text, '')) IN (N'afslag', N'ophørt')
                    THEN kf.current_status_text
                WHEN NULLIF(LTRIM(RTRIM(kf.cpr_elev)), '') IS NULL
                    THEN N'Fejlet'
                WHEN kf.complete_koersel_count = 0
                    THEN
                        CASE
                            WHEN kf.sagsbehandler_id IS NOT NULL
                                THEN N'Påbegyndt'
                            ELSE N'Ny'
                        END
                WHEN kf.invalid_date_range_count > 0
                    THEN N'Fejlet'
                WHEN kf.has_active_koersel = 1
                    THEN N'Aktiv'
                WHEN kf.has_future_koersel = 1
                    THEN N'Kommende'
                WHEN kf.has_past_koersel = 1
                    THEN N'Udløbet'
                ELSE N'Fejlet'
            END AS calculated_status_text,
            -- Reassessment flag: same triggers the old Revurdering status used.
            CASE
                WHEN LOWER(ISNULL(kf.current_status_text, '')) NOT IN (N'afslag', N'ophørt')
                    AND NULLIF(LTRIM(RTRIM(kf.cpr_elev)), '') IS NOT NULL
                    AND kf.complete_koersel_count > 0
                    AND kf.invalid_date_range_count = 0
                    AND (
                        -- entry
                        (
                            kf.has_active_koersel = 1
                            AND ISNULL(kf.revurderet_af_br, 0) = 0
                            AND (
                                (kf.revurderingsdato IS NOT NULL AND @today >= DATEADD(MONTH, -2, kf.revurderingsdato))
                                OR kf.skolekode_mismatch = 1
                                OR kf.adresse_mismatch = 1
                            )
                        )
                        OR
                        -- stay (was: current status = 'revurdering')
                        (
                            ISNULL(kf.current_revurdering, 0) = 1
                            AND ISNULL(kf.revurderet_af_ppr, 0) = 0
                            AND ISNULL(kf.revurderet_af_br, 0) = 0
                        )
                    )
                THEN 1
                ELSE 0
            END AS needs_revurdering
        FROM
            koersel_flags kf
    )

    SELECT
        c.bevilling_id,
        c.current_status_id,
        c.current_status_text,
        s.status_id AS calculated_status_id,
        c.calculated_status_text,
        c.needs_revurdering,
        c.skolekode_mismatch,
        c.adresse_mismatch,
        CASE
            WHEN ISNULL(c.current_status_id, -1) <> ISNULL(s.status_id, -1) THEN 1
            ELSE 0
        END AS status_will_change,
        CAST(NULL AS NVARCHAR(500)) AS status_reason
    INTO
        #calculated_statuses
    FROM
        calculated c
    LEFT JOIN
        [befordring].[Status] s ON s.status_tekst = c.calculated_status_text AND s.aktiv = 1;

    IF EXISTS (SELECT 1 FROM #calculated_statuses WHERE calculated_status_id IS NULL)
    BEGIN
        THROW 50002, 'Calculated status does not exist in Status table.', 1;
    END;

    /*
        Active conflict check.
        Rule: a citizen may not have more than one active bevilling.
        NOTE: reassessment-flagged bevillinger now have the real status Aktiv,
        so they participate in this rule (consistent with "still active").
    */
    ;WITH proposed_statuses AS (
        SELECT b.bevilling_id, b.cpr_elev, cs.calculated_status_text AS proposed_status_text
        FROM [befordring].[Bevilling] b
        INNER JOIN #calculated_statuses cs ON cs.bevilling_id = b.bevilling_id

        UNION ALL

        SELECT b.bevilling_id, b.cpr_elev, s.status_tekst AS proposed_status_text
        FROM [befordring].[Bevilling] b
        INNER JOIN [befordring].[Status] s ON s.status_id = b.status_id
        WHERE NOT EXISTS (SELECT 1 FROM #calculated_statuses cs WHERE cs.bevilling_id = b.bevilling_id)
    ),
    active_conflicts AS (
        SELECT ps.cpr_elev
        FROM proposed_statuses ps
        WHERE NULLIF(LTRIM(RTRIM(ps.cpr_elev)), '') IS NOT NULL
          AND LOWER(ps.proposed_status_text) = N'aktiv'
        GROUP BY ps.cpr_elev
        HAVING COUNT(*) > 1
    )

    UPDATE cs
    SET
        cs.calculated_status_id   = @fejlet_status_id,
        cs.calculated_status_text = N'Fejlet',
        cs.status_reason          = N'Borgeren har mere end én aktiv bevilling',
        cs.status_will_change     = CASE
                                        WHEN ISNULL(cs.current_status_id, -1) <> ISNULL(@fejlet_status_id, -1) THEN 1
                                        ELSE 0
                                    END
    FROM #calculated_statuses cs
    INNER JOIN [befordring].[Bevilling] b ON b.bevilling_id = cs.bevilling_id
    INNER JOIN active_conflicts ac ON ac.cpr_elev = b.cpr_elev
    WHERE LOWER(cs.calculated_status_text) = N'aktiv';

    -- Do not flag a broken (Fejlet) bevilling as needing reassessment.
    UPDATE #calculated_statuses
    SET needs_revurdering = 0
    WHERE calculated_status_text = N'Fejlet';

    /* Revurdering reason — skolekode mismatch. */
    UPDATE cs
    SET cs.status_reason = N'Skolekode på bevilling matcher ikke elevens aktuelle skolekode'
    FROM #calculated_statuses cs
    WHERE
        cs.skolekode_mismatch = 1
        AND cs.needs_revurdering = 1
        AND cs.status_reason IS NULL;

    /* Revurdering reason — address mismatch. */
    UPDATE cs
    SET cs.status_reason = N'Elevens adresse matcher ikke adressen på bevillingen'
    FROM #calculated_statuses cs
    WHERE
        cs.adresse_mismatch = 1
        AND cs.needs_revurdering = 1
        AND cs.status_reason IS NULL;

    /* Revurdering reason — approaching revurderingsdato. */
    UPDATE cs
    SET cs.status_reason = N'Bevillingen nærmer sig revurderingsdato'
    FROM #calculated_statuses cs
    INNER JOIN [befordring].[Bevilling] b ON b.bevilling_id = cs.bevilling_id
    WHERE
        cs.needs_revurdering = 1
        AND b.revurderingsdato IS NOT NULL
        AND @today >= DATEADD(MONTH, -2, CONVERT(DATE, b.revurderingsdato))
        AND cs.status_reason IS NULL;

    /* Fejlet reason — missing CPR. */
    UPDATE cs
    SET cs.status_reason = N'Bevillingen mangler CPR-nummer'
    FROM #calculated_statuses cs
    INNER JOIN [befordring].[Bevilling] b ON b.bevilling_id = cs.bevilling_id
    WHERE
        cs.calculated_status_text = N'Fejlet'
        AND NULLIF(LTRIM(RTRIM(b.cpr_elev)), '') IS NULL
        AND cs.status_reason IS NULL;

    /* Fejlet reason — invalid koerselsraekke date range. */
    UPDATE cs
    SET cs.status_reason = N'En eller flere kørselsrækker har ugyldig datoperiode'
    FROM #calculated_statuses cs
    WHERE
        cs.calculated_status_text = N'Fejlet'
        AND cs.status_reason IS NULL
        AND EXISTS (
            SELECT 1
            FROM [befordring].[Koersel] k
            WHERE k.bevilling_id = cs.bevilling_id
              AND k.gyldig_fra IS NOT NULL
              AND k.gyldig_til IS NOT NULL
              AND CONVERT(DATE, k.gyldig_fra) > CONVERT(DATE, k.gyldig_til)
        );

    IF @dry_run = 0
    BEGIN
        UPDATE b
        SET
            b.status_id = cs.calculated_status_id,
            b.revurdering = cs.needs_revurdering,
            b.statusbemaerkning = CASE
                WHEN cs.calculated_status_text = N'Fejlet' THEN cs.status_reason
                WHEN cs.needs_revurdering = 1 THEN cs.status_reason
                ELSE NULL
            END,
            -- Reset PPR/BR sign-off when a NEW reassessment cycle begins
            -- (flag flips 0 -> 1). Reads the OLD b.revurdering value.
            b.revurderet_af_ppr = CASE
                WHEN cs.needs_revurdering = 1 AND ISNULL(b.revurdering, 0) = 0
                    THEN NULL
                ELSE b.revurderet_af_ppr
            END,
            b.revurderet_af_br = CASE
                WHEN cs.needs_revurdering = 1 AND ISNULL(b.revurdering, 0) = 0
                    THEN NULL
                ELSE b.revurderet_af_br
            END,
            b.updated_by = 'status_engine',
            b.updated_at = GETDATE()
        FROM
            [befordring].[Bevilling] b
        INNER JOIN
            #calculated_statuses cs ON cs.bevilling_id = b.bevilling_id
        WHERE
            ISNULL(b.status_id, -1) <> ISNULL(cs.calculated_status_id, -1)
            OR ISNULL(b.revurdering, 0) <> cs.needs_revurdering
            OR ISNULL(b.statusbemaerkning, N'') <> ISNULL(
                   CASE
                       WHEN cs.calculated_status_text = N'Fejlet' THEN cs.status_reason
                       WHEN cs.needs_revurdering = 1 THEN cs.status_reason
                       ELSE NULL
                   END, N'');
    END;

    SELECT
        bevilling_id,
        current_status_id,
        current_status_text,
        calculated_status_id,
        calculated_status_text,
        needs_revurdering,
        skolekode_mismatch,
        adresse_mismatch,
        status_will_change,
        status_reason,
        @dry_run AS dry_run
    FROM
        #calculated_statuses
    ORDER BY
        bevilling_id;
END;
GO
