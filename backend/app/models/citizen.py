from __future__ import annotations

from uuid import UUID

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.mssql import UNIQUEIDENTIFIER
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


DB_SCHEMA = "befordring"


class Adresse(Base):
    __tablename__ = "Adresse"
    __table_args__ = {"schema": DB_SCHEMA}

    adresse_id: Mapped[UUID] = mapped_column(
        UNIQUEIDENTIFIER(as_uuid=True),
        primary_key=True,
    )

    adresse_tekst: Mapped[str] = mapped_column(String, nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)


class Elev(Base):
    __tablename__ = "Elev"
    __table_args__ = {"schema": DB_SCHEMA}

    cpr: Mapped[str] = mapped_column(
        String(10),
        primary_key=True,
    )

    adresseringsnavn: Mapped[str] = mapped_column(String, nullable=False)
    navne_adresse_beskyttelse: Mapped[bool] = mapped_column(Boolean, nullable=False)

    adresse_id: Mapped[UUID] = mapped_column(
        UNIQUEIDENTIFIER(as_uuid=True),
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

    skoleafstand: Mapped[float] = mapped_column(Float, nullable=False)
    klasseart: Mapped[str] = mapped_column(String, nullable=False)
    elevklassetrin: Mapped[str] = mapped_column(String, nullable=False)
    klassebetegnelse: Mapped[str] = mapped_column(String, nullable=False)
    sfo: Mapped[str] = mapped_column(String, nullable=False)
    bopaelsdistrikt: Mapped[str] = mapped_column(String, nullable=False)

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

    adresse_id: Mapped[UUID] = mapped_column(
        UNIQUEIDENTIFIER(as_uuid=True),
        ForeignKey(f"{DB_SCHEMA}.Adresse.adresse_id"),
        nullable=False,
    )

    navne_adresse_beskyttelse: Mapped[bool] = mapped_column(Boolean, nullable=False)
    foraeldremyndighed: Mapped[bool] = mapped_column(Boolean, nullable=False)
    maa_vide_barns_adresse: Mapped[bool] = mapped_column(Boolean, nullable=False)

    elev = relationship("Elev")
    adresse = relationship("Adresse")
