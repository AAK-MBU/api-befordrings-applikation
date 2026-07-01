"""Shared FastAPI dependencies.

This module contains reusable dependency aliases used across the API.

The main purpose is to avoid repeating dependency injection setup in every
endpoint function.

Instead of writing this in every route:

    db: Session = Depends(get_db)

we can write:

    db: DbSession

This keeps endpoint signatures cleaner and makes the code easier to update.
"""

import hmac
from typing import Annotated

from fastapi import Depends, HTTPException, Request, Security, status
from sqlalchemy.orm import Session

from oidc_auth.integrations import get_current_user

from app.core.database import get_db
from app.core.security import api_key_header, get_valid_api_key_hashes, hash_api_key


# Reusable database session dependency.
#
# Annotated combines two things:
#
# 1. The actual Python type:
#    Session
#
# 2. The FastAPI dependency:
#    Depends(get_db)
#
# So when an endpoint uses:
#
#     db: DbSession
#
# FastAPI understands that it should:
#
# - call get_db()
# - inject the returned database session
# - treat db as a SQLAlchemy Session
DbSession = Annotated[Session, Depends(get_db)]


def require_auth(
    request: Request,
    api_key: Annotated[str | None, Security(api_key_header)] = None,
):
    """Dual-auth dependency: accepts a valid API key OR an active OIDC session.

    Routes that serve both human users (browser/OIDC) and automated callers
    (RPA bots/API key) should use this dependency instead of verify_api_key.

    Resolution order:
      1. If the X-API-Key header is present, validate it and return immediately.
         An invalid key raises 403 rather than falling through to OIDC.
      2. If no API key header is present, delegate to get_current_user which
         reads the OIDC session cookie and raises 401 if there is no session.
    """
    if api_key is not None:
        incoming_hash = hash_api_key(api_key)
        for valid in get_valid_api_key_hashes():
            if hmac.compare_digest(incoming_hash, valid):
                return {"auth_type": "api_key"}
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid API key",
        )
    return get_current_user(request)
