"""Application settings.

This module loads environment variables and exposes them through one shared
settings object.

The purpose is to keep configuration values in one place instead of reading
os.getenv(...) directly throughout the application.
"""

import os

from dotenv import load_dotenv

# Load variables from a local .env file into the environment.
#
# This is mainly useful during local development.
# In production, these values may instead come from Docker, Azure, GitHub
# Actions, or another environment/configuration system.
load_dotenv()


class Settings:
    """Application configuration values.

    Each class attribute reads a value from the environment.

    If the environment variable is missing, an empty string is used as the
    default value.
    """

    # Main database connection string used by the application.
    db_connection_string: str = os.getenv("DBCONNECTIONSTRINGBEFORDRING", "")

    # Optional/secondary LIS database connection string.
    lis_db_connection_string: str = os.getenv("DBCONNECTIONSTRINGSERVER29", "")

    # Comma-separated or otherwise encoded API key hashes used for API auth.
    api_key_hashes: str = os.getenv("API_KEY_HASHES", "")

    # OpenID Connect settings.
    oidc_issuer: str = os.getenv("OIDC_ISSUER", "")
    oidc_client_id: str = os.getenv("OIDC_CLIENT_ID", "")
    oidc_client_secret: str = os.getenv("OIDC_CLIENT_SECRET", "")
    oidc_redirect_uri: str = os.getenv(
        "OIDC_REDIRECT_URI", "http://localhost:8000/auth/callback"
    )
    oidc_discovery_url: str | None = os.getenv("OIDC_DISCOVERY_URL") or None
    oidc_scopes: str = os.getenv("OIDC_SCOPES", "openid")
    oidc_environment: str = os.getenv("OIDC_ENVIRONMENT", "production")
    # Where the IdP returns the browser after ending the session. Azure B2C
    # rejects a logout that omits it ("AADB2C90036: The request does not contain
    # a URI to redirect the user to post logout"), so leaving this unset turns
    # every logout into an error page. It does *not* have to be a registered
    # reply URL — B2C validates redirect_uri but not this.
    oidc_post_logout_redirect: str | None = (
        os.getenv("OIDC_POST_LOGOUT_REDIRECT") or None
    )
    # Comma-separated IdP role claim values that may write. Configurable
    # because the values are provisioned in Systemregisteret, so they can be
    # renamed there without a code change. Roles that are not listed can read.
    # `or`, not a getenv default: an env var set to "" would otherwise leave
    # the set empty and lock every user out of writing.
    edit_roles: str = os.getenv("EDIT_ROLES") or "admin,user-edit"

    # Roles permitted to perform PPR's own actions on a bevilling: setting the
    # PPR-sagsbehandler, and ticking "PPR vurderet" on the revurdering page.
    # Deliberately wider than edit_roles, because PPR Medarbejder holds
    # "user-read" and that grants no other write — yet distributing cases among
    # themselves and signing off their own vurdering is their actual job.
    #
    # It buys those fields and nothing else: each one has its own endpoint that
    # writes only itself. See require_ppr and the endpoints it guards. Same `or`
    # pattern as above, for the same reason.
    ppr_roles: str = os.getenv("PPR_ROLES") or "admin,user-edit,user-read"

    # Secret used to sign the Starlette session cookie.
    session_secret: str = os.getenv("SESSION_SECRET", "dev-only-change-in-prod")

    # OpenRouteService API token, used for walking and driving distances.
    #
    # No default: an empty token means every distance request fails, and it
    # must fail loudly at the call rather than silently being sent as an
    # empty Authorization header. See app/utils/distance.py.
    ors_api_key: str = os.getenv("ORS_API_KEY", "")


# Shared settings instance used throughout the application.
#
# Other files can import this:
#
# from app.core.config import settings
#
# And then access:
#
# settings.db_connection_string
settings = Settings()
