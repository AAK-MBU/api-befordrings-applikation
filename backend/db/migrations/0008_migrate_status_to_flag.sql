/* ============================================================
   0008 — Migrate existing rows and retire the Revurdering status.

   RUN ORDER:
     0005 (column)  ->  0006 (proc)  ->  0007 (views)  ->  0008 (this)

   This recalculates every bevilling with the new proc (which moves
   rows off the 'Revurdering' status onto their real status and sets
   the `revurdering` flag), then removes the now-unused 'Revurdering'
   row from the Status lookup table.
   ============================================================ */

USE [Befordringssystemet];
GO

/* 1. Recalculate all bevillinger: assigns real status + sets revurdering flag. */
EXEC [befordring].[usp_recalculate_bevilling_status] @bevilling_id = NULL, @dry_run = 0;
GO

/* 2. Safety check: no bevilling should still point at the 'Revurdering' status. */
IF EXISTS (
    SELECT 1
    FROM [befordring].[Bevilling] b
    INNER JOIN [befordring].[Status] s ON s.status_id = b.status_id
    WHERE s.status_tekst = N'Revurdering'
)
BEGIN
    THROW 51000, 'Aborting: bevillinger still reference the Revurdering status after recalc. Investigate before deleting the status row.', 1;
END;
GO

/* 3. Remove the now-unused 'Revurdering' status row. */
DELETE FROM [befordring].[Status]
WHERE status_tekst = N'Revurdering';
GO
