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
    db_connection_string_dev: str = os.getenv("DBCONNECTIONSTRINGBEFORDRINGDEV", "")
    db_connection_string_prod: str = os.getenv("DBCONNECTIONSTRINGBEFORDRINGPROD", "")

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
