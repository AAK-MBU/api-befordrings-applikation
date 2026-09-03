USE [Befordringssystemet]
GO

/****** Object:  View [befordring].[view_New_Applications]    Script Date: 03/09/2026 09:06:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [befordring].[view_New_Applications]
AS
SELECT
    b.bevilling_id,
    e.adresseringsnavn,
    b.cpr_elev,
    b.esdh_noegle,
    b.ansoegningsdato,
    b.ansoegningstype,
    b.foerste_koersel_dato,
    b.sagsbehandler_id,
    sb.sagsbehandler_tekst AS sagsbehandler,
    b.ppr_sagsbehandler_id,
    ppr.ppr_sagsbehandler_tekst,
    s.status_tekst
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
    -- Soft-deleted bevillinger keep whatever status they had, so a deleted
    -- one still sitting at Ny/Påbegyndt would show on Nye ansøgninger.
    -- Note the parentheses: AND binds tighter than OR, so without them the
    -- aktiv filter would apply to the first status only.
    b.aktiv = 1
    AND (s.status_tekst = 'Ny' OR s.status_tekst = 'Påbegyndt');
GO


