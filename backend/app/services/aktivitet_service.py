"""Service layer for case activity (Sagsaktivitet) operations."""

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.citizen import Sagsaktivitet, SagsaktivitetType
from app.schemas.aktivitet import SagsaktivitetCreateRequest
from app.utils.identitet import samme_bruger

# type_kode of the only activity type a caseworker may delete.
DELETABLE_TYPE_KODE = "kommentar"

# Mapping from the legacy aktivitetstype strings sent by the frontend to the
# canonical type_kode. Only "kommentar" is user-created; this map lets the
# endpoint keep accepting the same payload without a breaking change.
_AKTIVITETSTYPE_TO_KODE: dict[str, str] = {
    "Kommentar": "kommentar",
}


class AktivitetService:
    """Service class for case activity operations."""

    def __init__(self, db: Session):
        self.db = db

    def _get_type_id(self, type_kode: str) -> int | None:
        return self.db.execute(
            select(SagsaktivitetType.type_id).where(SagsaktivitetType.type_kode == type_kode)
        ).scalar_one_or_none()

    def get_case_activity(self, cpr: str) -> list[Sagsaktivitet]:
        """Retrieve all activities for a citizen/case, newest first."""

        stmt = (
            select(Sagsaktivitet)
            .where(Sagsaktivitet.cpr == cpr)
            .options(joinedload(Sagsaktivitet.type))
            .order_by(Sagsaktivitet.oprettet_tidspunkt.desc())
        )

        return list(self.db.execute(stmt).scalars().all())

    def create_activity(self, cpr: str, payload: SagsaktivitetCreateRequest) -> Sagsaktivitet:
        """Create an activity/comment on a citizen case."""

        type_kode = _AKTIVITETSTYPE_TO_KODE.get(payload.aktivitetstype)
        type_id = self._get_type_id(type_kode) if type_kode else None

        aktivitet = Sagsaktivitet(
            cpr=cpr,
            aktivitetstype=payload.aktivitetstype,
            aktivitetstype_id=type_id,
            kommentar=payload.kommentar,
            udfoert_af=payload.udfoert_af,
            relateret_bevilling_id=payload.relateret_bevilling_id,
        )

        self.db.add(aktivitet)
        self.db.commit()

        # Re-query with joinedload so type_kode is available on the response.
        return self.db.execute(
            select(Sagsaktivitet)
            .where(Sagsaktivitet.aktivitet_id == aktivitet.aktivitet_id)
            .options(joinedload(Sagsaktivitet.type))
        ).scalar_one()

    def delete_activity(self, aktivitet_id: int, udfoert_af: str) -> dict:
        """Permanently delete one of the caller's own caseworker comments.

        A real DELETE — Sagsaktivitet has no aktiv flag. The DELETE call itself
        lands in PortalAuditLog with the caller's identity, so attribution is
        preserved even though the comment text is gone.

        Two independent rules, both enforced here rather than at the route, so
        no future caller can reach a delete that skips them:

          1. Only a comment may go. System history ("Bevilling oprettet",
             "Brev oprettet") is the case's record of what happened and is
             immutable for everyone.
          2. Only your own. This is the whole permission — it is deliberately
             not tied to a role, so a Medarbejder cannot delete a PPR
             colleague's comment any more than the other way round. Deleting
             kørselsrækker and bevillinger stays with the edit roles; this one
             action is governed by authorship instead.

        Args:
            aktivitet_id:
                ID of the comment to delete.

            udfoert_af:
                Display name of the signed-in caller, as get_udfoert_af
                resolves it — the same value create_activity stored.

        Raises:
            HTTPException:
                404 if the activity does not exist.
                403 if it is not a comment (system history is immutable).
                403 if it was written by someone else.
        """

        aktivitet = self.db.get(Sagsaktivitet, aktivitet_id)

        if aktivitet is None:
            raise HTTPException(
                status_code=404,
                detail=f"Aktivitet not found: {aktivitet_id}",
            )

        is_kommentar = (
            aktivitet.type_kode == DELETABLE_TYPE_KODE
            or aktivitet.aktivitetstype == "Kommentar"
        )

        if not is_kommentar:
            raise HTTPException(
                status_code=403,
                detail=(
                    "Kun kommentarer kan slettes. "
                    "Systemhændelser er en del af sagens historik."
                ),
            )

        if not samme_bruger(aktivitet.udfoert_af, udfoert_af):
            raise HTTPException(
                status_code=403,
                detail="Du kan kun slette dine egne kommentarer.",
            )

        self.db.delete(aktivitet)
        self.db.commit()

        return {"deleted": 1, "aktivitet_id": aktivitet_id}
