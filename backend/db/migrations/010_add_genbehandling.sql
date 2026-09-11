-- Migration 010: Add genbehandling columns to Bevilling
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guards make it idempotent.
--
-- Context:
--   The Revurdering page is being split into two:
--     Revurdering  — cases flagged because their revurderingsdato is approaching
--     Genbehandling — cases flagged because something changed (skolekode or
--                     adresse mismatch between the bevilling and the student's
--                     current CPR data)
--
--   This migration adds three columns to support the new Genbehandling concept:
--
--     genbehandling             BIT — set by usp_recalculate_bevilling_status
--                                     when a mismatch trigger fires. Mirrors the
--                                     existing revurdering column.
--     genbehandling_haandteret  BIT — single sign-off flag (replaces the
--                                     two-step PPR/BR flow used for revurdering).
--                                     Cleared automatically when a new
--                                     genbehandling cycle begins.
--     genbehandling_bemaerkning NVARCHAR — reason text written by the SP,
--                                     e.g. "Skolekode på bevilling matcher ikke
--                                     elevens aktuelle skolekode".
--
-- After running this migration, deploy the updated backend and run the updated
-- usp_recalculate_bevilling_status and view_Genbehandling scripts.

USE [Befordringssystemet];
GO

-- -----------------------------------------------------------------------
-- 1. genbehandling flag
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'genbehandling'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
        ADD genbehandling BIT NULL;

    PRINT 'Column genbehandling added to [befordring].[Bevilling].';
END
ELSE
BEGIN
    PRINT 'Column genbehandling already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. genbehandling_haandteret sign-off flag
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'genbehandling_haandteret'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
        ADD genbehandling_haandteret BIT NULL;

    PRINT 'Column genbehandling_haandteret added to [befordring].[Bevilling].';
END
ELSE
BEGIN
    PRINT 'Column genbehandling_haandteret already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 3. genbehandling_bemaerkning reason text
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'genbehandling_bemaerkning'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
        ADD genbehandling_bemaerkning NVARCHAR(500) NULL;

    PRINT 'Column genbehandling_bemaerkning added to [befordring].[Bevilling].';
END
ELSE
BEGIN
    PRINT 'Column genbehandling_bemaerkning already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 4. Verify
-- -----------------------------------------------------------------------
SELECT
    c.name          AS column_name,
    t.name          AS data_type,
    c.is_nullable   AS is_nullable
FROM      sys.columns AS c
JOIN      sys.types   AS t ON t.user_type_id = c.user_type_id
WHERE     c.object_id = OBJECT_ID(N'[befordring].[Bevilling]')
AND       c.name IN (
              N'genbehandling',
              N'genbehandling_haandteret',
              N'genbehandling_bemaerkning'
          )
ORDER BY  c.name;
GO