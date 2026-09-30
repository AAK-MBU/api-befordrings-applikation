-- Migration 025: Add brev_afsendt to SagsaktivitetType
-- Run once against the target database (test / prod).
-- Safe to re-run — the NOT EXISTS guard makes it idempotent.
--
-- Context:
--   set_afsendt now writes a Sagsaktivitet entry for every brev that actually
--   changes to afsendt = 1 on the Forsendelse page, so a dispatch is visible
--   in the Sagsforløb feed. This is the matching lookup row.
--
--   Separate from 023 rather than folded into it: 023 has been applied to
--   databases already, and editing an applied migration leaves no trace that
--   anything changed.
--
-- Requires migration 023.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

INSERT INTO [befordring].[SagsaktivitetType] (type_kode)
SELECT v.type_kode
FROM (VALUES (N'brev_afsendt')) AS v (type_kode)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[SagsaktivitetType] t
    WHERE t.type_kode = v.type_kode
);
PRINT CONCAT('SagsaktivitetType: ', @@ROWCOUNT, ' code(s) inserted.');
GO

SELECT type_id, type_kode
FROM   [befordring].[SagsaktivitetType]
WHERE  type_kode = N'brev_afsendt';
GO
