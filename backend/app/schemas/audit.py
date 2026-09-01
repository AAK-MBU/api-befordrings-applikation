"""Schema for one audit row, passed from the middleware to the write path."""

from pydantic import BaseModel


class AuditLogCreate(BaseModel):
    """One audit row for a completed HTTP call, ready for PortalAuditLog.

    Filled by middleware/audit_middleware and written by
    audit_log_service.create_audit_log, which maps each field to the
    like-named column.

    Attributes:
        bruger_ident: The actor. For a call authenticated with an API key this
            is the key's name; otherwise the user's identity from the session.
        api_key_name: Name of the API key the call authenticated with, or None
            for a session call.
        action: The matched route's name, or None when no route matched.
        query_params: The request's query parameters, already redacted and
            JSON-encoded. None when the call had none.
        error_message: The error text, when the call did not succeed.
    """

    # --- Identity ---
    bruger_ident: str | None = None
    api_key_name: str | None = None

    # --- Request ---
    action: str | None = None
    method: str
    path: str
    query_params: str | None = None

    # --- Outcome ---
    status_code: int | None = None
    duration_ms: float | None = None
    error_message: str | None = None

    # --- Client ---
    ip_address: str | None = None
    user_agent: str | None = None
