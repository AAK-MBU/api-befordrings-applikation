"""API router for created decision letters (Forsendelse).

Creating a letter queues an ATS work item and produces a document; it does NOT
post anything to the parents. These endpoints back the Forsendelse page, which
is the worklist of letters that exist but have not been sent yet.
"""

from fastapi import APIRouter

from app.api.dependencies import CurrentUser, DbSession, RequireEdit
from app.schemas.brev import BrevAfsendtRequest, BrevAfsendtResponse
from app.services.brev_service import BrevService


router = APIRouter(prefix="/brev", tags=["Brev"])


@router.get("/forsendelse")
def get_forsendelse(db: DbSession):
    """Letters created but not yet sent.

    Args:
        db:
            Database session injected by FastAPI.

    Returns:
        Rows from view_Forsendelse, oldest first — a letter waiting three weeks
        needs attention before one created this morning.
    """

    return BrevService(db=db).get_ikke_afsendte()


@router.put("/afsendt", response_model=BrevAfsendtResponse, dependencies=[RequireEdit])
def set_afsendt(
    request: BrevAfsendtRequest,
    afsendt_af: CurrentUser,
    db: DbSession,
):
    """Mark letters as sent, or reopen them.

    Takes a list rather than a single id: caseworkers post in batches, and
    marking twenty letters one at a time is the kind of friction that stops a
    worklist being used.

    Args:
        request:
            The letter ids and the state to set.

        afsendt_af:
            The signed-in caseworker, resolved from the OIDC session.

        db:
            Database session injected by FastAPI.

    Returns:
        Which ids changed, and how many were already in the requested state.
    """

    return BrevService(db=db).set_afsendt(
        brev_ids=request.brev_ids,
        afsendt=request.afsendt,
        afsendt_af=afsendt_af,
    )
