-- Migration 011: Add genbehandling snapshot columns to Bevilling
-- Run once against the target database (test / prod).
-- Safe to re-run — the IF NOT EXISTS guards make it idempotent.
--
-- Context:
--   Option D for the repeated-mismatch problem: instead of permanently
--   suppressing re-flagging via genbehandling_haandteret BIT alone, we
--   snapshot the elev's adresse_id and skolekode at the moment of sign-off.
--   usp_recalculate_bevilling_status re-flags the bevilling only when the
--   elev's current data diverges from the stored snapshot, i.e. a genuinely
--   new mismatch has occurred.
--
--     genbehandling_haandteret_adresse_id  NVARCHAR(36) — elev.adresse_id
--                                          at time of sign-off
--     genbehandling_haandteret_skolekode   INT          — elev.skolekode
--                                          at time of sign-off
--
-- After running this migration, deploy the updated backend and run the
-- updated usp_recalculate_bevilling_status script.

USE [Befordringssystemet];
GO

-- -----------------------------------------------------------------------
-- 1. genbehandling_haandteret_adresse_id snapshot
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'genbehandling_haandteret_adresse_id'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
        ADD genbehandling_haandteret_adresse_id NVARCHAR(36) NULL;

    PRINT 'Column genbehandling_haandteret_adresse_id added to [befordring].[Bevilling].';
END
ELSE
BEGIN
    PRINT 'Column genbehandling_haandteret_adresse_id already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. genbehandling_haandteret_skolekode snapshot
-- -----------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name      = N'genbehandling_haandteret_skolekode'
)
BEGIN
    ALTER TABLE [befordring].[Bevilling]
        ADD genbehandling_haandteret_skolekode INT NULL;

    PRINT 'Column genbehandling_haandteret_skolekode added to [befordring].[Bevilling].';
END
ELSE
BEGIN
    PRINT 'Column genbehandling_haandteret_skolekode already exists — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 3. Verify
-- -----------------------------------------------------------------------
SELECT
    c.name          AS column_name,
    t.name          AS data_type,
    c.is_nullable   AS is_nullable
FROM      sys.columns AS c
JOIN      sys.types   AS t ON t.user_type_id = c.user_type_id
WHERE     c.object_id = OBJECT_ID(N'[befordring].[Bevilling]')
AND       c.name IN (
              N'genbehandling_haandteret_adresse_id',
              N'genbehandling_haandteret_skolekode'
          )
ORDER BY  c.name;
GO