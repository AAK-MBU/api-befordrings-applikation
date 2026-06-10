# No update request schemas — citizen stamdata and parent data are
# maintained by external systems and are read-only in this application.
#
# Exception: create_elev is used by the RPA conversion bot to insert a
# minimal Elev record when migrating PPR bevillinger into the befordring app.

from pydantic import BaseModel, ConfigDict


class ElevCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cpr: str
    adresseringsnavn: str

    # FK to the Adresse table (LOIS AdresseId / DAR GUID).
    # The RPA resolves this at queue time from LOIS.CPR.PersonGeoView and
    # LOIS.DAR.AdresseGeoView, then ensures the row exists via
    # POST /adresse/create before calling this endpoint. Required to satisfy
    # the NOT NULL FK constraint on Elev.adresse_id.
    adresse_id: str

    navne_adresse_beskyttelse: bool = False
    matrikel_id: int | None = None
    klasseart: str = ""
    elevklassetrin: str = ""
    klassebetegnelse: str = ""
    sfo: str = ""
    bopaelsdistrikt: str = ""
    skoleafstand: float | None = None
    skolekode: int = 0
    kraever_genberegning: bool = False
