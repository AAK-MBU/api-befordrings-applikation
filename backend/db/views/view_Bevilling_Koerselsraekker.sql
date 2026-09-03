USE [Befordringssystemet]
GO

/****** Object:  View [befordring].[view_Bevilling_Koerselsraekker]    Script Date: 03/09/2026 09:05:25 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER VIEW [befordring].[view_Bevilling_Koerselsraekker]
AS
    SELECT
        k.koersel_id,
        b.bevilling_id,

        k.tidspunkt_id,
        t.tidspunkt_tekst,

        k.befordringstype_id,
        bt.befordringstype_tekst,

        k.rutetype_id,
        rt.rutetype_tekst,

        kt.tillaeg_ids,
        kt.tillaeg_tekst,

        k.bevilget_koereafstand_pr_vej,

        ud.dag_ids,
        ud.dage,

        k.gyldig_fra,
        k.gyldig_til,
        k.taxa_id,
        k.kommentar,

        k.transporttid_i_bus,
        k.skift_med_bus,

        k.koersel_til_institution,
        k.max_minutter_i_transport,
        k.koerselsgodtgoerelse_modtager_id,

        k.final
    FROM
        [Befordringssystemet].[befordring].[Koersel] k
    LEFT JOIN
        [Befordringssystemet].[befordring].[Bevilling] b
        ON k.bevilling_id = b.bevilling_id
    LEFT JOIN
        [Befordringssystemet].[befordring].[Tidspunkt] t
        ON k.tidspunkt_id = t.tidspunkt_id
    LEFT JOIN
        [Befordringssystemet].[befordring].[Befordringstype] bt
        ON k.befordringstype_id = bt.befordringstype_id
    LEFT JOIN
        [Befordringssystemet].[befordring].[Rutetype] rt
        ON k.rutetype_id = rt.rutetype_id
    LEFT JOIN (
        SELECT
            ktt_link.koersel_id,
            STRING_AGG(CAST(ktt_link.tillaeg_id AS varchar(20)), ',') AS tillaeg_ids,
            STRING_AGG(ktt.tillaeg_tekst, ', ') AS tillaeg_tekst
        FROM
            [Befordringssystemet].[befordring].[Koersel_KoerselstypeTillaeg_LINK] ktt_link
        INNER JOIN
            [Befordringssystemet].[befordring].[KoerselstypeTillaeg] ktt
            ON ktt.tillaeg_id = ktt_link.tillaeg_id
        GROUP BY
            ktt_link.koersel_id
    ) kt
        ON k.koersel_id = kt.koersel_id
    LEFT JOIN (
        SELECT
            ku_link.koersel_id,
            STRING_AGG(CAST(ku_link.dag_id AS varchar(20)), ',') AS dag_ids,
            STRING_AGG(u.dag_tekst, ', ') AS dage
        FROM
            [Befordringssystemet].[befordring].[Koersel_Ugedag_LINK] ku_link
        INNER JOIN
            [Befordringssystemet].[befordring].[Ugedag] u
            ON u.dag_id = ku_link.dag_id
        GROUP BY
            ku_link.koersel_id
    ) ud
        ON k.koersel_id = ud.koersel_id
    -- Soft-deleted kørselsrækker must not come back through this view.
    -- bevilling_service.get_bevilling_koerselsraekker currently compensates
    -- with its own AND k.aktiv = 1 join; that join becomes redundant once
    -- this is deployed, but stays harmless.
    WHERE k.aktiv = 1;

GO


