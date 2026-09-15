"""Schemas for created decision letters (Forsendelse)."""

from pydantic import BaseModel, ConfigDict, Field


class BrevAfsendtRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    # At least one id — an empty list is a caller mistake, not a no-op, and
    # silently succeeding on it hides a broken selection in the UI.
    brev_ids: list[int] = Field(min_length=1)

    # False reopens a letter marked sent by mistake. Both directions stamp who
    # acted, so the change stays attributable.
    afsendt: bool = True


class BrevAfsendtResponse(BaseModel):
    updated: list[int]
    rows_updated: int
    unchanged: int
