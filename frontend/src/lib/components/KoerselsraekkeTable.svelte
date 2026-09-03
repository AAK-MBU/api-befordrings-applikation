<script lang="ts">
  import { page } from "$app/stores";
  import { formatDanishDate } from "$lib/tableColumnConfig";
  import { backendFetch } from "$lib/client/backendFetch";
  import TagMultiSelect from "$lib/components/TagMultiSelect.svelte";

  const minDate = new Date(new Date().getFullYear() - 10, 0, 1).toISOString().slice(0, 10);
  const maxDate = new Date(new Date().getFullYear() + 10, 11, 31).toISOString().slice(0, 10);

  function isDateOutOfRange(value: string | null | undefined): boolean {
    return !!value && (value < minDate || value > maxDate);
  }

  // -----------------------------
  // Props
  // -----------------------------

  export let rows: any[] = [];

  export let lookupOptions: any = {
    tidspunkter: [],
    koerselstyper: [],
    koerselstypeTillaeg: [],
    dage: [],
    rutetyper: []
  };

  export let onCreateKoerselsraekke: (
    updates: any
  ) => Promise<string | null>;

  export let onSaveKoerselsraekke: (
    koerselId: number,
    updates: any
  ) => Promise<string | null>;

  export let onFinalizeKoerselsraekke: (
    koerselId: number
  ) => Promise<string | null>;

  export let adresseForBevilling: string = "";
  export let matrikelId: number | null = null;
  export let readonly: boolean = false;

  // Parties on the case, used by the egenbefordring kørselsrække to name the
  // recipient of the kilometre reimbursement.
  export let parter: any[] = [];

  // The bevilling's ansøgningstype. Only "Midlertidig kørsel" restricts which
  // kørselstyper may be chosen; every other type shows the full lookup.
  export let ansoegningstype: string = "";

  // Optional — if not provided, the delete button is hidden entirely.
  // Wire this up from the parent page only for users with the correct role.
  export let onDeleteKoerselsraekke: ((koerselId: number) => Promise<string | null>) | undefined = undefined;


  // -----------------------------
  // Distance calculation
  // -----------------------------

  let isCalculatingDistance = false;
  let distanceCalcTarget: 'edit' | 'new' | null = null;  // drives the spinner only
  let distanceErrorFrom: 'edit' | 'new' | null = null;   // persists after finally for display
  let distanceError: string | null = null;

  // Kørselstyper where Taxa-ID is relevant.
  const TAXA_TYPES = new Set(['rutekørsel', 'skånekørsel', 'solokørsel', 'variabel kørsel']);

  // Kørselstyper the midlertidig-kørsel form actually offers. The lookup table
  // holds every type used anywhere in the system, so without this a caseworker
  // can pick one the form could never have produced.
  const MIDLERTIDIG_ALLOWED = new Set([
    'egenbefordring', 'skolerejsekort', 'rutekørsel',
    'solokørsel', 'variabelkørsel', 'skånekørsel',
  ]);

  // Compared with whitespace stripped, because the lookup labels are not
  // consistent about it ("Variabel kørsel" vs "Variabelkørsel").
  $: availableKoerselstyper = ansoegningstype === 'Midlertidig kørsel'
    ? (lookupOptions.koerselstyper ?? []).filter(
        (type: any) => MIDLERTIDIG_ALLOWED.has(normalizeType(type.label).replace(/\s/g, ''))
      )
    : (lookupOptions.koerselstyper ?? []);

  function normalizeType(label: string | null | undefined): string {
    return String(label ?? '').trim().toLowerCase();
  }

  function labelForType(typeId: string | number | null | undefined): string | undefined {
    if (!typeId) return undefined;
    return lookupOptions.koerselstyper?.find(
      (t: any) => Number(t.id) === Number(typeId)
    )?.label;
  }

  // Tolerate both "Egen befordring" and "Egenbefordring".
  function labelIsEgenbefordring(label: string | null | undefined): boolean {
    return normalizeType(label).replace(/\s/g, '') === 'egenbefordring';
  }

  function labelIsTaxa(label: string | null | undefined): boolean {
    return TAXA_TYPES.has(normalizeType(label));
  }

  function isEgenbefordring(typeId: string | number | null | undefined): boolean {
    return labelIsEgenbefordring(labelForType(typeId));
  }

  function isTaxaType(typeId: string | number | null | undefined): boolean {
    return labelIsTaxa(labelForType(typeId));
  }

  // Tillæg only applies to befordringstyper that are a form of "kørsel"
  // (e.g. Rutekørsel, Skånekørsel) — not Skolerejsekort, Skolebus, Cykelbus, etc.
  function labelIsKoersel(label: string | null | undefined): boolean {
    return TAXA_TYPES.has(normalizeType(label));
  }

  function isKoerselType(typeId: string | number | null | undefined): boolean {
    return labelIsKoersel(labelForType(typeId));
  }

  // Transporttid i bus / antal skift only apply to Skolerejsekort.
  function labelIsSkolerejsekort(label: string | null | undefined): boolean {
    return normalizeType(label) === 'skolerejsekort';
  }

  function isSkolerejsekort(typeId: string | number | null | undefined): boolean {
    return labelIsSkolerejsekort(labelForType(typeId));
  }

  async function calculateAndFillDistance(
    befordringtypeId: string | number | null,
    target: 'edit' | 'new'
  ) {
    if (!isEgenbefordring(befordringtypeId)) {
      if (target === 'new') {
        updateNewField('bevilget_koereafstand_pr_vej', '');
      } else {
        updateField('bevilget_koereafstand_pr_vej', '');
      }
      return;
    }

    if (!adresseForBevilling) {
      distanceError = 'Ingen adresse på bevillingen — kan ikke beregne afstand';
      return;
    }

    if (!matrikelId) {
      distanceError = 'Ingen skole valgt på bevillingen — kan ikke beregne afstand';
      return;
    }

    isCalculatingDistance = true;
    distanceCalcTarget = target;
    distanceError = null;
    distanceErrorFrom = null;

    try {
      // 1. Geocode the citizen's address
      const geocodeRes = await backendFetch(
        `/bevilling/geocode_address?address=${encodeURIComponent(adresseForBevilling)}`
      );
      if (!geocodeRes.ok) {
        let detail = 'Kunne ikke geokode adressen';
        try { const body = await geocodeRes.json(); detail = body?.detail ?? detail; } catch { /* keep fallback */ }
        throw new Error(detail);
      }
      const geocodeData = await geocodeRes.json();

      // 2. Get school matrikel coordinates
      const schoolRes = await backendFetch(`/lookup/skolematrikel/${matrikelId}/coordinates`);
      if (!schoolRes.ok) {
        let detail = 'Kunne ikke hente skolens koordinater';
        try { const body = await schoolRes.json(); detail = body?.detail ?? detail; } catch { /* keep fallback */ }
        throw new Error(detail);
      }
      const schoolData = await schoolRes.json();

      // 3. Calculate driving distance
      const distParams = new URLSearchParams({
        lat1: String(geocodeData.latitude),
        lon1: String(geocodeData.longitude),
        lat2: String(schoolData.latitude),
        lon2: String(schoolData.longitude)
      });
      const distRes = await backendFetch(`/bevilling/calculate_driving_distance?${distParams}`);
      if (!distRes.ok) {
        let detail = 'Kunne ikke beregne køreafstand';
        try { const body = await distRes.json(); detail = body?.detail ?? detail; } catch { /* keep fallback */ }
        throw new Error(detail);
      }
      const distData = await distRes.json();

      const distance = distData.distance_km ?? distData.distance ?? distData.driving_distance_km;
      if (distance == null) throw new Error('Ugyldigt svar fra afstandsberegning');

      // 4. Guard: discard if the user changed the type while we were calculating
      const currentTypeId = target === 'new'
        ? newKoerselsraekke.befordringstype_id
        : editableKoerselsraekke.befordringstype_id;
      if (Number(currentTypeId) !== Number(befordringtypeId)) return;

      // 5. Auto-fill the km field
      if (target === 'new') {
        updateNewField('bevilget_koereafstand_pr_vej', String(distance));
      } else {
        updateField('bevilget_koereafstand_pr_vej', String(distance));
      }

    } catch (err: any) {
      distanceError = err?.message ?? 'Fejl ved beregning af afstand';
      distanceErrorFrom = target;
    } finally {
      isCalculatingDistance = false;
      distanceCalcTarget = null;
    }
  }


  // -----------------------------
  // Finalize state
  // -----------------------------

  let confirmingFinalizeId: number | null = null;
  let isFinalizing = false;
  let finalizeError: string | null = null;

  async function doFinalize() {
    if (confirmingFinalizeId === null) return;
    isFinalizing = true;
    const id = confirmingFinalizeId;
    confirmingFinalizeId = null;
    const error = await onFinalizeKoerselsraekke(id);
    if (error) finalizeError = error;
    isFinalizing = false;
  }

  let lockedEditRow: any | null = null;

  // -----------------------------
  // Delete state
  // -----------------------------

  let confirmingDeleteKoerselId: number | null = null;
  let isDeleting = false;
  let deleteError: string | null = null;

  // From $page rather than a prop: this component is nested two levels deep and
  // a module-level store would be shared across concurrent SSR requests.
  $: canEdit = $page.data.user?.can_edit ?? false;

  async function doDeleteKoerselsraekke() {
    if (isDeleting || confirmingDeleteKoerselId === null || !onDeleteKoerselsraekke) return;
    isDeleting = true;
    deleteError = null;

    const error = await onDeleteKoerselsraekke(confirmingDeleteKoerselId);

    isDeleting = false;

    // deleteError is rendered inside this dialog, so the dialog has to outlive
    // the failure. Closing it first — as this did — discarded the reason and
    // made a refused delete look exactly like a successful one.
    if (error) {
      deleteError = error;
      return;
    }

    confirmingDeleteKoerselId = null;
  }

  function doLockedEdit() {
    if (!lockedEditRow) return;
    const row = lockedEditRow;
    lockedEditRow = null;
    editingKoerselId = row.koersel_id;
    editableKoerselsraekke = { ...row };
    selectedTillaegIds = parseIds(row.tillaeg_ids);
    selectedDagIds = parseIds(row.dag_ids);
  }


  // -----------------------------
  // Edit state
  // -----------------------------

  let editingKoerselId: number | null = null;
  let editableKoerselsraekke: any = {};
  let editError: string | null = null;

  let selectedTillaegIds: number[] = [];
  let selectedDagIds: number[] = [];


  // -----------------------------
  // Create state
  // -----------------------------

  let isCreating = false;
  let newKoerselsraekke: any = {};
  let createError: string | null = null;

  let newSelectedTillaegIds: number[] = [];
  let newSelectedDagIds: number[] = [];


  // -----------------------------
  // Styling
  // -----------------------------

  const inputClass = "border border-gray-300 px-2 py-1.5 text-sm rounded w-full focus:border-blue-400 focus:ring-0 bg-white";
  const selectClass = "border border-gray-300 px-2 py-1.5 text-sm rounded w-full focus:border-blue-400 focus:ring-0 bg-white";


  // -----------------------------
  // Small helpers
  // -----------------------------

  // Unanswered means "", null or undefined. Zero is a real answer — 0 skift and
  // 0 minutter are both meaningful — so a plain falsy check would reject them.
  function isBlank(value: unknown): boolean {
    return value === "" || value === null || value === undefined;
  }

  // The Ja/Nej selects carry "true"/"false" strings, while a row loaded from
  // the API carries a real boolean. Unset stays null rather than collapsing to
  // false — "not answered" and "Nej" are different answers.
  function boolOrNull(value: unknown): boolean | null {
    if (value === true || value === "true") return true;
    if (value === false || value === "false") return false;
    return null;
  }

  function numberOrNull(value: string | number | null | undefined) {
    if (value === "" || value === null || value === undefined) {
      return null;
    }

    return Number(value);
  }


  function parseIds(rawValue: string | null | undefined) {
    if (!rawValue) {
      return [];
    }

    return rawValue
      .split(",")
      .map((value) => Number(value))
      .filter((value) => !Number.isNaN(value));
  }


  function getEmptyKoerselsraekke() {
    return {
      tidspunkt_id: "",
      befordringstype_id: "",
      bevilget_koereafstand_pr_vej: "",
      gyldig_fra: "",
      gyldig_til: "",
      taxa_id: "",
      kommentar: "",
      rutetype_id: "",
      koersel_til_institution: "",
      max_minutter_i_transport: "",
      koerselsgodtgoerelse_modtager_id: "",
      final: false
    };
  }


  // -----------------------------
  // Edit row handling
  // -----------------------------

  function startEdit(row: any) {
    if (row.final) { lockedEditRow = row; return; }
    editingKoerselId = row.koersel_id;
    editableKoerselsraekke = { ...row };

    selectedTillaegIds = parseIds(row.tillaeg_ids);
    selectedDagIds = parseIds(row.dag_ids);
  }


  function cancelEdit() {
    editingKoerselId = null;
    editableKoerselsraekke = {};
    editError = null;

    selectedTillaegIds = [];
    selectedDagIds = [];
  }


  function updateField(key: string, value: any) {
    editableKoerselsraekke = {
      ...editableKoerselsraekke,
      [key]: value
    };
  }


  async function saveEdit(row: any) {
    editError = null;

    // The edit form only checked the dates; the same required fields apply on
    // both sides, so the presence checks come first here too.
    if (!editableKoerselsraekke.tidspunkt_id) { editError = "Tidspunkt skal udfyldes"; return; }
    if (!editableKoerselsraekke.gyldig_fra)   { editError = "Gyldig fra skal udfyldes"; return; }
    if (!editableKoerselsraekke.gyldig_til)   { editError = "Gyldig til skal udfyldes"; return; }

    if (isDateOutOfRange(editableKoerselsraekke.gyldig_fra)) {
      editError = "Gyldig fra: Dato er ugyldig — kontrollér årstallet";
      return;
    }
    if (isDateOutOfRange(editableKoerselsraekke.gyldig_til)) {
      editError = "Gyldig til: Dato er ugyldig — kontrollér årstallet";
      return;
    }
    if (editableKoerselsraekke.gyldig_fra && editableKoerselsraekke.gyldig_til &&
        editableKoerselsraekke.gyldig_fra > editableKoerselsraekke.gyldig_til) {
      editError = "Gyldig fra kan ikke være efter gyldig til";
      return;
    }

    const koerselstypeError = validateKoerselstypeFields(
      editableKoerselsraekke,
      editableKoerselsraekke.befordringstype_id,
      selectedDagIds
    );

    if (koerselstypeError) {
      editError = koerselstypeError;
      return;
    }

    const updates = {
      tidspunkt_id: editableKoerselsraekke.tidspunkt_id,
      befordringstype_id: editableKoerselsraekke.befordringstype_id,
      bevilget_koereafstand_pr_vej: numberOrNull(editableKoerselsraekke.bevilget_koereafstand_pr_vej),
      gyldig_fra: editableKoerselsraekke.gyldig_fra,
      gyldig_til: editableKoerselsraekke.gyldig_til,
      taxa_id: editableKoerselsraekke.taxa_id,
      kommentar: editableKoerselsraekke.kommentar,
      rutetype_id: numberOrNull(editableKoerselsraekke.rutetype_id),
      final: false,

      transporttid_i_bus: isSkolerejsekort(editableKoerselsraekke.befordringstype_id) ? numberOrNull(editableKoerselsraekke.transporttid_i_bus) : null,
      skift_med_bus: isSkolerejsekort(editableKoerselsraekke.befordringstype_id) ? numberOrNull(editableKoerselsraekke.skift_med_bus) : null,
      // Only the fields belonging to the chosen kørselstype are sent; the rest
      // are nulled so a value cannot survive a change of type.
      koersel_til_institution: isTaxaType(editableKoerselsraekke.befordringstype_id) ? boolOrNull(editableKoerselsraekke.koersel_til_institution) : null,
      max_minutter_i_transport: isTaxaType(editableKoerselsraekke.befordringstype_id) ? numberOrNull(editableKoerselsraekke.max_minutter_i_transport) : null,
      koerselsgodtgoerelse_modtager_id: isEgenbefordring(editableKoerselsraekke.befordringstype_id) ? numberOrNull(editableKoerselsraekke.koerselsgodtgoerelse_modtager_id) : null,

      tillaeg_ids: isKoerselType(editableKoerselsraekke.befordringstype_id) ? selectedTillaegIds : [],
      dag_ids: selectedDagIds
    };

    const error = await onSaveKoerselsraekke(row.koersel_id, updates);

    if (error) {
      editError = error;
    } else {

      cancelEdit();
    }
  }


  // -----------------------------
  // Create row handling
  // -----------------------------

  function startCreate() {
    isCreating = true;

    // Pre-fill from the latest koerselsraekke (rows[0] after gyldig_til DESC sort).
    // Falls back to empty form if there are no existing rows.
    const source = rows.length > 0 ? rows[0] : null;

    if (source) {
      newKoerselsraekke = {
        tidspunkt_id: source.tidspunkt_id ?? "",
        befordringstype_id: source.befordringstype_id ?? "",
        bevilget_koereafstand_pr_vej: source.bevilget_koereafstand_pr_vej != null
          ? String(source.bevilget_koereafstand_pr_vej)
          : "",
        gyldig_fra: source.gyldig_fra ? String(source.gyldig_fra).slice(0, 10) : "",
        gyldig_til: source.gyldig_til ? String(source.gyldig_til).slice(0, 10) : "",
        taxa_id: source.taxa_id ?? "",
        kommentar: source.kommentar ?? "",
        rutetype_id: source.rutetype_id ?? "",
        koersel_til_institution: source.koersel_til_institution != null ? String(source.koersel_til_institution) : "",
        max_minutter_i_transport: source.max_minutter_i_transport != null ? String(source.max_minutter_i_transport) : "",
        koerselsgodtgoerelse_modtager_id: source.koerselsgodtgoerelse_modtager_id ?? "",
        final: false,
      };
      newSelectedTillaegIds = parseIds(source.tillaeg_ids);
      newSelectedDagIds = parseIds(source.dag_ids);
    } else {
      newKoerselsraekke = getEmptyKoerselsraekke();
      newSelectedTillaegIds = [];
      newSelectedDagIds = [];
    }
  }


  function cancelCreate() {
    isCreating = false;
    newKoerselsraekke = {};
    createError = null;

    newSelectedTillaegIds = [];
    newSelectedDagIds = [];
  }


  function updateNewField(key: string, value: any) {
    newKoerselsraekke = {
      ...newKoerselsraekke,
      [key]: value
    };
  }


  // The rules that depend on the chosen kørselstype. Shared by both the edit
  // and the create path so the two can never drift — they did in the code this
  // was ported from, where transporttid and antal skift used two different
  // idioms for the same "unanswered" check.
  function validateKoerselstypeFields(
    values: any,
    befordringstypeId: string | number | null | undefined,
    dagIds: number[]
  ): string | null {
    if (!befordringstypeId) return "Kørselstype skal udfyldes";
    if (dagIds.length === 0) return "Dage skal udfyldes";
    if (!values.rutetype_id) return "Rutetype skal udfyldes";

    if (isEgenbefordring(befordringstypeId)) {
      if (isBlank(values.bevilget_koereafstand_pr_vej)) return "Bevilget km pr. vej skal udfyldes";
      if (isBlank(values.koerselsgodtgoerelse_modtager_id)) return "Kørselsgodtgørelse modtager skal udfyldes";
    }

    if (isTaxaType(befordringstypeId)) {
      if (isBlank(values.koersel_til_institution)) return "Kørsel til institution skal udfyldes";
      if (isBlank(values.max_minutter_i_transport)) return "Max. antal min. i transport skal udfyldes";
    }

    if (isSkolerejsekort(befordringstypeId)) {
      if (isBlank(values.transporttid_i_bus)) return "Transporttid i bus skal udfyldes";
      if (isBlank(values.skift_med_bus)) return "Antal skift skal udfyldes";
    }

    return null;
  }

  function validateNewKoerselsraekke(): string | null {
    if (!newKoerselsraekke.tidspunkt_id) return "Tidspunkt skal udfyldes";
    if (!newKoerselsraekke.befordringstype_id) return "Kørselstype skal udfyldes";
    if (!newKoerselsraekke.gyldig_fra) return "Gyldig fra skal udfyldes";
    if (!newKoerselsraekke.gyldig_til) return "Gyldig til skal udfyldes";
    if (isDateOutOfRange(newKoerselsraekke.gyldig_fra)) return "Gyldig fra: Dato er ugyldig — kontrollér årstallet";
    if (isDateOutOfRange(newKoerselsraekke.gyldig_til)) return "Gyldig til: Dato er ugyldig — kontrollér årstallet";
    if (newKoerselsraekke.gyldig_fra > newKoerselsraekke.gyldig_til) return "Gyldig fra kan ikke være efter gyldig til";

    return validateKoerselstypeFields(
      newKoerselsraekke,
      newKoerselsraekke.befordringstype_id,
      newSelectedDagIds
    );
  }


  async function saveNew() {
    createError = null;
    const validationError = validateNewKoerselsraekke();
    if (validationError) {
      createError = validationError;
      return;
    }

    const updates = {
      tidspunkt_id: numberOrNull(newKoerselsraekke.tidspunkt_id),
      befordringstype_id: numberOrNull(newKoerselsraekke.befordringstype_id),
      bevilget_koereafstand_pr_vej: Number(newKoerselsraekke.bevilget_koereafstand_pr_vej),
      gyldig_fra: newKoerselsraekke.gyldig_fra,
      gyldig_til: newKoerselsraekke.gyldig_til,
      taxa_id: newKoerselsraekke.taxa_id || null,
      kommentar: newKoerselsraekke.kommentar || "",
      rutetype_id: numberOrNull(newKoerselsraekke.rutetype_id),
      final: false,

      transporttid_i_bus: isSkolerejsekort(newKoerselsraekke.befordringstype_id) ? numberOrNull(newKoerselsraekke.transporttid_i_bus) : null,
      skift_med_bus: isSkolerejsekort(newKoerselsraekke.befordringstype_id) ? numberOrNull(newKoerselsraekke.skift_med_bus) : null,
      // Only the fields belonging to the chosen kørselstype are sent; the rest
      // are nulled so a value cannot survive a change of type.
      koersel_til_institution: isTaxaType(newKoerselsraekke.befordringstype_id) ? boolOrNull(newKoerselsraekke.koersel_til_institution) : null,
      max_minutter_i_transport: isTaxaType(newKoerselsraekke.befordringstype_id) ? numberOrNull(newKoerselsraekke.max_minutter_i_transport) : null,
      koerselsgodtgoerelse_modtager_id: isEgenbefordring(newKoerselsraekke.befordringstype_id) ? numberOrNull(newKoerselsraekke.koerselsgodtgoerelse_modtager_id) : null,

      tillaeg_ids: isKoerselType(newKoerselsraekke.befordringstype_id) ? newSelectedTillaegIds : [],
      dag_ids: newSelectedDagIds
    };

    const error = await onCreateKoerselsraekke(updates);

    if (error) {
      createError = error;
    } else {
      cancelCreate();
    }
  }
</script>


<div class="space-y-0">

  {#if finalizeError}
    <div class="mb-3 px-3 py-2 text-sm text-red-700 bg-red-50 border border-red-200 rounded">
      {finalizeError}
    </div>
  {/if}

  <!-- + Ny kørselsrække button / create form — above the rows -->
  {#if !readonly}
  {#if isCreating}

    <div class="mt-2 p-4 bg-white rounded-lg border border-gray-300 shadow-sm">
      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-4">Ny kørselsrække</p>

      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-x-6 gap-y-4 mb-4">

        <!-- Row 1 col 1: Kørselstype — always fixed -->
        <label class="block">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kørselstype *</span>
          <select
            class={selectClass}
            value={newKoerselsraekke.befordringstype_id ?? ""}
            on:change={(e) => {
              const id = numberOrNull(e.currentTarget.value);
              updateNewField("befordringstype_id", id);
              if (!isTaxaType(id)) newSelectedTillaegIds = [];
              calculateAndFillDistance(id, 'new');
            }}
          >
            <option value="">Vælg</option>
            {#each availableKoerselstyper as option}
              <option value={option.id}>{option.label}</option>
            {/each}
          </select>
        </label>











        <!-- Row 1, shared: Rutetype | Tidspunkt | Dage -->
        <label class="block">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Rutetype *</span>
          <select class={selectClass} value={newKoerselsraekke.rutetype_id ?? ""} on:change={(e) => updateNewField("rutetype_id", numberOrNull(e.currentTarget.value))}>
            <option value="">Vælg</option>
            {#each lookupOptions.rutetyper ?? [] as option}<option value={option.id}>{option.label}</option>{/each}
          </select>
        </label>
        <label class="block">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Tidspunkt *</span>
          <select class={selectClass} value={newKoerselsraekke.tidspunkt_id ?? ""} on:change={(e) => updateNewField("tidspunkt_id", numberOrNull(e.currentTarget.value))}>
            <option value="">Vælg</option>
            {#each lookupOptions.tidspunkter ?? [] as option}<option value={option.id}>{option.label}</option>{/each}
          </select>
        </label>
        <div>
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Dage *</span>
          <TagMultiSelect options={lookupOptions.dage ?? []} bind:selected={newSelectedDagIds} placeholder="Tilføj dag" />
        </div>
        
        {#if isEgenbefordring(newKoerselsraekke.befordringstype_id)}
          <!-- Egenbefordring: Row 2: Bevilget km | Kørselsgodtgørelse modtager | empty | empty -->
          <label class="block md:col-start-1">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 flex items-center gap-1.5">
              Bevilget km pr. vej *
              {#if isCalculatingDistance && distanceCalcTarget === 'new'}
                <span class="text-blue-500 font-normal normal-case text-[10px]">beregner...</span>
              {/if}
            </span>
            <input type="number" step="0.1"
              class="{inputClass} {isCalculatingDistance && distanceCalcTarget === 'new' ? 'opacity-50' : ''}"
              disabled={isCalculatingDistance && distanceCalcTarget === 'new'}
              value={newKoerselsraekke.bevilget_koereafstand_pr_vej ?? ""}
              on:change={(e) => updateNewField("bevilget_koereafstand_pr_vej", e.currentTarget.value)} />
          </label>
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kørselsgodtgørelse modtager *</span>
            <select class={selectClass} value={newKoerselsraekke.koerselsgodtgoerelse_modtager_id ?? ""} on:change={(e) => updateNewField("koerselsgodtgoerelse_modtager_id", numberOrNull(e.currentTarget.value))}>
              <option value="">Vælg</option>
              {#each parter as p}<option value={p.part_id}>{p.fulde_navn ?? p.navn ?? p.part_id}</option>{/each}
            </select>
          </label>
          <div></div><div></div>
          <!-- Row 3: Gyldig fra | Gyldig til | empty | empty -->
          <label class="block md:col-start-1">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig fra *</span>
            <input type="date" class={inputClass} min={minDate} max={maxDate} value={newKoerselsraekke.gyldig_fra ?? ""} on:change={(e) => updateNewField("gyldig_fra", e.currentTarget.value)} />
          </label>
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig til *</span>
            <input type="date" class={inputClass} min={minDate} max={maxDate} value={newKoerselsraekke.gyldig_til ?? ""} on:change={(e) => updateNewField("gyldig_til", e.currentTarget.value)} />
          </label>
          <div></div><div></div>
          <!-- Row 4: Kommentar full width -->
          <label class="block md:col-start-1 md:col-span-4">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kommentar</span>
            <input class={inputClass} value={newKoerselsraekke.kommentar ?? ""} on:change={(e) => updateNewField("kommentar", e.currentTarget.value)} />
          </label>

        {:else if isTaxaType(newKoerselsraekke.befordringstype_id)}
          <!-- Taxa: Row 2: Tillæg | Kørsel til institution | Max min | Taxa-ID -->
          <div class="md:col-start-1">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Tillæg</span>
            <TagMultiSelect options={lookupOptions.koerselstypeTillaeg ?? []} bind:selected={newSelectedTillaegIds} placeholder="Tilføj tillæg" />
          </div>
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kørsel til institution *</span>
            <select class={selectClass} value={newKoerselsraekke.koersel_til_institution ?? ""} on:change={(e) => updateNewField("koersel_til_institution", e.currentTarget.value)}>
              <option value="">Vælg</option>
              <option value="true">Ja</option>
              <option value="false">Nej</option>
            </select>
          </label>
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Max. antal min. i transport *</span>
            <input type="number" min="0" max="500" class={inputClass} value={newKoerselsraekke.max_minutter_i_transport ?? ""} on:change={(e) => updateNewField("max_minutter_i_transport", e.currentTarget.value)} />
          </label>
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Taxa-ID</span>
            <input class={inputClass} value={newKoerselsraekke.taxa_id ?? ""} on:change={(e) => updateNewField("taxa_id", e.currentTarget.value)} />
          </label>
          <!-- Row 3: Gyldig fra | Gyldig til | empty | empty -->
          <label class="block md:col-start-1">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig fra *</span>
            <input type="date" class={inputClass} min={minDate} max={maxDate} value={newKoerselsraekke.gyldig_fra ?? ""} on:change={(e) => updateNewField("gyldig_fra", e.currentTarget.value)} />
          </label>
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig til *</span>
            <input type="date" class={inputClass} min={minDate} max={maxDate} value={newKoerselsraekke.gyldig_til ?? ""} on:change={(e) => updateNewField("gyldig_til", e.currentTarget.value)} />
          </label>
          <div></div><div></div>
          <!-- Row 4: Kommentar -->
          <label class="block md:col-start-1 md:col-span-4">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kommentar</span>
            <input class={inputClass} value={newKoerselsraekke.kommentar ?? ""} on:change={(e) => updateNewField("kommentar", e.currentTarget.value)} />
          </label>

        {:else if isSkolerejsekort(newKoerselsraekke.befordringstype_id)}
          <!-- Skolerejsekort: Row 2: Transporttid i bus | Antal skift | empty | empty -->
          <label class="block md:col-start-1">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Transporttid i bus (min.) *</span>
            <input type="number" min="0" max="500" class={inputClass} value={newKoerselsraekke.transporttid_i_bus ?? ""} on:change={(e) => updateNewField("transporttid_i_bus", e.currentTarget.value)} />
          </label>
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Antal skift *</span>
            <input type="number" min="0" max="10" class={inputClass} value={newKoerselsraekke.skift_med_bus ?? ""} on:change={(e) => updateNewField("skift_med_bus", e.currentTarget.value)} />
          </label>
          <div></div><div></div>
          <!-- Row 3: Gyldig fra | Gyldig til | empty | empty -->
          <label class="block md:col-start-1">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig fra *</span>
            <input type="date" class={inputClass} min={minDate} max={maxDate} value={newKoerselsraekke.gyldig_fra ?? ""} on:change={(e) => updateNewField("gyldig_fra", e.currentTarget.value)} />
          </label>
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig til *</span>
            <input type="date" class={inputClass} min={minDate} max={maxDate} value={newKoerselsraekke.gyldig_til ?? ""} on:change={(e) => updateNewField("gyldig_til", e.currentTarget.value)} />
          </label>
          <div></div><div></div>
          <!-- Row 4: Kommentar -->
          <label class="block md:col-start-1 md:col-span-4">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kommentar</span>
            <input class={inputClass} value={newKoerselsraekke.kommentar ?? ""} on:change={(e) => updateNewField("kommentar", e.currentTarget.value)} />
          </label>

        {:else}
          <!-- Default (Skolebus, Gåbus, etc.): Row 2: Gyldig fra | Gyldig til | empty | empty -->
          <label class="block md:col-start-1">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig fra *</span>
            <input type="date" class={inputClass} min={minDate} max={maxDate} value={newKoerselsraekke.gyldig_fra ?? ""} on:change={(e) => updateNewField("gyldig_fra", e.currentTarget.value)} />
          </label>
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig til *</span>
            <input type="date" class={inputClass} min={minDate} max={maxDate} value={newKoerselsraekke.gyldig_til ?? ""} on:change={(e) => updateNewField("gyldig_til", e.currentTarget.value)} />
          </label>
          <div></div><div></div>
          <!-- Row 3: Kommentar -->
          <label class="block md:col-start-1 md:col-span-4">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kommentar</span>
            <input class={inputClass} value={newKoerselsraekke.kommentar ?? ""} on:change={(e) => updateNewField("kommentar", e.currentTarget.value)} />
          </label>
        {/if}

      </div>

      {#if distanceError && distanceErrorFrom === 'new'}
        <div class="mb-3 px-3 py-2 text-xs text-red-700 bg-red-50 border border-red-200 rounded">
          {distanceError}
        </div>
      {/if}

      {#if createError}
        <div class="mb-3 px-3 py-2 text-sm text-red-700 bg-red-50 border border-red-200 rounded">
          {createError}
        </div>
      {/if}

      <div class="flex gap-2">
        <button
          type="button"
          class="px-4 py-1.5 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded transition-colors"
          on:click={saveNew}
        >
          Gem
        </button>
        <button
          type="button"
          class="px-4 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
          on:click={cancelCreate}
        >
          Annullér
        </button>
      </div>
    </div>

  {:else}

    <div class="pt-1 mb-2">
      <button
        type="button"
        disabled={!canEdit}
        class="text-sm font-medium text-sky-700 hover:underline disabled:text-gray-400 disabled:no-underline disabled:cursor-not-allowed"
        on:click={startCreate}
      >
        + Ny kørselsrække
      </button>
    </div>

  {/if}
  {/if}


  <!-- Existing rows -->
  {#if rows.length === 0 && !isCreating}
    <p class="text-sm text-gray-400 py-2">Ingen kørselsrækker endnu.</p>
  {/if}

  {#each rows as row}

    {@const isEditing = editingKoerselId === row.koersel_id}

    {#if isEditing}

      <!-- Edit form -->
      <div class="border border-blue-200 rounded-lg p-4 mb-3 bg-blue-50">

        <div class="flex justify-end items-center gap-2 mb-4">
          <button
            type="button"
            class="px-4 py-1.5 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded transition-colors"
            on:click={() => saveEdit(row)}
          >
            Gem
          </button>
          <button
            type="button"
            class="px-4 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
            on:click={cancelEdit}
          >
            Annullér
          </button>
          {#if onDeleteKoerselsraekke}
            <span class="w-px h-5 bg-blue-200 mx-1"></span>
            <button
              type="button"
              title="Slet kørselsrække"
              disabled={!canEdit}
              class="p-1 text-gray-400 hover:text-red-600 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
              on:click={() => { confirmingDeleteKoerselId = row.koersel_id; deleteError = null; }}
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          {/if}
        </div>

        {#if editError}
          <div class="mb-3 px-3 py-2 text-sm text-red-700 bg-red-50 border border-red-200 rounded">
            {editError}
          </div>
        {/if}

        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-x-6 gap-y-4 mb-3">

          <!-- Kørselstype — always Row 1, col 1 -->
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kørselstype *</span>
            <select
              class={selectClass}
              value={editableKoerselsraekke.befordringstype_id ?? ""}
              on:change={(e) => {
                const id = numberOrNull(e.currentTarget.value);
                updateField("befordringstype_id", id);
                if (!isTaxaType(id)) selectedTillaegIds = [];
                calculateAndFillDistance(id, 'edit');
              }}
            >
              <option value="">Vælg</option>
              {#each availableKoerselstyper as option}
                <option value={option.id}>{option.label}</option>
              {/each}
            </select>
          </label>


          <!-- Row 1, shared: Rutetype | Tidspunkt | Dage -->
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Rutetype *</span>
            <select class={selectClass} value={editableKoerselsraekke.rutetype_id ?? ""} on:change={(e) => updateField("rutetype_id", numberOrNull(e.currentTarget.value))}>
              <option value="">Vælg</option>
              {#each lookupOptions.rutetyper ?? [] as option}<option value={option.id}>{option.label}</option>{/each}
            </select>
          </label>
          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Tidspunkt *</span>
            <select class={selectClass} value={editableKoerselsraekke.tidspunkt_id ?? ""} on:change={(e) => updateField("tidspunkt_id", numberOrNull(e.currentTarget.value))}>
              <option value="">Vælg</option>
              {#each lookupOptions.tidspunkter ?? [] as option}<option value={option.id}>{option.label}</option>{/each}
            </select>
          </label>
          <div>
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Dage *</span>
            <TagMultiSelect options={lookupOptions.dage ?? []} bind:selected={selectedDagIds} placeholder="Tilføj dag" />
          </div>

          {#if isEgenbefordring(editableKoerselsraekke.befordringstype_id)}
            <!-- Egenbefordring: Row 2: Bevilget km | Kørselsgodtgørelse modtager | empty | empty -->
            <label class="block md:col-start-1">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 flex items-center gap-1.5">
                Bevilget km pr. vej *
                {#if isCalculatingDistance && distanceCalcTarget === 'edit'}
                  <span class="text-blue-500 font-normal normal-case text-[10px]">beregner...</span>
                {/if}
              </span>
              <input
                type="number"
                step="0.1"
                class="{inputClass} {isCalculatingDistance && distanceCalcTarget === 'edit' ? 'opacity-50' : ''}"
                disabled={isCalculatingDistance && distanceCalcTarget === 'edit'}
                value={editableKoerselsraekke.bevilget_koereafstand_pr_vej ?? ""}
                on:change={(e) => updateField("bevilget_koereafstand_pr_vej", e.currentTarget.value)}
              />
            </label>
            <label class="block">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kørselsgodtgørelse modtager *</span>
              <select class={selectClass} value={editableKoerselsraekke.koerselsgodtgoerelse_modtager_id ?? ""} on:change={(e) => updateField("koerselsgodtgoerelse_modtager_id", numberOrNull(e.currentTarget.value))}>
                <option value="">Vælg</option>
                {#each parter as p}<option value={p.part_id}>{p.fulde_navn ?? p.navn ?? p.part_id}</option>{/each}
              </select>
            </label>
            <div></div><div></div>
            <!-- Row 3: Gyldig fra | Gyldig til | empty | empty -->
            <label class="block md:col-start-1">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig fra *</span>
              <input type="date" class={inputClass} min={minDate} max={maxDate} value={editableKoerselsraekke.gyldig_fra ?? ""} on:change={(e) => updateField("gyldig_fra", e.currentTarget.value)} />
            </label>
            <label class="block">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig til *</span>
              <input type="date" class={inputClass} min={minDate} max={maxDate} value={editableKoerselsraekke.gyldig_til ?? ""} on:change={(e) => updateField("gyldig_til", e.currentTarget.value)} />
            </label>
            <div></div><div></div>
            <!-- Row 4: Kommentar -->
            <label class="block md:col-start-1 md:col-span-4">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kommentar</span>
              <input class={inputClass} value={editableKoerselsraekke.kommentar ?? ""} on:change={(e) => updateField("kommentar", e.currentTarget.value)} />
            </label>

          {:else if isTaxaType(editableKoerselsraekke.befordringstype_id)}
            <!-- Taxa (Skåne, Solo, Variabel, Rute): Row 2: Tillæg | Kørsel til institution | Max. antal min. i transport | Taxa-ID -->
            <div class="md:col-start-1">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Tillæg</span>
              <TagMultiSelect options={lookupOptions.koerselstypeTillaeg ?? []} bind:selected={selectedTillaegIds} placeholder="Tilføj tillæg" />
            </div>
            <label class="block">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kørsel til institution *</span>
              <select class={selectClass} value={editableKoerselsraekke.koersel_til_institution != null ? String(editableKoerselsraekke.koersel_til_institution) : ""} on:change={(e) => updateField("koersel_til_institution", e.currentTarget.value)}>
                <option value="">Vælg</option>
                <option value="true">Ja</option>
                <option value="false">Nej</option>
              </select>
            </label>
            <label class="block">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Max. antal min. i transport *</span>
              <input type="number" min="0" max="500" class={inputClass} value={editableKoerselsraekke.max_minutter_i_transport ?? ""} on:change={(e) => updateField("max_minutter_i_transport", e.currentTarget.value)} />
            </label>
            <label class="block">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Taxa-ID</span>
              <input class={inputClass} value={editableKoerselsraekke.taxa_id ?? ""} on:change={(e) => updateField("taxa_id", e.currentTarget.value)} />
            </label>
            <!-- Row 3: Gyldig fra | Gyldig til | empty | empty -->
            <label class="block md:col-start-1">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig fra *</span>
              <input type="date" class={inputClass} min={minDate} max={maxDate} value={editableKoerselsraekke.gyldig_fra ?? ""} on:change={(e) => updateField("gyldig_fra", e.currentTarget.value)} />
            </label>
            <label class="block">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig til *</span>
              <input type="date" class={inputClass} min={minDate} max={maxDate} value={editableKoerselsraekke.gyldig_til ?? ""} on:change={(e) => updateField("gyldig_til", e.currentTarget.value)} />
            </label>
            <div></div><div></div>
            <!-- Row 4: Kommentar -->
            <label class="block md:col-start-1 md:col-span-4">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kommentar</span>
              <input class={inputClass} value={editableKoerselsraekke.kommentar ?? ""} on:change={(e) => updateField("kommentar", e.currentTarget.value)} />
            </label>

          {:else if isSkolerejsekort(editableKoerselsraekke.befordringstype_id)}
            <!-- Skolerejsekort: Row 2: Transporttid i bus | Antal skift | empty | empty -->
            <label class="block md:col-start-1">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Transporttid i bus (min.) *</span>
              <input type="number" min="0" max="500" class={inputClass} value={editableKoerselsraekke.transporttid_i_bus ?? ""} on:change={(e) => updateField("transporttid_i_bus", e.currentTarget.value)} />
            </label>
            <label class="block">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Antal skift *</span>
              <input type="number" min="0" max="10" class={inputClass} value={editableKoerselsraekke.skift_med_bus ?? ""} on:change={(e) => updateField("skift_med_bus", e.currentTarget.value)} />
            </label>
            <div></div><div></div>
            <!-- Row 3: Gyldig fra | Gyldig til | empty | empty -->
            <label class="block md:col-start-1">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig fra *</span>
              <input type="date" class={inputClass} min={minDate} max={maxDate} value={editableKoerselsraekke.gyldig_fra ?? ""} on:change={(e) => updateField("gyldig_fra", e.currentTarget.value)} />
            </label>
            <label class="block">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig til *</span>
              <input type="date" class={inputClass} min={minDate} max={maxDate} value={editableKoerselsraekke.gyldig_til ?? ""} on:change={(e) => updateField("gyldig_til", e.currentTarget.value)} />
            </label>
            <div></div><div></div>
            <!-- Row 4: Kommentar -->
            <label class="block md:col-start-1 md:col-span-4">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kommentar</span>
              <input class={inputClass} value={editableKoerselsraekke.kommentar ?? ""} on:change={(e) => updateField("kommentar", e.currentTarget.value)} />
            </label>

          {:else}
            <!-- Default (Skolebus, Gåbus, etc.): Row 2: Gyldig fra | Gyldig til | empty | empty -->
            <label class="block md:col-start-1">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig fra *</span>
              <input type="date" class={inputClass} min={minDate} max={maxDate} value={editableKoerselsraekke.gyldig_fra ?? ""} on:change={(e) => updateField("gyldig_fra", e.currentTarget.value)} />
            </label>
            <label class="block">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig til *</span>
              <input type="date" class={inputClass} min={minDate} max={maxDate} value={editableKoerselsraekke.gyldig_til ?? ""} on:change={(e) => updateField("gyldig_til", e.currentTarget.value)} />
            </label>
            <div></div><div></div>
            <!-- Row 3: Kommentar -->
            <label class="block md:col-start-1 md:col-span-4">
              <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kommentar</span>
              <input class={inputClass} value={editableKoerselsraekke.kommentar ?? ""} on:change={(e) => updateField("kommentar", e.currentTarget.value)} />
            </label>
          {/if}

        </div>

        {#if distanceError && distanceErrorFrom === 'edit'}
          <div class="mb-3 px-3 py-2 text-xs text-red-700 bg-red-50 border border-red-200 rounded">
            {distanceError}
          </div>
        {/if}

      </div>

    {:else}
    
      {@const isEgb = labelIsEgenbefordring(row.befordringstype_tekst)}
      {@const isTxa = labelIsTaxa(row.befordringstype_tekst)}
      {@const isSRK = labelIsSkolerejsekort(row.befordringstype_tekst)}

      <!-- Labeled field grid view (matches the bevilling header card) -->
      <div class="mb-2 bg-white rounded-lg border shadow-sm overflow-hidden {row.final ? 'border-gray-200' : 'border-gray-300'}" style="border-left: 3px solid {row.final ? '#9ca3af' : '#2ab4a0'};">

        <div class="flex items-start justify-between gap-4 px-4 py-4">

          <div class="flex-1 min-w-0 grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-x-6 gap-y-4">

            <!-- Row 1, shared: Kørselstype | Rutetype | Tidspunkt | Dage -->
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Kørselstype</p>
              <p class="text-sm font-semibold text-gray-800 break-words">{row.befordringstype_tekst ?? "—"}</p>
            </div>
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Rutetype</p>
              <p class="text-sm text-gray-800 break-words">{row.rutetype_tekst ?? "—"}</p>
            </div>
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Tidspunkt</p>
              <p class="text-sm text-gray-800 break-words">{row.tidspunkt_tekst ?? "—"}</p>
            </div>
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Dage</p>
              <p class="text-sm text-gray-800 break-words">{row.dage ?? "—"}</p>
            </div>

            {#if isEgb}
              <!-- Egenbefordring: Row 2: Bevilget km | Kørselsgodtgørelse modtager | empty | empty -->
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Bevilget km pr. vej</p>
                <p class="text-sm text-gray-800">{row.bevilget_koereafstand_pr_vej != null ? String(parseFloat(row.bevilget_koereafstand_pr_vej)).replace('.', ',') : "—"}</p>
              </div>
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Kørselsgodtgørelse modtager</p>
                <p class="text-sm text-gray-800 break-words">{parter.find((p: any) => p.part_id === row.koerselsgodtgoerelse_modtager_id)?.fulde_navn ?? parter.find((p: any) => p.part_id === row.koerselsgodtgoerelse_modtager_id)?.navn ?? "—"}</p>
              </div>
              <div></div><div></div>
              <!-- Row 3: Gyldig fra | Gyldig til | empty | empty -->
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Gyldig fra</p>
                <p class="text-sm text-gray-800">{formatDanishDate(row.gyldig_fra)}</p>
              </div>
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Gyldig til</p>
                <p class="text-sm text-gray-800">{formatDanishDate(row.gyldig_til)}</p>
              </div>
              <div></div><div></div>
              <!-- Row 4: Kommentar -->
              <div class="md:col-span-4">
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Kommentar</p>
                <p class="text-sm text-gray-800 italic break-words">{row.kommentar ?? "—"}</p>
              </div>

            {:else if isTxa}
              <!-- Taxa: Row 2: Tillæg | Kørsel til institution | Max min | Taxa-ID -->
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Tillæg</p>
                <p class="text-sm text-gray-800 break-words">{row.tillaeg_tekst ?? "—"}</p>
              </div>
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Kørsel til institution</p>
                <p class="text-sm text-gray-800">{row.koersel_til_institution === true ? 'Ja' : row.koersel_til_institution === false ? 'Nej' : '—'}</p>
              </div>
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Max. antal min. i transport</p>
                <p class="text-sm text-gray-800">{row.max_minutter_i_transport ?? "—"}</p>
              </div>
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Taxa-ID</p>
                <p class="text-sm text-gray-800 break-words">{row.taxa_id || "—"}</p>
              </div>
              <!-- Row 3: Gyldig fra | Gyldig til | empty | empty -->
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Gyldig fra</p>
                <p class="text-sm text-gray-800">{formatDanishDate(row.gyldig_fra)}</p>
              </div>
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Gyldig til</p>
                <p class="text-sm text-gray-800">{formatDanishDate(row.gyldig_til)}</p>
              </div>
              <div></div><div></div>
              <!-- Row 4: Kommentar -->
              <div class="md:col-span-4">         
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Kommentar</p>
                <p class="text-sm text-gray-800 italic break-words">{row.kommentar ?? "—"}</p>
              </div>

            {:else if isSRK}
              <!-- Skolerejsekort: Row 2: Transporttid i bus | Antal skift | empty | empty -->
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Transporttid i bus (min.)</p>
                <p class="text-sm text-gray-800">{row.transporttid_i_bus ?? "—"}</p>
              </div>
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Antal skift</p>
                <p class="text-sm text-gray-800">{row.skift_med_bus ?? "—"}</p>
              </div>
              <div></div><div></div>
              <!-- Row 3: Gyldig fra | Gyldig til | empty | empty -->
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Gyldig fra</p>
                <p class="text-sm text-gray-800">{formatDanishDate(row.gyldig_fra)}</p>
              </div>
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Gyldig til</p>
                <p class="text-sm text-gray-800">{formatDanishDate(row.gyldig_til)}</p>
              </div>
              <div></div><div></div>
              <!-- Row 4: Kommentar -->
              <div class="md:col-span-4">
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Kommentar</p>
                <p class="text-sm text-gray-800 italic break-words">{row.kommentar ?? "—"}</p>
              </div>

            {:else}
              <!-- Default (Skolebus, Gåbus, etc.): Row 2: Gyldig fra | Gyldig til | empty | empty -->
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Gyldig fra</p>
                <p class="text-sm text-gray-800">{formatDanishDate(row.gyldig_fra)}</p>
              </div>
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Gyldig til</p>
                <p class="text-sm text-gray-800">{formatDanishDate(row.gyldig_til)}</p>
              </div>
              <div></div><div></div>
              <!-- Row 3: Kommentar -->
              <div class="md:col-span-4">
                <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Kommentar</p>
                <p class="text-sm text-gray-800 italic break-words">{row.kommentar ?? "—"}</p>
              </div>
            {/if}

          </div>

          <!-- Handlinger -->
          <div class="flex items-center gap-2 shrink-0">
            {#if row.final}
              <!-- Locked state: redigér + closed lock icon (mirrors unlocked layout) -->
              {#if !readonly}
                <button
                  type="button"
                  disabled={!canEdit}
                  class="px-3 py-1 text-xs border border-gray-300 rounded hover:bg-gray-50 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                  on:click={() => startEdit(row)}
                >
                  Redigér
                </button>
              {/if}
              <span title="Låst" class="p-1 text-gray-400 cursor-default">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </span>
            {:else if !readonly}
              <!-- Unlocked state: redigér + lock button -->
              <button
                type="button"
                disabled={!canEdit}
                class="px-3 py-1 text-xs border border-gray-300 rounded hover:bg-gray-50 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                on:click={() => startEdit(row)}
              >
                Redigér
              </button>
              <button
                type="button"
                title="Lås kørselsrække"
                class="p-1 text-gray-400 hover:text-gray-600 transition-colors"
                on:click={() => confirmingFinalizeId = row.koersel_id}
              >
                <!-- lock-open icon -->
                <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M8 11V7a4 4 0 118 0m-4 8v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2z" />
                </svg>
              </button>
            {/if}

          </div>

        </div>

      </div>

    {/if}

  {/each}



</div>


<svelte:window on:keydown={(e) => {
  if (e.key === 'Escape') {
    if (confirmingFinalizeId !== null) confirmingFinalizeId = null;
    if (lockedEditRow !== null) lockedEditRow = null;
    if (confirmingDeleteKoerselId !== null) confirmingDeleteKoerselId = null;
  }
}} />

<!-- Finalize confirmation modal -->
{#if confirmingFinalizeId !== null}
  <!-- Backdrop is non-dismissing: close only via Escape or the Annullér button. -->
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    role="presentation"
  >
    <div
      class="w-[420px] bg-white rounded-lg shadow-2xl"
      role="dialog"
      aria-modal="true"
      tabindex="-1"
    >
      <div class="px-6 py-5 border-b border-gray-200">
        <div class="flex items-center gap-3">
          <div class="w-9 h-9 rounded-full bg-amber-100 flex items-center justify-center shrink-0">
            <svg class="w-5 h-5 text-amber-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <div>
            <h2 class="text-base font-semibold text-gray-900">Lås kørselsrække</h2>
            <p class="text-xs text-gray-500 mt-0.5">Kan genåbnes ved behov</p>
          </div>
        </div>
      </div>

      <div class="px-6 py-5">
        <p class="text-sm text-gray-700">
          Kørselsrækken vil blive markeret som <strong>låst</strong> og kan kun redigeres efter bekræftelse.
        </p>
        <p class="text-sm text-gray-500 mt-2">
          Er du sikker på, at du vil låse denne kørselsrække?
        </p>
      </div>

      <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200 bg-gray-50 rounded-b-lg">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-white transition-colors"
          on:click={() => confirmingFinalizeId = null}
        >
          Annullér
        </button>
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium bg-amber-600 hover:bg-amber-700 text-white rounded transition-colors disabled:opacity-50"
          disabled={isFinalizing}
          on:click={doFinalize}
        >
          {isFinalizing ? 'Låser...' : 'Lås kørselsrække'}
        </button>
      </div>
    </div>
  </div>
{/if}


<!-- Locked edit confirmation popup -->
{#if lockedEditRow !== null}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    role="presentation"
  >
    <div
      class="w-[420px] bg-white rounded-lg shadow-2xl"
      role="dialog"
      aria-modal="true"
      tabindex="-1"
    >
      <div class="px-6 py-5 border-b border-gray-200">
        <div class="flex items-center gap-3">
          <div class="w-9 h-9 rounded-full bg-amber-100 flex items-center justify-center shrink-0">
            <svg class="w-5 h-5 text-amber-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <div>
            <h2 class="text-base font-semibold text-gray-900">Rediger låst kørselsrække</h2>
            <p class="text-xs text-gray-500 mt-0.5">Kræver bekræftelse</p>
          </div>
        </div>
      </div>

      <div class="px-6 py-5">
        <p class="text-sm text-gray-700">
          Kørselsrækken er låst. <strong>Husk at sende nyt brev</strong> når du har redigeret i en låst kørselsrække.
        </p>
        <p class="text-sm text-gray-500 mt-2">
          Er du sikker på, at du vil redigere denne kørselsrække?
        </p>
      </div>

      <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200 bg-gray-50 rounded-b-lg">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-white transition-colors"
          on:click={() => lockedEditRow = null}
        >
          Annullér
        </button>
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium bg-amber-600 hover:bg-amber-700 text-white rounded transition-colors"
          on:click={doLockedEdit}
        >
          Redigér
        </button>
      </div>
    </div>
  </div>
{/if}



<!-- Delete kørselsrække confirmation modal -->
{#if confirmingDeleteKoerselId !== null}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    role="presentation"
  >
    <div
      class="w-[420px] bg-white rounded-lg shadow-2xl"
      role="dialog"
      aria-modal="true"
      tabindex="-1"
    >
      <div class="px-6 py-5 border-b border-gray-200">
        <div class="flex items-center gap-3">
          <div class="w-9 h-9 rounded-full bg-red-100 flex items-center justify-center shrink-0">
            <svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6
v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </div>
          <div>
            <h3 class="text-sm font-semibold text-gray-900">Slet kørselsrække</h3>
            <p class="text-xs text-gray-500 mt-0.5">Kørselsrække #{confirmingDeleteKoerselId}</p>
          </div>
        </div>
      </div>
      <div class="px-6 py-4">
        <p class="text-sm text-gray-700">
          Er du sikker på, at du vil slette denne kørselsrække?
          Den vil blive skjult for brugere, men bevares i databasen.
        </p>
        {#if deleteError}
          <p class="mt-3 text-sm text-red-600 bg-red-50 border border-red-200 rounded px-3 py-2">{deleteError}</p>
        {/if}
      </div>
      <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200 bg-gray-50 rounded-b-lg">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-100 transition-colors"
          on:click={() => confirmingDeleteKoerselId = null}
        >
          Annullér
        </button>
        <button
          type="button"
          disabled={isDeleting}
          class="px-4 py-2 text-sm font-medium bg-red-600 hover:bg-red-700 text-white rounded transition-colors disabled:opacity-50"
          on:click={doDeleteKoerselsraekke}
        >
          {isDeleting ? "Sletter…" : "Slet kørselsrække"}
        </button>
      </div>
    </div>
  </div>
{/if}