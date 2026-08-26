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

from fastapi import HTTPException, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.adresse import Adresse
from app.models.lookup import Hjaelpemiddel, Skolematrikel, Ungdomsuddannelse
from app.schemas.bevilling import BevillingCreateRequest
from app.services.bevilling_service import BevillingService
from app.utils import date_utils
from app.utils import os2forms_mapping


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


    def _resolve_matrikel_id(self, school_name: str) -> int | None:
        """Look up matrikel_id from Skolematrikel by name. Returns None if not found."""

        return self.db.execute(
            select(Skolematrikel.matrikel_id).where(
                Skolematrikel.matrikel_navn == school_name
            )
        ).scalar_one_or_none()


    def _resolve_ungdomsuddannelse_id(self, school_name: str) -> int | None:
        """Look up ungdomsuddannelse_id from Ungdomsuddannelse by name. Returns None if not found."""

        return self.db.execute(
            select(Ungdomsuddannelse.ungdomsuddannelse_id).where(
                Ungdomsuddannelse.ungdomsuddannelse_navn == school_name
            )
        ).scalar_one_or_none()


    def _resolve_adresse_id(self, payload: dict) -> str | None:
        """Resolve the bevilling address text to an Adresse.adresse_id.

        OS2Forms provides a free-text address string, but BevillingCreateRequest
        needs the adresse_id it maps to. Resolve it by exact match against the
        Adresse register — the same mechanism as GET /adresse/by-tekst. Returns
        None when no address is present or no exact match is found; in that case
        create_bevilling raises a clear 422 for the missing address rather than
        a 500.
        """

        adresse_tekst = os2forms_mapping.get_adresse_for_bevilling(payload)

        if not adresse_tekst:
            return None

        return self.db.execute(
            select(Adresse.adresse_id)
            .where(Adresse.adresse_tekst == adresse_tekst)
            .limit(1)
        ).scalars().first()


    def _resolve_school(self, payload: dict) -> dict:
        """Resolve the school field from an OS2Forms payload.

        Args:
            payload:
                Parsed OS2Forms submission data.

        Returns:
            A dict with exactly one of matrikel_id or ungdomsuddannelse_id set,
            and the other as None.

        Raises:
            HTTPException 422 if no school field is populated, or if the name
            does not match any row in the expected table.

        Notes:
            Three payload fields are checked in order, each with a fixed
            destination table:

            barnets_skole       → Skolematrikel   (regular school application)
            barnets_folkeskole  → Skolematrikel   (folkeskole application)
            ungdomsuddannelse   → Ungdomsuddannelse
        """

        barnets_skole = (payload.get("barnets_skole") or "").strip()
        barnets_folkeskole = (payload.get("barnets_folkeskole") or "").strip()
        ungdomsuddannelse = (payload.get("ungdomsuddannelse") or "").strip()

        if barnets_skole or barnets_folkeskole:
            name = barnets_skole or barnets_folkeskole
            matrikel_id = self._resolve_matrikel_id(name)
            if matrikel_id is None:
                raise HTTPException(
                    status_code=422,
                    detail=f"'{name}' did not match any school in Skolematrikel.",
                )
            return {"matrikel_id": matrikel_id, "ungdomsuddannelse_id": None}

        if ungdomsuddannelse:
            ungdomsuddannelse_id = self._resolve_ungdomsuddannelse_id(ungdomsuddannelse)
            if ungdomsuddannelse_id is None:
                raise HTTPException(
                    status_code=422,
                    detail=f"'{ungdomsuddannelse}' did not match any institution in Ungdomsuddannelse.",
                )
            return {"matrikel_id": None, "ungdomsuddannelse_id": ungdomsuddannelse_id}

        raise HTTPException(
            status_code=422,
            detail="No school field found in submission (barnets_skole, barnets_folkeskole, or ungdomsuddannelse).",
        )


    def _resolve_hjaelpemiddel_ids(self, names: list[str]) -> list[int]:
        """Look up hjaelpemiddel_ids from Hjaelpemiddel by name.

        Args:
            names:
                List of hjaelpemiddel names from the OS2Forms payload.

        Returns:
            List of matching hjaelpemiddel_ids. Names that do not match
            any row in the Hjaelpemiddel table are silently skipped.
        """

        if not names:
            return []

        rows = self.db.execute(
            select(Hjaelpemiddel.hjaelpemiddel_id, Hjaelpemiddel.hjaelpemiddel_tekst).where(
                Hjaelpemiddel.hjaelpemiddel_tekst.in_(names)
            )
        ).all()

        return [row.hjaelpemiddel_id for row in rows]


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

            Pure payload transformations (no DB) are delegated to helper
            functions in app.utils.os2forms_mapping.

            Fields that require a database lookup to resolve (e.g. a name
            to an ID) are handled by _resolve_* private methods on this
            class, since they need access to self.db.
        """

        hjaelpemiddel_names = os2forms_mapping.get_hjaelpemiddel_names(payload)
        school = self._resolve_school(payload)

        return BevillingCreateRequest(
            adresse_id=self._resolve_adresse_id(payload),
            matrikel_id=school["matrikel_id"],
            ungdomsuddannelse_id=school["ungdomsuddannelse_id"],
            ansoegningsdato=date_utils.parse_os2forms_timestamp(payload.get("completed")),
            relation_til_barnet=os2forms_mapping.get_relation_til_barnet(payload),
            foerste_koersel_dato=payload.get("dato_for_foerste_koersel"),
            ansoegningstype=os2forms_mapping.get_ansoegningstype(payload),
            begrundelse_fra_formular=os2forms_mapping.get_begrundelse(payload),
            hjaelpemiddel_ids=self._resolve_hjaelpemiddel_ids(hjaelpemiddel_names),
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

        print(f"parsed_payload:\n{payload}")

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
