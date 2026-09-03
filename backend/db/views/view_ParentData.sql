USE [Befordringssystemet]
GO

/****** Object:  View [befordring].[view_ParentData]    Script Date: 03/09/2026 09:07:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER VIEW [befordring].[view_ParentData]
AS
SELECT
    f.cpr_elev,
    f.adresseringsnavn,
    f.cpr_foraelder,
    ad.adresse_tekst,
    f.navne_adresse_beskyttelse,
    f.maa_vide_barns_adresse,
    f.relation,

    CASE
        WHEN f.relation = 'Mor' THEN 1
        WHEN f.relation = 'Far' THEN 2
        ELSE 99
    END AS foraelderrolle_sortering

FROM
    [Befordringssystemet].[befordring].[Foraelder] f

LEFT JOIN
    [Befordringssystemet].[befordring].[Adresse] ad
    ON ad.adresse_id = f.adresse_id;
GO


