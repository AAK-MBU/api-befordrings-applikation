"""API router for lookup-related endpoints.

This module contains simple read-only endpoints for lookup/reference data.

Lookup data is typically used by the frontend to populate dropdowns, select
fields, filters, and other UI options.

Examples:
- Hjemler
- Status values
- Sagsbehandlere
- Skolematrikler
- Hjaelpemidler
- Koerselstyper
- Dage

The router should stay very thin. The actual database queries should live in
LookupService.
"""

from fastapi import APIRouter

from app.api.dependencies import DbSession
from app.services.lookup_service import LookupService


# All routes in this file are grouped under /lookup.
# The tag is used by Swagger/OpenAPI to group these endpoints visually.
router = APIRouter(prefix="/lookup", tags=["Lookup"])


@router.get("/hjemler")
def get_hjemler(db: DbSession):
    """Get available hjemler.

    Returns:
        A list of hjemler used when creating or updating bevillinger.
    """

    service = LookupService(db=db)

    return service.get_hjemler()


@router.get("/afgoerelsesbreve")
def get_afgoerelsesbreve(db: DbSession):
    """Get available afgørelsesbreve.

    Returns:
        A list of letter/decision templates or afgørelsesbrev options.
    """

    service = LookupService(db=db)

    return service.get_afgoerelsesbreve()


@router.get("/sagsbehandlere")
def get_sagsbehandlere(db: DbSession):
    """Get available sagsbehandlere.

    Returns:
        A list of case workers used by the frontend as lookup options.
    """

    service = LookupService(db=db)

    return service.get_sagsbehandlere()


@router.get("/ppr_sagsbehandlere")
def get_ppr_sagsbehandlere(db: DbSession):
    """Get available PPR sagsbehandlere.

    Returns:
        A list of PPR case workers used by the frontend as lookup options.
    """

    service = LookupService(db=db)

    return service.get_ppr_sagsbehandlere()


@router.get("/status")
def get_status(db: DbSession):
    """Get available status values.

    Returns:
        A list of statuses used for bevillinger.
    """

    service = LookupService(db=db)

    return service.get_status()


@router.get("/skolematrikel")
def get_skolematrikel(db: DbSession):
    """Get available skolematrikler.

    Returns:
        A list of school locations/matrikler used by the frontend.
    """

    service = LookupService(db=db)

    return service.get_skolematrikel()


@router.get("/hjaelpemidler")
def get_hjaelpemidler(db: DbSession):
    """Get available hjælpemidler.

    Returns:
        A list of hjælpemidler that can be attached to a bevilling.
    """

    service = LookupService(db=db)

    return service.get_hjaelpemidler()


@router.get("/tidspunkter")
def get_tidspunkter(db: DbSession):
    """Get available time options.

    Returns:
        A list of tidspunkter used by transport rows or related forms.
    """

    service = LookupService(db=db)

    return service.get_tidspunkter()


@router.get("/koerselstyper")
def get_koerselstyper(db: DbSession):
    """Get available kørselstyper.

    Returns:
        A list of transport types used when creating or updating kørselsrækker.
    """

    service = LookupService(db=db)

    return service.get_koerselstyper()


@router.get("/koerselstype_tillaeg")
def get_koerselstype_tillaeg(db: DbSession):
    """Get available kørselstype tillæg.

    Returns:
        A list of additions/tillæg that can be connected to a kørselsrække.
    """

    service = LookupService(db=db)

    return service.get_koerselstype_tillaeg()


@router.get("/dage")
def get_dage(db: DbSession):
    """Get available weekdays/days.

    Returns:
        A list of days that can be connected to a kørselsrække.
    """

    service = LookupService(db=db)

    return service.get_dage()
