"""API router for OS2Forms-related endpoints.

This module contains endpoints that receive submissions from OS2Forms.

Unlike normal frontend endpoints, OS2Forms may send data in formats that need
special parsing, for example JSON or form-encoded payloads. That parsing should
be handled inside OS2FormsService.

The router itself should stay thin:

1. Receive the raw FastAPI request.
2. Create an OS2FormsService using the current database session.
3. Pass the CPR and request object to the service.
4. Return the service result.
"""

from fastapi import APIRouter, Request

from app.api.dependencies import DbSession
from app.services.os2forms_service import OS2FormsService


# All routes in this file are grouped under /os2forms.
# The tag is used by Swagger/OpenAPI to group these endpoints visually.
router = APIRouter(prefix="/os2forms", tags=["OS2Forms"])


@router.post("/create_bevilling/{cpr}")
async def create_bevilling_from_os2forms(
    cpr: str,
    request: Request,
    db: DbSession,
):
    """Create a bevilling from an OS2Forms submission.

    This endpoint is intended to be called by OS2Forms when a form is submitted.

    Args:
        cpr:
            The CPR number received as part of the URL.

        request:
            The raw FastAPI request object.

            This is passed directly to the service because OS2Forms submissions
            may need custom parsing depending on the content type.

        db:
            The database session injected by FastAPI.

    Returns:
        A result object from OS2FormsService.create_bevilling_from_submission.

    Notes:
        This endpoint is async because reading/parsing the request body may
        require awaiting FastAPI's request methods.

        The actual parsing and creation logic should stay inside
        OS2FormsService, not in the router.
    """

    service = OS2FormsService(db=db)

    return await service.create_bevilling_from_submission(
        cpr=cpr,
        request=request,
    )
