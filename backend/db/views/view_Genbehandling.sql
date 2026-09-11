USE [Befordringssystemet]
GO


/* ---------- view_Genbehandling: bevillinger flagged for genbehandling ----------
   Triggered by data mismatches (skolekode or adresse) between the bevilling
   and the student's current CPR data. Separate from the date-driven Revurdering
   page. Sign-off is a single flag (genbehandling_haandteret) rather than the
   two-step PPR/BR flow used for revurdering.
*/
CREATE OR ALTER VIEW [befordring].[view_Genbehandling] AS
SELECT
    b.bevilling_id,
    b.cpr_elev,
    b.ansoegningstype,
    ba.adresse_tekst                AS adresse_for_bevilling,
    b.matrikel_id,
    b.ungdomsuddannelse_id,
    e.adresseringsnavn,
    a.adresse_tekst                 AS folkeregister_adresse,
    e.skoleafstand                  AS gaaafstand_km,
    e.klasseart,
    e.elevklassetrin,
    e.klassebetegnelse,
    sm.matrikel_navn                AS skole_navn,
    b.revurderingsdato,
    b.genbehandling,
    b.genbehandling_haandteret,
    b.genbehandling_bemaerkning,
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
WHERE      b.aktiv = 1
AND        b.genbehandling = 1;
GO