"""Writing the audit trail to PortalAuditLog.

Called by middleware/audit_middleware.py for the requests it selects, so that
each row in the table corresponds to one HTTP call against the API.
"""

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.audit import PortalAuditLog
from app.schemas.audit import AuditLogCreate


# Column widths from the table definition. Values are cut to fit rather than
# left to overflow: an oversized User-Agent would otherwise fail the INSERT and
# cost us the whole audit row, which is a worse outcome than a truncated one.
_MAX_LENGTHS = {
    "bruger_ident": 200,
    "api_key_name": 200,
    "action": 200,
    "method": 10,
    "path": 500,
    "ip_address": 50,
    "user_agent": 500,
}


def _fit(value: str | None, max_length: int) -> str | None:
    """Cut a value to the column width, leaving None untouched."""
    if value is None:
        return None

    return value[:max_length]


def create_audit_log(db: Session, data: AuditLogCreate) -> None:
    """Add one audit row for a completed HTTP call.

    The row is added with `add` and not flushed: the caller owns the
    transaction and decides when to commit.

    OprettetDato is set to SQL Server's SYSDATETIME() rather than a Python
    timestamp, so the value is stamped by the same clock as created_at and
    updated_at on the other tables. Migration 002 exists because mixing
    Python's UTC with SQL Server's local time had already caused exactly that
    inconsistency once.

    Args:
        db: An open SQLAlchemy session.
        data: The fields to log. Each is written to its like-named column
            (`ip_address` to IpAdresse, the rest to the same name in
            PascalCase) after being cut to that column's width.
    """
    log = PortalAuditLog(
        BrugerIdent=_fit(data.bruger_ident, _MAX_LENGTHS["bruger_ident"]),
        ApiKeyName=_fit(data.api_key_name, _MAX_LENGTHS["api_key_name"]),
        Action=_fit(data.action, _MAX_LENGTHS["action"]),
        Method=_fit(data.method, _MAX_LENGTHS["method"]),
        Path=_fit(data.path, _MAX_LENGTHS["path"]),
        QueryParams=data.query_params,
        StatusCode=data.status_code,
        DurationMs=data.duration_ms,
        ErrorMessage=data.error_message,
        IpAdresse=_fit(data.ip_address, _MAX_LENGTHS["ip_address"]),
        UserAgent=_fit(data.user_agent, _MAX_LENGTHS["user_agent"]),
        OprettetDato=func.sysdatetime(),
    )

    db.add(log)
