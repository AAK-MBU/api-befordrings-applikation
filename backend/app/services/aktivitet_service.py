"""Service layer for case activity (Sagsaktivitet) operations."""

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.citizen import Sagsaktivitet
from app.schemas.aktivitet import SagsaktivitetCreateRequest


# The only aktivitetstype a user may delete. Every other value on Sagsaktivitet
# is written by the application to record something that happened to the case —
# "Bevilling oprettet", "Brev oprettet" — and is part of the case history rather
# than something a caseworker authored.
DELETABLE_AKTIVITETSTYPE = "Kommentar"


class AktivitetService:
    """Service class for case activity operations.

    Args:
        db:
            SQLAlchemy database session.
    """

    def __init__(self, db: Session):
        """Initialize the service with a database session."""

        self.db = db

    def get_case_activity(self, cpr: str) -> list[Sagsaktivitet]:
        """Retrieve all activities for a citizen/case, newest first.

        Args:
            cpr:
                CPR number of the citizen/student.

        Returns:
            A list of Sagsaktivitet records ordered by oprettet_tidspunkt
            descending.
        """

        stmt = (
            select(Sagsaktivitet)
            .where(Sagsaktivitet.cpr == cpr)
            .order_by(Sagsaktivitet.oprettet_tidspunkt.desc())
        )

        return list(self.db.execute(stmt).scalars().all())

    def create_activity(self, cpr: str, payload: SagsaktivitetCreateRequest) -> Sagsaktivitet:
        """Create an activity/comment on a citizen case.

        Args:
            cpr:
                CPR number of the citizen/student.

            payload:
                The activity to create.

        Returns:
            The created Sagsaktivitet record.
        """

        aktivitet = Sagsaktivitet(
            cpr=cpr,
            aktivitetstype=payload.aktivitetstype,
            kommentar=payload.kommentar,
            udfoert_af=payload.udfoert_af,
            relateret_bevilling_id=payload.relateret_bevilling_id,
        )

        self.db.add(aktivitet)
        self.db.commit()
        self.db.refresh(aktivitet)

        return aktivitet

    def delete_activity(self, aktivitet_id: int) -> dict:
        """Permanently delete a caseworker comment.

        A real DELETE, unlike bevilling and kørselsrække which are soft-deleted
        via an `aktiv` flag. Sagsaktivitet has no such column, and the intent
        here is that a deleted comment leaves no trace in the feed.

        The row is not gone without record: the DELETE call itself is written to
        PortalAuditLog with the caller's identity, so who removed which activity
        is answerable afterwards. What the comment *said* is not recoverable.

        Args:
            aktivitet_id:
                ID of the activity to delete.

        Returns:
            Dictionary containing the deleted row count and id.

        Raises:
            HTTPException:
                404 if no activity has that id.

                403 if the activity is not a comment. Authorisation to delete
                comments is granted by the route's RequireEdit dependency; this
                is the separate rule that system-written history is off limits
                to everyone.
        """

        aktivitet = self.db.get(Sagsaktivitet, aktivitet_id)

        if aktivitet is None:
            raise HTTPException(
                status_code=404,
                detail=f"Aktivitet not found: {aktivitet_id}",
            )

        if aktivitet.aktivitetstype != DELETABLE_AKTIVITETSTYPE:
            raise HTTPException(
                status_code=403,
                detail=(
                    "Kun kommentarer kan slettes. "
                    "Systemhændelser er en del af sagens historik."
                ),
            )

        self.db.delete(aktivitet)
        self.db.commit()

        return {"deleted": 1, "aktivitet_id": aktivitet_id}
