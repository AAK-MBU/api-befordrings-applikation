USE [Befordringssystemet]
GO

/****** Object:  View [befordring].[view_Letter_Koerselsraekker]    Script Date: 03/09/2026 09:06:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER VIEW [befordring].[view_Letter_Koerselsraekker]
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

        -- Egenbefordring-specific: the recipient's name, not the id. The id
        -- means nothing in a letter, and this view resolves ids to text
        -- everywhere else (befordringstype_tekst, tidspunkt_tekst, dage).
        modtager.fulde_navn AS koerselsgodtgoerelse_modtager,

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
-- A deleted kørselsrække must never reach a decision letter.
WHERE
    k.aktiv = 1;
GO


