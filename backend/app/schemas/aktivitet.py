from datetime import datetime

from pydantic import BaseModel, ConfigDict


class SagsaktivitetCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    aktivitetstype: str
    kommentar: str | None = None
    udfoert_af: str | None = None
    relateret_bevilling_id: int | None = None


class SagsaktivitetResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    aktivitet_id: int
    cpr: str
    aktivitetstype: str
    kommentar: str | None = None
    udfoert_af: str | None = None
    oprettet_tidspunkt: datetime
    relateret_bevilling_id: int | None = None
