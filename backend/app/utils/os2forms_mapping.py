"""Helper functions for mapping OS2Forms payloads.

This module contains small mapping helpers used when converting raw OS2Forms
submission data into internal API values.

The functions are kept separate from OS2FormsService to make the mapping logic
easier to read, test, and reuse.
"""


def is_checked(value) -> bool:
    """Return True when an OS2Forms checkbox-like value is checked."""

    return str(value).strip() == "1"


def get_begrundelse(payload: dict) -> str:
    """Determine the applicant's foundation for applying."""

    begrundelse_fields = {
        "sygdom_funktionsnedsaettelse_handicap": "Sygdom/funktionsnedsaettelse/handicap",
        "trafikfarlig_vej": "Trafikfarlig vej",
        "langt_mellem_skole_og_hjem": "Langt mellem skole og hjem",
    }

    begrundelser = []

    for field_name, label in begrundelse_fields.items():
        if is_checked(payload.get(field_name)):
            begrundelser.append(label)

    return ", ".join(begrundelser)


def get_relation_til_barnet(payload: dict) -> str | None:
    """Determine the applicant's relation to the child/student.

    Args:
        payload:
            Parsed OS2Forms submission data.

    Returns:
        A relation text value, for example:
        - "Forældremyndighed"
        - "Ansøger selv"
        - "Uddannelsesinstitution"
        - A manually entered relation
        - None if no relation can be determined

    Notes:
        The temporary transport form uses different fields than the normal
        application forms, so it has its own mapping logic.
    """

    webform_id = payload.get("webform_id")

    foraeldremyndighed = payload.get(
        "er_du_foraeldremyndighedsindehaver_til_barnet_der_ansoeges_paa_v"
    )

    anden_tilknytning = payload.get("angiv_din_tilknytning_til_barnet")

    hvem_ansoges_der_for = payload.get(
        "hvem_ansoeger_du_om_midlertidig_koersel_for"
    )

    # Temporary transport has its own applicant/relation question.
    if webform_id == "ny_ansoegning_om_midlertidig_koe":
        if hvem_ansoges_der_for == "Mit barn":
            return "Forældremyndighed"

        if hvem_ansoges_der_for == "Et barn, som jeg ansøger på vegne af":
            return anden_tilknytning

        if hvem_ansoges_der_for == "Mig selv":
            return "Ansøger selv"

        if hvem_ansoges_der_for == "En elev på en uddannelsesinstitution":
            return "Uddannelsesinstitution"

        return None

    # For normal application forms, use the parent custody question first.
    if foraeldremyndighed == "Ja":
        return "Forældremyndighed"

    # If the applicant does not have custody, use their manually entered
    # relation to the child.
    return anden_tilknytning


def get_adresse_for_bevilling(payload: dict) -> str | None:
    """Determine which address should be used for the bevilling.

    Args:
        payload:
            Parsed OS2Forms submission data.

    Returns:
        The address that should be stored on the bevilling.
        Returns None if no address exists in the payload.

    Notes:
        The child's normal address is used by default.

        If the form says the child should be transported to/from another
        address, that other address is used instead.
    """

    # Prefer the MitID address, but fall back to the manually entered address.
    barnets_adresse = (
        payload.get("barnets_adresse_mitid")
        or payload.get("barnets_adresse_manuelt")
    )

    # OS2Forms checkbox values often arrive as strings.
    # Here, "1" means the checkbox/condition is selected.
    skal_koeres_fra_anden_adresse = (
        payload.get("barnet_skal_koeres_til_fra_anden_adresse") == "1"
    )

    if skal_koeres_fra_anden_adresse:
        return payload.get("barnets_anden_adresse") or barnets_adresse

    return barnets_adresse


def get_hjaelpemiddel_names(payload: dict) -> list[str]:
    """Extract hjaelpemiddel names from the OS2Forms payload.

    Args:
        payload:
            Parsed OS2Forms submission data.

    Returns:
        A list of hjaelpemiddel name strings, or an empty list if none
        were marked or the question was not answered.

    Notes:
        OS2Forms sends multi-value checkbox fields as indexed keys:
            angiv_hjaelpemiddel[0] = 'Kørestol'
            angiv_hjaelpemiddel[1] = 'Rollator'

        The presence question er_der_et_hjaelpemiddel_... must be 'Ja'
        for the list to be considered.
    """

    if payload.get("er_der_et_hjaelpemiddel_der_skal_med_under_koersel_") != "Ja":
        return []

    names = []

    for key, value in payload.items():
        if key.startswith("angiv_hjaelpemiddel[") and value:
            names.append(str(value).strip())

    return names


def get_ansoegningstype(payload: dict) -> str:
    """Determine the application type from the OS2Forms webform ID.

    Args:
        payload:
            Parsed OS2Forms submission data.

    Returns:
        Application type text used internally by the API.

    Notes:
        Unknown webform IDs fall back to "Kørsel".
    """

    webform_id = payload.get("webform_id")

    if webform_id == "ny_ansoegning_om_midlertidig_koe":
        return "Midlertidig kørsel"

    # "Skolebus" is treated as regular "Kørsel" - they are the same koersel type;
    # we only distinguish "Kørsel" from "Midlertidig kørsel". The skolebus webform
    # therefore falls through to the "Kørsel" default below.
    return "Kørsel"
