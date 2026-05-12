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

from app.api.v1.endpoints import bevilling, citizen, lookup, overview
from app.core.security import verify_api_key


# Main router for all API v1 endpoints.
#
# This router is usually included in main.py with something like:
#
# app.include_router(api_router, prefix="/api/v1")
api_router = APIRouter()


# Shared dependencies for protected API routes.
#
# Depends(verify_api_key) means FastAPI will run verify_api_key before allowing
# access to the routes below.
#
# If the API key is missing or invalid, the request should be rejected before it
# reaches the actual endpoint function.
protected_dependencies = [Depends(verify_api_key)]


# Register overview routes.
#
# These endpoints will require a valid API key because protected_dependencies
# is passed to include_router.
api_router.include_router(
    overview.router,
    dependencies=protected_dependencies,
)


# Register citizen routes.
#
# Final route paths depend on how this api_router is included in main.py.
#
# Example:
# If main.py uses prefix="/api/v1" and citizen.router uses prefix="/citizen",
# the final path becomes:
#
# /api/v1/citizen/...
api_router.include_router(
    citizen.router,
    dependencies=protected_dependencies,
)


# Register bevilling routes.
#
# These endpoints contain most of the bevilling-related functionality such as
# create, update, delete, kørselsrækker, hjælpemidler, and letter creation.
api_router.include_router(
    bevilling.router,
    dependencies=protected_dependencies,
)


# Register lookup routes.
#
# Lookup routes are also protected here, even though they are read-only.
# This keeps all API v1 endpoints behind the same API-key requirement.
api_router.include_router(
    lookup.router,
    dependencies=protected_dependencies,
)
