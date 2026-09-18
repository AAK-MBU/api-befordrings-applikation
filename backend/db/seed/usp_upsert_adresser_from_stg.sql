USE [Befordringssystemet]
GO

/****** Object:  StoredProcedure [befordring].[usp_upsert_adresser_from_stg]    Script Date: 18/09/2026 10:11:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [befordring].[usp_upsert_adresser_from_stg]
    @load_id UNIQUEIDENTIFIER,
    @clear_stage_afterwards BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @updated_rows INT = 0;
    DECLARE @inserted_rows INT = 0;
    DECLARE @staged_rows INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

            ;WITH SourceRows AS
            (
                SELECT
                    adresse_id,
                    adresse_tekst,
                    latitude,
                    longitude,
                    ROW_NUMBER() OVER (
                        PARTITION BY adresse_id
                        ORDER BY stage_id DESC
                    ) AS rn
                FROM [befordring].[Adresse_STG]
                WHERE load_id = @load_id
            )
            SELECT
                adresse_id,
                adresse_tekst,
                latitude,
                longitude
            INTO #SourceDeduplicated
            FROM SourceRows
            WHERE rn = 1;

            CREATE UNIQUE CLUSTERED INDEX IX_SourceDeduplicated_adresse_id
            ON #SourceDeduplicated (adresse_id);

            SELECT
                @staged_rows = COUNT(*)
            FROM #SourceDeduplicated;


            UPDATE target
            SET
                target.adresse_tekst = source.adresse_tekst,
                target.latitude = source.latitude,
                target.longitude = source.longitude
            FROM [befordring].[Adresse] target
            JOIN #SourceDeduplicated source
                ON source.adresse_id = target.adresse_id
            WHERE EXISTS
            (
                SELECT
                    target.adresse_tekst,
                    target.latitude,
                    target.longitude

                EXCEPT

                SELECT
                    source.adresse_tekst,
                    source.latitude,
                    source.longitude
            );

            SET @updated_rows = @@ROWCOUNT;


            INSERT INTO [befordring].[Adresse]
            (
                adresse_id,
                adresse_tekst,
                latitude,
                longitude
            )
            SELECT
                source.adresse_id,
                source.adresse_tekst,
                source.latitude,
                source.longitude
            FROM #SourceDeduplicated source
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [befordring].[Adresse] target
                WHERE target.adresse_id = source.adresse_id
            );

            SET @inserted_rows = @@ROWCOUNT;


            IF @clear_stage_afterwards = 1
            BEGIN
                DELETE FROM [befordring].[Adresse_STG]
                WHERE load_id = @load_id;
            END;

        COMMIT TRANSACTION;

        SELECT
            @staged_rows AS staged_rows,
            @updated_rows AS updated_rows,
            @inserted_rows AS inserted_rows;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO


