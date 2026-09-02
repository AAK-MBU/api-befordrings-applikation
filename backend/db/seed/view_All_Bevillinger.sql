USE [Befordringssystemet]
GO

/****** Object:  View [befordring].[view_All_Bevillinger]    Script Date: 02/09/2026 14:09:32 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
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
	b.final,
    b.esdh_noegle,
    sb.sagsbehandler_tekst      AS sagsbehandler,
    ppr.ppr_sagsbehandler_tekst
FROM      [Befordringssystemet].[befordring].[Bevilling]         b
LEFT JOIN [Befordringssystemet].[befordring].[Elev]              e   ON e.cpr                    = b.cpr_elev
LEFT JOIN [Befordringssystemet].[befordring].[Sagsbehandler]     sb  ON sb.sagsbehandler_id      = b.sagsbehandler_id
LEFT JOIN [Befordringssystemet].[befordring].[Status]            s   ON s.status_id              = b.status_id
LEFT JOIN [Befordringssystemet].[befordring].[PPR_Sagsbehandler] ppr ON ppr.ppr_sagsbehandler_id = b.ppr_sagsbehandler_id
/* Soft-deleted bevillinger keep whatever status they had when they were
   deleted, so without this a deleted bevilling still reading 'Aktiv' shows up
   on the overview — and wins the per-student row selection in
   overview_service.get_alle_bevillinger, which prefers an active one.
   view_Student_Bevillinger has always filtered this; these two had not. */
WHERE
    b.aktiv = 1;
GO


