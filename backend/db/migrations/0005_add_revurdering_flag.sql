/* ============================================================
   0005 — Add the `revurdering` flag to Bevilling.

   "Revurdering" is no longer a status. A bevilling that needs
   reassessment keeps its real status (Aktiv/Kommende/…) and is
   marked with this bit instead. The flag is maintained by
   usp_recalculate_bevilling_status (see 0006).
   ============================================================ */

USE [Befordringssystemet];
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[befordring].[Bevilling]')
      AND name = N'revurdering'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
        ADD [revurdering] BIT NULL;
END;
GO

-- Backfill existing rows to 0 (the recalc in 0008 will set 1 where needed).
UPDATE [befordring].[Bevilling]
SET [revurdering] = 0
WHERE [revurdering] IS NULL;
GO
