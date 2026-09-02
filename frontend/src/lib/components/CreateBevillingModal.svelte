  <script lang="ts">
    import { onMount, createEventDispatcher } from "svelte";
    import { backendFetch } from "$lib/client/backendFetch";
    import { filterHjemler, filterAfgoerelsesbreve, isMidlertidigKoersel } from "$lib/lookupFilters";
    import {
      AFSTANDSKRITERIE_KLASSETRIN,
      beregnAfstandskriterieDato,
      beregnAfstandskriterieKlassetrin
    } from "$lib/afstandskriterie";
    import AddresseSearch from "$lib/components/AddresseSearch.svelte";

  import { ansoegerRelationOptions } from "$lib/ansoegerRelation";
    export let cpr: string;
    export let mode: 'kopi' | 'tom';
    export let existingBevillinger: any[] = [];
    export let lookupOptions: any = {};

    // The student's current klassetrin (Elev.elevklassetrin), used to derive the
    // afstandskriterie fields. Optional: without it the two fields simply stay
    // manual, which is what an ungdomsuddannelse student needs anyway.
    export let elevklassetrin: string | number | null = null;

    const dispatch = createEventDispatcher<{ created: void; cancel: void }>();

    function emptyToNull(value: any) { return value === "" ? null : value; }
    function numberOrNull(value: any) { return value === "" ? null : Number(value); }
    
    const minDate = new Date(new Date().getFullYear() - 10, 0, 1).toISOString().slice(0, 10);
    const maxDate = new Date(new Date().getFullYear() + 10, 11, 31).toISOString().slice(0, 10);
    
    function isDateOutOfRange(value: string): boolean {
      return !!value && (value < minDate || value > maxDate);
    }

    function validateBevillingDates(): boolean {
      const fields: [string, string][] = [
        [newBevilling.revurderingsdato,      'Revurderingsdato'],
        [newBevilling.befordringsudvalg,     'Befordringsudvalg'], 
        [newBevilling.sagsbehandlingsdato,   'Sagsbehandlingsdato'],
        [newBevilling.foerste_koersel_dato,  'Dato for første kørsel'],
        [newBevilling.afstandskriterie_dato, 'Afstandskriterie dato'],
      ];
      for (const [value, label] of fields) {
        if (isDateOutOfRange(value)) {
          modalError = `${label}: Dato er ugyldig — kontrollér årstallet`;
          return false;
        }
      }
      return true;
    }

  
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

    let createBevillingStep: 1 | 2 = 1;
    let modalKoersel: any = {};
    let modalKoerselTillaegIds: number[] = [];
    let modalKoerselDagIds: number[] = [];
    let modalKoerselTillaegSelectValue = "";
    let modalKoerselDagSelectValue = "";
    let isCreatingKoerselInModal = false;
    let isCalculatingModalKoerselDistance = false;
    let modalKoerselDistanceError: string | null = null;
    let modalError: string | null = null;
    let skoleType: 'folkeskole' | 'ungdomsuddannelse' | null = null;
    let newBevilling: any = {};
    let selectedSourceBevillingId: number | null = null;
    let selectedBegrundelser: string[] = [];
    let begrundelseSelectValue = "";
    const begrundelseOptions = ["Sygdom", "Afstand", "Farlig skolevej"];

    $: koerselstyper       = lookupOptions.koerselstyper       ?? [];
    $: tidspunkter         = lookupOptions.tidspunkter         ?? [];
    $: koerselstypeTillaeg = lookupOptions.koerselstypeTillaeg ?? [];
    $: dage                = lookupOptions.dage                ?? [];

    $: modalBefordringstypeLabel = (koerselstyper.find((t: any) => Number(t.id) === Number(modalKoersel.befordringstype_id))?.label ?? '').toLowerCase().trim();

    // Midlertidig kørsel is granted on a different basis, so the afstandskriterie
    // fields, befordringsudvalg and PPR ansvarlig do not apply and are hidden.
    $: isMidlertidig = isMidlertidigKoersel(newBevilling.ansoegningstype);

    $: visibleHjemler = filterHjemler(lookupOptions?.hjemler, newBevilling.ansoegningstype, skoleType);
    $: selectedHjemmelLabel = visibleHjemler.find((h: any) => String(h.id) === String(newBevilling.hjemmel_id))?.label ?? null;
    $: visibleAfgoerelsesbreve = filterAfgoerelsesbreve(lookupOptions?.afgoerelsesbreve, newBevilling.ansoegningstype, skoleType, selectedHjemmelLabel);

  // ---------------------------------------------------------------------------
  // Functions
  // ---------------------------------------------------------------------------

    // A bevilling being copied can hold a klassetrin outside the standard list,
    // and a <select> whose value matches no option silently blanks itself —
    // which looks exactly like the copy having dropped the field. Append the
    // stored value instead.
    function klassetrinOptions(current: string | number | null | undefined): string[] {
      const value = String(current ?? "").trim();
      const known = AFSTANDSKRITERIE_KLASSETRIN.map(String);

      if (!value || known.includes(value)) {
        return known;
      }

      return [...known, value];
    }

    // Derived from the student's klassetrin rather than typed in. Recomputed
    // whenever the klassetrin changes, but not written straight into
    // newBevilling: applyBeregnetAfstandskriterie() does that, so a caseworker
    // who overrides either field keeps their value.
    $: beregnetKlassetrin = beregnAfstandskriterieKlassetrin(elevklassetrin);
    $: beregnetDato = beregnAfstandskriterieDato(elevklassetrin);

    function applyBeregnetAfstandskriterie() {
      if (beregnetKlassetrin === null || beregnetDato === null) {
        return;
      }

      newBevilling = {
        ...newBevilling,
        afstandskriterie_klassetrin: String(beregnetKlassetrin),
        afstandskriterie_dato: beregnetDato
      };
    }

    function resetLookupSelections() {
      newBevilling = { ...newBevilling, hjemmel_id: "", afgoerelsesbrev_id: "" };
    }

    function onAnsoegningstypeChange() {
      resetLookupSelections();

      // Drop anything already typed into the fields that are about to be
      // hidden, so a value entered under another ansøgningstype cannot be
      // submitted invisibly. Only on the way *into* Midlertidig — switching
      // between two other types must not discard the user's input.
      if (isMidlertidigKoersel(newBevilling.ansoegningstype)) {
        newBevilling = {
          ...newBevilling,
          afstandskriterie_dato: "",
          afstandskriterie_klassetrin: "",
          befordringsudvalg: "",
          ppr_sagsbehandler_id: ""
        };
      }
    }

    function getEmptyBevilling() {
      return {
        adresse_id: null as string | null,
        adresse_tekst: "",
        matrikel_id: "",
        ungdomsuddannelse_id: "",
        hjemmel_id: "",
        afgoerelsesbrev_id: "",
        revurderingsdato: "",
        befordringsudvalg: "",
        esdh_noegle: "",
        sagsbehandler_id: "",
        ppr_sagsbehandler_id: "",
        ansoegningsdato: "",
        sagsbehandlingsdato: "",
        relation_til_barnet: "",
        foerste_koersel_dato: "",
        ansoegningstype: "",
        afstandskriterie_dato: "",
        afstandskriterie_klassetrin: "",
        begrundelse_fra_formular: "",
        hjaelpemiddel_ids: [],
      };
    }

    function resetCreateBevillingForm() {
      newBevilling = getEmptyBevilling();
      skoleType = null;
      selectedBegrundelser = [];
      begrundelseSelectValue = "";
    }

    function resetModalKoerselEmpty() {
      modalKoersel = { tidspunkt_id: "", befordringstype_id: "", bevilget_koereafstand_pr_vej: "", gyldig_fra: "", gyldig_til: "", taxa_id: "", kommentar: "", transporttid_i_bus: "", skift_med_bus: "" };
      modalKoerselTillaegIds = [];
      modalKoerselDagIds = [];
    }

    function resetModalKoersel(m: 'kopi' | 'tom', sourceBev?: any) {
      if (m === 'kopi') {
        const src = sourceBev?.koerselsraekker?.[0] ?? null;        
        if (src) {
          modalKoersel = {
            tidspunkt_id: src.tidspunkt_id ?? "",
            befordringstype_id: src.befordringstype_id ?? "",
            bevilget_koereafstand_pr_vej: src.bevilget_koereafstand_pr_vej != null ? String(src.bevilget_koereafstand_pr_vej) : "",
            gyldig_fra: "",
            gyldig_til: "",
            taxa_id: src.taxa_id ?? "",
            kommentar: src.kommentar ?? "",
            transporttid_i_bus: src.transporttid_i_bus != null ? String(src.transporttid_i_bus) : "",
            skift_med_bus: src.skift_med_bus != null ? String(src.skift_med_bus) : "",
          };
          const rawTillaeg = src.tillaeg_ids ?? "";
          modalKoerselTillaegIds = rawTillaeg ? String(rawTillaeg).split(",").map(Number).filter((n: number) => !isNaN(n)) : [];
          const rawDage = src.dag_ids ?? "";
          modalKoerselDagIds = rawDage ? String(rawDage).split(",").map(Number).filter((n: number) => !isNaN(n)) : [];
        } else {
          resetModalKoerselEmpty();
        }
      } else {
        resetModalKoerselEmpty();
      }
      modalKoerselTillaegSelectValue = "";
      modalKoerselDagSelectValue = "";
      modalKoerselDistanceError = null;
    }

    function isModalKoerselEgenbefordring(typeId: any): boolean {
      if (!typeId) return false;
      const type = koerselstyper.find((t: any) => Number(t.id) === Number(typeId));
      return type?.label?.toLowerCase().replace(/\s/g, '') === 'egenbefordring';
    }
    
    const TAXA_TYPES = new Set(['rutekørsel', 'skånekørsel', 'solokørsel', 'variabel kørsel']);
    function normalizeModalType(label: string | null | undefined): string { return (label ?? '').toLowerCase().trim(); }

    function isModalKoerselTaxaType(typeId: any): boolean {
      if (!typeId) return false;
      const type = koerselstyper.find((t: any) => Number(t.id) === Number(typeId));
      return TAXA_TYPES.has(normalizeModalType(type?.label));
    }

    function isModalKoerselSkolerejsekort(typeId: any): boolean {
      if (!typeId) return false;
      const type = koerselstyper.find((t: any) => Number(t.id) === Number(typeId));
      return normalizeModalType(type?.label) === 'skolerejsekort';
    }

    async function calculateModalKoerselDistance(typeId: any) {
      if (!isModalKoerselEgenbefordring(typeId)) {
        modalKoersel = { ...modalKoersel, bevilget_koereafstand_pr_vej: "" };
        return;
      }
      if (!newBevilling.adresse_tekst) {
        modalKoerselDistanceError = "Ingen adresse på bevillingen — kan ikke beregne afstand";
        return;
      }
      if (!newBevilling.matrikel_id) {
        modalKoerselDistanceError = "Ingen skole valgt på bevillingen — kan ikke beregne afstand";
        return;
      }
      isCalculatingModalKoerselDistance = true;
      modalKoerselDistanceError = null;
      try {
        const geoRes = await backendFetch(`/bevilling/geocode_address?address=${encodeURIComponent(newBevilling.adresse_tekst)}`);
        if (!geoRes.ok) throw new Error("Kunne ikke geokode adressen");
        const geo = await geoRes.json();
        const schoolRes = await backendFetch(`/lookup/skolematrikel/${newBevilling.matrikel_id}/coordinates`);
        if (!schoolRes.ok) throw new Error("Kunne ikke hente skolens koordinater");
        const school = await schoolRes.json();
        const params = new URLSearchParams({ lat1: String(geo.latitude), lon1: String(geo.longitude), lat2: String(school.latitude), lon2: String(school.longitude) });
        const distRes = await backendFetch(`/bevilling/calculate_driving_distance?${params}`);
        if (!distRes.ok) throw new Error("Kunne ikke beregne køreafstand");
        const dist = await distRes.json();
        const km = dist.distance_km ?? dist.distance ?? dist.driving_distance_km;
        if (km == null) throw new Error("Ugyldigt svar fra afstandsberegning");
        if (Number(modalKoersel.befordringstype_id) !== Number(typeId)) return;
        modalKoersel = { ...modalKoersel, bevilget_koereafstand_pr_vej: String(km) };
      } catch (err: any) {
        modalKoerselDistanceError = err?.message ?? "Fejl ved beregning af afstand";
      } finally {
        isCalculatingModalKoerselDistance = false;
      }
    }

    function handleGoToStep2() { 
      modalError = null;
      if (newBevilling.ansoegningstype === "Midlertidig kørsel") {
        if (!skoleType) { modalError = "Vælg skoletype (Folkeskole eller Ungdomsuddannelse)"; return; }
        if (skoleType === 'folkeskole' && !newBevilling.matrikel_id) { modalError = "Folkeskole skal udfyldes"; return; }
        if (skoleType === 'ungdomsuddannelse' && !newBevilling.ungdomsuddannelse_id) { modalError = "Ungdomsuddannelse skal udfyldes"; return; }
      } else {
        if (!newBevilling.matrikel_id) { modalError = "Folkeskole skal udfyldes"; return; }
      }
      if (!newBevilling.hjemmel_id)         { modalError = "Hjemmel skal udfyldes"; return; }
      if (!newBevilling.afgoerelsesbrev_id) { modalError = "Afgørelsesbrev skal udfyldes"; return; }
      if (!newBevilling.sagsbehandler_id)   { modalError = "Sagsbehandler skal udfyldes"; return; }
      createBevillingStep = 2; 
    }

    function prefillFromBevilling(source: any) {
      skoleType = (source.ungdomsuddannelse_id && !source.matrikel_id) ? 'ungdomsuddannelse' : 'folkeskole';
      const rawBegrundelse = source.begrundelse_fra_formular ?? "";
      selectedBegrundelser = rawBegrundelse.split(", ").filter((b: string) => begrundelseOptions.includes(b));
      begrundelseSelectValue = "";
      newBevilling = {
        adresse_id:                  source.adresse_id ?? null,
        adresse_tekst:               source.adresse_for_bevilling ?? "",
        matrikel_id:                 source.matrikel_id != null ? String(source.matrikel_id) : "",
        ungdomsuddannelse_id:        source.ungdomsuddannelse_id != null ? String(source.ungdomsuddannelse_id) : "",
        hjemmel_id:                  source.hjemmel_id != null ? String(source.hjemmel_id) : "",
        afgoerelsesbrev_id:          source.afgoerelsesbrev_id != null ? String(source.afgoerelsesbrev_id) : "",
        sagsbehandler_id:            source.sagsbehandler_id != null ? String(source.sagsbehandler_id) : "",
        ppr_sagsbehandler_id:        source.ppr_sagsbehandler_id != null ? String(source.ppr_sagsbehandler_id) : "",
        relation_til_barnet:         source.relation_til_barnet ?? "",
        ansoegningstype:             source.ansoegningstype ?? "",
        afstandskriterie_dato:       source.afstandskriterie_dato ? String(source.afstandskriterie_dato).slice(0, 10) : "",
        afstandskriterie_klassetrin: source.afstandskriterie_klassetrin != null ? String(source.afstandskriterie_klassetrin) : "",
        revurderingsdato:            source.revurderingsdato ? String(source.revurderingsdato).slice(0, 10) : "",
        befordringsudvalg:           source.befordringsudvalg ? String(source.befordringsudvalg).slice(0, 10) : "",
        begrundelse_fra_formular:    rawBegrundelse,
        // A revurdering continues the same ESDH case, so the key carries over.
        // The other fields below stay blank on purpose: they belong to the new
        // bevilling, not the one being copied.
        esdh_noegle:                 source.esdh_noegle ?? "",
        ansoegningsdato:             "",
        sagsbehandlingsdato:         "",
        foerste_koersel_dato:        "",
        hjaelpemiddel_ids:           [],
      };
    }

    function addBegrundelse() {
      if (begrundelseSelectValue === "") return;
      if (!selectedBegrundelser.includes(begrundelseSelectValue)) {
        selectedBegrundelser = [...selectedBegrundelser, begrundelseSelectValue];
      }
      newBevilling.begrundelse_fra_formular = selectedBegrundelser.join(", ");
      begrundelseSelectValue = "";
    }

    function removeBegrundelse(value: string) {
      selectedBegrundelser = selectedBegrundelser.filter((v) => v !== value);
      newBevilling.begrundelse_fra_formular = selectedBegrundelser.join(", ");
    }

    async function handleCreateBevilling() {
      modalError = null;
      if (newBevilling.ansoegningstype === "Midlertidig kørsel") {
        if (!skoleType) { modalError = "Vælg skoletype (Folkeskole eller Ungdomsuddannelse)"; return; }
        if (skoleType === 'folkeskole' && !newBevilling.matrikel_id) { modalError = "Folkeskole skal udfyldes"; return; }
        if (skoleType === 'ungdomsuddannelse' && !newBevilling.ungdomsuddannelse_id) { modalError = "Ungdomsuddannelse skal udfyldes"; return; }
      } else {
        if (!newBevilling.matrikel_id) { modalError = "Folkeskole skal udfyldes"; return; }
      }
      if (!newBevilling.adresse_id)        { modalError = "Adresse for bevilling skal udfyldes"; return; }
      if (!newBevilling.hjemmel_id)         { modalError = "Hjemmel skal udfyldes"; return; }
      if (!newBevilling.afgoerelsesbrev_id) { modalError = "Afgørelsesbrev skal udfyldes"; return; }
      if (!newBevilling.sagsbehandler_id)   { modalError = "Sagsbehandler skal udfyldes"; return; }
      if (!validateBevillingDates()) return;
      const payload = {
        adresse_id:                  newBevilling.adresse_id,
        matrikel_id:                 (isMidlertidig && skoleType === 'ungdomsuddannelse') ? null : numberOrNull(newBevilling.matrikel_id),
        ungdomsuddannelse_id:        (isMidlertidig && skoleType === 'ungdomsuddannelse') ? numberOrNull(newBevilling.ungdomsuddannelse_id) : null,
        hjemmel_id:                  numberOrNull(newBevilling.hjemmel_id),
        afgoerelsesbrev_id:          numberOrNull(newBevilling.afgoerelsesbrev_id),
        revurderingsdato:            emptyToNull(newBevilling.revurderingsdato),
        befordringsudvalg:           isMidlertidig ? null : emptyToNull(newBevilling.befordringsudvalg),
        esdh_noegle:                 emptyToNull(newBevilling.esdh_noegle),
        sagsbehandler_id:            numberOrNull(newBevilling.sagsbehandler_id),
        ppr_sagsbehandler_id:        isMidlertidig ? null : numberOrNull(newBevilling.ppr_sagsbehandler_id),
        ansoegningsdato:             emptyToNull(newBevilling.ansoegningsdato),
        sagsbehandlingsdato:         emptyToNull(newBevilling.sagsbehandlingsdato),
        relation_til_barnet:         emptyToNull(newBevilling.relation_til_barnet),
        foerste_koersel_dato:        emptyToNull(newBevilling.foerste_koersel_dato),
        ansoegningstype:             emptyToNull(newBevilling.ansoegningstype),
        afstandskriterie_dato:       isMidlertidig ? null : emptyToNull(newBevilling.afstandskriterie_dato),
        afstandskriterie_klassetrin: isMidlertidig ? null : numberOrNull(newBevilling.afstandskriterie_klassetrin),
        begrundelse_fra_formular:    emptyToNull(newBevilling.begrundelse_fra_formular),
        hjaelpemiddel_ids:           newBevilling.hjaelpemiddel_ids ?? [],
      };
      const res = await backendFetch(
        `/bevilling/create_bevilling/${cpr}?status_text=${encodeURIComponent("Kommende")}`,
        { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) }
      );
      if (!res.ok) {
        let message = "Kunne ikke oprette bevilling";
        try {
          const err = await res.json();
          message = err?.detail?.message ?? (Array.isArray(err?.detail) ? err.detail.map((e: any) => e.msg ?? JSON.stringify(e)).join("\n") : err?.detail) ?? message;
        } catch { /* keep fallback */ }
        modalError = `Fejl ${res.status}: ${message}`;
        return;
      }
      dispatch('created');
    }

    async function handleCreateBevillingAndKoersel() {
      modalError = null;
      if (!newBevilling.adresse_id) { modalError = "Adresse mangler"; return; }
      if (!validateBevillingDates()) return;
      if (!modalKoersel.befordringstype_id) { modalError = "Kørselstype skal udfyldes"; return; }
      if (!modalKoersel.tidspunkt_id)       { modalError = "Tidspunkt skal udfyldes"; return; }
      if (!modalKoersel.gyldig_fra)         { modalError = "Gyldig fra skal udfyldes"; return; }
      if (!modalKoersel.gyldig_til)         { modalError = "Gyldig til skal udfyldes"; return; }
      if (isDateOutOfRange(modalKoersel.gyldig_fra)) { modalError = "Gyldig fra: Dato er ugyldig — kontrollér årstallet"; return; }
      if (isDateOutOfRange(modalKoersel.gyldig_til))  { modalError = "Gyldig til: Dato er ugyldig — kontrollér årstallet"; return; }
      if (modalKoersel.gyldig_fra && modalKoersel.gyldig_til && modalKoersel.gyldig_fra > modalKoersel.gyldig_til) {
        modalError = "Gyldig fra kan ikke være efter gyldig til";
        return;
      }
      if (modalKoerselDagIds.length === 0) { modalError = "Mindst én dag skal vælges"; return; }    
      if (isModalKoerselEgenbefordring(modalKoersel.befordringstype_id) && !modalKoersel.bevilget_koereafstand_pr_vej) {
        modalError = "Bevilget km pr. vej skal udfyldes";
        return;
      }
      if (isModalKoerselSkolerejsekort(modalKoersel.befordringstype_id)) {
        if (modalKoersel.transporttid_i_bus === "" || modalKoersel.transporttid_i_bus == null) { modalError = "Transporttid i bus skal udfyldes"; return; }
        if (modalKoersel.skift_med_bus === "" || modalKoersel.skift_med_bus == null)           { modalError = "Antal skift skal udfyldes"; return; }
      }
      isCreatingKoerselInModal = true;
      const payload = {
        adresse_id:                  newBevilling.adresse_id,
        matrikel_id:                 (isMidlertidig && skoleType === 'ungdomsuddannelse') ? null : numberOrNull(newBevilling.matrikel_id),
        ungdomsuddannelse_id:        (isMidlertidig && skoleType === 'ungdomsuddannelse') ? numberOrNull(newBevilling.ungdomsuddannelse_id) : null,
        hjemmel_id:                  numberOrNull(newBevilling.hjemmel_id),
        afgoerelsesbrev_id:          numberOrNull(newBevilling.afgoerelsesbrev_id),
        revurderingsdato:            emptyToNull(newBevilling.revurderingsdato),
        befordringsudvalg:           isMidlertidig ? null : emptyToNull(newBevilling.befordringsudvalg),
        esdh_noegle:                 emptyToNull(newBevilling.esdh_noegle),
        sagsbehandler_id:            numberOrNull(newBevilling.sagsbehandler_id),
        ppr_sagsbehandler_id:        isMidlertidig ? null : numberOrNull(newBevilling.ppr_sagsbehandler_id),
        ansoegningsdato:             emptyToNull(newBevilling.ansoegningsdato),
        sagsbehandlingsdato:         emptyToNull(newBevilling.sagsbehandlingsdato),
        relation_til_barnet:         emptyToNull(newBevilling.relation_til_barnet),
        foerste_koersel_dato:        emptyToNull(newBevilling.foerste_koersel_dato),
        ansoegningstype:             emptyToNull(newBevilling.ansoegningstype),
        afstandskriterie_dato:       isMidlertidig ? null : emptyToNull(newBevilling.afstandskriterie_dato),
        afstandskriterie_klassetrin: isMidlertidig ? null : numberOrNull(newBevilling.afstandskriterie_klassetrin),
        begrundelse_fra_formular:    emptyToNull(newBevilling.begrundelse_fra_formular),
        hjaelpemiddel_ids:           newBevilling.hjaelpemiddel_ids ?? [],
      };
      try {
        const bevRes = await backendFetch(
          `/bevilling/create_bevilling/${cpr}?status_text=${encodeURIComponent("Kommende")}`,
          { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) }
        );
        if (!bevRes.ok) {
          let message = "Kunne ikke oprette bevilling";
          try { const err = await bevRes.json(); message = err?.detail?.message ?? err?.detail ?? message; } catch { /* keep fallback */ }
          modalError = `Fejl ${bevRes.status}: ${message}`;
          return;
        }
        const { bevilling_id: newBevillingId } = await bevRes.json();
        const krPayload = {
          tidspunkt_id:                 numberOrNull(modalKoersel.tidspunkt_id),
          befordringstype_id:           numberOrNull(modalKoersel.befordringstype_id),
          bevilget_koereafstand_pr_vej: Number(modalKoersel.bevilget_koereafstand_pr_vej) || 0,
          gyldig_fra:                   modalKoersel.gyldig_fra || null,
          gyldig_til:                   modalKoersel.gyldig_til || null,
          taxa_id:                      isModalKoerselTaxaType(modalKoersel.befordringstype_id) ? (modalKoersel.taxa_id || null) : null,
          kommentar:                    modalKoersel.kommentar || "",
          final:                        false,
          tillaeg_ids:                  modalKoerselTillaegIds,
          dag_ids:                      modalKoerselDagIds,
          transporttid_i_bus:            isModalKoerselSkolerejsekort(modalKoersel.befordringstype_id) ? numberOrNull(modalKoersel.transporttid_i_bus) : null,
          skift_med_bus:                 isModalKoerselSkolerejsekort(modalKoersel.befordringstype_id) ? numberOrNull(modalKoersel.skift_med_bus) : null,
        };
        const krRes = await backendFetch(
          `/bevilling/create_koerselsraekke/${newBevillingId}`,
          { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(krPayload) }
        );
        if (!krRes.ok) {
          let message = "Ukendt fejl";
          try { const err = await krRes.json(); message = err?.detail?.message ?? err?.detail ?? message; } catch { /* keep fallback */ }
          modalError = `Bevilling oprettet, men kørselsrækken fejlede: ${message}`;
          return;
        }
        dispatch('created');
      } finally {
        isCreatingKoerselInModal = false;
      }
    }

    onMount(() => {
      createBevillingStep = 1;
      resetCreateBevillingForm();
      if (mode === 'kopi') {
        const activeBev = existingBevillinger.find((b: any) => b.status_tekst === 'Aktiv') ?? existingBevillinger[0];
        selectedSourceBevillingId = activeBev?.bevilling_id ?? null;
        resetModalKoersel('kopi', activeBev);
        if (activeBev) prefillFromBevilling(activeBev);
      } else {
        resetModalKoersel('tom');
      }

      // Last, so it also wins over a copied bevilling's values: those were
      // right for the klassetrin the student was in then, and a revurdering is
      // precisely when that has moved on.
      applyBeregnetAfstandskriterie();
    });
  </script>

  <!-- Backdrop -->
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" role="presentation">
    <div class="w-[750px] max-h-[90vh] overflow-y-auto bg-white rounded-lg shadow-2xl" role="dialog" aria-modal="true" tabindex="-1">

      <div class="sticky top-0 z-10 px-8 py-5 border-b border-gray-200" style="background-color: #032A42;">
        <h2 class="text-lg font-bold text-white">Opret ny bevilling</h2>
        <p class="mt-0.5 text-sm" style="color: rgba(255,255,255,0.7);">
          {createBevillingStep === 1 ? 'Trin 1 af 2 — Bevillingsoplysninger' : 'Trin 2 af 2 — Kørselsrække'}
        </p>
      </div>

     {#if createBevillingStep === 1}
      <div class="p-8">
        <div class="grid grid-cols-2 gap-5">

          {#if mode === 'kopi'}
          <label class="text-sm font-medium text-gray-700 col-span-2">
            Kopier fra bevilling
            <select
              class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm"
              bind:value={selectedSourceBevillingId}
              on:change={() => {
                const bev = existingBevillinger.find((b: any) => b.bevilling_id === selectedSourceBevillingId) ?? null;
                if (bev) { prefillFromBevilling(bev); resetModalKoersel('kopi', bev); applyBeregnetAfstandskriterie(); }
              }}
            >
              {#each existingBevillinger as bev}
                <option value={bev.bevilling_id}>Bevilling #{bev.bevilling_id} — {bev.status_tekst ?? 'Ukendt status'}</option>
              {/each}
            </select>
          </label>
          {/if}

          <label class="text-sm font-medium text-gray-700 col-span-2">
            Ansøgningstype <span class="text-red-500">*</span>
            <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.ansoegningstype} on:change={onAnsoegningstypeChange}>
              <option value="">Vælg ansøgningstype</option>
              <option value="Kørsel">Kørsel</option>
              <option value="Midlertidig kørsel">Midlertidig kørsel</option>
            </select>
          </label>

          {#if newBevilling.ansoegningstype === "Midlertidig kørsel"}
            <div class="col-span-2">
              <p class="text-sm font-medium text-gray-700 mb-2">Skole type <span class="text-red-500">*</span></p>
              <div class="flex gap-2">
                <button type="button"
                  class="flex-1 py-2 text-sm font-medium rounded border transition-colors"
                  style={skoleType === 'folkeskole' ? 'background-color:#032A42;color:#fff;border-color:#032A42;' : 'background-color:#fff;color:#374151;border-color:#d1d5db;'}
                  on:click={() => { skoleType = 'folkeskole'; resetLookupSelections(); }}>Folkeskole</button>
                <button type="button"
                  class="flex-1 py-2 text-sm font-medium rounded border transition-colors"
                  style={skoleType === 'ungdomsuddannelse' ? 'background-color:#032A42;color:#fff;border-color:#032A42;' : 'background-color:#fff;color:#374151;border-color:#d1d5db;'}
                  on:click={() => { skoleType = 'ungdomsuddannelse'; resetLookupSelections(); }}>Ungdomsuddannelse</button>
              </div>
            </div>
            {#if skoleType === 'folkeskole'}
              <label class="text-sm font-medium text-gray-700 col-span-2">
                Folkeskole (matrikel) <span class="text-red-500">*</span>
                <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.matrikel_id}>
                  <option value="">Vælg</option>
                  {#each lookupOptions.skolematrikler ?? [] as option}
                    <option value={String(option.id)}>{option.label}</option>
                  {/each}
                </select>
              </label>
            {:else if skoleType === 'ungdomsuddannelse'}
              <label class="text-sm font-medium text-gray-700 col-span-2">
                Ungdomsuddannelse <span class="text-red-500">*</span>
                <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.ungdomsuddannelse_id}>
                  <option value="">Vælg</option>
                  {#each lookupOptions.ungdomsuddannelser ?? [] as option}
                    <option value={String(option.id)}>{option.label}</option>
                  {/each}
                </select>
              </label>
            {/if}
          {:else if newBevilling.ansoegningstype}
            <label class="text-sm font-medium text-gray-700 col-span-2">
              Folkeskole (matrikel) <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.matrikel_id}>
                <option value="">Vælg</option>
                {#each lookupOptions.skolematrikler ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>
          {/if}

          {#if (newBevilling.ansoegningstype && newBevilling.ansoegningstype !== "Midlertidig kørsel") || (newBevilling.ansoegningstype === "Midlertidig kørsel" && skoleType !== null)}

            <label class="text-sm font-medium text-gray-700 col-span-2">
              Adresse for bevilling <span class="text-red-500">*</span>
              <div class="mt-1.5">
                <AddresseSearch
                  adresseId={newBevilling.adresse_id}
                  adresseTekst={newBevilling.adresse_tekst}
                  onSelect={(result) => {
                    newBevilling = { ...newBevilling, adresse_id: result?.adresse_id ?? null, adresse_tekst: result?.adresse_tekst ?? "" };
                  }}
                />
              </div>
            </label>

            <label class="text-sm font-medium text-gray-700">
              Hjemmel <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.hjemmel_id}
                on:change={() => { newBevilling = { ...newBevilling, afgoerelsesbrev_id: "" }; }}>
                <option value="">Vælg</option>
                {#each visibleHjemler as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm font-medium text-gray-700">
              Afgørelsesbrev <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.afgoerelsesbrev_id}>
                <option value="">Vælg</option>
                {#each visibleAfgoerelsesbreve as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm font-medium text-gray-700">
              Revurdering
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.revurderingsdato} />
            </label>

            {#if !isMidlertidig}
            <label class="text-sm font-medium text-gray-700">
              Befordringsudvalg
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.befordringsudvalg} />
            </label>
            {/if}

            <label class="text-sm font-medium text-gray-700">
              ESDH-nøgle
              <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.esdh_noegle} />
            </label>

            <label class="text-sm font-medium text-gray-700">
              Sagsbehandler <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.sagsbehandler_id}>
                <option value="">Vælg</option>
                {#each lookupOptions.sagsbehandlere ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            {#if !isMidlertidig}
            <label class="text-sm font-medium text-gray-700">
              PPR ansvarlig
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.ppr_sagsbehandler_id}>
                <option value="">Vælg</option>
                {#each lookupOptions.pprSagsbehandlere ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>
            {/if}

            <label class="text-sm font-medium text-gray-700">
              Sagsbehandlingsdato
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.sagsbehandlingsdato} />
            </label>

            <label class="text-sm font-medium text-gray-700">
              Ansøger relation
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.relation_til_barnet}>
                <option value="">Vælg</option>
                {#each ansoegerRelationOptions(newBevilling.relation_til_barnet) as relation}
                  <option value={relation}>{relation}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm font-medium text-gray-700">
              Dato for første kørsel
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.foerste_koersel_dato} />
            </label>

            {#if !isMidlertidig}
            <label class="text-sm font-medium text-gray-700">
              Afstandskriterie dato
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.afstandskriterie_dato} />
              {#if beregnetDato}
                <span class="mt-1 block text-[11px] font-normal text-gray-500">
                  Beregnet ud fra elevens klassetrin — kan rettes
                </span>
              {/if}
            </label>
            {/if}

            {#if !isMidlertidig}
            <label class="text-sm font-medium text-gray-700">
              Afstandskriterie klassetrin
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.afstandskriterie_klassetrin}>
                <option value="">Vælg</option>
                {#each klassetrinOptions(newBevilling.afstandskriterie_klassetrin) as trin}
                  <option value={trin}>{trin}</option>
                {/each}
              </select>
              {#if beregnetKlassetrin !== null}
                <span class="mt-1 block text-[11px] font-normal text-gray-500">
                  Beregnet ud fra elevens klassetrin — kan rettes
                </span>
              {/if}
            </label>
            {/if}

            <div class="col-span-2">
              <p class="text-sm font-medium text-gray-700 mb-1.5">Begrundelse</p>
              <div class="border border-gray-300 rounded p-3">
                <div class="mb-2 flex flex-wrap gap-1.5">
                  {#each selectedBegrundelser as val}
                    <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                      {val}
                      <button type="button" class="ml-1 text-red-500 hover:text-red-700 font-bold"
                        on:click={() => removeBegrundelse(val)}>×</button>
                    </span>
                  {/each}
                </div>
                <select class="w-full border border-gray-300 rounded px-2 py-1.5 text-sm"
                  bind:value={begrundelseSelectValue}
                  on:change={addBegrundelse}>
                  <option value="">Tilføj begrundelse</option>
                  {#each begrundelseOptions.filter(o => !selectedBegrundelser.includes(o)) as opt}
                    <option value={opt}>{opt}</option>
                  {/each}
                </select>
              </div>
            </div>

          {/if}

        </div>
      </div>

      {:else}

      <!-- Step 2: Kørselsrække -->
      <div class="p-8">
        <div class="grid grid-cols-2 gap-5">

          {#if isModalKoerselEgenbefordring(modalKoersel.befordringstype_id)}
            <!-- Egenbefordring -->
            <label class="text-sm font-medium text-gray-700">
              Tidspunkt <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.tidspunkt_id}>
                <option value="">Vælg</option>
                {#each tidspunkter as opt}<option value={opt.id}>{opt.label}</option>{/each}
              </select>
            </label>
            <label class="text-sm font-medium text-gray-700">
              Kørselstype <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm"
                bind:value={modalKoersel.befordringstype_id}
                on:change={() => {
                  calculateModalKoerselDistance(modalKoersel.befordringstype_id);
                  if (!isModalKoerselTaxaType(modalKoersel.befordringstype_id)) modalKoerselTillaegIds = [];
                }}
              >
                <option value="">Vælg</option>
                {#each koerselstyper as opt}<option value={opt.id}>{opt.label}</option>{/each}
              </select>
            </label>
            <label class="text-sm font-medium text-gray-700">
              Gyldig fra <span class="text-red-500">*</span>
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.gyldig_fra} />
            </label>
            <label class="text-sm font-medium text-gray-700">
              Gyldig til <span class="text-red-500">*</span>
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.gyldig_til} />
            </label>
            <label class="text-sm font-medium text-gray-700">
              Bevilget km pr. vej <span class="text-red-500">*</span>
              {#if isCalculatingModalKoerselDistance}
                <span class="ml-1 text-blue-500 text-xs font-normal">beregner...</span>
              {/if}
              <input type="number" step="0.1"
                class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm {isCalculatingModalKoerselDistance ? 'opacity-50' : ''}"
                disabled={isCalculatingModalKoerselDistance}
                bind:value={modalKoersel.bevilget_koereafstand_pr_vej} />
            </label>
            <label class="text-sm font-medium text-gray-700 col-span-2">
              Dage <span class="text-red-500">*</span>
              <div class="mt-1.5 border border-gray-300 rounded p-3">
                <div class="mb-2 flex flex-wrap gap-1.5">
                  {#each modalKoerselDagIds as id}
                    {@const opt = dage.find((d: any) => Number(d.id) === id)}
                    <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                      {opt?.label ?? id}
                      <button type="button" class="ml-1 text-red-500 hover:text-red-700 font-bold"
                        on:click={() => { modalKoerselDagIds = modalKoerselDagIds.filter(x => x !== id); }}>×</button>
                    </span>
                  {/each}
                </div>
                <select class="w-full border border-gray-300 rounded px-2 py-1.5 text-sm"
                  bind:value={modalKoerselDagSelectValue}
                  on:change={(e) => {
                    const val = Number(e.currentTarget.value);
                    if (val && !modalKoerselDagIds.includes(val)) modalKoerselDagIds = [...modalKoerselDagIds, val];
                    modalKoerselDagSelectValue = "";
                  }}>
                  <option value="">Tilføj dag</option>
                  {#each dage.filter((d: any) => !modalKoerselDagIds.includes(Number(d.id))) as opt}
                    <option value={String(opt.id)}>{opt.label}</option>
                  {/each}
                </select>
              </div>
            </label>
            <label class="text-sm font-medium text-gray-700 col-span-2">
              Kommentar
              <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.kommentar} />
            </label>

          {:else if TAXA_TYPES.has(modalBefordringstypeLabel)}
            <!-- TAXA -->
            <label class="text-sm font-medium text-gray-700">
              Tidspunkt <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.tidspunkt_id}>
                <option value="">Vælg</option>
                {#each tidspunkter as opt}<option value={opt.id}>{opt.label}</option>{/each}
              </select>
            </label>
            <label class="text-sm font-medium text-gray-700">
              Kørselstype <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm"
                bind:value={modalKoersel.befordringstype_id}
                on:change={() => {
                  calculateModalKoerselDistance(modalKoersel.befordringstype_id);
                  if (!isModalKoerselTaxaType(modalKoersel.befordringstype_id)) modalKoerselTillaegIds = [];
                }}
              >
                <option value="">Vælg</option>
                {#each koerselstyper as opt}<option value={opt.id}>{opt.label}</option>{/each}
              </select>
            </label>
            <label class="text-sm font-medium text-gray-700">
              Gyldig fra <span class="text-red-500">*</span>
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.gyldig_fra} />
            </label>
            <label class="text-sm font-medium text-gray-700">
              Gyldig til <span class="text-red-500">*</span>
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.gyldig_til} />
            </label>
            <label class="text-sm font-medium text-gray-700">
              Taxa-ID
              <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.taxa_id} />
            </label>
            <label class="text-sm font-medium text-gray-700 col-span-2">
              Kørselstype tillæg
              <div class="mt-1.5 border border-gray-300 rounded p-3">
                <div class="mb-2 flex flex-wrap gap-1.5">
                  {#each modalKoerselTillaegIds as id}
                    {@const opt = koerselstypeTillaeg.find((t: any) => Number(t.id) === id)}
                    <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                      {opt?.label ?? id}
                      <button type="button" class="ml-1 text-red-500 hover:text-red-700 font-bold"
                        on:click={() => { modalKoerselTillaegIds = modalKoerselTillaegIds.filter(x => x !== id); }}>×</button>
                    </span>
                  {/each}
                </div>
                <select class="w-full border border-gray-300 rounded px-2 py-1.5 text-sm"
                  bind:value={modalKoerselTillaegSelectValue}
                  on:change={(e) => {
                    const val = Number(e.currentTarget.value);
                    if (val && !modalKoerselTillaegIds.includes(val)) modalKoerselTillaegIds = [...modalKoerselTillaegIds, val];
                    modalKoerselTillaegSelectValue = "";
                  }}>
                  <option value="">Tilføj tillæg</option>
                  {#each koerselstypeTillaeg.filter((t: any) => !modalKoerselTillaegIds.includes(Number(t.id))) as opt}
                    <option value={String(opt.id)}>{opt.label}</option>
                  {/each}
                </select>
              </div>
            </label>
            <label class="text-sm font-medium text-gray-700 col-span-2">
              Dage <span class="text-red-500">*</span>
              <div class="mt-1.5 border border-gray-300 rounded p-3">
                <div class="mb-2 flex flex-wrap gap-1.5">
                  {#each modalKoerselDagIds as id}
                    {@const opt = dage.find((d: any) => Number(d.id) === id)}
                    <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                      {opt?.label ?? id}
                      <button type="button" class="ml-1 text-red-500 hover:text-red-700 font-bold"
                        on:click={() => { modalKoerselDagIds = modalKoerselDagIds.filter(x => x !== id); }}>×</button>
                    </span>
                  {/each}
                </div>
                <select class="w-full border border-gray-300 rounded px-2 py-1.5 text-sm"
                  bind:value={modalKoerselDagSelectValue}
                  on:change={(e) => {
                    const val = Number(e.currentTarget.value);
                    if (val && !modalKoerselDagIds.includes(val)) modalKoerselDagIds = [...modalKoerselDagIds, val];
                    modalKoerselDagSelectValue = "";
                  }}>
                  <option value="">Tilføj dag</option>
                  {#each dage.filter((d: any) => !modalKoerselDagIds.includes(Number(d.id))) as opt}
                    <option value={String(opt.id)}>{opt.label}</option>
                  {/each}
                </select>
              </div>
            </label>
            <label class="text-sm font-medium text-gray-700 col-span-2">
              Kommentar
              <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.kommentar} />
            </label>

          {:else if modalBefordringstypeLabel === 'skolerejsekort'}
            <!-- Skolerejsekort -->
            <label class="text-sm font-medium text-gray-700">
              Tidspunkt <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.tidspunkt_id}>
                <option value="">Vælg</option>
                {#each tidspunkter as opt}<option value={opt.id}>{opt.label}</option>{/each}
              </select>
            </label>
            <label class="text-sm font-medium text-gray-700">
              Kørselstype <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm"
                bind:value={modalKoersel.befordringstype_id}
                on:change={() => {
                  calculateModalKoerselDistance(modalKoersel.befordringstype_id);
                  if (!isModalKoerselTaxaType(modalKoersel.befordringstype_id)) modalKoerselTillaegIds = [];
                }}
              >
                <option value="">Vælg</option>
                {#each koerselstyper as opt}<option value={opt.id}>{opt.label}</option>{/each}
              </select>
            </label>
            <label class="text-sm font-medium text-gray-700">
              Gyldig fra <span class="text-red-500">*</span>
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.gyldig_fra} />
            </label>
            <label class="text-sm font-medium text-gray-700">
              Gyldig til <span class="text-red-500">*</span>
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.gyldig_til} />
            </label>
            <label class="text-sm font-medium text-gray-700">
              Transporttid i bus (min.) <span class="text-red-500">*</span>
              <input type="number" min="0" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.transporttid_i_bus} />
            </label>
            <label class="text-sm font-medium text-gray-700">
              Antal skift <span class="text-red-500">*</span>
              <input type="number" min="0" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.skift_med_bus} />
            </label>
            <label class="text-sm font-medium text-gray-700 col-span-2">
              Dage <span class="text-red-500">*</span>
              <div class="mt-1.5 border border-gray-300 rounded p-3">
                <div class="mb-2 flex flex-wrap gap-1.5">
                  {#each modalKoerselDagIds as id}
                    {@const opt = dage.find((d: any) => Number(d.id) === id)}
                    <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                      {opt?.label ?? id}
                      <button type="button" class="ml-1 text-red-500 hover:text-red-700 font-bold"
                        on:click={() => { modalKoerselDagIds = modalKoerselDagIds.filter(x => x !== id); }}>×</button>
                    </span>
                  {/each}
                </div>
                <select class="w-full border border-gray-300 rounded px-2 py-1.5 text-sm"
                  bind:value={modalKoerselDagSelectValue}
                  on:change={(e) => {
                    const val = Number(e.currentTarget.value);
                    if (val && !modalKoerselDagIds.includes(val)) modalKoerselDagIds = [...modalKoerselDagIds, val];
                    modalKoerselDagSelectValue = "";
                  }}>
                  <option value="">Tilføj dag</option>
                  {#each dage.filter((d: any) => !modalKoerselDagIds.includes(Number(d.id))) as opt}
                    <option value={String(opt.id)}>{opt.label}</option>
                  {/each}
                </select>
              </div>            
            </label>
            <label class="text-sm font-medium text-gray-700 col-span-2">
              Kommentar
              <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.kommentar} />
            </label>

          {:else}
            <!-- Default (Skolebus, Gåbus, Cykelbus, etc.) -->
            <label class="text-sm font-medium text-gray-700">
              Tidspunkt <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.tidspunkt_id}>
                <option value="">Vælg</option>
                {#each tidspunkter as opt}<option value={opt.id}>{opt.label}</option>{/each}
              </select>
            </label>
            <label class="text-sm font-medium text-gray-700">
              Kørselstype <span class="text-red-500">*</span>
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm"
                bind:value={modalKoersel.befordringstype_id}
                on:change={() => {
                  calculateModalKoerselDistance(modalKoersel.befordringstype_id);
                  if (!isModalKoerselTaxaType(modalKoersel.befordringstype_id)) modalKoerselTillaegIds = [];
                }}
              >
                <option value="">Vælg</option>
                {#each koerselstyper as opt}<option value={opt.id}>{opt.label}</option>{/each}
              </select>
            </label>
            <label class="text-sm font-medium text-gray-700">
              Gyldig fra <span class="text-red-500">*</span>
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.gyldig_fra} />
            </label>
            <label class="text-sm font-medium text-gray-700">
              Gyldig til <span class="text-red-500">*</span>
              <input type="date" min={minDate} max={maxDate} class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.gyldig_til} />
            </label>
            <label class="text-sm font-medium text-gray-700 col-span-2">
              Dage <span class="text-red-500">*</span>
              <div class="mt-1.5 border border-gray-300 rounded p-3">
                <div class="mb-2 flex flex-wrap gap-1.5">
                  {#each modalKoerselDagIds as id}
                    {@const opt = dage.find((d: any) => Number(d.id) === id)}
                    <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                      {opt?.label ?? id}
                      <button type="button" class="ml-1 text-red-500 hover:text-red-700 font-bold"
                        on:click={() => { modalKoerselDagIds = modalKoerselDagIds.filter(x => x !== id); }}>×</button>
                    </span>
                  {/each}
                </div>
                <select class="w-full border border-gray-300 rounded px-2 py-1.5 text-sm"
                  bind:value={modalKoerselDagSelectValue}
                  on:change={(e) => {
                    const val = Number(e.currentTarget.value);
                    if (val && !modalKoerselDagIds.includes(val)) modalKoerselDagIds = [...modalKoerselDagIds, val];
                    modalKoerselDagSelectValue = "";
                  }}>
                  <option value="">Tilføj dag</option>
                  {#each dage.filter((d: any) => !modalKoerselDagIds.includes(Number(d.id))) as opt}
                    <option value={String(opt.id)}>{opt.label}</option>
                  {/each}
                </select>
              </div>
            </label>
            <label class="text-sm font-medium text-gray-700 col-span-2">
              Kommentar
              <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.kommentar} />
            </label>
          {/if}

          {#if modalKoerselDistanceError}
            <div class="col-span-2 px-3 py-2 text-xs text-red-700 bg-red-50 border border-red-200 rounded">
              {modalKoerselDistanceError}
            </div>
          {/if}

      </div>
    </div>

    {/if}

    <!-- Footer: different buttons per step -->
    {#if modalError}
      <div class="mx-8 mb-4 px-3 py-2 text-sm text-red-700 bg-red-50 border border-red-200 rounded">
        {modalError}
      </div>
    {/if}

    {#if createBevillingStep === 1}
    <div class="flex justify-end gap-3 border-t border-gray-200 px-8 py-5">
      <button type="button"
        class="px-5 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
        on:click={() => dispatch('cancel')}>
        Annullér
      </button>
      <button type="button"
        disabled={!newBevilling.ansoegningstype}
        class="px-5 py-2 text-sm font-medium text-white rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        style="background-color: #032A42;"
        on:click={handleCreateBevilling}>
        Opret bevilling
      </button>
      <button type="button"
        disabled={!newBevilling.adresse_id}
        class="px-5 py-2 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        on:click={handleGoToStep2}>
        Tilføj Kørselsrækker →
      </button>
    </div>
    {:else}
    <div class="flex items-center justify-between border-t border-gray-200 px-8 py-5">
      <button type="button"
        class="px-4 py-2 text-sm font-medium text-gray-600 hover:text-gray-900 flex items-center gap-1 transition-colors"
        on:click={() => { modalError = null; createBevillingStep = 1; }}>
        ← Tilbage
      </button>
      <div class="flex gap-3">
        <button type="button"
          class="px-5 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
          on:click={() => dispatch('cancel')}>
          Annullér
        </button>
        <button type="button"
          disabled={isCreatingKoerselInModal || !newBevilling.adresse_id}
          class="px-5 py-2 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          on:click={handleCreateBevillingAndKoersel}>
          {isCreatingKoerselInModal ? 'Opretter...' : 'Opret bevilling + kørsel'}
        </button>
      </div>
    </div>
    {/if}

  </div>
</div>