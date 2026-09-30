-- Migration 024: Add koerselsraekke_oprettet to SagsaktivitetType
-- Run once against the target database (test / prod).
-- Safe to re-run — the NOT EXISTS guard makes it idempotent.
--
-- Context:
--   create_koerselsraekke now writes a Sagsaktivitet entry when a kørselsrække
--   is created, so the Sagsforløb feed shows it alongside the other events.
--   Without this row the entry would be written with aktivitetstype_id NULL
--   and the feed would fall back to matching the display text.
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
FROM (VALUES (N'koerselsraekke_oprettet')) AS v (type_kode)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[SagsaktivitetType] t
    WHERE t.type_kode = v.type_kode
);
PRINT CONCAT('SagsaktivitetType: ', @@ROWCOUNT, ' code(s) inserted.');
GO

SELECT type_id, type_kode
FROM   [befordring].[SagsaktivitetType]
WHERE  type_kode = N'koerselsraekke_oprettet';
GO
