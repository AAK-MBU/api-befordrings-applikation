from pydantic import BaseModel


class OS2FormsCreateBevillingResponse(BaseModel):
    status: str
    cpr: str
    result: dict
