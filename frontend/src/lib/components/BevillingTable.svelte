<script lang="ts">
  import KoerselsraekkeTable from "$lib/components/KoerselsraekkeTable.svelte";
  import AddresseSearch from "$lib/components/AddresseSearch.svelte";

  import {
    getStatusBadgeClass,
    formatDanishDate,
  } from "$lib/tableColumnConfig";
  import { backendFetch } from "$lib/client/backendFetch";

  // -----------------------------
  // Props
  // -----------------------------

  export let bevillinger: any[] = [];

  export let lookupOptions: any = {
    statuser: [],
    skolematrikler: [],
    hjemler: [],
    afgoerelsesbreve: [],
    sagsbehandlere: [],
    pprSagsbehandlere: [],
    hjaelpemidler: []
  };

  export let onSaveBevilling: (
    bevillingId: number,
    updates: any
  ) => Promise<boolean>;

  export let onSaveKoerselsraekke: (
    koerselId: number,
    updates: any
  ) => Promise<boolean> = async () => false;

  export let onCreateKoerselsraekke: (
    bevillingId: number,
    updates: any
  ) => Promise<boolean>;

  export let onFinalizeKoerselsraekke: (
    koerselId: number
  ) => Promise<boolean> = async () => false;


  // -----------------------------
  // Table state
  // -----------------------------

  let expandedRows = new Set<number>();

  let editingBevillingId: number | null = null;
  let editableBevilling: any = {};

  let selectedHjaelpemiddelIds: number[] = [];
  let hjaelpemiddelSelectValue = "";


  // -----------------------------
  // Styling
  // -----------------------------

  const inputClass = "border border-gray-300 px-2 py-1 text-sm rounded focus:border-blue-400 focus:ring-0";
  const mediumSelectClass = "w-full border border-gray-300 px-2 py-1 pr-8 text-sm rounded focus:border-blue-400 focus:ring-0";
  const largeSelectClass = "w-full border border-gray-300 px-2 py-1 pr-8 text-sm rounded focus:border-blue-400 focus:ring-0";

  function getStatusBemaerkningClass(status: string | null | undefined): string {
    switch (status) {
      case "Fejlet":       return "bg-red-50 text-red-700 border border-red-200";
      case "Revurdering":  return "bg-amber-50 text-amber-700 border border-amber-200";
      case "Afslag":       return "bg-orange-50 text-orange-700 border border-orange-200";
      case "Ophørt":       return "bg-gray-100 text-gray-600 border border-gray-300";
      case "Udløbet":      return "bg-gray-100 text-gray-600 border border-gray-300";
      default:             return "bg-blue-50 text-blue-700 border border-blue-200";
    }
  }

  function getStatusBemaerkningIcon(status: string | null | undefined): string {
    switch (status) {
      case "Fejlet":      return "error";
      case "Revurdering": return "warning";
      case "Afslag":      return "warning";
      default:            return "info";
    }
  }


  // -----------------------------
  // Derived state
  // -----------------------------

  $: availableHjaelpemidler = (lookupOptions.hjaelpemidler ?? []).filter(
    (option: any) => !selectedHjaelpemiddelIds.includes(Number(option.id))
  );


  // -----------------------------
  // Small helpers
  // -----------------------------

  function numberOrNull(value: string) {
    if (value === "") {
      return null;
    }

    return Number(value);
  }

  function emptyToNull(value: string) {
    if (value === "") {
      return null;
    }

    return value;
  }


  function parseHjaelpemiddelIds(rawValue: string | null | undefined) {
    if (!rawValue) {
      return [];
    }

    return rawValue
      .split(",")
      .map((value) => Number(value))
      .filter((value) => !Number.isNaN(value));
  }


  function getHjaelpemiddelLabel(id: number) {
    const option = lookupOptions.hjaelpemidler?.find(
      (item: any) => Number(item.id) === Number(id)
    );

    return option?.label ?? id;
  }


  // -----------------------------
  // Expand/collapse
  // -----------------------------

  function toggleRow(bevillingId: number) {
    if (expandedRows.has(bevillingId)) {
      expandedRows.delete(bevillingId);
    } else {
      expandedRows.add(bevillingId);
    }

    expandedRows = new Set(expandedRows);
  }


  // -----------------------------
  // Hjælpemiddel selection
  // -----------------------------

  function addHjaelpemiddel() {
    if (hjaelpemiddelSelectValue === "") {
      return;
    }

    const id = Number(hjaelpemiddelSelectValue);

    if (!selectedHjaelpemiddelIds.includes(id)) {
      selectedHjaelpemiddelIds = [
        ...selectedHjaelpemiddelIds,
        id
      ];
    }

    hjaelpemiddelSelectValue = "";
  }


  function removeHjaelpemiddel(id: number) {
    selectedHjaelpemiddelIds = selectedHjaelpemiddelIds.filter(
      (existingId) => existingId !== Number(id)
    );

    hjaelpemiddelSelectValue = "";
  }


  // -----------------------------
  // Egenbefordring auto-recalculation
  // -----------------------------

  function isEgenbefordringType(typeId: number | null | undefined): boolean {
    if (!typeId) return false;
    const type = lookupOptions.koerselstyper?.find(
      (t: any) => Number(t.id) === Number(typeId)
    );
    return type?.label?.toLowerCase() === 'egenbefordring';
  }

  function parseIds(raw: string | null | undefined): number[] {
    if (!raw) return [];
    return raw.split(',').map(Number).filter(n => !isNaN(n));
  }

  async function recalculateEgenbefordringRows(
    koerselsraekker: any[],
    lat1: number,
    lon1: number,
    matrikel: number
  ) {
    const egenRows = koerselsraekker.filter(k => isEgenbefordringType(k.befordringstype_id));
    if (egenRows.length === 0) return;

    // Get school coordinates
    const schoolRes = await backendFetch(`/lookup/skolematrikel/${matrikel}/coordinates`);
    if (!schoolRes.ok) return;
    const { latitude: lat2, longitude: lon2 } = await schoolRes.json();

    // Calculate distance once
    const distParams = new URLSearchParams({
      lat1: String(lat1), lon1: String(lon1),
      lat2: String(lat2), lon2: String(lon2)
    });
    const distRes = await backendFetch(`/bevilling/calculate_driving_distance?${distParams}`);
    if (!distRes.ok) return;
    const { distance_km } = await distRes.json();

    // Update each egenbefordring row
    for (const koersel of egenRows) {
      await onSaveKoerselsraekke(koersel.koersel_id, {
        tidspunkt_id: koersel.tidspunkt_id,
        befordringstype_id: koersel.befordringstype_id,
        bevilget_koereafstand_pr_vej: distance_km,
        gyldig_fra: koersel.gyldig_fra,
        gyldig_til: koersel.gyldig_til,
        taxa_id: koersel.taxa_id,
        kommentar: koersel.kommentar,
        tillaeg_ids: parseIds(koersel.tillaeg_ids),
        dag_ids: parseIds(koersel.dag_ids)
      });
    }
  }


  // -----------------------------
  // Bevilling edit handling
  // -----------------------------

  const manualStatusLabels = ["Afslag", "Ophørt"];

  $: manualStatuser = (lookupOptions.statuser ?? []).filter(
    (s: any) => manualStatusLabels.includes(s.label)
  );

  function startEdit(bevilling: any) {
    editingBevillingId = bevilling.bevilling_id;

    // Only pre-select a status if it's one of the manual ones.
    // Otherwise show "Auto" so computed statuses aren't editable.
    const isManualStatus = manualStatusLabels.includes(bevilling.status_tekst);
    editableBevilling = {
      ...bevilling,
      status_id:    isManualStatus ? bevilling.status_id : null,
      // Address fields — adresse_for_bevilling is the text alias from the view
      adresse_id:   bevilling.adresse_id   ?? null,
      adresse_tekst: bevilling.adresse_for_bevilling ?? "",
      adresse_lat:  bevilling.adresse_latitude  ?? null,
      adresse_lon:  bevilling.adresse_longitude ?? null,
    };

    selectedHjaelpemiddelIds = parseHjaelpemiddelIds(
      bevilling.hjaelpemiddel_ids
    );

    hjaelpemiddelSelectValue = "";
  }


  function cancelEdit() {
    editingBevillingId = null;
    editableBevilling = {};

    selectedHjaelpemiddelIds = [];
    hjaelpemiddelSelectValue = "";
  }


  function updateField(key: string, value: any) {
    editableBevilling = {
      ...editableBevilling,
      [key]: value
    };
  }


  async function saveEdit(bevilling: any) {
    // null status_id means the user selected "Auto" — ask the SP to recalculate
    // freely instead of sending a manual status_id.
    const statusField = editableBevilling.status_id
      ? { status_id: editableBevilling.status_id }
      : { reset_status: true };

    const updates = {
      ...statusField,
      sagsbehandlingsdato: editableBevilling.sagsbehandlingsdato,
      adresse_id: editableBevilling.adresse_id,
      matrikel_id: editableBevilling.matrikel_id,
      afstandskriterie_dato: editableBevilling.afstandskriterie_dato,
      afstandskriterie_klassetrin: editableBevilling.afstandskriterie_klassetrin,
      relation_til_barnet: editableBevilling.relation_til_barnet,
      revurderingsdato: editableBevilling.revurderingsdato,
      befordringsudvalg: editableBevilling.befordringsudvalg,
      hjemmel_id: editableBevilling.hjemmel_id,
      afgoerelsesbrev_id: editableBevilling.afgoerelsesbrev_id,
      sagsbehandler_id: editableBevilling.sagsbehandler_id,
      ppr_sagsbehandler_id: editableBevilling.ppr_sagsbehandler_id,

      hjaelpemiddel_ids: selectedHjaelpemiddelIds
    };

    const addressChanged = editableBevilling.adresse_id !== bevilling.adresse_id;
    const schoolChanged  = editableBevilling.matrikel_id !== bevilling.matrikel_id;
    const koerselsraekker = [...(bevilling.koerselsraekker ?? [])];
    const newMatrikelId   = editableBevilling.matrikel_id;
    const adresseLat      = editableBevilling.adresse_lat;
    const adresseLon      = editableBevilling.adresse_lon;

    const success = await onSaveBevilling(bevilling.bevilling_id, updates);

    if (success) {
      if ((addressChanged || schoolChanged) && newMatrikelId && adresseLat && adresseLon) {
        await recalculateEgenbefordringRows(koerselsraekker, adresseLat, adresseLon, newMatrikelId);
      }
      cancelEdit();
    }
  }
</script>


<div class="space-y-4">

  {#if bevillinger.length === 0}
    <div class="bg-white border border-gray-200 rounded-lg p-8 text-center text-gray-500 text-sm">
      Ingen bevillinger fundet.
    </div>
  {:else}

    {#each bevillinger as bevilling}

      {@const isEditing = editingBevillingId === bevilling.bevilling_id}
      {@const isExpanded = expandedRows.has(bevilling.bevilling_id)}
      {@const koerselCount = bevilling.koerselsraekker?.length ?? 0}

      <div class="bg-white border border-gray-300 rounded-lg shadow overflow-hidden">

        <!-- Card header -->
        <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <div class="flex items-center gap-3">
            {#if isEditing}
              <select
                class="border border-gray-300 px-2 py-1 pr-6 text-sm rounded focus:border-blue-400 focus:ring-0"
                value={editableBevilling.status_id ?? ""}
                on:change={(e) => updateField("status_id", numberOrNull(e.currentTarget.value))}
              >
                <option value="">Auto (beregnet automatisk)</option>
                {#each manualStatuser as option}
                  <option value={option.id}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <span class="inline-block px-2 py-0.5 rounded text-xs font-medium {getStatusBadgeClass(bevilling.status_tekst)}">
                {bevilling.status_tekst ?? ""}
              </span>
              {#if bevilling.statusbemaerkning}
                <span class="inline-flex items-center gap-1.5 rounded px-2 py-0.5 text-xs font-medium {getStatusBemaerkningClass(bevilling.status_tekst)}">
                  {#if getStatusBemaerkningIcon(bevilling.status_tekst) === "error"}
                    <!-- X-circle -->
                    <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <circle cx="12" cy="12" r="9"/>
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 9l-6 6M9 9l6 6"/>
                    </svg>
                  {:else if getStatusBemaerkningIcon(bevilling.status_tekst) === "warning"}
                    <!-- Triangle warning -->
                    <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v4m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
                    </svg>
                  {:else}
                    <!-- Info circle -->
                    <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <circle cx="12" cy="12" r="9"/>
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 8h.01M12 12v4"/>
                    </svg>
                  {/if}
                  {bevilling.statusbemaerkning}
                </span>
              {/if}
            {/if}
            <span class="font-mono text-sm text-gray-500">{bevilling.esdh_noegle ?? ""}</span>
          </div>

          <div class="flex items-center gap-2">
            {#if isEditing}
              <button
                type="button"
                disabled={!editableBevilling.adresse_id}
                class="px-3 py-1.5 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-green-600"
                on:click={() => saveEdit(bevilling)}
              >
                Gem
              </button>
              <button
                type="button"
                class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                on:click={cancelEdit}
              >
                Annullér
              </button>
            {:else}
              <button
                type="button"
                class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                on:click={() => startEdit(bevilling)}
              >
                Redigér
              </button>
            {/if}

            <button
              type="button"
              class="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
              on:click={() => toggleRow(bevilling.bevilling_id)}
            >
              Kørselsrækker {koerselCount}
              <span class="text-xs opacity-60">{isExpanded ? "▲" : "▼"}</span>
            </button>
          </div>
        </div>


        <!-- Card body: field grid -->
        <div class="px-4 md:px-6 py-5 grid grid-cols-1 sm:grid-cols-2 md:grid-cols-5 gap-x-6 gap-y-5">

          <!-- ANSØGNINGSTYPE -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Ansøgningstype</p>
            <p class="text-sm text-gray-800">{bevilling.ansoegningstype ?? "—"}</p>
          </div>

          <!-- OPRETTET -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Oprettet</p>
            <p class="text-sm text-gray-800">{formatDanishDate(bevilling.created_at?.slice(0, 10))}</p>
          </div>

          <!-- SAGSBEHANDLINGSDATO -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Sagsbehandlingsdato</p>
            {#if isEditing}
              <input
                type="date"
                class={inputClass}
                value={editableBevilling.sagsbehandlingsdato ?? ""}
                on:change={(e) => updateField("sagsbehandlingsdato", emptyToNull(e.currentTarget.value))}
              />
            {:else}
              <p class="text-sm text-gray-800">{formatDanishDate(bevilling.sagsbehandlingsdato)}</p>
            {/if}
          </div>

          <!-- ADRESSE FOR BEVILLING -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Adresse for bevilling</p>
            {#if isEditing}
              <AddresseSearch
                adresseId={editableBevilling.adresse_id}
                adresseTekst={editableBevilling.adresse_tekst ?? ""}
                inputClass={inputClass + " w-full"}
                onSelect={(result) => {
                  editableBevilling = {
                    ...editableBevilling,
                    adresse_id:    result?.adresse_id   ?? null,
                    adresse_tekst: result?.adresse_tekst ?? "",
                    adresse_lat:   result?.latitude      ?? null,
                    adresse_lon:   result?.longitude     ?? null,
                  };
                }}
              />
            {:else}
              <p class="text-sm text-gray-800">{bevilling.adresse_for_bevilling ?? "—"}</p>
            {/if}
          </div>

          <!-- SKOLE -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Skole</p>
            {#if isEditing}
              {#if editableBevilling.ungdomsuddannelse_id && !editableBevilling.matrikel_id}
                <select
                  class={largeSelectClass}
                  value={editableBevilling.ungdomsuddannelse_id ?? ""}
                  on:change={(e) => updateField("ungdomsuddannelse_id", numberOrNull(e.currentTarget.value))}
                >
                  <option value="">Vælg</option>
                  {#each lookupOptions.ungdomsuddannelser ?? [] as option}
                    <option value={option.id}>{option.label}</option>
                  {/each}
                </select>
              {:else}
                <select
                  class={largeSelectClass}
                  value={editableBevilling.matrikel_id ?? ""}
                  on:change={(e) => updateField("matrikel_id", numberOrNull(e.currentTarget.value))}
                >
                  <option value="">Vælg</option>
                  {#each lookupOptions.skolematrikler ?? [] as option}
                    <option value={option.id}>{option.label}</option>
                  {/each}
                </select>
              {/if}
            {:else}
              <p class="text-sm text-gray-800">
                {bevilling.skole_navn ?? bevilling.matrikel_navn ?? bevilling.ungdomsuddannelse_navn ?? "—"}
              </p>
              {#if bevilling.ungdomsuddannelse_id && !bevilling.matrikel_id}
                <span class="inline-block mt-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-slate-100 text-slate-600">
                  Ungdomsuddannelse
                </span>
              {/if}
            {/if}
          </div>

          <!-- HJÆLPEMIDLER -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Hjælpemidler</p>
            {#if isEditing}
              <div class="flex flex-wrap gap-1.5 mb-2">
                {#each selectedHjaelpemiddelIds as selectedId}
                  <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                    {getHjaelpemiddelLabel(selectedId)}
                    <button
                      type="button"
                      class="ml-0.5 text-red-500 hover:text-red-700 font-bold"
                      on:click={() => removeHjaelpemiddel(selectedId)}
                    >×</button>
                  </span>
                {/each}
              </div>
              <select
                class="min-w-44 border border-gray-300 px-2 py-1 pr-6 text-sm rounded"
                bind:value={hjaelpemiddelSelectValue}
                on:change={addHjaelpemiddel}
              >
                <option value="">Tilføj hjælpemiddel</option>
                {#each availableHjaelpemidler as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <p class="text-sm text-gray-800">{bevilling.hjaelpemidler ?? "—"}</p>
            {/if}
          </div>

          <!-- AFSTANDSKRITERIE DATO -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Afstandskriterie dato</p>
            {#if isEditing}
              <input
                type="date"
                class={inputClass}
                value={editableBevilling.afstandskriterie_dato ?? ""}
                on:change={(e) => updateField("afstandskriterie_dato", emptyToNull(e.currentTarget.value))}
              />
            {:else}
              <p class="text-sm text-gray-800">{formatDanishDate(bevilling.afstandskriterie_dato)}</p>
            {/if}
          </div>

          <!-- AFSTANDSKRITERIE KLASSETRIN -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Afstandskriterie klassetrin</p>
            {#if isEditing}
              <input
                type="number"
                class="{inputClass} w-24"
                value={editableBevilling.afstandskriterie_klassetrin ?? ""}
                on:change={(e) => updateField("afstandskriterie_klassetrin", numberOrNull(e.currentTarget.value))}
              />
            {:else}
              <p class="text-sm text-gray-800">{bevilling.afstandskriterie_klassetrin ?? "—"}</p>
            {/if}
          </div>

          <!-- ANSØGER RELATION -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Ansøger relation</p>
            <p class="text-sm text-gray-800">{bevilling.relation_til_barnet ?? "—"}</p>
          </div>

          <!-- REVURDERING -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Revurdering</p>
            {#if isEditing}
              <input
                type="date"
                class={inputClass}
                value={editableBevilling.revurderingsdato ?? ""}
                on:change={(e) => updateField("revurderingsdato", emptyToNull(e.currentTarget.value))}
              />
            {:else}
              <p class="text-sm text-gray-800">{formatDanishDate(bevilling.revurderingsdato)}</p>
            {/if}
          </div>

          <!-- BEFORDRINGSUDVALG -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Befordringsudvalg</p>
            {#if isEditing}
              <input
                type="date"
                class={inputClass}
                value={editableBevilling.befordringsudvalg ?? ""}
                on:change={(e) => updateField("befordringsudvalg", emptyToNull(e.currentTarget.value))}
              />
            {:else}
              <p class="text-sm text-gray-800">{formatDanishDate(bevilling.befordringsudvalg)}</p>
            {/if}
          </div>

          <!-- HJEMMEL -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Hjemmel</p>
            {#if isEditing}
              <select
                class={largeSelectClass}
                value={editableBevilling.hjemmel_id ?? ""}
                on:change={(e) => updateField("hjemmel_id", numberOrNull(e.currentTarget.value))}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.hjemler ?? [] as option}
                  <option value={option.id}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <p class="text-sm text-gray-800">{bevilling.hjemmel_tekst ?? "—"}</p>
            {/if}
          </div>

          <!-- AFGØRELSESBREV -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Afgørelsesbrev</p>
            {#if isEditing}
              <select
                class={largeSelectClass}
                value={editableBevilling.afgoerelsesbrev_id ?? ""}
                on:change={(e) => updateField("afgoerelsesbrev_id", numberOrNull(e.currentTarget.value))}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.afgoerelsesbreve ?? [] as option}
                  <option value={option.id}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <p class="text-sm text-gray-800">{bevilling.afgoerelsesbrev_tekst ?? "—"}</p>
            {/if}
          </div>

          <!-- SAGSBEHANDLER -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Sagsbehandler</p>
            {#if isEditing}
              <select
                class={mediumSelectClass}
                value={editableBevilling.sagsbehandler_id ?? ""}
                on:change={(e) => updateField("sagsbehandler_id", numberOrNull(e.currentTarget.value))}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.sagsbehandlere ?? [] as option}
                  <option value={option.id}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <p class="text-sm text-gray-800">{bevilling.sagsbehandler_tekst ?? "—"}</p>
            {/if}
          </div>

          <!-- PPR ANSVARLIG -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">PPR ansvarlig</p>
            {#if isEditing}
              <select
                class={mediumSelectClass}
                value={editableBevilling.ppr_sagsbehandler_id ?? ""}
                on:change={(e) => updateField("ppr_sagsbehandler_id", numberOrNull(e.currentTarget.value))}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.pprSagsbehandlere ?? [] as option}
                  <option value={option.id}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <p class="text-sm text-gray-800">{bevilling.ppr_sagsbehandler_tekst ?? "—"}</p>
            {/if}
          </div>

        </div>


        <!-- Kørselsrækker section (expanded) -->
        {#if isExpanded}
          <div class="border-t-2 border-gray-300 bg-gray-100">

            <div class="px-6 py-2.5 border-b border-gray-300">
              <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500">Kørselsrækker</p>
            </div>

            <div class="px-6 py-4">
              <KoerselsraekkeTable
                rows={bevilling.koerselsraekker ?? []}
                lookupOptions={lookupOptions}
                adresseForBevilling={bevilling.adresse_for_bevilling ?? ""}
                matrikelId={bevilling.matrikel_id ?? null}
                onSaveKoerselsraekke={onSaveKoerselsraekke}
                onCreateKoerselsraekke={(updates) => onCreateKoerselsraekke(bevilling.bevilling_id, updates)}
                onFinalizeKoerselsraekke={onFinalizeKoerselsraekke}
              />
            </div>

          </div>
        {/if}

      </div>

    {/each}

  {/if}

</div>
