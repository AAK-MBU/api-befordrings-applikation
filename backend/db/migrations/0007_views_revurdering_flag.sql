/* ============================================================
   0007 — Update views for the revurdering flag.

   - view_Revurderinger: select by the flag (b.revurdering = 1)
     instead of the 'Revurdering' status; also expose
     revurderet_af_br (was missing) and the flag itself.
   - view_All_Bevillinger, view_Student_Bevillinger: expose
     b.revurdering so lists / the sag page can render the pill.
   - view_Stamdata: no change (it doesn't reference the status
     and nothing reads the flag from it).

   Run AFTER 0005 (column) + 0006 (proc), BEFORE 0008 (migrate).
   ============================================================ */

USE [Befordringssystemet];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---------- view_All_Bevillinger: expose the flag ---------- */
ALTER VIEW [befordring].[view_All_Bevillinger]
AS
SELECT
    b.bevilling_id,
    e.adresseringsnavn,
    b.cpr_elev,
    s.status_tekst,
    b.statusbemaerkning,
    b.revurdering,
    b.esdh_noegle,
    sb.sagsbehandler_tekst      AS sagsbehandler,
    ppr.ppr_sagsbehandler_tekst
FROM      [Befordringssystemet].[befordring].[Bevilling]         b
LEFT JOIN [Befordringssystemet].[befordring].[Elev]              e   ON e.cpr                    = b.cpr_elev
LEFT JOIN [Befordringssystemet].[befordring].[Sagsbehandler]     sb  ON sb.sagsbehandler_id      = b.sagsbehandler_id
LEFT JOIN [Befordringssystemet].[befordring].[Status]            s   ON s.status_id              = b.status_id
LEFT JOIN [Befordringssystemet].[befordring].[PPR_Sagsbehandler] ppr ON ppr.ppr_sagsbehandler_id = b.ppr_sagsbehandler_id;
GO

/* ---------- view_Revurderinger: filter on the flag ---------- */
ALTER VIEW [befordring].[view_Revurderinger] AS
SELECT
    b.bevilling_id,
    b.cpr_elev,
    ba.adresse_tekst                AS adresse_for_bevilling,
    b.matrikel_id,
    e.adresseringsnavn,
    a.adresse_tekst                 AS folkeregister_adresse,
    e.skoleafstand                  AS gaaafstand_km,
    e.klasseart,
    e.elevklassetrin,
    e.klassebetegnelse,
    sm.matrikel_navn                AS skole_navn,
    b.revurderingsdato,
    b.revurderet_af_ppr,
    b.revurderet_af_br,
    b.revurdering,
    b.afstandskriterie_dato,
    b.hjemmel_id,
    h.hjemmel_tekst,
    b.afgoerelsesbrev_id,
    ab.afgoerelsesbrev_tekst,
    b.ppr_sagsbehandler_id,
    ppr.ppr_sagsbehandler_tekst,
    b.sagsbehandler_id,
    sb.sagsbehandler_tekst,
    s.status_tekst,
    b.statusbemaerkning
FROM       [befordring].[Bevilling]          b
INNER JOIN [befordring].[Status]             s   ON s.status_id              = b.status_id
INNER JOIN [befordring].[Elev]               e   ON e.cpr                    = b.cpr_elev
INNER JOIN [befordring].[Adresse]            a   ON a.adresse_id             = e.adresse_id
LEFT  JOIN [befordring].[Adresse]            ba  ON ba.adresse_id            = b.adresse_id
LEFT  JOIN [befordring].[Skolematrikel]      sm  ON sm.matrikel_id           = b.matrikel_id
LEFT  JOIN [befordring].[Hjemmel]            h   ON h.hjemmel_id             = b.hjemmel_id
LEFT  JOIN [befordring].[Afgoerelsesbrev]    ab  ON ab.afgoerelsesbrev_id    = b.afgoerelsesbrev_id
LEFT  JOIN [befordring].[PPR_Sagsbehandler]  ppr ON ppr.ppr_sagsbehandler_id = b.ppr_sagsbehandler_id
LEFT  JOIN [befordring].[Sagsbehandler]      sb  ON sb.sagsbehandler_id      = b.sagsbehandler_id
WHERE      b.revurdering = 1;
GO

/* ---------- view_Student_Bevillinger: expose the flag ---------- */
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

    b.sagsbehandlingsdato,
    ba.adresse_tekst                                              AS adresse_for_bevilling,
    b.adresse_id,
    ba.latitude                                                   AS adresse_latitude,
    ba.longitude                                                  AS adresse_longitude,
    b.ansoegningstype,

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

FROM      [Befordringssystemet].[befordring].[Bevilling]                b
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

GROUP BY
    b.bevilling_id, b.created_at, b.updated_at,
    e.navne_adresse_beskyttelse, e.adresseringsnavn, e.cpr,
    b.status_id, st.status_tekst, b.statusbemaerkning, b.revurdering,
    b.sagsbehandlingsdato,
    ba.adresse_tekst,
    b.adresse_id,
    ba.latitude,
    ba.longitude,
    b.ansoegningstype,
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
