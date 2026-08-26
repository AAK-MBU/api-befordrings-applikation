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

    # Secret used to sign the Starlette session cookie.
    session_secret: str = os.getenv("SESSION_SECRET", "dev-only-change-in-prod")


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
