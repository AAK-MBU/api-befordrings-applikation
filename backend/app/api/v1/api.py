"""Main API router for version 1 endpoints.

This module collects all endpoint routers for API v1 and registers them under
one shared APIRouter.

It also applies shared dependencies, such as API key validation, to protected
routers.

The routers included here are:

- overview
- citizen
- bevilling
- lookup

By centralizing router registration here, main.py only needs to include this
single api_router instead of importing every endpoint router individually.
"""

from fastapi import APIRouter, Depends

from app.api.dependencies import require_auth
from app.api.v1.endpoints import adresse, aktivitet, bevilling, citizen, lookup, overview, os2forms
from app.core.security import verify_api_key


# Main router for all API v1 endpoints.
#
# This router is usually included in main.py with something like:
#
# app.include_router(api_router, prefix="/api/v1")
api_router = APIRouter()


# Human-facing routes accept either a valid API key (X-API-Key header) or an
# active OIDC browser session.  RPA bots and integration partners continue to
# use API keys; human users logging in via the browser use OIDC.
human_dependencies = [Depends(require_auth)]

# Automated / webhook routes keep the original API-key-only requirement.
# os2forms submissions come from an external system with no browser session.
rpa_dependencies = [Depends(verify_api_key)]


# Register overview routes.
api_router.include_router(
    overview.router,
    dependencies=human_dependencies,
)


# Register citizen routes.
#
# citizen/stamdata is read by the human-facing case page.
# citizen/create_elev is called by the RPA conversion bot.
# Both are covered by human_dependencies: the RPA bot sends an API key, the
# browser uses the OIDC session — require_auth handles both.
api_router.include_router(
    citizen.router,
    dependencies=human_dependencies,
)


# Register bevilling routes.
api_router.include_router(
    bevilling.router,
    dependencies=human_dependencies,
)


# Register lookup routes.
api_router.include_router(
    lookup.router,
    dependencies=human_dependencies,
)


# Register os2forms routes.
#
# OS2Forms submissions arrive from an external system; they always authenticate
# with an API key and never hold a browser session.
api_router.include_router(
    os2forms.router,
    dependencies=rpa_dependencies,
)


# Register adresse routes.
api_router.include_router(
    adresse.router,
    dependencies=human_dependencies,
)


# Register aktivitet routes.
api_router.include_router(
    aktivitet.router,
    dependencies=human_dependencies,
)
