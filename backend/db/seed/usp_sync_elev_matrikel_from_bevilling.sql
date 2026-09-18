USE [Befordringssystemet]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    Derive Elev.matrikel_id and Elev.ungdomsuddannelse_id from the student's
    bevillinger.

    Elev_STG carries neither — the data worker's source has no school. The only
    place a school exists is on the bevilling, so it is copied back onto the
    student here.

    Which bevilling:

        * the student's ACTIVE bevilling, if they have a qualifying one
        * otherwise their most recently created qualifying bevilling

    Soft-deleted bevillinger (aktiv = 0) are ignored throughout.

    What makes a bevilling QUALIFY:

      folkeskole            b.matrikel_id is set, AND that matrikel's skolekode
                            equals the student's own skolekode.

                            The student's skolekode comes from the data
                            worker's load and is the authority on which school
                            the child attends. A bevilling that has not caught
                            up — still pointing at last year's school — must not
                            supply a matrikel, or the walking distance would be
                            measured to a school the child no longer attends.

      ungdomsuddannelse     b.matrikel_id is NULL and b.ungdomsuddannelse_id is
                            set. There is no skolekode on an ungdomsuddannelse,
                            so there is nothing to cross-check; the bevilling is
                            taken at face value.

    Where NOTHING qualifies, both columns are CLEARED. That is the point of the
    procedure as much as the copying is: a stale school is worse than no
    school. It skips the walking-distance step (which needs coordinates) rather
    than producing a confidently wrong number, and the mismatch is already on
    the Genbehandling page for a caseworker to resolve. Once the bevilling is
    corrected, the next night derives the school again.

    This procedure is therefore AUTHORITATIVE over both columns: after it runs,
    they mirror the chosen bevilling or they are NULL. Nothing else writes them.

    What this is for, and what it is NOT for:

      The pair feeds the walking-distance calculation, which resolves school
      coordinates from Skolematrikel or Ungdomsuddannelse. Measuring to the
      bevilling's school is correct: skoleafstand exists to serve the
      afstandskriterie on that bevilling.

      It does NOT feed genbehandling. usp_recalculate_bevilling_status compares
      Elev.SKOLEKODE against the skolekode of the BEVILLING's matrikel — two
      independent sources. Deriving matrikel_id from the bevilling cannot mask
      a mismatch, because the qualifying rule above means a mismatched bevilling
      never supplies one in the first place.

    kraever_genberegning is raised wherever the pair actually changes, cleared
    or set, because the school the distance is measured to has moved. The other
    two triggers live with the columns they belong to — skolekode in
    usp_upsert_elev_from_stg, adresse_id in usp_upsert_adresse_ids_from_stg.

    Ordering: run AFTER usp_upsert_elev_from_stg, so that new students exist to
    match against and skolekode is already current.
*/

CREATE OR ALTER PROCEDURE [befordring].[usp_sync_elev_matrikel_from_bevilling]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @qualifying  INT = 0;
    DECLARE @changed     INT = 0;
    DECLARE @cleared     INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

            /* Bevillinger that may supply a school for their student. */
            ;WITH Qualifying AS
            (
                SELECT
                    b.cpr_elev,
                    b.matrikel_id,
                    b.ungdomsuddannelse_id,
                    b.created_at,
                    b.bevilling_id,
                    CASE WHEN s.status_tekst = N'Aktiv' THEN 0 ELSE 1 END AS status_rank
                FROM       [befordring].[Bevilling]      b
                LEFT JOIN  [befordring].[Status]         s  ON s.status_id   = b.status_id
                INNER JOIN [befordring].[Elev]           e  ON e.cpr         = b.cpr_elev
                LEFT JOIN  [befordring].[Skolematrikel]  sm ON sm.matrikel_id = b.matrikel_id
                WHERE b.aktiv = 1
                AND (
                        /* folkeskole: the matrikel must belong to the school
                           the child is actually registered at. */
                        (
                            b.matrikel_id IS NOT NULL
                            AND ISNULL(e.skolekode, 0) <> 0
                            AND sm.skolekode = e.skolekode
                        )
                        OR
                        /* ungdomsuddannelse: no skolekode exists to check. */
                        (
                            b.matrikel_id IS NULL
                            AND b.ungdomsuddannelse_id IS NOT NULL
                        )
                    )
            ),
            /* rank 0 sorts before 1, so an Aktiv bevilling wins regardless of
               age; within a rank, newest first. bevilling_id breaks a tie on
               identical created_at, so the choice is stable from one night to
               the next rather than arbitrary. */
            Ranked AS
            (
                SELECT
                    cpr_elev,
                    matrikel_id,
                    ungdomsuddannelse_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY cpr_elev
                        ORDER BY     status_rank, created_at DESC, bevilling_id DESC
                    ) AS rn
                FROM Qualifying
            )
            SELECT cpr_elev, matrikel_id, ungdomsuddannelse_id
            INTO   #Chosen
            FROM   Ranked
            WHERE  rn = 1;

            CREATE UNIQUE CLUSTERED INDEX IX_Chosen_cpr ON #Chosen (cpr_elev);

            SELECT @qualifying = COUNT(*) FROM #Chosen;

            /* Every student is considered, not just those with a chosen
               bevilling: the LEFT JOIN yields NULLs where nothing qualifies,
               which is exactly the value that should be written.

               EXCEPT rather than "<>" so NULL compares equal to NULL — a
               student who has no school and should have none is not rewritten,
               and does not have kraever_genberegning raised, every night. */
            SELECT
                e.cpr,
                c.matrikel_id,
                c.ungdomsuddannelse_id,
                CASE WHEN c.cpr_elev IS NULL THEN 1 ELSE 0 END AS is_clear
            INTO      #Delta
            FROM      [befordring].[Elev] e
            LEFT JOIN #Chosen c ON c.cpr_elev = e.cpr
            WHERE EXISTS (
                      SELECT e.matrikel_id, e.ungdomsuddannelse_id
                      EXCEPT
                      SELECT c.matrikel_id, c.ungdomsuddannelse_id
                  );

            SELECT
                @changed = COUNT(*),
                @cleared = SUM(CASE WHEN is_clear = 1 THEN 1 ELSE 0 END)
            FROM #Delta;

            UPDATE e
            SET    e.matrikel_id          = d.matrikel_id,
                   e.ungdomsuddannelse_id = d.ungdomsuddannelse_id,
                   e.kraever_genberegning = 1
            FROM   [befordring].[Elev] e
            JOIN   #Delta d ON d.cpr = e.cpr;

        COMMIT TRANSACTION;

        SELECT
            @qualifying        AS students_with_qualifying_bevilling,
            @changed           AS school_changed,
            ISNULL(@cleared,0) AS of_which_cleared;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
