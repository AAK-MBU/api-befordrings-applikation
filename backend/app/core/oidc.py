"""OIDC configuration singleton.

Builds one OIDCConfig from environment variables (via Settings) and exposes
it as a module-level singleton so the router and dependencies can import it
without re-reading the environment on every request.
"""

from oidc_auth import OIDCConfig

from app.core.config import settings

# OIDC_DISCOVERY_URL must use Azure B2C's path-based /tfp/ form:
#
#   https://<tenant>.b2clogin.com/tfp/<tenant>.onmicrosoft.com/<policy>/v2.0/
#       .well-known/openid-configuration
#
# NOT the ?p=<policy> query form. Both describe the same policy and return the
# same issuer, but the ?p= document advertises endpoints that already carry a
# query string, and oidc-auth builds the login URL as
# f"{authorization_endpoint}?{urlencode(params)}" — appending a second "?".
# B2C then reads the policy name as "<policy>?response_type=code", fails to
# resolve it, and answers 404 before it ever looks at our parameters.
#
# The /tfp/ document puts the policy in the path, so the endpoints have no
# query of their own and that concatenation stays well-formed.
oidc_config = OIDCConfig(
    issuer=settings.oidc_issuer,
    client_id=settings.oidc_client_id,
    client_secret=settings.oidc_client_secret,
    redirect_uri=settings.oidc_redirect_uri,
    discovery_url_override=settings.oidc_discovery_url,
    scopes=tuple(settings.oidc_scopes.split()),
    environment=settings.oidc_environment,
)
