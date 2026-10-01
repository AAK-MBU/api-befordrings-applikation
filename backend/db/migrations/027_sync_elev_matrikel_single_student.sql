/*
    027 — usp_sync_elev_matrikel_from_bevilling takes an optional @cpr.

    Why:
        Elev.matrikel_id and Elev.skoleafstand are derived by the nightly run.
        A student registered today therefore has neither until tomorrow — and
        both are needed before a letter can be produced for them.

        This lets the application resolve one student on demand. The rules are
        unchanged and not duplicated: @cpr simply narrows the same procedure to
        one row. Called with no argument, as the nightly run calls it, it
        behaves exactly as before.

    Safe to re-run: the procedure body is CREATE OR ALTER, and the parameter is
    optional, so every existing caller keeps working untouched.

    Apply the procedure from its own file — this migration exists so the change
    has a numbered place in the sequence:

        backend/db/seed/usp_sync_elev_matrikel_from_bevilling.sql
*/

USE [Befordringssystemet];
GO

IF NOT EXISTS (
    SELECT 1
    FROM   sys.parameters p
    JOIN   sys.objects    o ON o.object_id = p.object_id
    WHERE  o.name = N'usp_sync_elev_matrikel_from_bevilling'
    AND    SCHEMA_NAME(o.schema_id) = N'befordring'
    AND    p.name = N'@cpr'
)
    PRINT 'ADVARSEL: usp_sync_elev_matrikel_from_bevilling har ikke @cpr endnu — kør db/seed/usp_sync_elev_matrikel_from_bevilling.sql.';
ELSE
    PRINT 'OK: usp_sync_elev_matrikel_from_bevilling tager @cpr.';
GO
