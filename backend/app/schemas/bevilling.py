import re
from datetime import date

from pydantic import BaseModel, ConfigDict, Field, model_validator

# A valid date in this system is a real calendar date with an exactly-4-digit
# year written as YYYY-MM-DD. Native date pickers happily accept absurd years
# (HTML allows up to 275760), so this guards the untyped letter payload.
_ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def _is_valid_iso_date(value: str) -> bool:
    if not _ISO_DATE_RE.match(value):
        return False

    try:
        date.fromisoformat(value)
    except ValueError:
        return False

    return True


class BevillingCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    adresse_id: str
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
    adresse_id: str | None = None
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
    revurderet_af_br: bool | None = None

    # Lock flag. Sent on its own by the lock/unlock control, exactly as the
    # kørselsrække lock sends {"final": true} to its own update endpoint.
    final: bool | None = None


class HjaelpemidlerUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    hjaelpemiddel_ids: list[int] = Field(default_factory=list)


class KoerselsraekkeCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    gyldig_fra: date
    gyldig_til: date
    tidspunkt_id: int
    befordringstype_id: int
    rutetype_id: int | None = None
    bevilget_koereafstand_pr_vej: float | None = None

    taxa_id: str | None = None
    kommentar: str | None = None
    final: bool = False

    # Skolerejsekort-specific.
    transporttid_i_bus: int | None = None
    skift_med_bus: int | None = None

    # Taxa-specific (Rutekørsel, Skånekørsel, Solo kørsel, Variabel kørsel).
    koersel_til_institution: bool | None = None
    max_minutter_i_transport: int | None = None

    # Egenbefordring-specific: the Part receiving the kilometre reimbursement.
    koerselsgodtgoerelse_modtager_id: int | None = None

    tillaeg_ids: list[int] = Field(default_factory=list)
    dag_ids: list[int] = Field(default_factory=list)


class KoerselsraekkeCreateResponse(BaseModel):
    koersel_id: int
    rows_inserted: int


class KoerselsraekkeUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    tidspunkt_id: int | None = None
    befordringstype_id: int | None = None
    rutetype_id: int | None = None
    bevilget_koereafstand_pr_vej: float | None = None
    gyldig_fra: date | None = None
    gyldig_til: date | None = None
    taxa_id: str | None = None
    kommentar: str | None = None
    final: bool | None = None

    # Skolerejsekort-specific.
    transporttid_i_bus: int | None = None
    skift_med_bus: int | None = None

    # Taxa-specific (Rutekørsel, Skånekørsel, Solo kørsel, Variabel kørsel).
    koersel_til_institution: bool | None = None
    max_minutter_i_transport: int | None = None

    # Egenbefordring-specific: the Part receiving the kilometre reimbursement.
    koerselsgodtgoerelse_modtager_id: int | None = None


class KoerselTillaegUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    tillaeg_ids: list[int] = Field(default_factory=list)


class KoerselDageUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    dag_ids: list[int] = Field(default_factory=list)


class LetterCreateRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    @model_validator(mode="after")
    def _validate_date_fields(self) -> "LetterCreateRequest":
        """Reject any date-named extra field that is not a valid ISO date.

        The letter payload is dynamic (``extra="allow"``), so its date values
        (e.g. ``dato_for_seneste_bevilling``, ``ophoersdato``) arrive as raw
        strings with no type coercion. Any extra field whose name contains
        "dato" must therefore be a real calendar date with a 4-digit year, or
        empty/None.
        """

        extras = self.__pydantic_extra__ or {}

        for key, value in extras.items():
            if "dato" not in key.lower():
                continue

            if value in (None, ""):
                continue

            if not isinstance(value, str) or not _is_valid_iso_date(value):
                raise ValueError(
                    f"Feltet '{key}' skal være en gyldig dato på formen "
                    f"åååå-mm-dd."
                )

        return self
