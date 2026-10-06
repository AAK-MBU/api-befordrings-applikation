"""API router for case activity (Sagsaktivitet) endpoints.

Sagsaktivitet is an audit/activity log for a citizen case — system events
and caseworker comments shown on the "Sagsforløb" tab of the case page.
"""

from fastapi import APIRouter

from app.api.dependencies import CurrentUser, DbSession
from app.schemas.aktivitet import SagsaktivitetCreateRequest, SagsaktivitetResponse
from app.services.aktivitet_service import AktivitetService


router = APIRouter(prefix="/aktivitet", tags=["Aktivitet"])


@router.get("/{cpr}", response_model=list[SagsaktivitetResponse])
def get_case_activity(cpr: str, db: DbSession):
    """Retrieve the activity feed for a citizen case.

    Args:
        cpr:
            CPR number of the citizen/student.

        db:
            Database session injected by FastAPI.

    Returns:
        Activities for the case, newest first.
    """

    service = AktivitetService(db=db)

    return service.get_case_activity(cpr=cpr)


@router.post("/{cpr}", response_model=SagsaktivitetResponse)
def create_activity(
    cpr: str,
    payload: SagsaktivitetCreateRequest,
    db: DbSession,
    udfoert_af: CurrentUser,
):
    """Create an activity/comment on a citizen case.

    Args:
        cpr:
            CPR number of the citizen/student.

        payload:
            The activity to create.

        db:
            Database session injected by FastAPI.

        udfoert_af:
            Display name of the signed-in caller, used for attribution when
            the payload does not explicitly set it.

    Returns:
        The created activity record.
    """

    # Default attribution to the signed-in user unless the caller supplied one.
    payload.udfoert_af = payload.udfoert_af or udfoert_af

    service = AktivitetService(db=db)

    return service.create_activity(cpr=cpr, payload=payload)


@router.delete("/kommentar/{aktivitet_id}")
def delete_comment(aktivitet_id: int, db: DbSession, udfoert_af: CurrentUser):
    """Permanently delete one of the caller's own caseworker comments.

    Deliberately NOT behind RequireEdit. Authorship is the permission here, not
    a role: everyone may delete their own comment and nobody may delete anyone
    else's, so an edit role grants nothing extra and the lack of one takes
    nothing away. That also makes the endpoint symmetrical with the POST above,
    which has never required an edit role — a user who can write a comment can
    now withdraw it.

    This is the one mutation governed that way. Deleting kørselsrækker and
    bevillinger stays behind RequireEdit, untouched.

    Both rules live in the service: only aktivitetstype "Kommentar" may be
    deleted, so system-written history ("Bevilling oprettet", "Brev oprettet")
    cannot be erased by anyone, and only by the person it is attributed to. The
    endpoint is still authenticated — CurrentUser resolves through require_auth
    — and an API-key caller resolves to "System", which owns nothing.

    Addressed by aktivitet_id under its own /kommentar prefix rather than as
    /aktivitet/{aktivitet_id}: the sibling GET and POST on this router take a
    *cpr* in that position, and a CPR coerced to int would silently name a
    different row.

    Args:
        aktivitet_id:
            ID of the comment to delete.

        udfoert_af:
            Display name of the signed-in caller, compared against the
            comment's own attribution.

    Returns:
        Dictionary containing the deleted row count and id.
    """

    service = AktivitetService(db=db)

    return service.delete_activity(
        aktivitet_id=aktivitet_id,
        udfoert_af=udfoert_af,
    )
