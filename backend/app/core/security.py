"""API key security helpers.

This module contains the logic used to protect API endpoints with an API key.

The expected flow is:

1. The client sends an API key in the HTTP header:

       X-API-Key: <plain-api-key>

2. The API hashes the incoming key with SHA-256.

3. The hashed incoming key is compared against the allowed hashes stored in
   the API_KEY_HASHES environment variable.

4. If a matching hash is found, the request is allowed and the key's name is
   recorded on request.state for the audit trail.

5. If no matching hash is found, the request is rejected.

Each comma-separated entry in API_KEY_HASHES is either a bare hash or a
"<name>:<hash>" pair. Naming a key is what lets an audit row say which
automated caller acted, so prefer the named form:

    API_KEY_HASHES=os2forms:<hash>,konverteringsbot:<hash>

Important:
    The plain API keys are never stored in the application settings.
    Only hashed API keys should be stored in the environment variable.
"""

import hashlib
import hmac
import os

from typing import Annotated

from fastapi import HTTPException, Request, Security, status
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


# Separator between an optional key name and its hash in API_KEY_HASHES.
# A SHA-256 hex digest never contains a colon, so splitting on the last one is
# unambiguous and leaves bare-hash entries working exactly as before.
_NAME_SEPARATOR = ":"


# Stand-in name for a key configured without one. Naming keys is what lets an
# audit row say *which* automated caller acted, so this is a nudge rather than
# something to aim for.
UNNAMED_API_KEY = "unnamed-api-key"


def get_api_key_entries() -> list[tuple[str, str]]:
    """Get (name, hash) pairs for every configured API key.

    Two forms are accepted per entry, so configuration written before names
    existed keeps working unchanged:

        <sha256-hash>            -> named UNNAMED_API_KEY
        <name>:<sha256-hash>     -> named <name>

    Example:
        API_KEY_HASHES=os2forms:hash1,konverteringsbot:hash2,hash3

    Returns:
        One (name, hash) pair per entry. Empty values are ignored, which makes
        the parse tolerant of stray commas and whitespace.
    """

    raw_entries = os.getenv("API_KEY_HASHES", "")

    entries: list[tuple[str, str]] = []

    for raw_entry in raw_entries.split(","):
        entry = raw_entry.strip()

        if not entry:
            continue

        name, separator, key_hash = entry.rpartition(_NAME_SEPARATOR)

        if not separator:
            entries.append((UNNAMED_API_KEY, entry))
            continue

        if not key_hash.strip():
            continue

        entries.append((name.strip() or UNNAMED_API_KEY, key_hash.strip()))

    return entries


def match_api_key(api_key: str) -> str | None:
    """Find the name of the configured key matching a presented one.

    Args:
        api_key:
            The plain API key received from the client.

    Returns:
        The matching key's name, or None if no configured key matches.

    Notes:
        hmac.compare_digest is used instead of a normal == comparison because
        it is safer for comparing secrets. It helps avoid timing-based attacks.
    """

    incoming_hash = hash_api_key(api_key)

    for name, valid_hash in get_api_key_entries():
        if hmac.compare_digest(incoming_hash, valid_hash):
            return name

    return None


async def verify_api_key(
    request: Request,
    api_key: Annotated[str | None, Security(api_key_header)],
) -> None:
    """Validate the API key from the request header.

    This function is used as a FastAPI dependency.

    Args:
        request:
            The incoming request. The matched key's name is stamped onto
            request.state so the audit middleware can attribute the call to a
            named automated caller instead of logging it as anonymous.

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
    """

    # No API key was provided in the X-API-Key header.
    #
    # This means the request is not authenticated at all.
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing API key",
        )

    key_name = match_api_key(api_key)

    # An API key was provided, but it did not match any known valid hash.
    if key_name is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid API key",
        )

    request.state.api_key_name = key_name
