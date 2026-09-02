USE [Befordringssystemet]
GO

/****** Object:  View [befordring].[view_All_Active_Bevillinger]    Script Date: 02/09/2026 14:09:08 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



ALTER VIEW [befordring].[view_All_Active_Bevillinger]
AS

SELECT
    e.adresseringsnavn,
    b.cpr_elev,
    s.status_tekst,
    b.esdh_noegle,
    sb.sagsbehandler_tekst AS sagsbehandler,
    ppr.ppr_sagsbehandler_tekst
FROM
    [Befordringssystemet].[befordring].[Bevilling] b

LEFT JOIN
    [Befordringssystemet].[befordring].Elev e 
    ON b.cpr_elev = e.cpr

LEFT JOIN
    [Befordringssystemet].[befordring].Sagsbehandler sb 
    ON b.sagsbehandler_id = sb.sagsbehandler_id

LEFT JOIN
    [Befordringssystemet].[befordring].Status s 
    ON b.status_id = s.status_id

LEFT JOIN
    [Befordringssystemet].[befordring].PPR_Sagsbehandler ppr 
    ON b.ppr_sagsbehandler_id = ppr.ppr_sagsbehandler_id

WHERE
    /* Both halves are needed: status_tekst alone lets through a soft-deleted
       bevilling that was Aktiv when it was deleted. */
    b.aktiv = 1
    AND s.status_tekst = 'Aktiv';
GO


