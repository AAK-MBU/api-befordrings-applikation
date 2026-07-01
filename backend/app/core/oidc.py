"""OIDC configuration singleton.

Builds one OIDCConfig from environment variables (via Settings) and exposes
it as a module-level singleton so the router and dependencies can import it
without re-reading the environment on every request.
"""

from oidc_auth import OIDCConfig

from app.core.config import settings

oidc_config = OIDCConfig(
    issuer=settings.oidc_issuer,
    client_id=settings.oidc_client_id,
    client_secret=settings.oidc_client_secret,
    redirect_uri=settings.oidc_redirect_uri,
    discovery_url_override=settings.oidc_discovery_url,
    scopes=tuple(settings.oidc_scopes.split()),
    environment=settings.oidc_environment,
)
