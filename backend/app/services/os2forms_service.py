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

import json
from urllib.parse import parse_qs

from fastapi import HTTPException, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.adresse import Adresse
from app.models.bevilling import Bevilling
from app.models.citizen import Elev
from app.models.lookup import Hjaelpemiddel, Skolematrikel, Ungdomsuddannelse
from app.schemas.bevilling import BevillingCreateRequest
from app.services.bevilling_service import BevillingService
from app.services.citizen_service import CitizenService
from app.utils import adresse_matching
from app.utils import date_utils
from app.utils import os2forms_mapping


# A street name shorter than this cannot drive a useful index seek.
_MIN_PREFIX_LENGTH = 2

# Far above any real street within a single postcode, so reaching it means
# the prefix is wrong rather than the street being large.
_MAX_CANDIDATES = 5000


def _match(
    adresse_tekst: str,
    candidates: list,
    ignore_bynavn: bool,
) -> list[str]:
    """The adresse_ids among candidates whose text normalises to the same key.

    Args:
        adresse_tekst:
            The address as submitted.

        candidates:
            (adresse_id, adresse_tekst) rows from the Adresse register.

        ignore_bynavn:
            Where True, the supplerende bynavn is removed from the REGISTER
            side only, never from the submission.

            That asymmetry is the point. The observed problem runs one way:
            DAR carries the component and MitID drops it. Stripping both
            sides would also make a submission match a row under a DIFFERENT
            place name —

                submission   Bygaden 7, Lisbjerg,  8200 Aarhus N
                register     Bygaden 7, Hjortshøj, 8200 Aarhus N

            — which is a wrong address, not a near miss. Stripped one way,
            the submission keeps "lisbjerg" in its key, nothing matches, and
            a caseworker sees the address named in a 422.

            A submission that carries the right place name needs no
            relaxation: it matches the register verbatim in the strict pass.

    Returns:
        Every matching adresse_id. The caller decides what more than one
        means.
    """

    def register_key(tekst: str) -> str:
        if ignore_bynavn:
            tekst = adresse_matching.strip_supplerende_bynavn(tekst) or tekst

        return adresse_matching.normalise_adresse(tekst)

    wanted = adresse_matching.normalise_adresse(adresse_tekst)

    return [
        adresse_id
        for adresse_id, tekst in candidates
        if register_key(tekst) == wanted
    ]


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


    def _folkeregister_adresse_id(self, cpr: str) -> str | None:
        """The child's registered address, as the nightly sync last saw it.

        Returns None where no Elev row exists yet — a first application
        for a child this system has never seen — or where the row carries
        no address. Callers must treat None as 'no opinion', never as a
        mismatch.
        """

        return self.db.execute(
            select(Elev.adresse_id).where(Elev.cpr == cpr)
        ).scalars().first()


    def _resolve_adresse_id(self, payload: dict, cpr: str) -> str:
        """Resolve the bevilling address text to an Adresse.adresse_id.

        OS2Forms provides a free-text address string, but
        BevillingCreateRequest needs the adresse_id it maps to.

        Args:
            payload:
                Parsed OS2Forms submission data.

        Returns:
            The adresse_id of the one Adresse row the submitted address
            resolves to.

        Raises:
            HTTPException 422:
                Where the submission carries no address, where no row matches,
                or where more than one does. Each case names the address, so
                the caseworker reading the queue item can see what to correct.

        Notes:
            Matching is by normalised equality, not raw equality: the MitID
            address field writes CPR's formatting rather than DAR's, so an
            apartment address never matches character for character. See
            app.utils.adresse_matching for what the normalisation does and,
            more importantly, what it refuses to do.

            The comparison runs in Python, but the candidate rows are narrowed
            in SQL first. Adresse holds the whole of Denmark — roughly four
            million rows — so normalising adresse_tekst inside the WHERE
            clause would scan all of them on every submission. Instead the
            street name drives an index seek on IX_Adresse_adresse_tekst and
            the postcode narrows the result, exactly as search_adresser does;
            only those rows are normalised. Narrowing can only ever cost a
            match, never invent one — the decision is still full equality of
            the normalised strings.

            Where two rows normalise identically this refuses rather than
            picking one. That replaces an earlier .limit(1), which silently
            chose a row; the address ends up on a bevilling as the place a
            taxi is dispatched to and a letter is sent to, and a quiet wrong
            answer there is worse than a stopped queue item.

            The refusal is also what makes the supplerende bynavn relaxation
            safe. Ignoring the component widens what can match — a postcode
            can span several villages holding the same street name — but a
            widening that produces two rows is rejected, not resolved.

            Before refusing, _break_tie gets one chance to settle it from the
            child's registered address. That resolves the two ambiguities the
            register actually produces — duplicate rows for one address, and
            one street name under two village names in a single postcode —
            without ever choosing a row the address did not already match.
        """

        adresse_tekst = os2forms_mapping.get_adresse_for_bevilling(payload)

        if not adresse_tekst:
            raise HTTPException(
                status_code=422,
                detail="Submission carries no address.",
            )

        prefix = adresse_matching.lookup_prefix(adresse_tekst)

        if len(prefix) < _MIN_PREFIX_LENGTH:
            raise HTTPException(
                status_code=422,
                detail=f"'{adresse_tekst}' has no usable street name to search on.",
            )

        query = self.db.query(Adresse.adresse_id, Adresse.adresse_tekst).filter(
            Adresse.adresse_tekst.startswith(prefix, autoescape=True)
        )

        postnummer = adresse_matching.extract_postnummer(adresse_tekst)

        if postnummer:
            # The postcode always follows ", " — it is the last component of
            # adresse_tekst, before the town. The filter is a contains match,
            # but it runs on top of the prefix seek, so it only touches rows
            # the index already narrowed to.
            query = query.filter(Adresse.adresse_tekst.like(f"%, {postnummer} %"))

        candidates = query.limit(_MAX_CANDIDATES).all()

        if len(candidates) == _MAX_CANDIDATES:
            # Deliberately an error rather than a search of what came back.
            # A truncated candidate set is indistinguishable from a complete
            # one, so "no match" here could mean the row was cut off. The
            # limit is far above any real street-in-one-postcode, so reaching
            # it means something is wrong with the address, not with the data.
            raise HTTPException(
                status_code=422,
                detail=f"'{adresse_tekst}' matched too many addresses to search reliably.",
            )

        hits = _match(adresse_tekst, candidates, ignore_bynavn=False)

        if not hits:
            # Only now, and only because the strict pass found nothing: MitID
            # omits the supplerende bynavn that DAR keeps, so "Thomas Windings
            # Gade 52, 8200 Aarhus N" has to be able to reach "Thomas Windings
            # Gade 52, Lisbjerg, 8200 Aarhus N". Running this second rather
            # than merged into the first keeps the relaxation from ever
            # beating an exact match, and it still has to be unambiguous to
            # be accepted.
            hits = _match(adresse_tekst, candidates, ignore_bynavn=True)

        if not hits:
            raise HTTPException(
                status_code=422,
                detail=f"'{adresse_tekst}' did not match any address in Adresse.",
            )

        if len(hits) > 1:
            hits = self._break_tie(hits, payload, cpr)

        if len(hits) > 1:
            raise HTTPException(
                status_code=422,
                detail=f"'{adresse_tekst}' matched {len(hits)} addresses in Adresse.",
            )

        self._verify_against_folkeregister(hits[0], adresse_tekst, payload, cpr)

        return hits[0]


    def _verify_against_folkeregister(
        self,
        adresse_id: str,
        adresse_tekst: str,
        payload: dict,
        cpr: str,
    ) -> None:
        """Refuse a resolved address the child is not registered at.

        Args:
            adresse_id:
                The adresse_id the submitted address resolved to.

            adresse_tekst:
                The address as submitted, for the error message.

            payload:
                Parsed OS2Forms submission data.

            cpr:
                The child's CPR.

        Raises:
            HTTPException 422:
                Where the submission states the folkeregisteradresse, the
                child is registered at a different one, and both are known.

        Notes:
            Where the "kør til/fra en anden adresse" box is NOT ticked, the
            form is not merely supplying an address — it is asserting that
            this is the child's folkeregisteradresse. Elev.adresse_id is the
            authoritative answer to that same question, from the nightly
            LOIS/CPR sync. Two answers to one question that disagree mean
            something is wrong, and this is the last point at which anyone
            can notice.

            That makes this a genuine gate rather than the tie-break above:
            it can reject a match, not merely choose between matches. It is
            the one check that covers the whole pipeline at once — a bad
            normalisation, a wrongly stripped component, a register
            duplicate — because it compares the ANSWER against an
            independent source rather than re-examining the reasoning.

            It stands down, silently, wherever it has no standing:

            - The box IS ticked. The bevilling address is a different place
              by design, so the registered address proves nothing.
            - No Elev row, or no address on it. A first application for a
              child this system has never seen. Nothing to compare against,
              and absence is not disagreement.

            What remains is the timing window: a family moves, and the form
            and the sync are snapshots of CPR taken at different moments. The
            kontrol RPA normally processes a submission within a day of its
            arrival, so that window is small — and a submission caught in it
            is stopped for a caseworker, not lost. Measure the rate before
            deploying this with
            db/analyse/bevilling_adresse_mod_folkeregister.sql; the check is
            only worth having while the stops stay rare.
        """

        if os2forms_mapping.is_alternate_address(payload):
            return

        registreret = self._folkeregister_adresse_id(cpr)

        if registreret is None or registreret == adresse_id:
            return

        # Read the registered address for the message. Only on the failure
        # path, and it is what makes the queue item actionable: a caseworker
        # needs to see WHICH two addresses disagree, not that two ids did.
        registreret_tekst = self.db.execute(
            select(Adresse.adresse_tekst).where(Adresse.adresse_id == registreret)
        ).scalars().first()

        raise HTTPException(
            status_code=422,
            detail=(
                f"'{adresse_tekst}' resolved to an address the child is not "
                f"registered at. The submission states the folkeregisteradresse, "
                f"but Elev holds '{registreret_tekst or registreret}'."
            ),
        )


    def _break_tie(self, hits: list[str], payload: dict, cpr: str) -> list[str]:
        """Narrow an ambiguous match using the child's registered address.

        Args:
            hits:
                Two or more adresse_ids that the submitted address matched.

            payload:
                Parsed OS2Forms submission data.

            cpr:
                The child's CPR.

        Returns:
            A single-element list where the register settles it, otherwise
            hits unchanged so the caller refuses.

        Notes:
            This is a tie-break, not a verification, and the distinction is
            the whole design. It only ever CHOOSES BETWEEN rows the address
            already matched; it can never introduce a row, override a match,
            or reject one.

            A verification — demanding that the resolved address equal the
            child's registered one — would be wrong, because the two
            legitimately differ:

            - The family moved. The form carries the new address and the
              nightly sync has not caught up, or the reverse. Applying for
              transport is exactly what a family does after moving, so this
              is a routine case, not a suspicious one.
            - The Elev row does not exist yet, which is normal for a first
              application.
            - The family asked to be driven from somewhere else entirely,
              which is checked below.

            Each of those would turn into a stopped queue item on a perfectly
            good submission. As a tie-break none of them costs anything: a
            stale or absent registered address simply fails to appear among
            the hits, and the caller refuses exactly as it would have.

            Why it is sound where it does fire: Elev.adresse_id comes from the
            nightly LOIS/CPR sync, and so does the MitID address on the form.
            When the register says this child lives at one of the rows under
            consideration, that is not an inference about which row is
            likelier — it is the authoritative answer to the question being
            asked.
        """

        # The family asked to be driven from a different address, so the
        # registered one is a DIFFERENT place by design and says nothing about
        # which candidate is right. Using it here would actively mislead.
        if os2forms_mapping.is_alternate_address(payload):
            return hits

        folkeregister = self._folkeregister_adresse_id(cpr)

        if folkeregister is None or folkeregister not in hits:
            return hits

        return [folkeregister]


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


    def _find_bevilling_by_os2forms_id(self, os2forms_id: str | None) -> int | None:
        """The bevilling already created from this submission, if any.

        Args:
            os2forms_id:
                The OS2Forms submission id, or None when the caller did not
                send one.

        Returns:
            The existing bevilling_id, or None.

        Notes:
            None in means None out: a submission that carries no id cannot be
            recognised on a second delivery, so it is created. That is the old
            behaviour, kept deliberately rather than refusing the request —
            the live OS2Forms remote post handler does not send the id yet,
            and refusing would stop applications reaching caseworkers.

            Soft-deleted bevillinger count. A caseworker who deleted one has
            decided it should not exist; recreating it on the next delivery
            would undo that silently.
        """

        if not os2forms_id:
            return None

        return self.db.execute(
            select(Bevilling.bevilling_id).where(
                Bevilling.os2forms_id == os2forms_id
            )
        ).scalars().first()


    def map_submission_to_bevilling(self, payload: dict, cpr: str) -> BevillingCreateRequest:
        """Map an OS2Forms payload to a BevillingCreateRequest.

        Args:
            payload:
                Parsed OS2Forms submission data.

            cpr:
                The child's CPR. Needed to resolve the address: where the
                submitted one is ambiguous, the child's registered address
                settles it. See _break_tie.

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
            adresse_id=self._resolve_adresse_id(payload, cpr),
            matrikel_id=school["matrikel_id"],
            ungdomsuddannelse_id=school["ungdomsuddannelse_id"],
            ansoegningsdato=date_utils.parse_os2forms_timestamp(payload.get("completed")),
            relation_til_barnet=os2forms_mapping.get_relation_til_barnet(payload),
            foerste_koersel_dato=payload.get("dato_for_foerste_koersel"),
            ansoegningstype=os2forms_mapping.get_ansoegningstype(payload),
            begrundelse_fra_formular=os2forms_mapping.get_begrundelse(payload),
            hjaelpemiddel_ids=self._resolve_hjaelpemiddel_ids(hjaelpemiddel_names),
            os2forms_id=os2forms_mapping.get_os2forms_id(payload),
            # Serialised here rather than in the mapper, so the mapper stays
            # testable as plain data. ensure_ascii=False keeps "Rutekørsel"
            # readable in the column instead of \u00f8-escaped.
            ansoegningsdata=(
                json.dumps(ansoegningsdata, ensure_ascii=False)
                if (ansoegningsdata := os2forms_mapping.get_ansoegningsdata(payload))
                else None
            ),
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
        bevilling_request = self.map_submission_to_bevilling(payload, cpr)

        # One bevilling per submission. Without this, every retry makes another
        # one for the same family: a manually re-driven journalization, two
        # overlapping reconciler runs, or OS2Forms simply delivering twice.
        #
        # Answered before anything is written, so a repeat call is a no-op
        # rather than a half-applied one — create_elev below is get-or-create
        # and harmless, but the bevilling is not.
        eksisterende = self._find_bevilling_by_os2forms_id(bevilling_request.os2forms_id)

        if eksisterende is not None:
            return {
                "status": "already_exists",
                "cpr": cpr,
                "result": {"bevilling_id": eksisterende},
            }

        # Ensure an Elev row exists for this CPR before creating the bevilling.
        #
        # The child list in the OS2Forms formular comes from the MitID registry,
        # which is external to this application — so ANY submission (child picked
        # from the list OR entered manually) may reference a CPR that has no Elev
        # row here, and the Bevilling.cpr_elev → Elev.cpr foreign key would fail.
        # create_elev is get-or-create, so it is a no-op when the Elev exists.
        CitizenService(db=self.db).create_elev(
            {
                "cpr": cpr,
                "adresseringsnavn": os2forms_mapping.get_barn_navn(payload),
                "adresse_id": bevilling_request.adresse_id,
            }
        )

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
