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


def get_udfoert_af(
    principal: Annotated[object, Depends(require_auth)],
) -> str:
    """Resolve a display name for audit attribution (Sagsaktivitet.udfoert_af).

    Reuses require_auth so the dual API-key/OIDC resolution is not duplicated:
      - API-key callers (RPA bots) have no human identity and are attributed
        to "System".
      - Human OIDC sessions are attributed to their display name, falling back
        to email and then subject.

    The result is truncated to 100 chars to match the udfoert_af column width.
    """
    if isinstance(principal, dict):
        # API-key auth (e.g. RPA) — no human identity available.
        return "System"

    # principal is an oidc_auth IDTokenClaims object.
    name = (
        getattr(principal, "name", None)
        or getattr(principal, "email", None)
        or getattr(principal, "sub", None)
    )

    return (name or "Ukendt")[:100]


# Reusable dependency that yields the display name of the current caller,
# used for audit attribution on write endpoints (Sagsaktivitet.udfoert_af).
CurrentUser = Annotated[str, Depends(get_udfoert_af)]


def user_can_delete(principal: Annotated[object, Depends(require_auth)]) -> bool:
    """Check whether the current user is allowed to soft-delete records.

    TODO: Replace the stub below with a real group/role check once the OIDC
    group claims are available.  Example (Azure AD):
        groups = getattr(principal, "groups", []) or []
        return "befordring-admin" in groups

    Until then, all authenticated users can delete.
    """
    return True


CanDelete = Annotated[bool, Depends(user_can_delete)]
