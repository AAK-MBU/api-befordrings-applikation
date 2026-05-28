from fastapi import APIRouter, Query

from app.api.dependencies import DbSession
from app.services.overview_service import OverviewService


router = APIRouter(prefix="/overview", tags=["Overview"])


@router.get("/search")
def search_bevillinger(db: DbSession, q: str = Query(default="", min_length=0)):
    return OverviewService(db=db).search_bevillinger(q)


@router.get("/aktive_bevillinger")
def get_active_bevillinger(db: DbSession):
    return OverviewService(db=db).get_active_bevillinger()


@router.get("/ikke_aktive_bevillinger")
def get_non_active_bevillinger(db: DbSession):
    return OverviewService(db=db).get_non_active_bevillinger()


@router.get("/revurderinger")
def get_revurderinger(db: DbSession):
    return OverviewService(db=db).get_revurderinger()


@router.get("/new_applications")
def get_new_applications(db: DbSession):
    return OverviewService(db=db).get_new_applications()


@router.get("/reports")
def get_reports(db: DbSession):
    return OverviewService(db=db).get_reports()
