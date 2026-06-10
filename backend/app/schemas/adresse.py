from pydantic import BaseModel, ConfigDict


class AdresseSearchResult(BaseModel):
    model_config = {"from_attributes": True}

    adresse_id: str
    adresse_tekst: str | None = None
    latitude: float | None = None
    longitude: float | None = None


class AdresseCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    # LOIS AdresseId (DAR GUID) — PK of the Adresse table.
    adresse_id: str
    adresse_tekst: str | None = None
    latitude: float | None = None
    longitude: float | None = None


class AdresseCreateResponse(BaseModel):
    adresse_id: str
    created: bool
