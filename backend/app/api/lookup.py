"""API routes for lookup data used by the befordring frontend.

This module exposes read-only endpoints for dropdown/select options.
Each endpoint returns a list of dictionaries with the same shape:

[
    {
        "id": 1,
        "label": "Some display value"
    }
]

The frontend uses these values when editing or creating bevillinger and
koerselsraekker.
"""

from fastapi import APIRouter

from app.services.lookup_service import LookupService


router = APIRouter(prefix="/lookup", tags=["lookup"])


@router.get("/hjemler")
def get_hjemler():
    """Return active hjemmel options.

    Used when selecting the legal basis/home authority for a bevilling.

    Returns
    -------
    list[dict]
        A list of active hjemler formatted as:

        [
            {
                "id": hjemmel_id,
                "label": hjemmel_tekst
            }
        ]
    """

    service = LookupService()

    return service.get_hjemler()


@router.get("/afgoerelsesbreve")
def get_afgoerelsesbreve():
    """Return active afgørelsesbrev options.

    Used when selecting which decision-letter template belongs to a
    bevilling.

    Returns
    -------
    list[dict]
        A list of active afgørelsesbreve formatted as:

        [
            {
                "id": afgoerelsesbrev_id,
                "label": afgoerelsesbrev_tekst
            }
        ]
    """

    service = LookupService()

    return service.get_afgoerelsesbreve()


@router.get("/sagsbehandlere")
def get_sagsbehandlere():
    """Return active sagsbehandler options.

    Used when assigning a caseworker to a bevilling.

    Returns
    -------
    list[dict]
        A list of active sagsbehandlere formatted as:

        [
            {
                "id": sagsbehandler_id,
                "label": sagsbehandler_tekst
            }
        ]
    """

    service = LookupService()

    return service.get_sagsbehandlere()


@router.get("/ppr_sagsbehandlere")
def get_ppr_sagsbehandlere():
    """Return active PPR sagsbehandler options.

    Used when assigning a PPR responsible caseworker to a bevilling.

    Returns
    -------
    list[dict]
        A list of active PPR sagsbehandlere formatted as:

        [
            {
                "id": ppr_sagsbehandler_id,
                "label": ppr_sagsbehandler_tekst
            }
        ]
    """

    service = LookupService()

    return service.get_ppr_sagsbehandlere()


@router.get("/status")
def get_status():
    """Return active status options.

    Used by bevillinger and internally by koerselsraekker.

    Returns
    -------
    list[dict]
        A list of active statuses formatted as:

        [
            {
                "id": status_id,
                "label": status_tekst
            }
        ]
    """

    service = LookupService()

    return service.get_status()


@router.get("/skolematrikel")
def get_skolematrikel():
    """Return skolematrikel options.

    Used when selecting the school/matrikel connected to a bevilling.

    Returns
    -------
    list[dict]
        A list of skolematrikler formatted as:

        [
            {
                "id": matrikel_id,
                "label": matrikel_navn
            }
        ]
    """

    service = LookupService()

    return service.get_skolematrikel()


@router.get("/hjaelpemidler")
def get_hjaelpemidler():
    """Return active hjælpemiddel options.

    Used when attaching one or more hjælpemidler to a bevilling.

    Returns
    -------
    list[dict]
        A list of active hjælpemidler formatted as:

        [
            {
                "id": hjaelpemiddel_id,
                "label": hjaelpemiddel_tekst
            }
        ]
    """

    service = LookupService()

    return service.get_hjaelpemidler()


@router.get("/tidspunkter")
def get_tidspunkter():
    """Return active tidspunkt options.

    Used when selecting when a kørselsrække applies, for example morning,
    afternoon, or both.

    Returns
    -------
    list[dict]
        A list of active tidspunkter formatted as:

        [
            {
                "id": tidspunkt_id,
                "label": tidspunkt_tekst
            }
        ]
    """

    service = LookupService()

    return service.get_tidspunkter()


@router.get("/koerselstyper")
def get_koerselstyper():
    """Return active kørselstype options.

    Used when selecting the transport type for a kørselsrække.

    Returns
    -------
    list[dict]
        A list of active kørselstyper formatted as:

        [
            {
                "id": befordringstype_id,
                "label": befordringstype_tekst
            }
        ]
    """

    service = LookupService()

    return service.get_koerselstyper()


@router.get("/koerselstype_tillaeg")
def get_koerselstype_tillaeg():
    """Return active kørselstype-tillæg options.

    Used when attaching one or more tillæg to a kørselsrække.

    Returns
    -------
    list[dict]
        A list of active tillæg formatted as:

        [
            {
                "id": tillaeg_id,
                "label": tillaeg_tekst
            }
        ]
    """

    service = LookupService()

    return service.get_koerselstype_tillaeg()


@router.get("/dage")
def get_dage():
    """Return active weekday options.

    Used when attaching one or more weekdays to a kørselsrække.

    Returns
    -------
    list[dict]
        A list of active weekdays formatted as:

        [
            {
                "id": dag_id,
                "label": dag_tekst
            }
        ]
    """

    service = LookupService()

    return service.get_dage()
