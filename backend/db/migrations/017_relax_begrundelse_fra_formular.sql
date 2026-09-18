-- Migration 017: Make Bevilling.begrundelse_fra_formular nullable
-- Run once against the target database (test / prod).
-- Safe to re-run — the guard checks current nullability, so a second run is
-- a no-op.
--
-- Context:
--   begrundelse_fra_formular holds the reason the citizen gave on the os2forms
--   application. It was created NOT NULL, which assumes every bevilling starts
--   from a form — but caseworkers also create bevillinger by hand ("ny fra
--   tom", "ny fra kopi"), and those have no form and therefore no reason.
--
--   With the column NOT NULL and no default, those inserts fail outright:
--       Cannot insert the value NULL into column 'begrundelse_fra_formular'
--
--   Dev was already relaxed to NULL; prod was not, which is the difference
--   this migration closes.
--
--   Deliberately NOT given a default of '': an empty string and "no form" are
--   different things, and letter text distinguishes them.
--
-- After running this migration, deploy the updated backend code.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 1. Relax the column if it is currently NOT NULL
-- -----------------------------------------------------------------------
IF EXISTS (
    SELECT 1
    FROM   sys.columns
    WHERE  object_id   = OBJECT_ID(N'[befordring].[Bevilling]')
    AND    name        = N'begrundelse_fra_formular'
    AND    is_nullable = 0
)
BEGIN
    -- Type restated exactly as it is today. ALTER COLUMN rewrites the whole
    -- definition, so omitting the type would change it.
    ALTER TABLE [befordring].[Bevilling]
        ALTER COLUMN [begrundelse_fra_formular] VARCHAR(MAX) NULL;

    PRINT 'Column begrundelse_fra_formular on [befordring].[Bevilling] is now NULLable.';
END
ELSE
BEGIN
    PRINT 'Column begrundelse_fra_formular is already NULLable (or missing) — skipped.';
END
GO

-- -----------------------------------------------------------------------
-- 2. Verify — is_nullable must be 1
-- -----------------------------------------------------------------------
SELECT
    c.name        AS column_name,
    t.name        AS data_type,
    c.max_length,
    c.is_nullable
FROM
    sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE
    c.object_id = OBJECT_ID(N'[befordring].[Bevilling]')
    AND c.name = N'begrundelse_fra_formular';
GO
