from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String, Unicode, text
from sqlalchemy.dialects.mssql import DATETIME2
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.adresse import Adresse  # noqa: F401 — re-exported; also ensures Adresse is
                                         # registered with Base.metadata before FK resolution.


DB_SCHEMA = "befordring"


class Elev(Base):
    __tablename__ = "Elev"
    __table_args__ = {"schema": DB_SCHEMA}

    cpr: Mapped[str] = mapped_column(
        String(10),
        primary_key=True,
    )

    adresseringsnavn: Mapped[str] = mapped_column(String, nullable=False)
    navne_adresse_beskyttelse: Mapped[bool] = mapped_column(Boolean, nullable=False)

    adresse_id: Mapped[str] = mapped_column(
        Unicode(36),
        ForeignKey(f"{DB_SCHEMA}.Adresse.adresse_id"),
        nullable=False,
    )

    matrikel_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Skolematrikel.matrikel_id"),
        nullable=True,
    )

    ungdomsuddannelse_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Ungdomsuddannelse.ungdomsuddannelse_id"),
        nullable=True,
    )

    skoleafstand: Mapped[float | None] = mapped_column(Float, nullable=True)
    klasseart: Mapped[str] = mapped_column(String, nullable=False)
    elevklassetrin: Mapped[str] = mapped_column(String, nullable=False)
    klassebetegnelse: Mapped[str] = mapped_column(String, nullable=False)
    sfo: Mapped[str] = mapped_column(String, nullable=False)
    bopaelsdistrikt: Mapped[str] = mapped_column(String, nullable=False)

    # Skolekode is denormalised directly onto Elev so the nightly RPA can
    # compare it against the skolekode on the bevilling's matrikel without
    # needing to join through Skolematrikel on the student side.
    skolekode: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=text("0"),
    )

    # Flag set by the nightly RPA when it detects that skoleafstand needs to
    # be recalculated (e.g. school assignment changed). Cleared once the RPA
    # has successfully written the new distance.
    kraever_genberegning: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=text("0"),
    )

    adresse = relationship("Adresse")


class Foraelder(Base):
    __tablename__ = "Foraelder"
    __table_args__ = {"schema": DB_SCHEMA}

    cpr_foraelder: Mapped[str] = mapped_column(
        String(10),
        primary_key=True,
    )

    cpr_elev: Mapped[str] = mapped_column(
        String(10),
        ForeignKey(f"{DB_SCHEMA}.Elev.cpr"),
        nullable=False,
    )

    adresseringsnavn: Mapped[str] = mapped_column(String, nullable=False)

    adresse_id: Mapped[str] = mapped_column(
        Unicode(36),
        ForeignKey(f"{DB_SCHEMA}.Adresse.adresse_id"),
        nullable=False,
    )

    navne_adresse_beskyttelse: Mapped[bool] = mapped_column(Boolean, nullable=False)
    foraeldremyndighed: Mapped[bool] = mapped_column(Boolean, nullable=False)
    maa_vide_barns_adresse: Mapped[bool] = mapped_column(Boolean, nullable=False)

    elev = relationship("Elev")
    adresse = relationship("Adresse")


class Sagsaktivitet(Base):
    """Audit log of case-level events for a citizen.

    Intentionally has no FK constraints in the database (matching the DB
    design), so rows survive bevilling deletes and can reference CPRs that
    are not yet in the Elev table.
    """

    __tablename__ = "Sagsaktivitet"
    __table_args__ = {"schema": DB_SCHEMA}

    aktivitet_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    cpr: Mapped[str] = mapped_column(String(10), nullable=False)
    aktivitetstype: Mapped[str] = mapped_column(String(50), nullable=False)
    kommentar: Mapped[str | None] = mapped_column(Unicode, nullable=True)
    oprettet_af: Mapped[str | None] = mapped_column(String(100), nullable=True)

    oprettet_tidspunkt: Mapped[datetime] = mapped_column(
        DATETIME2,
        nullable=False,
        server_default=text("getdate()"),
    )

    # Soft reference — no FK constraint in the DB.
    relateret_bevilling_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
