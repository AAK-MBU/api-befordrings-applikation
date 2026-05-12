"""Main FastAPI application entrypoint.

This module creates and configures the FastAPI application.

It is responsible for:

- Creating the app instance
- Setting API metadata for Swagger/OpenAPI
- Configuring CORS
- Registering the API routers
- Exposing basic root and health-check endpoints
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.api import api_router


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
