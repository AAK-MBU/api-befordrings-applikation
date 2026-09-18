USE [Befordringssystemet]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    Resolve adresse_id for elever and forældre from Elev_Adresse_STG.

    Elev_STG and Foraelder_STG never carry an address — the data worker's job
    does not have one. The link between a person and an address comes from
    LOIS.CPR.PersonGeoView instead, which the RPA loads into Elev_Adresse_STG
    keyed on PNR_0 (ten digits, no dash, matching Elev.cpr and
    Foraelder.cpr_foraelder).

    One stage serves both tables: the column is `cpr`, not `cpr_elev`, so a
    guardian's row looks exactly like a student's.

    This procedure owns Elev.adresse_id. It is therefore also what raises
    kraever_genberegning when a student moves, since a new address changes the
    distance to school. usp_upsert_elev_from_stg raises the flag for the other
    half — a change of school.

    Addresses not present in Adresse are skipped, not written. Elev's and
    Foraelder's foreign keys to Adresse are trusted (migration 021), so writing
    an unknown id would fail the whole batch; and an address the nightly
    Adresse import has not loaded yet is a sequencing problem, not a reason to
    lose the rest of the run. The skipped count is returned so a persistent
    gap is visible.

    Ordering: this must run AFTER usp_upsert_adresser_from_stg (so Adresse is
    current) and AFTER usp_upsert_elev_from_stg (so new students exist to
    match).
*/

CREATE OR ALTER PROCEDURE [befordring].[usp_upsert_adresse_ids_from_stg]
    @load_id                UNIQUEIDENTIFIER,
    @clear_stage_afterwards BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @staged_rows       INT = 0;
    DECLARE @unknown_adresse   INT = 0;
    DECLARE @elev_updated      INT = 0;
    DECLARE @foraelder_updated INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

            /* One row per cpr for this load. A person appears once in
               PersonGeoView, but the stage has no key to enforce it. */
            ;WITH SourceRows AS
            (
                SELECT
                    LTRIM(RTRIM(cpr))        AS cpr,
                    LTRIM(RTRIM(adresse_id)) AS adresse_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY LTRIM(RTRIM(cpr))
                        ORDER BY     (SELECT NULL)
                    ) AS rn
                FROM [befordring].[Elev_Adresse_STG]
                WHERE load_id = @load_id
                AND   NULLIF(LTRIM(RTRIM(cpr)), '')        IS NOT NULL
                AND   NULLIF(LTRIM(RTRIM(adresse_id)), '') IS NOT NULL
            )
            SELECT cpr, adresse_id
            INTO   #Source
            FROM   SourceRows
            WHERE  rn = 1;

            SELECT @staged_rows = COUNT(*) FROM #Source;

            /* Drop anything Adresse does not know about, rather than letting
               the foreign key take the whole transaction down. */
            SELECT @unknown_adresse = COUNT(*)
            FROM   #Source s
            WHERE  NOT EXISTS (SELECT 1 FROM [befordring].[Adresse] a
                               WHERE a.adresse_id = s.adresse_id);

            DELETE s
            FROM   #Source s
            WHERE  NOT EXISTS (SELECT 1 FROM [befordring].[Adresse] a
                               WHERE a.adresse_id = s.adresse_id);

            CREATE UNIQUE CLUSTERED INDEX IX_Source_cpr ON #Source (cpr);

            /* Students who are actually moving. Captured before the UPDATE,
               while the old adresse_id is still readable. ISNULL guards the
               first-ever resolution, where the current value is NULL. */
            SELECT e.cpr
            INTO   #Moved
            FROM   [befordring].[Elev] e
            JOIN   #Source s ON s.cpr = e.cpr
            WHERE  ISNULL(e.adresse_id, '') <> s.adresse_id;

            UPDATE e
            SET    e.adresse_id = s.adresse_id
            FROM   [befordring].[Elev] e
            JOIN   #Source s ON s.cpr = e.cpr
            WHERE  ISNULL(e.adresse_id, '') <> s.adresse_id;

            SET @elev_updated = @@ROWCOUNT;

            /* A new address moves the child relative to their school, so the
               walking distance has to be recalculated. */
            UPDATE e
            SET    e.kraever_genberegning = 1
            FROM   [befordring].[Elev] e
            JOIN   #Moved m ON m.cpr = e.cpr;

            /* Guardians are matched on their own CPR, so one row in the stage
               updates every Foraelder row that adult has — one per child. */
            UPDATE f
            SET    f.adresse_id = s.adresse_id
            FROM   [befordring].[Foraelder] f
            JOIN   #Source s ON s.cpr = f.cpr_foraelder
            WHERE  ISNULL(f.adresse_id, '') <> s.adresse_id;

            SET @foraelder_updated = @@ROWCOUNT;

            IF @clear_stage_afterwards = 1
            BEGIN
                DELETE FROM [befordring].[Elev_Adresse_STG]
                WHERE load_id = @load_id;
            END;

        COMMIT TRANSACTION;

        SELECT
            @staged_rows       AS staged_rows,
            @unknown_adresse   AS skipped_unknown_adresse,
            @elev_updated      AS elev_updated,
            @foraelder_updated AS foraelder_updated;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
