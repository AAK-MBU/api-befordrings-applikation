"""Service layer for OS2Forms submission handling.

This module contains logic for receiving, parsing, and mapping OS2Forms
submissions into internal bevilling creation data.

The main responsibilities are:

- Parse incoming OS2Forms payloads
- Support both JSON and form-encoded request bodies
- Map OS2Forms field names to BevillingCreateRequest fields
- Create a bevilling through BevillingService

The API router should only pass the raw request into this service.
"""

from urllib.parse import parse_qs

from fastapi import Request
from sqlalchemy.orm import Session

from app.schemas.bevilling import BevillingCreateRequest
from app.services.bevilling_service import BevillingService
from app.utils.date_utils import parse_os2forms_timestamp
from app.utils.os2forms_mapping import (
    get_adresse_for_bevilling,
    get_ansoegningstype,
    get_relation_til_barnet,
)


class OS2FormsService:
    """Service class for OS2Forms-related operations.

    Args:
        db:
            SQLAlchemy database session.
    """

    def __init__(self, db: Session):
        """Initialize the service with a database session."""

        self.db = db


    async def parse_payload(self, request: Request) -> dict:
        """Parse the incoming OS2Forms request payload.

        Args:
            request:
                The raw FastAPI request object.

        Returns:
            A dictionary containing the parsed request payload.

        Notes:
            OS2Forms may send submissions as JSON or as form-encoded data.

            If the request content type is application/json, the request body
            is parsed as JSON.

            Otherwise, the body is parsed as form-encoded text using parse_qs.
        """

        content_type = request.headers.get("content-type", "")

        # If OS2Forms sends JSON, FastAPI can parse it directly.
        if "application/json" in content_type:
            return await request.json()

        # For non-JSON payloads, read the raw body bytes.
        raw_body = await request.body()

        # Decode the body as text.
        #
        # errors="replace" prevents the entire request from crashing if an
        # unexpected character cannot be decoded cleanly.
        raw_text = raw_body.decode("utf-8", errors="replace")

        # parse_qs parses form-encoded strings like:
        #
        # name=Test&age=10
        #
        # into:
        #
        # {
        #     "name": ["Test"],
        #     "age": ["10"],
        # }
        parsed_body = parse_qs(raw_text)

        # Convert one-item lists into simple values.
        #
        # Example:
        # {"name": ["Test"]} becomes {"name": "Test"}
        #
        # If a field has multiple values, the list is kept.
        return {
            key: values[0] if len(values) == 1 else values
            for key, values in parsed_body.items()
        }


    def map_submission_to_bevilling(self, payload: dict) -> BevillingCreateRequest:
        """Map an OS2Forms payload to a BevillingCreateRequest.

        Args:
            payload:
                Parsed OS2Forms submission data.

        Returns:
            A BevillingCreateRequest containing the fields needed to create a
            new bevilling.

        Notes:
            This method is where OS2Forms-specific field names are translated
            into the internal API schema.

            More complex mapping logic is delegated to helper functions in
            app.utils.os2forms_mapping.
        """

        return BevillingCreateRequest(
            adresse_for_bevilling=get_adresse_for_bevilling(payload),
            ansoegningsdato=parse_os2forms_timestamp(payload.get("completed")),
            relation_til_barnet=get_relation_til_barnet(payload),
            foerste_koersel_dato=payload.get("dato_for_foerste_koersel"),
            ansoegningstype=get_ansoegningstype(payload),
            begrundelse_fra_formular=payload.get("begrundelse_for_ansoegning"),
        )


    async def create_bevilling_from_submission(self, cpr: str, request: Request):
        """Create a bevilling from an OS2Forms submission.

        Args:
            cpr:
                CPR number from the route path.

            request:
                Raw FastAPI request object containing the OS2Forms submission.

        Returns:
            A dictionary containing:
            - status
            - CPR
            - result from BevillingService.create_bevilling

        Notes:
            This method ties the full OS2Forms flow together:

            1. Parse the incoming request.
            2. Map the payload to the internal create schema.
            3. Create the bevilling through BevillingService.
            4. Return a small response object.
        """

        # Parse the raw OS2Forms request into a normal dictionary.
        payload = await self.parse_payload(request)

        # Convert OS2Forms field names/values into the internal API schema.
        bevilling_request = self.map_submission_to_bevilling(payload)

        # Reuse BevillingService for the actual creation logic.
        #
        # This keeps creation rules in one place instead of duplicating them
        # inside OS2FormsService.
        service = BevillingService(db=self.db)

        result = service.create_bevilling(
            cpr=cpr,
            new_bevilling_data=bevilling_request.model_dump(exclude_none=True),
            status_text="Ny",
        )

        return {
            "status": "created",
            "cpr": cpr,
            "result": result,
        }
