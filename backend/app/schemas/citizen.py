from pydantic import BaseModel, ConfigDict


class CitizenStamdataUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    skoleafstand: float | None = None
    klasseart: str | None = None
    elevklassetrin: int | None = None
    klassebetegnelse: str | None = None
    sfo: bool | None = None
    bopaelsdistrikt: str | None = None
