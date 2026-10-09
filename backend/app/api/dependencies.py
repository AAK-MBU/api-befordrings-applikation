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

from typing import Annotated

from fastapi import Depends, HTTPException, Request, Security, status
from sqlalchemy.orm import Session

from oidc_auth.integrations import get_current_user

from app.core.config import settings
from app.core.database import get_db
from app.core.security import api_key_header, match_api_key
from app.core.session_udloeb import er_udloebet
from app.utils.identitet import visningsnavn


# Reusable database session dependency.
DbSession = Annotated[Session, Depends(get_db)]


def aktiv_session(request: Request):
    """The current user's claims, refused once the session has passed 01:00.

    Args:
        request:
            The incoming request, carrying the session cookie.

    Returns:
        The OIDC claims.

    Raises:
        HTTPException:
            401 where there is no session, or where it began before the last
            nightly boundary.

    Notes:
        Wraps get_current_user rather than replacing it, so the library keeps
        owning how claims are read and this only adds the age check.

        Used by require_auth AND by GET /me. Both, deliberately: the frontend
        decides whether someone is logged in by probing /me, so a check only in
        require_auth would leave the UI showing an authenticated user while
        every API call behind it answered 401.

        API-key callers never reach this — require_auth returns before it — and
        must not: the RPAs hold no session and have nothing to re-authenticate
        with.
    """

    claims = get_current_user(request)

    if er_udloebet(getattr(claims, "iat", None)):
        # Same 401 as "no session at all", so the frontend's existing redirect
        # to login handles it without a second code path. Logging in writes a
        # fresh cookie over the stale one.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="session expired",
        )

    return claims


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

    On an API-key match the key's name is stamped onto request.state, which is
    where the audit middleware reads it from — it runs outside the dependency
    system and has no other way to tell one automated caller from another.
    """
    if api_key is not None:
        key_name = match_api_key(api_key)

        if key_name is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid API key",
            )

        request.state.api_key_name = key_name

        return {"auth_type": "api_key", "api_key_name": key_name}

    return aktiv_session(request)


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
    #
    # visningsnavn rather than principal.name: the prod IdP (Entra) carries no
    # "name" claim at all and spells it "displayname" instead, so reading only
    # "name" attributed every prod action to an email address while dev showed
    # a name. See app/utils/identitet.
    name = (
        visningsnavn(principal)
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


def edit_role_names() -> frozenset[str]:
    """Role claim values permitted to write, lowercased for comparison.

    Claim values arrive from the IdP in whatever case Systemregisteret assigned,
    so both sides of the comparison are normalised.
    """
    return frozenset(
        role.strip().lower()
        for role in settings.edit_roles.split(",")
        if role.strip()
    )


def ppr_role_names() -> frozenset[str]:
    """Role claim values permitted to perform PPR's own actions."""
    return frozenset(
        role.strip().lower()
        for role in settings.ppr_roles.split(",")
        if role.strip()
    )


def require_ppr(principal: Annotated[object, Depends(require_auth)]) -> object:
    """Authorise one of PPR's own actions on a bevilling.

    A separate gate from require_edit because it is deliberately wider. PPR
    Medarbejder is provisioned as "user-read" in Systemregisteret, which grants
    no write at all — yet assigning cases to one another and signing off their
    own vurdering is the work they are there to do. Rather than promote them to
    user-edit, which would hand them every field on the bevilling, its
    kørselsrækker and the delete endpoints, this permits a small fixed set of
    actions, each on an endpoint that writes only its own field.

    Guards:
      PUT /bevilling/{id}/ppr_sagsbehandler
      PUT /bevilling/{id}/revurderet_af_ppr

    Note what is NOT here: revurderet_af_br stays on the general update behind
    require_edit. BR's sign-off is not PPR's to give.

    Automated callers pass through untouched, as in require_edit.
    """
    if isinstance(principal, dict):
        return principal

    roles = {str(role).lower() for role in (getattr(principal, "roles", None) or ())}

    if not roles & ppr_role_names():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Din bruger har ikke rettigheder til PPR-handlinger. "
                "Rettigheder tildeles centralt via Systemregisteret."
            ),
        )

    return principal


def require_edit(principal: Annotated[object, Depends(require_auth)]) -> object:
    """Authorise a write. Reads are open to every role, writes are not.

    Automated callers pass through untouched. An RPA bot authenticates with an
    API key and holds no roles at all, so applying the role check to it would
    lock out the OS2Forms conversion flow and /citizen/create_elev. require_auth
    has already validated that key; a caller holding it is trusted here.

    For a browser session the check is real, and it only works because
    /backend/* forwards the user's session cookie *instead of* the shared API
    key — otherwise require_auth would resolve every browser write as an API-key
    caller and this dependency would silently permit everything.

    Roles are assigned centrally in the IdP, so the 403 says so rather than
    implying there is something to change in this application.
    """
    if isinstance(principal, dict):
        return principal

    roles = {str(role).lower() for role in (getattr(principal, "roles", None) or ())}

    if not roles & edit_role_names():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Din bruger har ikke rettigheder til at ændre data. "
                "Rettigheder tildeles centralt via Systemregisteret."
            ),
        )

    return principal


# Applied per endpoint via the route decorator's `dependencies=` argument, so
# that endpoint signatures stay unchanged:
#
#     @router.put("/{id}", dependencies=[RequireEdit])
RequireEdit = Depends(require_edit)

# Narrow companion to RequireEdit, for PPR's own actions only.
RequirePpr = Depends(require_ppr)
