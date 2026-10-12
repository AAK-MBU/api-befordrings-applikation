-- Migration 031: Add bevilling_afslag to SagsaktivitetType
-- Run once against the target database (test / prod).
-- Safe to re-run — the NOT EXISTS guard makes it idempotent.
--
-- Context:
--   update_bevilling now detects the false→true transition to "Afslag" status
--   and writes a dedicated Sagsaktivitet entry (type_kode bevilling_afslag),
--   parallel to the existing bevilling_ophoert entry written for Ophørt.
--
--   The dedicated code is needed for the same reason as bevilling_ophoert:
--   "Afslag" is a protected status that the SP leaves untouched, so it may
--   report rows_updated=0, causing the generic status_opdateret log branch to
--   be skipped. A dedicated type also enables distinct feed styling and
--   filtering in the frontend.
--
-- Requires migration 023.

USE [Befordringssystemet];   -- adjust database name if different in your environment
GO

INSERT INTO [befordring].[SagsaktivitetType] (type_kode)
SELECT v.type_kode
FROM (VALUES (N'bevilling_afslag')) AS v (type_kode)
WHERE NOT EXISTS (
    SELECT 1 FROM [befordring].[SagsaktivitetType] t
    WHERE t.type_kode = v.type_kode
);
PRINT CONCAT('SagsaktivitetType: ', @@ROWCOUNT, ' code(s) inserted.');
GO

SELECT type_id, type_kode
FROM   [befordring].[SagsaktivitetType]
WHERE  type_kode = N'bevilling_afslag';
GO