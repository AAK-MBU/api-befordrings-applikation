from fastapi import APIRouter, Query

from app.api.dependencies import DbSession
from app.services.overview_service import OverviewService


router = APIRouter(prefix="/overview", tags=["Overview"])


@router.get("/alle_bevillinger")
def get_alle_bevillinger(db: DbSession):
    """Get all bevillinger (every status) for the overview table."""

    return OverviewService(db=db).get_alle_bevillinger()


@router.get("/search")
def search_elever(db: DbSession, q: str = Query(default="", min_length=0)):
    """Global search box: find a student by CPR or name.

    Not gated by RequireEdit — anyone with access to the system may look a
    student up; only writing is restricted.
    """

    return OverviewService(db=db).search_elever(q)


@router.get("/aktive_bevillinger")
def get_active_bevillinger(db: DbSession):
    return OverviewService(db=db).get_active_bevillinger()


@router.get("/fejlede_bevillinger")
def get_fejlede_bevillinger(db: DbSession):
    return OverviewService(db=db).get_fejlede_bevillinger()


@router.get("/revurderinger")
def get_revurderinger(db: DbSession):
    return OverviewService(db=db).get_revurderinger()


@router.get("/genbehandlinger")
def get_genbehandlinger(db: DbSession):
    return OverviewService(db=db).get_genbehandlinger()


@router.get("/new_applications")
def get_new_applications(db: DbSession):
    return OverviewService(db=db).get_new_applications()


@router.get("/reports")
def get_reports(db: DbSession):
    return OverviewService(db=db).get_reports()
