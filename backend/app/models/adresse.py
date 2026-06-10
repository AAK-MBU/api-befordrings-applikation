from sqlalchemy import Float, Unicode
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


DB_SCHEMA = "befordring"


class Adresse(Base):
    """Municipality address record.

    The primary key is the address GUID (AdresseId / DAR id) from LOIS — it
    is NOT a server-generated identity.  All FK references from Elev,
    Foraelder, and Bevilling point here.

    Rows are populated either by the nightly SAS address register sync, or
    by the RPA conversion bot (POST /adresse/create) when an address resolved
    from LOIS at queue time does not yet exist.
    """

    __tablename__ = "Adresse"
    __table_args__ = {"schema": DB_SCHEMA}

    adresse_id: Mapped[str] = mapped_column(
        Unicode(36),
        primary_key=True,
    )

    adresse_tekst: Mapped[str | None] = mapped_column(Unicode(500), nullable=True)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
