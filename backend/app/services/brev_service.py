"""Service layer for created decision letters.

Creating a letter queues an ATS work item and produces a document; it does NOT
post anything to the parents. This service owns the gap between those two: a
Brev row is written when the letter is generated, and marked `afsendt` when a
caseworker has actually sent it.

The Forsendelse page is the worklist of rows where afsendt = 0.
"""

from datetime import datetime

from fastapi import HTTPException
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.models.bevilling import Brev


class BrevService:
    """Service class for Brev operations."""

    def __init__(self, db: Session):
        self.db = db

    def _rows_to_dicts(self, result):
        return [dict(row) for row in result.mappings().all()]

    def create_brev(
        self,
        bevilling_id: int,
        cpr_elev: str,
        reference: str | None = None,
        afgoerelsesbrev_tekst: str | None = None,
        brev_i_forbindelse_med: str | None = None,
        oprettet_af: str | None = None,
        commit: bool = True,
    ) -> Brev:
        """Record that a letter was created for a bevilling.

        Called from the create_letter endpoint AFTER the ATS enqueue has
        succeeded — a failed enqueue must not leave a row claiming a letter
        exists.

        Args:
            bevilling_id:
                The bevilling the letter concerns.
            cpr_elev:
                CPR of the student, so the worklist can show who it is about
                without joining back through the bevilling.
            reference:
                The ATS work-item reference.
            afgoerelsesbrev_tekst:
                Snapshot of which letter this was — see the model docstring for
                why this is copied rather than referenced.
            brev_i_forbindelse_med:
                ansøgning / revurdering / midlertidig kørsel.
            oprettet_af:
                The signed-in caseworker.
            commit:
                Whether to commit. False lets a caller fold this into its own
                transaction.

        Returns:
            The created Brev.
        """

        brev = Brev(
            bevilling_id=bevilling_id,
            cpr_elev=cpr_elev,
            reference=reference,
            afgoerelsesbrev_tekst=afgoerelsesbrev_tekst,
            brev_i_forbindelse_med=brev_i_forbindelse_med,
            oprettet_af=oprettet_af,
            afsendt=False,
            aktiv=True,
        )

        self.db.add(brev)

        if commit:
            self.db.commit()
            self.db.refresh(brev)
        else:
            self.db.flush()

        return brev

    def get_ikke_afsendte(self):
        """Letters that exist but have not been sent — the Forsendelse worklist.

        Reads through view_Forsendelse so the student's name and the bevilling's
        løbenummer come along without the caller joining them.

        Returns:
            A list of dicts, oldest first: a letter waiting three weeks is more
            urgent than one created this morning.
        """

        sql = text("""
            SELECT
                *
            FROM
                [befordring].[view_Forsendelse]
            ORDER BY
                oprettet_tidspunkt ASC
        """)

        result = self.db.execute(sql)

        return self._rows_to_dicts(result)

    def set_afsendt(
        self,
        brev_ids: list[int],
        afsendt: bool,
        afsendt_af: str,
    ) -> dict:
        """Mark one or more letters as sent, or undo that.

        Bulk by design — caseworkers post in batches, and marking twenty
        letters one at a time is the kind of friction that stops a worklist
        being used at all.

        Undo is allowed (afsendt=False) because a mis-click is easy and the
        alternative is an unreachable row. Both directions stamp who acted, so
        the change is attributable either way.

        Args:
            brev_ids:
                The letters to update.
            afsendt:
                True to mark sent, False to reopen.
            afsendt_af:
                The signed-in caseworker.

        Returns:
            Dict with the ids actually updated and how many were skipped
            because they were already in the requested state.

        Raises:
            HTTPException:
                400 if no ids were given.
                404 if any id does not exist or is soft-deleted — a partial
                    bulk update would leave the caller unsure what happened.
        """

        if not brev_ids:
            raise HTTPException(status_code=400, detail="Ingen breve angivet")

        breve = (
            self.db.execute(
                select(Brev).where(
                    Brev.brev_id.in_(brev_ids),
                    Brev.aktiv == True,  # noqa: E712
                )
            )
            .scalars()
            .all()
        )

        found = {brev.brev_id for brev in breve}
        missing = sorted(set(brev_ids) - found)

        if missing:
            raise HTTPException(
                status_code=404,
                detail=f"Brev ikke fundet: {', '.join(str(i) for i in missing)}",
            )

        updated: list[int] = []
        stamped = datetime.now()

        for brev in breve:
            if bool(brev.afsendt) == afsendt:
                continue

            brev.afsendt = afsendt
            brev.afsendt_tidspunkt = stamped if afsendt else None
            brev.afsendt_af = afsendt_af if afsendt else None
            updated.append(brev.brev_id)

        self.db.commit()

        return {
            "updated": updated,
            "rows_updated": len(updated),
            "unchanged": len(brev_ids) - len(updated),
        }
