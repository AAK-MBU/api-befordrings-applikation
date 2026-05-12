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
