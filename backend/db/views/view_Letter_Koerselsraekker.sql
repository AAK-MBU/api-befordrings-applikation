USE [Befordringssystemet]
GO

/****** Object:  View [befordring].[view_Letter_Koerselsraekker]    Script Date: 03/09/2026 09:06:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER VIEW [befordring].[view_Letter_Koerselsraekker]
AS
    SELECT
        k.koersel_id,
        k.bevilling_id,

        LOWER(
            REPLACE(
                REPLACE(
                    REPLACE(bt.befordringstype_tekst, 'ø', 'oe'),
                'å', 'aa'),
            ' ', '_')
        ) AS koerselstype_key,

        bt.befordringstype_tekst AS koerselstype,

        t.tidspunkt_tekst AS tidspunkt,

        CONVERT(varchar(10), k.gyldig_fra, 105) AS bevilling_fra,
        CONVERT(varchar(10), k.gyldig_til, 105) AS bevilling_til,

        k.bevilget_koereafstand_pr_vej,
        k.taxa_id,

        k.transporttid_i_bus,
        k.skift_med_bus,

        -- Taxa-specific. koersel_til_institution is resolved to Ja/Nej here
        -- rather than shipped as a BIT: everything this view exposes drops
        -- straight into letter text, and a raw bit arrives in the RPA as
        -- Python True/False.
        CASE
            WHEN k.koersel_til_institution = 1 THEN N'Ja'
            WHEN k.koersel_til_institution = 0 THEN N'Nej'
            ELSE NULL
        END AS koersel_til_institution,
        k.max_minutter_i_transport,

        -- Egenbefordring-specific: who the kørselsgodtgørelse is paid to.
        -- Resolved to name and CPR, not the id — the id means nothing in a
        -- letter, and this view resolves ids to text everywhere else
        -- (befordringstype_tekst, tidspunkt_tekst, dage).
        --
        -- The recipient lives in one of two mutually exclusive columns:
        --   koerselsgodtgoerelse_modtager_id  -> Part      (øvrig part)
        --   koerselsgodtgoerelse_modtager_cpr -> Foraelder (legal guardian)
        -- so both are COALESCEd, exactly as view_Koerselsgodtgoerelse_Modtagere
        -- does. Only the Part branch was resolved before, which left every
        -- parent recipient blank in the letter.
        COALESCE(foraelder.adresseringsnavn, modtager.fulde_navn)
            AS koerselsgodtgoerelse_modtager,
        COALESCE(foraelder.cpr_foraelder, modtager.cpr_nummer)
            AS koerselsgodtgoerelse_modtager_cpr,

        dage.dage,
        tillaeg.koerselstype_tillaeg
    FROM
        [Befordringssystemet].[befordring].[Koersel] k
    LEFT JOIN
        [Befordringssystemet].[befordring].[Befordringstype] bt
        ON bt.befordringstype_id = k.befordringstype_id
    LEFT JOIN
        [Befordringssystemet].[befordring].[Tidspunkt] t
        ON t.tidspunkt_id = k.tidspunkt_id
    LEFT JOIN (
        SELECT
            kud.koersel_id,
            STRING_AGG(u.dag_tekst, ', ') AS dage
        FROM
            [Befordringssystemet].[befordring].[Koersel_Ugedag_LINK] kud
        INNER JOIN
            [Befordringssystemet].[befordring].[Ugedag] u
            ON u.dag_id = kud.dag_id
        GROUP BY
            kud.koersel_id
    ) dage
        ON dage.koersel_id = k.koersel_id
    LEFT JOIN (
        SELECT
            ktt_link.koersel_id,
            STRING_AGG(ktt.tillaeg_tekst, ', ') AS koerselstype_tillaeg
        FROM
            [Befordringssystemet].[befordring].[Koersel_KoerselstypeTillaeg_LINK] ktt_link
        INNER JOIN
            [Befordringssystemet].[befordring].[KoerselstypeTillaeg] ktt
            ON ktt.tillaeg_id = ktt_link.tillaeg_id
        GROUP BY
            ktt_link.koersel_id
    ) tillaeg
        ON tillaeg.koersel_id = k.koersel_id
    LEFT JOIN
        [Befordringssystemet].[befordring].[Part] modtager
        ON modtager.part_id = k.koerselsgodtgoerelse_modtager_id
    -- Foraelder is keyed on (cpr_foraelder, cpr_elev), so BOTH halves are
    -- matched. On cpr_foraelder alone a parent with two children in the system
    -- would multiply this kørselsrække into two rows, and the letter would
    -- list it twice.
    LEFT JOIN
        [Befordringssystemet].[befordring].[Bevilling] bev
        ON bev.bevilling_id = k.bevilling_id
    LEFT JOIN
        [Befordringssystemet].[befordring].[Foraelder] foraelder
        ON  foraelder.cpr_foraelder = k.koerselsgodtgoerelse_modtager_cpr
        AND foraelder.cpr_elev      = bev.cpr_elev
-- A deleted kørselsrække must never reach a decision letter.
WHERE
    k.aktiv = 1;
GO


