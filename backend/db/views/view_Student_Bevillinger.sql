USE [Befordringssystemet]
GO

/****** Object:  View [befordring].[view_Student_Bevillinger]    Script Date: 02/09/2026 14:09:53 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






ALTER VIEW [befordring].[view_Student_Bevillinger]
AS
SELECT
    b.bevilling_id,
    b.created_at,
    b.updated_at,

    e.navne_adresse_beskyttelse,
    e.adresseringsnavn,
    e.cpr,

    b.status_id,
    st.status_tekst,
    b.statusbemaerkning,
    b.revurdering,
    b.final,
    b.esdh_noegle,
    e.elevklassetrin,

    b.sagsbehandlingsdato,
    ba.adresse_tekst                                              AS adresse_for_bevilling,
    b.adresse_id,
    ba.latitude                                                   AS adresse_latitude,
    ba.longitude                                                  AS adresse_longitude,
    b.ansoegningstype,
    b.ansoegningsdato,

    b.matrikel_id,
    sk.matrikel_navn,

    b.ungdomsuddannelse_id,
    uu.ungdomsuddannelse_navn,

    COALESCE(sk.matrikel_navn, uu.ungdomsuddannelse_navn)         AS skole_navn,

    e.skoleafstand,

    STRING_AGG(CAST(h.hjaelpemiddel_id AS varchar(20)), ',')     AS hjaelpemiddel_ids,
    STRING_AGG(h.hjaelpemiddel_tekst, ', ')                      AS hjaelpemidler,

    b.afstandskriterie_dato,
    b.afstandskriterie_klassetrin,
    b.relation_til_barnet,
    b.revurderingsdato,
    b.befordringsudvalg,

    b.hjemmel_id,
    hjemmel.hjemmel_tekst,

    b.afgoerelsesbrev_id,
    afg.afgoerelsesbrev_tekst,

    b.sagsbehandler_id,
    sb.sagsbehandler_tekst,

    b.ppr_sagsbehandler_id,
    ppr.ppr_sagsbehandler_tekst
FROM
    [Befordringssystemet].[befordring].[Bevilling]                b
LEFT JOIN [Befordringssystemet].[befordring].[Elev]                     e       ON e.cpr                    = b.cpr_elev
LEFT JOIN [Befordringssystemet].[befordring].[Adresse]                  ba      ON ba.adresse_id             = b.adresse_id
LEFT JOIN [Befordringssystemet].[befordring].[Status]                   st      ON b.status_id               = st.status_id
LEFT JOIN [Befordringssystemet].[befordring].[Skolematrikel]            sk      ON sk.matrikel_id            = b.matrikel_id
LEFT JOIN [Befordringssystemet].[befordring].[Ungdomsuddannelse]        uu      ON uu.ungdomsuddannelse_id   = b.ungdomsuddannelse_id
LEFT JOIN [Befordringssystemet].[befordring].[Bevilling_Hjaelpemiddel_LINK] bhl ON b.bevilling_id            = bhl.bevilling_id
LEFT JOIN [Befordringssystemet].[befordring].[Hjaelpemiddel]            h       ON h.hjaelpemiddel_id        = bhl.hjaelpemiddel_id
LEFT JOIN [Befordringssystemet].[befordring].[Hjemmel]                  hjemmel ON b.hjemmel_id              = hjemmel.hjemmel_id
LEFT JOIN [Befordringssystemet].[befordring].[Afgoerelsesbrev]          afg     ON b.afgoerelsesbrev_id      = afg.afgoerelsesbrev_id
LEFT JOIN [Befordringssystemet].[befordring].[Sagsbehandler]            sb      ON b.sagsbehandler_id        = sb.sagsbehandler_id
LEFT JOIN [Befordringssystemet].[befordring].[PPR_Sagsbehandler]        ppr     ON b.ppr_sagsbehandler_id    = ppr.ppr_sagsbehandler_id

WHERE
    b.aktiv = 1

GROUP BY
    b.bevilling_id, b.created_at, b.updated_at,
    e.navne_adresse_beskyttelse, e.adresseringsnavn, e.cpr,
    b.status_id, st.status_tekst, b.statusbemaerkning, b.revurdering, b.final, b.esdh_noegle, e.elevklassetrin,
    b.sagsbehandlingsdato,
    ba.adresse_tekst,
    b.adresse_id,
    ba.latitude,
    ba.longitude,
    b.ansoegningstype,
    b.ansoegningsdato,
    b.matrikel_id, sk.matrikel_navn,
    b.ungdomsuddannelse_id, uu.ungdomsuddannelse_navn,
    e.skoleafstand,
    b.afstandskriterie_dato, b.afstandskriterie_klassetrin,
    b.relation_til_barnet, b.revurderingsdato, b.befordringsudvalg,
    b.hjemmel_id, hjemmel.hjemmel_tekst,
    b.afgoerelsesbrev_id, afg.afgoerelsesbrev_tekst,
    b.sagsbehandler_id, sb.sagsbehandler_tekst,
    b.ppr_sagsbehandler_id, ppr.ppr_sagsbehandler_tekst;
GO


