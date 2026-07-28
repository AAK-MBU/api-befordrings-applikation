from datetime import datetime

from pydantic import BaseModel, ConfigDict


class PartCreateRequest(BaseModel):
    """Payload for creating a party. Every person field is optional."""

    model_config = ConfigDict(extra="forbid")

    fulde_navn: str | None = None
    cpr_nummer: str | None = None
    adresse_id: str | None = None
    relation: str | None = None
    telefonnummer: str | None = None
    oprettet_af: str | None = None


class PartUpdateRequest(BaseModel):
    """Payload for updating a party. Only provided fields are changed."""

    model_config = ConfigDict(extra="forbid")

    fulde_navn: str | None = None
    cpr_nummer: str | None = None
    adresse_id: str | None = None
    relation: str | None = None
    telefonnummer: str | None = None


class PartResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    part_id: int
    cpr_elev: str
    fulde_navn: str | None = None
    cpr_nummer: str | None = None
    adresse_id: str | None = None
    adresse_tekst: str | None = None
    relation: str | None = None
    telefonnummer: str | None = None
    oprettet_tidspunkt: datetime
    oprettet_af: str | None = None
    aktiv: bool
