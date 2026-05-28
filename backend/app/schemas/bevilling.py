from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class BevillingCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    adresse_for_bevilling: str | None = None
    matrikel_id: int | None = None
    ungdomsuddannelse_id: int | None = None
    hjemmel_id: int | None = None
    afgoerelsesbrev_id: int | None = None

    revurderingsdato: date | None = None
    befordringsudvalg: date | None = None
    esdh_noegle: str | None = None

    sagsbehandler_id: int | None = None
    ppr_sagsbehandler_id: int | None = None

    ansoegningsdato: date | None = None
    sagsbehandlingsdato: date | None = None
    relation_til_barnet: str | None = None
    foerste_koersel_dato: date | None = None
    ansoegningstype: str | None = None

    afstandskriterie_dato: date | None = None
    afstandskriterie_klassetrin: int | None = None
    begrundelse_fra_formular: str | None = None

    hjaelpemiddel_ids: list[int] = Field(default_factory=list)


class BevillingCreateResponse(BaseModel):
    bevilling_id: int
    status_text: str
    rows_inserted: int


class BevillingUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status_id: int | None = None
    reset_status: bool = False
    matrikel_id: int | None = None
    ungdomsuddannelse_id: int | None = None
    sagsbehandlingsdato: date | None = None
    adresse_for_bevilling: str | None = None
    afstandskriterie_dato: date | None = None
    afstandskriterie_klassetrin: int | None = None
    relation_til_barnet: str | None = None
    revurderingsdato: date | None = None
    befordringsudvalg: date | None = None
    hjemmel_id: int | None = None
    afgoerelsesbrev_id: int | None = None
    sagsbehandler_id: int | None = None
    ppr_sagsbehandler_id: int | None = None
    revurderet_af_ppr: bool | None = None


class HjaelpemidlerUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    hjaelpemiddel_ids: list[int] = Field(default_factory=list)


class KoerselsraekkeCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    gyldig_fra: date
    gyldig_til: date
    tidspunkt_id: int
    befordringstype_id: int
    bevilget_koereafstand_pr_vej: float

    taxa_id: str | None = None
    kommentar: str | None = None
    final: bool = False

    tillaeg_ids: list[int] = Field(default_factory=list)
    dag_ids: list[int] = Field(default_factory=list)


class KoerselsraekkeCreateResponse(BaseModel):
    koersel_id: int
    rows_inserted: int


class KoerselsraekkeUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    tidspunkt_id: int | None = None
    befordringstype_id: int | None = None
    bevilget_koereafstand_pr_vej: float | None = None
    gyldig_fra: date | None = None
    gyldig_til: date | None = None
    taxa_id: str | None = None
    kommentar: str | None = None
    final: bool | None = None


class KoerselTillaegUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    tillaeg_ids: list[int] = Field(default_factory=list)


class KoerselDageUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    dag_ids: list[int] = Field(default_factory=list)


class LetterCreateRequest(BaseModel):
    model_config = ConfigDict(extra="allow")
