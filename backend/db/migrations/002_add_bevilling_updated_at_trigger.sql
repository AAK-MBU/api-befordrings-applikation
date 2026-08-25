-- Migration 002: Trigger to auto-stamp updated_at on Bevilling
-- Run once against the target database (test / prod).
-- Safe to re-run — the DROP IF EXISTS + CREATE makes it idempotent.
--
-- Context:
--   updated_at on Bevilling was previously only set by the status SP
--   (usp_recalculate_bevilling_status) or manually in Python with datetime.now(),
--   which gives UTC time while SQL Server uses local time (CET/CEST).
--   This trigger fires on every UPDATE and stamps updated_at = SYSDATETIME()
--   so all updates use a consistent server-side timestamp, matching created_at.

USE [Befordringssystemet];
GO

DROP TRIGGER IF EXISTS [befordring].[trg_Bevilling_UpdatedAt];
GO

CREATE TRIGGER [befordring].[trg_Bevilling_UpdatedAt]
ON [befordring].[Bevilling]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE b
    SET b.updated_at = SYSDATETIME()
    FROM [befordring].[Bevilling] b
    INNER JOIN inserted i ON i.bevilling_id = b.bevilling_id;
END;
GO

-- Verify
SELECT
    t.name          AS trigger_name,
    o.name          AS table_name,
    t.is_disabled,
    t.create_date,
    t.modify_date
FROM
    sys.triggers t
    JOIN sys.objects o ON o.object_id = t.parent_id
WHERE
    o.name = 'Bevilling'
    AND SCHEMA_NAME(o.schema_id) = 'befordring';
GO

