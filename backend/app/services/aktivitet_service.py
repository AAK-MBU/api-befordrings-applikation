"""Service layer for case activity (Sagsaktivitet) operations."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.citizen import Sagsaktivitet
from app.schemas.aktivitet import SagsaktivitetCreateRequest


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
            oprettet_af=payload.oprettet_af,
            relateret_bevilling_id=payload.relateret_bevilling_id,
        )

        self.db.add(aktivitet)
        self.db.commit()
        self.db.refresh(aktivitet)

        return aktivitet
