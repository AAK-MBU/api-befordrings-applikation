"""API key security helpers.

This module contains the logic used to protect API endpoints with an API key.

The expected flow is:

1. The client sends an API key in the HTTP header:

       X-API-Key: <plain-api-key>

2. The API hashes the incoming key with SHA-256.

3. The hashed incoming key is compared against the allowed hashes stored in
   the API_KEY_HASHES environment variable.

4. If a matching hash is found, the request is allowed.

5. If no matching hash is found, the request is rejected.

Important:
    The plain API keys are never stored in the application settings.
    Only hashed API keys should be stored in the environment variable.
"""

import hashlib
import hmac
import os

from typing import Annotated

from fastapi import HTTPException, Security, status
from fastapi.security import APIKeyHeader


# Defines where FastAPI should look for the API key.
#
# In this case, clients must send the key as an HTTP header:
#
#     X-API-Key: your-api-key-here
#
# auto_error=False means FastAPI will not automatically reject the request if
# the header is missing. Instead, we handle that manually in verify_api_key().
api_key_header = APIKeyHeader(
    name="X-API-Key",
    auto_error=False,
)


def hash_api_key(api_key: str) -> str:
    """Hash a plain-text API key using SHA-256.

    Args:
        api_key:
            The plain API key received from the client.

    Returns:
        The SHA-256 hash of the API key as a hexadecimal string.

    Notes:
        This allows us to compare hashed values instead of storing or comparing
        plain-text API keys.
    """

    return hashlib.sha256(api_key.encode("utf-8")).hexdigest()


def get_valid_api_key_hashes() -> list[str]:
    """Get valid API key hashes from the environment.

    The API_KEY_HASHES environment variable is expected to contain one or more
    SHA-256 hashes.

    Multiple hashes can be separated by commas.

    Example:
        API_KEY_HASHES=hash1,hash2,hash3

    Returns:
        A cleaned list of valid API key hashes.

    Notes:
        Empty values are ignored. This makes the function more tolerant of
        extra commas or whitespace in the environment variable.
    """

    raw_hashes = os.getenv("API_KEY_HASHES", "")

    return [
        api_key_hash.strip()
        for api_key_hash in raw_hashes.split(",")
        if api_key_hash.strip()
    ]


async def verify_api_key(
    api_key: Annotated[str | None, Security(api_key_header)],
) -> None:
    """Validate the API key from the request header.

    This function is used as a FastAPI dependency.

    Args:
        api_key:
            The API key extracted from the X-API-Key request header.

            If the header is missing, this value will be None because
            api_key_header uses auto_error=False.

    Returns:
        None if the API key is valid.

    Raises:
        HTTPException:
            401 Unauthorized if the API key header is missing.

            403 Forbidden if the API key is present but invalid.

    Notes:
        This function does not return user data or a token.
        It only allows or blocks access to protected routes.

        hmac.compare_digest is used instead of normal == comparison because it
        is safer for comparing secrets. It helps avoid timing-based attacks.
    """

    # No API key was provided in the X-API-Key header.
    #
    # This means the request is not authenticated at all.
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing API key",
        )

    # Hash the incoming plain-text API key so it can be compared against the
    # stored hashes from the environment.
    incoming_hash = hash_api_key(api_key)

    # Load all allowed API key hashes from the API_KEY_HASHES environment
    # variable.
    valid_hashes = get_valid_api_key_hashes()

    # Compare the incoming hash with each allowed hash.
    #
    # hmac.compare_digest is preferred for secret comparison because it avoids
    # some timing-leak issues that can happen with normal string comparison.
    for valid_hash in valid_hashes:
        if hmac.compare_digest(incoming_hash, valid_hash):
            return

    # An API key was provided, but it did not match any known valid hash.
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Invalid API key",
    )
