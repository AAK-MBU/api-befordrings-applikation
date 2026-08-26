"""Main FastAPI application entrypoint.

This module creates and configures the FastAPI application.

It is responsible for:

- Creating the app instance
- Setting API metadata for Swagger/OpenAPI
- Configuring CORS
- Registering the API routers
- Exposing basic root and health-check endpoints
"""

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.sessions import SessionMiddleware

from oidc_auth import IDTokenClaims
from oidc_auth.integrations import create_oidc_router, get_current_user

from app.api.v1.api import api_router
from app.core.config import settings
from app.core.oidc import oidc_config


class UTF8JSONResponse(JSONResponse):
    """JSON response class with explicit UTF-8 charset.

    Notes:
        This makes API responses explicitly declare UTF-8 encoding.

        That is useful when returning Danish characters such as æ, ø and å.
    """

    media_type = "application/json; charset=utf-8"


# Create the FastAPI application.
#
# The metadata below is shown in Swagger/OpenAPI docs.
app = FastAPI(
    title="Befordrings applikation",
    description="API for Befordrings applikation",
    version="1.0.0",
    default_response_class=UTF8JSONResponse,
    root_path="/api"
)


# Session middleware must be added before CORS so that it ends up as the inner
# layer of the middleware stack.  The session cookie carries OIDC state between
# the /auth/login redirect and the /auth/callback return.
# same_site="lax" is required for the IdP redirect to send the cookie back.
app.add_middleware(
    SessionMiddleware,
    secret_key=settings.session_secret,
    same_site="lax",
)

# Configure CORS.
#
# CORS controls which frontend origins are allowed to call the API from a
# browser.
#
# allow_origins=["*"] means all origins are allowed.
# This is convenient during development, but should usually be restricted in
# production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Register OIDC login / callback / logout routes.
#
# create_oidc_router already applies the /auth prefix internally, so routes
# are mounted at /auth/login, /auth/callback and /auth/logout.
#
# OIDC_REDIRECT_URI points at the *frontend's* /callback, not at the
# /auth/callback below. The frontend owns the return leg so it can restore the
# page the user originally asked for, then forwards the code here.
app.include_router(
    create_oidc_router(
        oidc_config,
        post_logout_redirect=settings.oidc_post_logout_redirect,
    )
)

# Register all API v1 routers.
#
# The api_router includes endpoint routers such as:
# - overview
# - citizen
# - bevilling
# - lookup
app.include_router(api_router)


@app.get("/")
def root():
    """Root endpoint.

    Returns:
        A simple message confirming that the API is running.

    Notes:
        This is useful for quickly checking the API in a browser.
    """

    return {"message": "Befordrings Application API is running"}


@app.get("/me", tags=["auth"])
def me(user: IDTokenClaims = Depends(get_current_user)) -> dict:
    """Return the OIDC claims for the currently logged-in user.

    Raises 401 if there is no active OIDC session.
    """
    return {
        "sub": user.sub,
        "name": user.name,
        "email": user.email,
        "roles": list(user.roles),
        "groups": list(user.groups),
        "organisation": user.organisation,
        "mapped_claims": user.mapped_claims,
        # The whole validated ID token payload. The curated fields above cover
        # the common cases; this is what to read when an expected claim is
        # missing from them because the IdP names it something else.
        "raw": user.raw,
    }


@app.get("/health", tags=["health"])
async def health_check():
    """Health-check endpoint.

    Returns:
        A simple status response.

    Notes:
        This endpoint can be used by Docker, monitoring tools, load balancers,
        or deployment systems to check whether the API is alive.
    """

    return {"status": "ok"}
