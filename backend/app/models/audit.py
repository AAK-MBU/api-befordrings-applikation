"""Technical audit trail: one row per handled HTTP call.

Written by middleware/audit_middleware.py after every business-relevant
request, in its own session with its own commit, so that a failed log write
never takes down the response it was describing.
"""

from datetime import datetime
from decimal import Decimal

from sqlalchemy import Integer, Numeric, Unicode
from sqlalchemy.dialects.mssql import DATETIME2
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


DB_SCHEMA = "befordring"


class PortalAuditLog(Base):
    """One completed HTTP call against the API.

    Column names are PascalCase here, unlike every other model in this package,
    because the table is PascalCase in the database — the same shape as the
    PortalAuditLog in the sibling aktindsigt application. Mapping it verbatim
    keeps the two recognisably the same table.

    Every column except AuditLogId is nullable: a call can be cut short before
    its fields are known.

    Attributes:
        BrugerIdent: Who made the call — the name of the API key it
            authenticated with, else the OIDC session's email claim, else the
            IdP's subject. NULL for unauthenticated calls.
        Action: The matched route's name (the endpoint function), e.g.
            "delete_bevilling". NULL when no route matched, such as a 404.
        Path: The request path. Note that several routes carry a CPR number in
            the path itself (/citizen/stamdata/{cpr}, /aktivitet/{cpr}), so
            this column holds personal data by design — knowing who looked up
            which citizen is the point of the trail.
        QueryParams: Query parameters as a JSON object, with credential-bearing
            values redacted. NULL when the call had none.
        ApiKeyId: Never written. API keys come from configuration and have no
            table to take an id from, so this stays NULL until they do.
        ApiKeyName: Name of the matched API key, for calls that used one. NULL
            for calls with an OIDC session.
        StatusCode: The response's status code; 500 when the call raised.
        DurationMs: Handling time in milliseconds, to two decimals.
        ErrorMessage: The error text, read out of the response's `detail` field
            for status 400 and up, or "type: message" for an unhandled
            exception. NULL for successful calls.
        IpAdresse: The client's IP, from X-Forwarded-For (first value), else
            X-Real-IP, else the connection's host.
        OprettetDato: When the call was logged. Stamped by SQL Server with
            SYSDATETIME() at insert, not by Python — the rest of this database
            stores local server time (see migration 002), and a UTC value here
            would sit one or two hours off every other timestamp beside it.
    """

    __tablename__ = "PortalAuditLog"
    __table_args__ = {"schema": DB_SCHEMA}

    AuditLogId: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    # --- Identity ---
    BrugerIdent: Mapped[str | None] = mapped_column(Unicode(200), nullable=True)
    ApiKeyId: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ApiKeyName: Mapped[str | None] = mapped_column(Unicode(200), nullable=True)

    # --- Request ---
    Action: Mapped[str | None] = mapped_column(Unicode(200), nullable=True)
    Method: Mapped[str | None] = mapped_column(Unicode(10), nullable=True)
    Path: Mapped[str | None] = mapped_column(Unicode(500), nullable=True)
    QueryParams: Mapped[str | None] = mapped_column(Unicode, nullable=True)

    # --- Outcome ---
    StatusCode: Mapped[int | None] = mapped_column(Integer, nullable=True)
    DurationMs: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    ErrorMessage: Mapped[str | None] = mapped_column(Unicode, nullable=True)

    # --- Client ---
    IpAdresse: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)
    UserAgent: Mapped[str | None] = mapped_column(Unicode(500), nullable=True)

    OprettetDato: Mapped[datetime] = mapped_column(DATETIME2, nullable=False)
