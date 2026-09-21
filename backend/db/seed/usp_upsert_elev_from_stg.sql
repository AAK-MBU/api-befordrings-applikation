USE [Befordringssystemet]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    Merge the nightly student load from Elev_STG into Elev.

    Elev_STG is filled by the data worker's job, which runs before the RPA.
    That job is the authority on the columns it carries, so a NULL arriving in
    STG is a real change and overwrites — except for the columns listed under
    "Not copied" below.

    Unlike Adresse_STG there is no load_id on this table: the loading job
    truncates and refills it. This procedure therefore processes whatever it
    finds, and does NOT clear the stage afterwards — that table belongs to the
    other job and deleting from it could race their load.

    Not copied, and why:

      adresse_id            Always NULL in STG. Resolved separately from
                            LOIS.CPR.PersonGeoView — see
                            usp_upsert_adresse_ids_from_stg.

      matrikel_id           ALWAYS NULL in STG — the data worker's source has
      ungdomsuddannelse_id  no school. Both are derived from the student's
                            bevillinger instead; see
                            usp_sync_elev_matrikel_from_bevilling, which runs
                            straight after this procedure. Copying either from
                            STG would fight that derivation.

                            This procedure does CLEAR them — see below.

      skoleafstand          Written by the walking-distance step at the end of
                            the nightly run. Copying a stale value from STG
                            would overwrite last night's calculation.

      kraever_genberegning  Set by THIS procedure when a watched column
                            changes. Copying it from STG would clobber the flag
                            we just raised, or raise one nothing asked for.

    When skolekode changes, matrikel_id and ungdomsuddannelse_id are cleared
    and kraever_genberegning is raised.

    Clearing matters because those two are derived from a bevilling, and a
    bevilling that has not caught up with the child's new school now points at
    the wrong one. usp_sync_elev_matrikel_from_bevilling runs next and puts
    back whatever the student's bevilling actually says — but where the student
    has no bevilling to derive from, there is nothing to put back, and the
    stale school must not survive. Leaving it would measure the walking
    distance to a school the child no longer attends.

    The other two kraever_genberegning triggers are raised by the procedures
    that own those columns: usp_sync_elev_matrikel_from_bevilling for
    matrikel_id, usp_upsert_adresse_ids_from_stg for adresse_id. Each flag is
    raised where the change is visible, so none can overwrite another's work.

    All or nothing: one transaction, so a failure part-way leaves Elev exactly
    as it was rather than half-merged.
*/

CREATE OR ALTER PROCEDURE [befordring].[usp_upsert_elev_from_stg]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @staged_rows    INT = 0;
    DECLARE @duplicate_cpr  INT = 0;
    DECLARE @updated_rows   INT = 0;
    DECLARE @inserted_rows  INT = 0;
    DECLARE @flagged_rows   INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

            /* One row per cpr. There is no load_id or identity column to order
               by, so a duplicate cpr in the stage is resolved arbitrarily —
               and counted, so it shows up in the log rather than silently
               picking a winner every night. Rows without a cpr are dropped:
               the column is nullable in the stage but is the match key here. */
            ;WITH SourceRows AS
            (
                SELECT
                    *,
                    ROW_NUMBER() OVER (
                        PARTITION BY LTRIM(RTRIM(cpr))
                        ORDER BY     (SELECT NULL)
                    ) AS rn
                FROM [befordring].[Elev_STG]
                WHERE NULLIF(LTRIM(RTRIM(cpr)), '') IS NOT NULL
            )
            SELECT
                LTRIM(RTRIM(cpr))         AS cpr,
                adresselinjesnavn,
                navne_adresse_beskyttelse,
                klasseart,
                elevklassetrin,
                klassebetegnelse,
                institution,
                bopaelsdistrikt,
                skolekode
            INTO #Source
            FROM SourceRows
            WHERE rn = 1;

            CREATE UNIQUE CLUSTERED INDEX IX_Source_cpr ON #Source (cpr);

            SELECT @staged_rows = COUNT(*) FROM #Source;

            SELECT @duplicate_cpr =
                (SELECT COUNT(*) FROM [befordring].[Elev_STG]
                 WHERE NULLIF(LTRIM(RTRIM(cpr)), '') IS NOT NULL)
                - @staged_rows;

            /* Which students are about to have their registered school code
               change. Captured before the UPDATE, because afterwards the old
               value is gone. */
            SELECT s.cpr
            INTO   #NeedsRecalc
            FROM   #Source s
            JOIN   [befordring].[Elev] e ON e.cpr = s.cpr
            WHERE  EXISTS (
                       SELECT e.skolekode
                       EXCEPT
                       SELECT s.skolekode
                   );

            SELECT @flagged_rows = COUNT(*) FROM #NeedsRecalc;

            /* EXCEPT compares NULL to NULL as equal, which "<>" does not — so
               a row whose values are unchanged is not rewritten just because
               one of them is NULL. */
            UPDATE target
            SET
                target.adresseringsnavn          = source.adresselinjesnavn,
                target.navne_adresse_beskyttelse = source.navne_adresse_beskyttelse,
                target.klasseart                 = source.klasseart,
                target.elevklassetrin            = source.elevklassetrin,
                target.klassebetegnelse          = source.klassebetegnelse,
                target.institution               = source.institution,
                target.bopaelsdistrikt           = source.bopaelsdistrikt,
                target.skolekode                 = source.skolekode
            FROM [befordring].[Elev] target
            JOIN #Source source ON source.cpr = target.cpr
            WHERE EXISTS
            (
                SELECT
                    target.adresseringsnavn,
                    target.navne_adresse_beskyttelse,
                    target.klasseart,
                    target.elevklassetrin,
                    target.klassebetegnelse,
                    target.institution,
                    target.bopaelsdistrikt,
                    target.skolekode

                EXCEPT

                SELECT
                    source.adresselinjesnavn,
                    source.navne_adresse_beskyttelse,
                    source.klasseart,
                    source.elevklassetrin,
                    source.klassebetegnelse,
                    source.institution,
                    source.bopaelsdistrikt,
                    source.skolekode
            );

            SET @updated_rows = @@ROWCOUNT;

            /* Separate from the UPDATE above so the flag survives a row that
               changed school but nothing else, and is not raised for a row
               where only the name changed.

               matrikel_id and ungdomsuddannelse_id are cleared rather than
               left: both are derived from a bevilling, and the child has just
               moved school, so whatever a bevilling said before now points at
               the wrong one. The sync procedure that runs next re-derives them
               where a bevilling exists; where none does, cleared is correct. */
            UPDATE e
            SET    e.kraever_genberegning = 1,
                   e.matrikel_id          = NULL,
                   e.ungdomsuddannelse_id = NULL
            FROM   [befordring].[Elev] e
            JOIN   #NeedsRecalc n ON n.cpr = e.cpr;

            /* New students. adresse_id, matrikel_id and ungdomsuddannelse_id
               are left NULL for the procedures that own them, and
               kraever_genberegning starts at 1 because a student with no
               skoleafstand needs one calculated. */
            INSERT INTO [befordring].[Elev]
            (
                cpr,
                adresseringsnavn,
                navne_adresse_beskyttelse,
                klasseart,
                elevklassetrin,
                klassebetegnelse,
                institution,
                bopaelsdistrikt,
                skolekode,
                kraever_genberegning
            )
            SELECT
                source.cpr,
                source.adresselinjesnavn,
                source.navne_adresse_beskyttelse,
                source.klasseart,
                source.elevklassetrin,
                source.klassebetegnelse,
                source.institution,
                source.bopaelsdistrikt,
                source.skolekode,
                1
            FROM #Source source
            WHERE NOT EXISTS
            (
                SELECT 1 FROM [befordring].[Elev] target
                WHERE target.cpr = source.cpr
            );

            SET @inserted_rows = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT
            @staged_rows   AS staged_rows,
            @duplicate_cpr AS duplicate_cpr_dropped,
            @updated_rows  AS updated_rows,
            @inserted_rows AS inserted_rows,
            @flagged_rows  AS skolekode_changed_school_cleared;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
