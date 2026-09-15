USE [Befordringssystemet]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Letters that have been created but not yet sent — the Forsendelse worklist.
--
-- Creating a letter queues an ATS work item and produces a document; it does
-- not post anything to the parents. This view is the gap between those two.
--
-- Joined here rather than in the caller so the page gets the student's name and
-- the bevilling's løbenummer without a second round trip. The columns from Brev
-- are snapshots taken when the letter was created — see backend/db/migrations/
-- 014_add_brev.sql for why they are not resolved live.

CREATE OR ALTER VIEW [befordring].[view_Forsendelse]
AS
SELECT
    br.brev_id,
    br.reference,

    br.bevilling_id,
    b.loebenummer,
    b.esdh_noegle,

    br.cpr_elev,
    e.adresseringsnavn,

    br.afgoerelsesbrev_tekst,
    br.brev_i_forbindelse_med,

    br.oprettet_tidspunkt,
    br.oprettet_af,

    -- Whole days the letter has been waiting. Lets the page highlight a
    -- backlog without every client recomputing it from a timestamp.
    DATEDIFF(DAY, br.oprettet_tidspunkt, GETDATE()) AS dage_ventet,

    st.status_tekst     AS bevilling_status,
    sb.sagsbehandler_tekst AS sagsbehandler

FROM      [befordring].[Brev]           br
LEFT JOIN [befordring].[Bevilling]      b   ON b.bevilling_id    = br.bevilling_id
LEFT JOIN [befordring].[Elev]           e   ON e.cpr             = br.cpr_elev
LEFT JOIN [befordring].[Status]         st  ON st.status_id      = b.status_id
LEFT JOIN [befordring].[Sagsbehandler]  sb  ON sb.sagsbehandler_id = b.sagsbehandler_id

-- The worklist is exactly "created, not sent". A soft-deleted letter, or one
-- on a soft-deleted bevilling, is not work anybody should be doing.
WHERE
    br.afsendt = 0
AND br.aktiv   = 1
AND ISNULL(b.aktiv, 0) = 1;
GO
