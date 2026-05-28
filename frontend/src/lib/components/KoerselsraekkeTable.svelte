<script lang="ts">
  import { formatDanishDate } from "$lib/tableColumnConfig";
  import { backendFetch } from "$lib/client/backendFetch";

  // -----------------------------
  // Props
  // -----------------------------

  export let rows: any[] = [];

  export let lookupOptions: any = {
    tidspunkter: [],
    koerselstyper: [],
    koerselstypeTillaeg: [],
    dage: []
  };

  export let onCreateKoerselsraekke: (
    updates: any
  ) => Promise<boolean>;

  export let onSaveKoerselsraekke: (
    koerselId: number,
    updates: any
  ) => Promise<boolean>;

  export let onFinalizeKoerselsraekke: (
    koerselId: number
  ) => Promise<boolean>;

  export let adresseForBevilling: string = "";
  export let matrikelId: number | null = null;


  // -----------------------------
  // Distance calculation
  // -----------------------------

  let isCalculatingDistance = false;
  let distanceCalcTarget: 'edit' | 'new' | null = null;  // drives the spinner only
  let distanceErrorFrom: 'edit' | 'new' | null = null;   // persists after finally for display
  let distanceError: string | null = null;

  function isEgenbefordring(typeId: string | number | null | undefined): boolean {
    if (!typeId) return false;
    const type = lookupOptions.koerselstyper?.find(
      (t: any) => Number(t.id) === Number(typeId)
    );
    return type?.label?.toLowerCase() === 'egenbefordring';
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

  async function doFinalize() {
    if (confirmingFinalizeId === null) return;
    isFinalizing = true;
    const id = confirmingFinalizeId;
    confirmingFinalizeId = null;
    await onFinalizeKoerselsraekke(id);
    isFinalizing = false;
  }


  // -----------------------------
  // Edit state
  // -----------------------------

  let editingKoerselId: number | null = null;
  let editableKoerselsraekke: any = {};

  let selectedTillaegIds: number[] = [];
  let selectedDagIds: number[] = [];

  let tillaegSelectValue = "";
  let dagSelectValue = "";


  // -----------------------------
  // Create state
  // -----------------------------

  let isCreating = false;
  let newKoerselsraekke: any = {};

  let newSelectedTillaegIds: number[] = [];
  let newSelectedDagIds: number[] = [];

  let newTillaegSelectValue = "";
  let newDagSelectValue = "";


  // -----------------------------
  // Styling
  // -----------------------------

  const inputClass = "border border-gray-300 px-2 py-1.5 text-sm rounded w-full focus:border-blue-400 focus:ring-0";
  const selectClass = "border border-gray-300 px-2 py-1.5 text-sm rounded w-full focus:border-blue-400 focus:ring-0";
  const tagClass = "inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs";
  const removeTagButtonClass = "ml-0.5 text-red-500 hover:text-red-700 font-bold";


  // -----------------------------
  // Derived state
  // -----------------------------

  $: availableTillaeg = (lookupOptions.koerselstypeTillaeg ?? []).filter(
    (option: any) => !selectedTillaegIds.includes(Number(option.id))
  );

  $: availableDage = (lookupOptions.dage ?? []).filter(
    (option: any) => !selectedDagIds.includes(Number(option.id))
  );

  $: availableNewTillaeg = (lookupOptions.koerselstypeTillaeg ?? []).filter(
    (option: any) => !newSelectedTillaegIds.includes(Number(option.id))
  );

  $: availableNewDage = (lookupOptions.dage ?? []).filter(
    (option: any) => !newSelectedDagIds.includes(Number(option.id))
  );


  // -----------------------------
  // Small helpers
  // -----------------------------

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


  function getTillaegLabel(id: number) {
    const option = lookupOptions.koerselstypeTillaeg?.find(
      (item: any) => Number(item.id) === Number(id)
    );

    return option?.label ?? id;
  }


  function getDagLabel(id: number) {
    const option = lookupOptions.dage?.find(
      (item: any) => Number(item.id) === Number(id)
    );

    return option?.label ?? id;
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
      final: false
    };
  }


  // -----------------------------
  // Shared selection helpers
  // -----------------------------

  function addId(currentIds: number[], value: string) {
    if (value === "") {
      return currentIds;
    }

    const id = Number(value);

    if (currentIds.includes(id)) {
      return currentIds;
    }

    return [...currentIds, id];
  }


  function removeId(currentIds: number[], id: number) {
    return currentIds.filter((existingId) => existingId !== Number(id));
  }


  // -----------------------------
  // Edit selection handlers
  // -----------------------------

  function addTillaeg() {
    selectedTillaegIds = addId(selectedTillaegIds, tillaegSelectValue);
    tillaegSelectValue = "";
  }

  function removeTillaeg(id: number) {
    selectedTillaegIds = removeId(selectedTillaegIds, id);
    tillaegSelectValue = "";
  }

  function addDag() {
    selectedDagIds = addId(selectedDagIds, dagSelectValue);
    dagSelectValue = "";
  }

  function removeDag(id: number) {
    selectedDagIds = removeId(selectedDagIds, id);
    dagSelectValue = "";
  }


  // -----------------------------
  // Create selection handlers
  // -----------------------------

  function addNewTillaeg() {
    newSelectedTillaegIds = addId(newSelectedTillaegIds, newTillaegSelectValue);
    newTillaegSelectValue = "";
  }

  function removeNewTillaeg(id: number) {
    newSelectedTillaegIds = removeId(newSelectedTillaegIds, id);
    newTillaegSelectValue = "";
  }

  function addNewDag() {
    newSelectedDagIds = addId(newSelectedDagIds, newDagSelectValue);
    newDagSelectValue = "";
  }

  function removeNewDag(id: number) {
    newSelectedDagIds = removeId(newSelectedDagIds, id);
    newDagSelectValue = "";
  }


  // -----------------------------
  // Edit row handling
  // -----------------------------

  function startEdit(row: any) {
    if (row.final) return;
    editingKoerselId = row.koersel_id;
    editableKoerselsraekke = { ...row };

    selectedTillaegIds = parseIds(row.tillaeg_ids);
    selectedDagIds = parseIds(row.dag_ids);

    tillaegSelectValue = "";
    dagSelectValue = "";
  }


  function cancelEdit() {
    editingKoerselId = null;
    editableKoerselsraekke = {};

    selectedTillaegIds = [];
    selectedDagIds = [];

    tillaegSelectValue = "";
    dagSelectValue = "";
  }


  function updateField(key: string, value: any) {
    editableKoerselsraekke = {
      ...editableKoerselsraekke,
      [key]: value
    };
  }


  async function saveEdit(row: any) {
    const updates = {
      tidspunkt_id: editableKoerselsraekke.tidspunkt_id,
      befordringstype_id: editableKoerselsraekke.befordringstype_id,
      bevilget_koereafstand_pr_vej: numberOrNull(editableKoerselsraekke.bevilget_koereafstand_pr_vej),
      gyldig_fra: editableKoerselsraekke.gyldig_fra,
      gyldig_til: editableKoerselsraekke.gyldig_til,
      taxa_id: editableKoerselsraekke.taxa_id,
      kommentar: editableKoerselsraekke.kommentar,

      tillaeg_ids: selectedTillaegIds,
      dag_ids: selectedDagIds
    };

    const success = await onSaveKoerselsraekke(row.koersel_id, updates);

    if (success) {
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
        final: false,
      };
      newSelectedTillaegIds = parseIds(source.tillaeg_ids);
      newSelectedDagIds = parseIds(source.dag_ids);
    } else {
      newKoerselsraekke = getEmptyKoerselsraekke();
      newSelectedTillaegIds = [];
      newSelectedDagIds = [];
    }

    newTillaegSelectValue = "";
    newDagSelectValue = "";
  }


  function cancelCreate() {
    isCreating = false;
    newKoerselsraekke = {};

    newSelectedTillaegIds = [];
    newSelectedDagIds = [];

    newTillaegSelectValue = "";
    newDagSelectValue = "";
  }


  function updateNewField(key: string, value: any) {
    newKoerselsraekke = {
      ...newKoerselsraekke,
      [key]: value
    };
  }


  function validateNewKoerselsraekke() {
    if (!newKoerselsraekke.tidspunkt_id) {
      alert("Tidspunkt skal udfyldes");
      return false;
    }

    if (!newKoerselsraekke.befordringstype_id) {
      alert("Kørselstype skal udfyldes");
      return false;
    }

    if (!newKoerselsraekke.gyldig_fra) {
      alert("Bevilling fra skal udfyldes");
      return false;
    }

    if (!newKoerselsraekke.gyldig_til) {
      alert("Bevilling til skal udfyldes");
      return false;
    }

    return true;
  }


  async function saveNew() {
    if (!validateNewKoerselsraekke()) {
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
      final: false,

      tillaeg_ids: newSelectedTillaegIds,
      dag_ids: newSelectedDagIds
    };

    const success = await onCreateKoerselsraekke(updates);

    if (success) {
      cancelCreate();
    }
  }
</script>


<div class="space-y-0">

  <!-- + Ny kørselsrække button / create form — above the rows -->
  {#if isCreating}

    <div class="mt-2 p-4 bg-white rounded-lg border border-gray-300 shadow-sm">
      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-4">Ny kørselsrække</p>

      <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3 mb-3">

        <label class="block">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Tidspunkt *</span>
          <select
            class={selectClass}
            value={newKoerselsraekke.tidspunkt_id ?? ""}
            on:change={(e) => updateNewField("tidspunkt_id", numberOrNull(e.currentTarget.value))}
          >
            <option value="">Vælg</option>
            {#each lookupOptions.tidspunkter ?? [] as option}
              <option value={option.id}>{option.label}</option>
            {/each}
          </select>
        </label>

        <label class="block">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kørselstype *</span>
          <select
            class={selectClass}
            value={newKoerselsraekke.befordringstype_id ?? ""}
            on:change={(e) => {
              const id = numberOrNull(e.currentTarget.value);
              updateNewField("befordringstype_id", id);
              calculateAndFillDistance(id, 'new');
            }}
          >
            <option value="">Vælg</option>
            {#each lookupOptions.koerselstyper ?? [] as option}
              <option value={option.id}>{option.label}</option>
            {/each}
          </select>
        </label>

        <label class="block">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 flex items-center gap-1.5">
            Bevilget km pr. vej *
            {#if isCalculatingDistance && distanceCalcTarget === 'new'}
              <span class="text-blue-500 font-normal normal-case text-[10px]">beregner...</span>
            {/if}
          </span>
          <input
            type="number"
            step="0.1"
            class="{inputClass} {isCalculatingDistance && distanceCalcTarget === 'new' ? 'opacity-50' : ''}"
            disabled={isCalculatingDistance && distanceCalcTarget === 'new'}
            value={newKoerselsraekke.bevilget_koereafstand_pr_vej ?? ""}
            on:change={(e) => updateNewField("bevilget_koereafstand_pr_vej", e.currentTarget.value)}
          />
        </label>

        <label class="block">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig fra *</span>
          <input
            type="date"
            class={inputClass}
            value={newKoerselsraekke.gyldig_fra ?? ""}
            on:change={(e) => updateNewField("gyldig_fra", e.currentTarget.value)}
          />
        </label>

        <label class="block">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig til *</span>
          <input
            type="date"
            class={inputClass}
            value={newKoerselsraekke.gyldig_til ?? ""}
            on:change={(e) => updateNewField("gyldig_til", e.currentTarget.value)}
          />
        </label>

        <label class="block">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Taxa-ID</span>
          <input
            class={inputClass}
            value={newKoerselsraekke.taxa_id ?? ""}
            on:change={(e) => updateNewField("taxa_id", e.currentTarget.value)}
          />
        </label>

      </div>

      <div class="mb-3">
        <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kørselstype tillæg</span>
        <div class="flex flex-wrap gap-1.5 mb-1.5">
          {#each newSelectedTillaegIds as selectedId}
            <span class={tagClass}>
              {getTillaegLabel(selectedId)}
              <button type="button" class={removeTagButtonClass} on:click={() => removeNewTillaeg(selectedId)}>×</button>
            </span>
          {/each}
        </div>
        <select class="border border-gray-300 pl-2 pr-8 py-1.5 text-sm rounded" bind:value={newTillaegSelectValue} on:change={addNewTillaeg}>
          <option value="">+ Tilføj tillæg</option>
          {#each availableNewTillaeg as option}
            <option value={String(option.id)}>{option.label}</option>
          {/each}
        </select>
      </div>

      <div class="mb-3">
        <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Dage</span>
        <div class="flex flex-wrap gap-1.5 mb-1.5">
          {#each newSelectedDagIds as selectedId}
            <span class={tagClass}>
              {getDagLabel(selectedId)}
              <button type="button" class={removeTagButtonClass} on:click={() => removeNewDag(selectedId)}>×</button>
            </span>
          {/each}
        </div>
        <select class="border border-gray-300 pl-2 pr-8 py-1.5 text-sm rounded" bind:value={newDagSelectValue} on:change={addNewDag}>
          <option value="">+ Tilføj dag</option>
          {#each availableNewDage as option}
            <option value={String(option.id)}>{option.label}</option>
          {/each}
        </select>
      </div>

      <label class="block mb-4">
        <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kommentar</span>
        <input
          class={inputClass}
          value={newKoerselsraekke.kommentar ?? ""}
          on:change={(e) => updateNewField("kommentar", e.currentTarget.value)}
        />
      </label>

      {#if distanceError && distanceErrorFrom === 'new'}
        <div class="mb-4 px-3 py-2 text-xs text-red-700 bg-red-50 border border-red-200 rounded">
          {distanceError}
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
        class="text-sm font-medium text-sky-700 hover:underline"
        on:click={startCreate}
      >
        + Ny kørselsrække
      </button>
    </div>

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
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3 mb-3">

          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Tidspunkt</span>
            <select
              class={selectClass}
              value={editableKoerselsraekke.tidspunkt_id ?? ""}
              on:change={(e) => updateField("tidspunkt_id", numberOrNull(e.currentTarget.value))}
            >
              <option value="">Vælg</option>
              {#each lookupOptions.tidspunkter ?? [] as option}
                <option value={option.id}>{option.label}</option>
              {/each}
            </select>
          </label>

          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kørselstype</span>
            <select
              class={selectClass}
              value={editableKoerselsraekke.befordringstype_id ?? ""}
              on:change={(e) => {
                const id = numberOrNull(e.currentTarget.value);
                updateField("befordringstype_id", id);
                calculateAndFillDistance(id, 'edit');
              }}
            >
              <option value="">Vælg</option>
              {#each lookupOptions.koerselstyper ?? [] as option}
                <option value={option.id}>{option.label}</option>
              {/each}
            </select>
          </label>

          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 flex items-center gap-1.5">
              Km pr. vej
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
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig fra</span>
            <input
              type="date"
              class={inputClass}
              value={editableKoerselsraekke.gyldig_fra ?? ""}
              on:change={(e) => updateField("gyldig_fra", e.currentTarget.value)}
            />
          </label>

          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Gyldig til</span>
            <input
              type="date"
              class={inputClass}
              value={editableKoerselsraekke.gyldig_til ?? ""}
              on:change={(e) => updateField("gyldig_til", e.currentTarget.value)}
            />
          </label>

          <label class="block">
            <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Taxa-ID</span>
            <input
              class={inputClass}
              value={editableKoerselsraekke.taxa_id ?? ""}
              on:change={(e) => updateField("taxa_id", e.currentTarget.value)}
            />
          </label>

        </div>

        <div class="mb-3">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kørselstype tillæg</span>
          <div class="flex flex-wrap gap-1.5 mb-1.5">
            {#each selectedTillaegIds as selectedId}
              <span class={tagClass}>
                {getTillaegLabel(selectedId)}
                <button type="button" class={removeTagButtonClass} on:click={() => removeTillaeg(selectedId)}>×</button>
              </span>
            {/each}
          </div>
          <select class="border border-gray-300 pl-2 pr-8 py-1.5 text-sm rounded" bind:value={tillaegSelectValue} on:change={addTillaeg}>
            <option value="">+ Tilføj tillæg</option>
            {#each availableTillaeg as option}
              <option value={String(option.id)}>{option.label}</option>
            {/each}
          </select>
        </div>

        <div class="mb-3">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Dage</span>
          <div class="flex flex-wrap gap-1.5 mb-1.5">
            {#each selectedDagIds as selectedId}
              <span class={tagClass}>
                {getDagLabel(selectedId)}
                <button type="button" class={removeTagButtonClass} on:click={() => removeDag(selectedId)}>×</button>
              </span>
            {/each}
          </div>
          <select class="border border-gray-300 pl-2 pr-8 py-1.5 text-sm rounded" bind:value={dagSelectValue} on:change={addDag}>
            <option value="">+ Tilføj dag</option>
            {#each availableDage as option}
              <option value={String(option.id)}>{option.label}</option>
            {/each}
          </select>
        </div>

        <label class="block mb-3">
          <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1 block">Kommentar</span>
          <input
            class={inputClass}
            value={editableKoerselsraekke.kommentar ?? ""}
            on:change={(e) => updateField("kommentar", e.currentTarget.value)}
          />
        </label>

        {#if distanceError && distanceErrorFrom === 'edit'}
          <div class="mb-3 px-3 py-2 text-xs text-red-700 bg-red-50 border border-red-200 rounded">
            {distanceError}
          </div>
        {/if}

        <div class="flex gap-2">
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
        </div>
      </div>

    {:else}

      <!-- Compact view row -->
      <div class="mb-2 bg-white rounded-lg border shadow-sm overflow-hidden {row.final ? 'border-gray-200' : 'border-gray-300'}" style="border-left: 3px solid {row.final ? '#9ca3af' : '#2ab4a0'};">

        <!-- Top: identifier badges + actions -->
        <div class="flex items-center justify-between gap-3 px-4 py-3 flex-wrap">
          <div class="flex items-center gap-1.5 flex-wrap">
            {#if row.tidspunkt_tekst}
              <span class="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-100 text-blue-700">
                {row.tidspunkt_tekst}
              </span>
            {/if}
            {#if row.befordringstype_tekst}
              <span class="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-teal-100 text-teal-700">
                {row.befordringstype_tekst}
              </span>
            {/if}
            {#if row.tillaeg_tekst}
              {#each row.tillaeg_tekst.split(',') as t}
                <span class="px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700 border border-amber-200">
                  {t.trim()}
                </span>
              {/each}
            {/if}
          </div>

          <div class="flex items-center gap-2 shrink-0">
            {#if row.final}
              <!-- Locked state: static badge -->
              <span class="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium text-gray-500 bg-gray-100 border border-gray-200 rounded">
                <!-- lock-closed icon -->
                <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
                Afsluttet
              </span>
            {:else}
              <!-- Unlocked state: redigér + lock button -->
              <button
                type="button"
                class="px-3 py-1 text-xs border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                on:click={() => startEdit(row)}
              >
                Redigér
              </button>
              <button
                type="button"
                title="Afslut kørselsrække"
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

        <!-- Bottom: labeled detail grid -->
        <div class="px-4 pb-3 pt-1 border-t border-gray-100 grid grid-cols-2 sm:grid-cols-4 gap-x-6 gap-y-3">
          {#if row.dage}
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Dage</p>
              <p class="text-xs font-medium text-gray-700">{row.dage}</p>
            </div>
          {/if}
          {#if row.gyldig_fra || row.gyldig_til}
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Periode</p>
              <p class="text-xs font-medium text-gray-700">
                {formatDanishDate(row.gyldig_fra)} → {formatDanishDate(row.gyldig_til)}
              </p>
            </div>
          {/if}
          {#if row.bevilget_koereafstand_pr_vej != null}
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Km pr. vej</p>
              <p class="text-xs font-medium text-gray-700">
                {parseFloat(row.bevilget_koereafstand_pr_vej).toFixed(2).replace(/\.?0+$/, '') || '0'}
              </p>
            </div>
          {/if}
          {#if row.taxa_id}
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Taxa</p>
              <p class="text-xs font-medium text-gray-700">{row.taxa_id}</p>
            </div>
          {/if}
        </div>

        {#if row.kommentar}
          <div class="px-4 pb-3 text-xs italic text-gray-500 border-t border-gray-100 pt-2">
            {row.kommentar}
          </div>
        {/if}

      </div>

    {/if}

  {/each}



</div>


<!-- Finalize confirmation modal -->
{#if confirmingFinalizeId !== null}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    on:click|self={() => confirmingFinalizeId = null}
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
            <h2 class="text-base font-semibold text-gray-900">Afslut kørselsrække</h2>
            <p class="text-xs text-gray-500 mt-0.5">Denne handling kan ikke fortrydes</p>
          </div>
        </div>
      </div>

      <div class="px-6 py-5">
        <p class="text-sm text-gray-700">
          Kørselsrækken vil blive markeret som <strong>afsluttet</strong> og kan herefter ikke længere redigeres via applikationen.
        </p>
        <p class="text-sm text-gray-500 mt-2">
          Er du sikker på, at du vil afslutte denne kørselsrække?
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
          {isFinalizing ? 'Afslutter...' : 'Afslut kørselsrække'}
        </button>
      </div>
    </div>
  </div>
{/if}
