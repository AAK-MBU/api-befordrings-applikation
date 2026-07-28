from datetime import date, datetime

from sqlalchemy import Boolean, Date, Float, ForeignKey, Integer, String, Unicode, text
from sqlalchemy.dialects.mssql import DATETIME2
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


DB_SCHEMA = "befordring"


class Bevilling(Base):
    __tablename__ = "Bevilling"
    __table_args__ = {"schema": DB_SCHEMA}

    bevilling_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    cpr_elev: Mapped[str] = mapped_column(
        String(10),
        ForeignKey(f"{DB_SCHEMA}.Elev.cpr"),
        nullable=False,
    )

    adresse_id: Mapped[str] = mapped_column(
        Unicode(36),
        ForeignKey(f"{DB_SCHEMA}.Adresse.adresse_id"),
        nullable=False,
    )

    status_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Status.status_id"),
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

    hjemmel_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Hjemmel.hjemmel_id"),
        nullable=True,
    )

    afgoerelsesbrev_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Afgoerelsesbrev.afgoerelsesbrev_id"),
        nullable=True,
    )

    revurderingsdato: Mapped[date | None] = mapped_column(Date, nullable=True)
    befordringsudvalg: Mapped[date | None] = mapped_column(Date, nullable=True)

    esdh_noegle: Mapped[str | None] = mapped_column(
        Unicode,
        nullable=True,
    )

    sagsbehandler_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Sagsbehandler.sagsbehandler_id"),
        nullable=True,
    )

    ppr_sagsbehandler_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.PPR_Sagsbehandler.ppr_sagsbehandler_id"),
        nullable=True,
    )

    ansoegningsdato: Mapped[date | None] = mapped_column(Date, nullable=True)
    sagsbehandlingsdato: Mapped[date | None] = mapped_column(Date, nullable=True)

    relation_til_barnet: Mapped[str | None] = mapped_column(String, nullable=True)
    foerste_koersel_dato: Mapped[date | None] = mapped_column(Date, nullable=True)
    ansoegningstype: Mapped[str] = mapped_column(String, nullable=False)

    afstandskriterie_dato: Mapped[date | None] = mapped_column(Date, nullable=True)
    afstandskriterie_klassetrin: Mapped[int | None] = mapped_column(Integer, nullable=True)

    begrundelse_fra_formular: Mapped[str | None] = mapped_column(String, nullable=True)

    revurderet_af_ppr: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    revurderet_af_br: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    # Flag set by usp_recalculate_bevilling_status: the bevilling keeps its real
    # status (Aktiv/Kommende/…) but is marked as needing reassessment.
    revurdering: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    # System-managed field — written by usp_recalculate_bevilling_status.
    # Explains why the bevilling is in its current status (e.g. skolekode
    # mismatch, approaching revurderingsdato). Cleared automatically when
    # the status resolves to Aktiv or Ophørt.
    statusbemaerkning: Mapped[str | None] = mapped_column(Unicode, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DATETIME2,
        nullable=False,
        server_default=text("sysdatetime()"),
    )

    created_by: Mapped[str] = mapped_column(String, nullable=False)

    updated_at: Mapped[datetime] = mapped_column(
        DATETIME2,
        nullable=False,
        server_default=text("sysdatetime()"),
    )

    updated_by: Mapped[str] = mapped_column(String, nullable=False)

    aktiv: Mapped[bool] = mapped_column(Boolean, nullable=False)

    koerselsraekker = relationship(
        "Koersel",
        back_populates="bevilling",
    )


class Koersel(Base):
    __tablename__ = "Koersel"
    __table_args__ = {"schema": DB_SCHEMA}

    koersel_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    bevilling_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Bevilling.bevilling_id"),
        nullable=False,
    )

    gyldig_fra: Mapped[date] = mapped_column(Date, nullable=False)
    gyldig_til: Mapped[date] = mapped_column(Date, nullable=False)

    tidspunkt_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Tidspunkt.tidspunkt_id"),
        nullable=False,
    )

    befordringstype_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Befordringstype.befordringstype_id"),
        nullable=False,
    )

    bevilget_koereafstand_pr_vej: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
    )

    taxa_id: Mapped[str | None] = mapped_column(String, nullable=True)
    kommentar: Mapped[str | None] = mapped_column(String, nullable=True)

    # Skolerejsekort-specific values, entered on the koerselsrække form.
    # Nullable and type-specific, exactly like taxa_id / bevilget_koereafstand_pr_vej.
    transporttid_i_bus: Mapped[int | None] = mapped_column(Integer, nullable=True)
    skift_med_bus: Mapped[int | None] = mapped_column(Integer, nullable=True)

    final: Mapped[bool] = mapped_column(Boolean, nullable=False)

    bevilling = relationship(
        "Bevilling",
        back_populates="koerselsraekker",
    )


class BevillingHjaelpemiddelLink(Base):
    __tablename__ = "Bevilling_Hjaelpemiddel_LINK"
    __table_args__ = {"schema": DB_SCHEMA}

    bevilling_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Bevilling.bevilling_id"),
        primary_key=True,
    )

    hjaelpemiddel_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Hjaelpemiddel.hjaelpemiddel_id"),
        primary_key=True,
    )


class KoerselKoerselstypeTillaegLink(Base):
    __tablename__ = "Koersel_KoerselstypeTillaeg_LINK"
    __table_args__ = {"schema": DB_SCHEMA}

    koersel_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Koersel.koersel_id"),
        primary_key=True,
    )

    tillaeg_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.KoerselstypeTillaeg.tillaeg_id"),
        primary_key=True,
    )


class KoerselUgedagLink(Base):
    __tablename__ = "Koersel_Ugedag_LINK"
    __table_args__ = {"schema": DB_SCHEMA}

    koersel_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Koersel.koersel_id"),
        primary_key=True,
    )

    dag_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Ugedag.dag_id"),
        primary_key=True,
    )
