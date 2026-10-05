"""Daily expiry of OIDC sessions.

The application previously kept a user logged in for a fortnight: the session
is a signed cookie with Starlette's default max_age of 14 days, and
get_current_user never checked the ID token's own exp. Once someone had logged
in, nothing asked them again.

GDPR-wise the requirement is that a user is treated as new at least once a day.
This enforces that server side.

WHY A FIXED TIME OF DAY, NOT A ROLLING MAX AGE:
A rolling "expires N hours after login" fires whenever the clock happens to
reach it — which for a caseworker halfway through a bevilling is precisely the
worst moment. A fixed nightly boundary expires every session at an hour nobody
is working, so in practice people log in once in the morning and are not
interrupted again that day.

WHY NOT DELETE SESSIONS SERVER SIDE:
There is nothing to delete. SessionMiddleware stores the claims in the cookie
itself, signed with SESSION_SECRET; the server holds no session table. The only
wholesale invalidation available is rotating that secret, which would also log
everyone out on any deploy that changed it.
"""

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

# Local time, because the point is "overnight for the people using it", not
# an offset from UTC that drifts an hour twice a year.
TIDSZONE = ZoneInfo("Europe/Copenhagen")

# 01:00 is safe to hardcode against DST: Denmark's transitions happen at 02:00
# and 03:00 local, so 01:00 exists exactly once on every calendar day. An
# hour like 02:00 or 02:30 would be skipped one night a year and ambiguous
# another, and the comparison below would silently do the wrong thing.
UDLOEB_TIME = 1


def udloebstidspunkt(login: datetime) -> datetime:
    """The moment a session begun at `login` stops being valid.

    Args:
        login:
            When the user authenticated, timezone-aware.

    Returns:
        The first UDLOEB_TIME o'clock strictly after `login`, in local time.

    Notes:
        Strictly after: a session begun exactly at 01:00 runs to 01:00 the
        NEXT day rather than expiring the instant it was created.
    """

    lokal = login.astimezone(TIDSZONE)
    graense = lokal.replace(hour=UDLOEB_TIME, minute=0, second=0, microsecond=0)

    if graense <= lokal:
        graense += timedelta(days=1)

    return graense


def er_udloebet(iat: int | float | None, nu: datetime | None = None) -> bool:
    """Whether a session issued at `iat` has passed its nightly boundary.

    Args:
        iat:
            The ID token's issued-at claim, Unix seconds. This is the login
            time: oidc_auth stores the claims when the callback completes, and
            _claims_from_session preserves iat.

        nu:
            Override for testing.

    Returns:
        True when the session should be refused.

    Notes:
        A missing or unreadable iat answers True — FAIL CLOSED. A session we
        cannot date is one we cannot prove is fresh, and the cost of being
        wrong is a login prompt rather than a stale session living on.
    """

    if iat is None:
        return True

    try:
        login = datetime.fromtimestamp(float(iat), tz=TIDSZONE)
    except (TypeError, ValueError, OverflowError, OSError):
        return True

    return (nu or datetime.now(TIDSZONE)) >= udloebstidspunkt(login)
