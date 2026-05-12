from pydantic import BaseModel


class BevillingOverviewRecord(BaseModel):
    navn: str | None = None
    cpr: str | None = None
    status: str | None = None
    esdh_noegle: str | None = None
    sagsbehandler: str | None = None
    ppr_sagsbehandler: str | None = None
