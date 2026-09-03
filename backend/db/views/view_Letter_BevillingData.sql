USE [Befordringssystemet]
GO

/****** Object:  View [befordring].[view_Letter_BevillingData]    Script Date: 03/09/2026 09:06:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [befordring].[view_Letter_BevillingData]
AS
SELECT
    b.bevilling_id,
    e.cpr                           AS barnets_cpr,
    e.adresseringsnavn              AS barnets_fulde_navn,
    ad.adresse_tekst                AS folkeregisteradresse,
    e.sfo,
    e.klasseart,
    e.klassebetegnelse,
    e.elevklassetrin                AS personligt_klassetrin,
    e.bopaelsdistrikt,
    bad.adresse_tekst               AS adresse_for_bevilling,
    b.esdh_noegle                   AS sags_nummer,
    st.status_tekst                 AS status,
    -- School can be a folkeskole (Skolematrikel) OR an ungdomsuddannelse.
    -- Fall back to the ungdomsuddannelse so {skole}/{skolematrikel} resolve
    -- for both student types.
    COALESCE(sk.matrikel_navn,    uu.ungdomsuddannelse_navn)    AS skole,
    COALESCE(sk.matrikel_adresse, uu.ungdomsuddannelse_adresse) AS skolematrikel,
    e.skoleafstand                  AS gaaafstand_km,
    hjemmel.hjemmel_tekst           AS hjemmel,
    afg.afgoerelsesbrev_tekst       AS afgoerelsesbrev,
    sb.sagsbehandler_tekst          AS sagsbehandler,
    ppr.ppr_sagsbehandler_tekst     AS ppr_ansvarlig,
    CONVERT(varchar(10), b.ansoegningsdato,       105) AS modtagelsesdato,
    CONVERT(varchar(10), b.sagsbehandlingsdato,   105) AS sagsbehandlingsdato,
    CONVERT(varchar(10), b.revurderingsdato,      105) AS revurdering,
    CONVERT(varchar(10), b.befordringsudvalg,     105) AS befordringsudvalg,
    CONVERT(varchar(10), b.afstandskriterie_dato, 105) AS afstandskriterie_dato,
    b.afstandskriterie_klassetrin,
    b.relation_til_barnet           AS ansoeger_relation,
    hjaelpemidler.hjaelpemidler
FROM
    [Befordringssystemet].[befordring].[Bevilling]              b
LEFT JOIN [Befordringssystemet].[befordring].[Elev]                   e       ON e.cpr                    = b.cpr_elev
LEFT JOIN [Befordringssystemet].[befordring].[Adresse]                ad      ON ad.adresse_id             = e.adresse_id
LEFT JOIN [Befordringssystemet].[befordring].[Adresse]                bad     ON bad.adresse_id            = b.adresse_id
LEFT JOIN [Befordringssystemet].[befordring].[Status]                 st      ON st.status_id              = b.status_id
LEFT JOIN [Befordringssystemet].[befordring].[Skolematrikel]          sk      ON sk.matrikel_id            = b.matrikel_id
LEFT JOIN [Befordringssystemet].[befordring].[Ungdomsuddannelse]      uu      ON uu.ungdomsuddannelse_id   = b.ungdomsuddannelse_id
LEFT JOIN [Befordringssystemet].[befordring].[Hjemmel]                hjemmel ON hjemmel.hjemmel_id        = b.hjemmel_id
LEFT JOIN [Befordringssystemet].[befordring].[Afgoerelsesbrev]        afg     ON afg.afgoerelsesbrev_id    = b.afgoerelsesbrev_id
LEFT JOIN [Befordringssystemet].[befordring].[Sagsbehandler]          sb      ON sb.sagsbehandler_id       = b.sagsbehandler_id
LEFT JOIN [Befordringssystemet].[befordring].[PPR_Sagsbehandler]      ppr     ON ppr.ppr_sagsbehandler_id  = b.ppr_sagsbehandler_id
LEFT JOIN (
    SELECT
        bhl.bevilling_id,
        STRING_AGG(h.hjaelpemiddel_tekst, ', ') AS hjaelpemidler
    FROM
    [Befordringssystemet].[befordring].[Bevilling_Hjaelpemiddel_LINK] bhl
    INNER JOIN [Befordringssystemet].[befordring].[Hjaelpemiddel]               h
               ON h.hjaelpemiddel_id = bhl.hjaelpemiddel_id
    GROUP BY bhl.bevilling_id
) hjaelpemidler ON hjaelpemidler.bevilling_id = b.bevilling_id
-- A letter should never be built from a deleted bevilling.
WHERE b.aktiv = 1;
GO


