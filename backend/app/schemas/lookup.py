from pydantic import BaseModel


class LookupOption(BaseModel):
    id: int
    label: str
