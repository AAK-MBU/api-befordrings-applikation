from fastapi import APIRouter

from app.api.dependencies import DbSession
from app.services.overview_service import OverviewService


router = APIRouter(prefix="/overview", tags=["Overview"])


@router.get("/aktive_bevillinger")
def get_active_bevillinger(db: DbSession):
    return OverviewService(db=db).get_active_bevillinger()


@router.get("/ikke_aktive_bevillinger")
def get_non_active_bevillinger(db: DbSession):
    return OverviewService(db=db).get_non_active_bevillinger()


@router.get("/revurderinger")
def get_reassessments(db: DbSession):
    return OverviewService(db=db).get_reassessments()


@router.get("/new_applications")
def get_new_applications(db: DbSession):
    return OverviewService(db=db).get_new_applications()


@router.get("/reports")
def get_reports(db: DbSession):
    return OverviewService(db=db).get_reports()
