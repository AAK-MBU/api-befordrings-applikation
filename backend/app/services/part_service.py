"""Service layer for Part (associated parties) operations."""

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.citizen import Part
from app.schemas.part import PartCreateRequest, PartUpdateRequest


class PartService:
    """Service class for party operations.

    Args:
        db:
            SQLAlchemy database session.
    """

    def __init__(self, db: Session):
        self.db = db

    def get_parts(self, cpr: str) -> list[Part]:
        """Return all active parties for a student, newest first."""

        # NB: use `== True` (not `.is_(True)`) — on SQL Server `.is_(True)`
        # renders as `aktiv IS 1`, which is invalid T-SQL (IS only allows NULL).
        # joinedload(Part.adresse) so adresse_tekst is available without N+1.
        stmt = (
            select(Part)
            .options(joinedload(Part.adresse))
            .where(Part.cpr_elev == cpr, Part.aktiv == True)  # noqa: E712
            .order_by(Part.oprettet_tidspunkt.desc())
        )

        return list(self.db.execute(stmt).scalars().all())

    def create_part(self, cpr: str, payload: PartCreateRequest) -> Part:
        """Create a party for a student."""

        part = Part(
            cpr_elev=cpr,
            fulde_navn=payload.fulde_navn,
            cpr_nummer=payload.cpr_nummer,
            adresse_id=payload.adresse_id,
            relation=payload.relation,
            telefonnummer=payload.telefonnummer,
            oprettet_af=payload.oprettet_af,
        )

        self.db.add(part)
        self.db.commit()
        self.db.refresh(part)

        return part

    def update_part(self, part_id: int, payload: PartUpdateRequest) -> Part | None:
        """Update an active party. Only provided fields are changed.

        Returns the updated Part, or None if it does not exist / is inactive.
        """

        part = self.db.get(Part, part_id)

        if part is None or not part.aktiv:
            return None

        for key, value in payload.model_dump(exclude_unset=True).items():
            setattr(part, key, value)

        self.db.commit()
        self.db.refresh(part)

        return part

    def delete_part(self, part_id: int) -> bool:
        """Soft-delete a party (aktiv = False).

        Returns True if a party was deactivated, False if not found / already
        inactive.
        """

        part = self.db.get(Part, part_id)

        if part is None or not part.aktiv:
            return False

        part.aktiv = False
        self.db.commit()

        return True
