USE [Befordringssystemet]
GO

/****** Object:  View [befordring].[view_Applications]    Script Date: 03/09/2026 09:04:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER VIEW [befordring].[view_Applications]
AS
SELECT
    form_id,
    form_sid,
    form_type,
    form_source,
    form_submitted_date,
    destination_system,
    status,
    response,
    documented_date,
    form_data,
    last_time_modified
FROM
    RPA.journalizing.view_Journalizing
WHERE
    form_type IN (
        'ny_ansoegning_om_koersel_af_skol',
        'ny_ansoegning_om_midlertidig_koe'
    );
GO


