-- Migration 004: Add PortalAuditLog table
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guard makes it idempotent.
--
-- Context:
--   Technical audit trail, one row per handled HTTP call. Written by
--   backend/app/middleware/audit_middleware.py in its own session with its
--   own commit, so a failed log write never takes down the response it was
--   describing.
--
--   The table already exists in OUR database because it was created directly
--   when the feature was built. This file formalises it so a fresh database
--   matches the ORM model in app/models/audit.py.
--
--   Column names are PascalCase, unlike the snake_case used everywhere else
--   in this schema, because the table mirrors the PortalAuditLog in the
--   sibling aktindsigt application.
--
--   NOTE: Path holds personal data by design. Several routes carry a CPR in
--   the path itself (/citizen/stamdata/{cpr}, /aktivitet/{cpr}), and knowing
--   who looked up which citizen is the point of the trail. Retention and
--   access to this table need to be governed accordingly.
--
-- After running this migration, deploy the updated backend code.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Create the table if it does not already exist
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM sys.tables AS t
    JOIN sys.schemas AS s ON s.schema_id = t.schema_id
    WHERE s.name = 'befordring'
      AND t.name = 'PortalAuditLog'
)
BEGIN
    CREATE TABLE befordring.PortalAuditLog (
        AuditLogId     INT IDENTITY(1,1) NOT NULL,
        BrugerIdent    NVARCHAR(200) NULL,
        IpAdresse      NVARCHAR(50) NULL,
        UserAgent      NVARCHAR(500) NULL,
        OprettetDato   DATETIME2(7) NOT NULL,
        Method         NVARCHAR(10) NULL,
        Path           NVARCHAR(500) NULL,
        QueryParams    NVARCHAR(MAX) NULL,
        StatusCode     INT NULL,
        DurationMs     DECIMAL(10,2) NULL,
        ErrorMessage   NVARCHAR(MAX) NULL,
        ApiKeyId       INT NULL,
        ApiKeyName     NVARCHAR(200) NULL,
        Action         NVARCHAR(200) NULL,

        CONSTRAINT PK_PortalAuditLog
            PRIMARY KEY (AuditLogId)
    );
END
GO

-- -----------------------------------------------------------------------
-- 2. Index for the queries this table actually gets
-- -----------------------------------------------------------------------
--   The trail is read two ways: "what happened recently" and "what did this
--   user do". Both start from OprettetDato, which is also the column an
--   eventual retention job will delete by. Without it every such query is a
--   full scan of a table that grows by one row per request.
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_PortalAuditLog_OprettetDato'
      AND object_id = OBJECT_ID('befordring.PortalAuditLog')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_PortalAuditLog_OprettetDato
        ON befordring.PortalAuditLog (OprettetDato DESC)
        INCLUDE (BrugerIdent, Method, Path, StatusCode);
END
GO
