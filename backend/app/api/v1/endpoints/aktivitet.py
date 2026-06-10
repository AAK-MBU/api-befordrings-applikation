"""API router for case activity (Sagsaktivitet) endpoints.

Sagsaktivitet is an audit/activity log for a citizen case — system events
and caseworker comments shown on the "Sagsforløb" tab of the case page.
"""

from fastapi import APIRouter

from app.api.dependencies import DbSession
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
def create_activity(cpr: str, payload: SagsaktivitetCreateRequest, db: DbSession):
    """Create an activity/comment on a citizen case.

    Args:
        cpr:
            CPR number of the citizen/student.

        payload:
            The activity to create.

        db:
            Database session injected by FastAPI.

    Returns:
        The created activity record.
    """

    service = AktivitetService(db=db)

    return service.create_activity(cpr=cpr, payload=payload)
