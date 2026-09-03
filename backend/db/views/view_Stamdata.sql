USE [Befordringssystemet]
GO

/****** Object:  View [befordring].[view_Stamdata]    Script Date: 03/09/2026 09:07:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [befordring].[view_Stamdata]
AS

WITH PrioritizedBevilling AS (
    SELECT
        b.*,
        st.status_tekst,
        ROW_NUMBER() OVER (
            PARTITION BY b.cpr_elev
            ORDER BY
                CASE WHEN st.status_tekst = 'Aktiv' THEN 0 ELSE 1 END,
                b.updated_at DESC,
                b.created_at DESC
        ) AS rn
    FROM [Befordringssystemet].[befordring].[Bevilling] b
    LEFT JOIN [Befordringssystemet].[befordring].[Status] st
        ON b.status_id = st.status_id
    -- Filtered BEFORE the ranking, not after: soft-delete never changes the
    -- status, so a bevilling deleted while Aktiv sorts to rn = 1 on the CASE
    -- above and becomes the student's displayed bevilling.
    WHERE b.aktiv = 1
)

SELECT
    e.navne_adresse_beskyttelse,
    e.adresseringsnavn,
    e.cpr,

    b.bevilling_id,
    b.esdh_noegle,
    b.status_tekst,

    ad.adresse_tekst,

    e.matrikel_id,
    sm.matrikel_navn                             AS skolematrikel,

    e.ungdomsuddannelse_id,
    uu.ungdomsuddannelse_navn,

    COALESCE(sm.matrikel_navn,
             uu.ungdomsuddannelse_navn)          AS skole_navn,

    CASE
        WHEN e.ungdomsuddannelse_id IS NOT NULL THEN 'Ungdomsuddannelse'
        WHEN e.matrikel_id          IS NOT NULL THEN 'Folkeskole'
        ELSE NULL
    END                                          AS skole_type,

    e.skolekode,

    e.skoleafstand,
    e.klasseart,
    e.klassebetegnelse,
    e.elevklassetrin,
    e.sfo,
    e.bopaelsdistrikt

FROM [Befordringssystemet].[befordring].[Elev] e

LEFT JOIN PrioritizedBevilling b
    ON b.cpr_elev = e.cpr AND b.rn = 1

LEFT JOIN [Befordringssystemet].[befordring].[Adresse] ad
    ON ad.adresse_id = e.adresse_id

LEFT JOIN [Befordringssystemet].[befordring].[Skolematrikel] sm
    ON sm.matrikel_id = e.matrikel_id

LEFT JOIN [Befordringssystemet].[befordring].[Ungdomsuddannelse] uu
    ON uu.ungdomsuddannelse_id = e.ungdomsuddannelse_id;
GO


