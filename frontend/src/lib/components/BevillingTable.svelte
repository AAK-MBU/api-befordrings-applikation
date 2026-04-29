<script lang="ts">
  import KoerselsraekkeTable from "$lib/components/KoerselsraekkeTable.svelte";
  import { getStatusBadgeClass } from "$lib/tableColumnConfig";


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

  const inputClass = "border px-2 py-1 text-sm";
  const smallSelectClass = "min-w-36 border px-2 py-1 pr-8 text-sm";
  const mediumSelectClass = "min-w-52 border px-2 py-1 pr-8 text-sm";
  const largeSelectClass = "min-w-64 border px-2 py-1 pr-8 text-sm";


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

    // Reassigning forces Svelte reactivity for Set changes
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
  // Bevilling edit handling
  // -----------------------------

  function startEdit(bevilling: any) {
    editingBevillingId = bevilling.bevilling_id;
    editableBevilling = { ...bevilling };

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
    const updates = {
      status_id: editableBevilling.status_id,
      sagsbehandlingsdato: editableBevilling.sagsbehandlingsdato,
      adresse_for_bevilling: editableBevilling.adresse_for_bevilling,
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

    const success = await onSaveBevilling(bevilling.bevilling_id, updates);

    if (success) {
      cancelEdit();
    }
  }
</script>


<div class="w-full overflow-x-auto">

  <table class="w-full text-sm border-collapse">

    <thead>
      <tr class="bg-gray-100 text-left">
        <th class="w-12 px-2 py-2"></th>
        <th class="w-24 px-3 py-2 font-medium whitespace-nowrap">Handling</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Status</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Sagsbehandlingsdato</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Adresse for bevilling</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Skole</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Gåafstand (km)</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Hjælpemidler</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Afstandskriterie dato</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Afstandskriterie klassetrin</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Ansøger relation</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Revurdering</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Befordringsudvalg</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Hjemmel</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Afgørelsesbrev</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">Sagsbehandler</th>
        <th class="px-3 py-2 font-medium whitespace-nowrap">PPR ansvarlig</th>
      </tr>
    </thead>


    <tbody>

      {#if bevillinger.length === 0}

        <tr>
          <td colspan="17" class="px-3 py-6 text-gray-500">
            Ingen bevillinger fundet.
          </td>
        </tr>

      {:else}

        {#each bevillinger as bevilling}

          {@const isEditing = editingBevillingId === bevilling.bevilling_id}
          {@const isExpanded = expandedRows.has(bevilling.bevilling_id)}

          <tr class="border-b border-gray-100 hover:bg-gray-50">

            <td class="px-2 py-2 align-top">
              <button
                type="button"
                class="text-yellow-600 hover:scale-110"
                on:click={() => toggleRow(bevilling.bevilling_id)}
                aria-label="Vis kørselsrækker"
              >
                {isExpanded ? "📂" : "📁"}
              </button>
            </td>


            <td class="px-3 py-2 whitespace-nowrap">
              {#if isEditing}
                <button
                  type="button"
                  class="text-green-700 hover:underline mr-2"
                  on:click={() => saveEdit(bevilling)}
                >
                  Gem
                </button>

                <button
                  type="button"
                  class="text-red-600 hover:underline"
                  on:click={cancelEdit}
                >
                  Annullér
                </button>
              {:else}
                <button
                  type="button"
                  class="text-sky-600 hover:underline"
                  on:click={() => startEdit(bevilling)}
                >
                  Redigér
                </button>
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap min-w-36">
              {#if isEditing}
                <select
                  class={smallSelectClass}
                  value={editableBevilling.status_id ?? ""}
                  on:change={(e) => updateField("status_id", numberOrNull(e.currentTarget.value))}
                >
                  <option value="">Vælg</option>

                  {#each lookupOptions.statuser ?? [] as option}
                    <option value={option.id}>
                      {option.label}
                    </option>
                  {/each}
                </select>
              {:else}
                <span class={`inline-block px-3 py-1 ${getStatusBadgeClass(bevilling.status_tekst)}`}>
                  {bevilling.status_tekst ?? ""}
                </span>
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap">
              {#if isEditing}
                <input
                  type="date"
                  class={inputClass}
                  value={editableBevilling.sagsbehandlingsdato ?? ""}
                  on:change={(e) => updateField("sagsbehandlingsdato", e.currentTarget.value)}
                />
              {:else}
                {bevilling.sagsbehandlingsdato ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap">
              {#if isEditing}
                <input
                  class={`${inputClass} min-w-56`}
                  value={editableBevilling.adresse_for_bevilling ?? ""}
                  on:change={(e) => updateField("adresse_for_bevilling", e.currentTarget.value)}
                />
              {:else}
                {bevilling.adresse_for_bevilling ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap min-w-64">
              {#if isEditing}
                <select
                  class={largeSelectClass}
                  value={editableBevilling.matrikel_id ?? ""}
                  on:change={(e) => updateField("matrikel_id", numberOrNull(e.currentTarget.value))}
                >
                  <option value="">Vælg</option>

                  {#each lookupOptions.skolematrikler ?? [] as option}
                    <option value={option.id}>
                      {option.label}
                    </option>
                  {/each}
                </select>
              {:else}
                {bevilling.matrikel_navn ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap">
              {bevilling.skoleafstand ?? ""}
            </td>


            <td class="px-3 py-2 whitespace-nowrap min-w-72">
              {#if isEditing}

                <div class="mb-2 flex flex-wrap gap-1.5">
                  {#each selectedHjaelpemiddelIds as selectedId}
                    <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2.5 py-1.5 text-sm">
                      {getHjaelpemiddelLabel(selectedId)}

                      <button
                        type="button"
                        class="ml-1 text-sm font-semibold text-red-600 hover:text-red-800"
                        on:click={() => removeHjaelpemiddel(selectedId)}
                      >
                        X
                      </button>
                    </span>
                  {/each}
                </div>

                <select
                  class="min-w-56 border px-2 py-1 pr-8 text-sm"
                  bind:value={hjaelpemiddelSelectValue}
                  on:change={addHjaelpemiddel}
                >
                  <option value="">Tilføj hjælpemiddel</option>

                  {#each availableHjaelpemidler as option}
                    <option value={String(option.id)}>
                      {option.label}
                    </option>
                  {/each}
                </select>

              {:else}
                {bevilling.hjaelpemidler ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap">
              {#if isEditing}
                <input
                  type="date"
                  class={inputClass}
                  value={editableBevilling.afstandskriterie_dato ?? ""}
                  on:change={(e) => updateField("afstandskriterie_dato", e.currentTarget.value)}
                />
              {:else}
                {bevilling.afstandskriterie_dato ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap">
              {#if isEditing}
                <input
                  type="number"
                  class={`${inputClass} w-28`}
                  value={editableBevilling.afstandskriterie_klassetrin ?? ""}
                  on:change={(e) => updateField("afstandskriterie_klassetrin", e.currentTarget.value)}
                />
              {:else}
                {bevilling.afstandskriterie_klassetrin ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap">
              {#if isEditing}
                <input
                  class={`${inputClass} min-w-44`}
                  value={editableBevilling.relation_til_barnet ?? ""}
                  on:change={(e) => updateField("relation_til_barnet", e.currentTarget.value)}
                />
              {:else}
                {bevilling.relation_til_barnet ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap">
              {#if isEditing}
                <input
                  type="date"
                  class={inputClass}
                  value={editableBevilling.revurderingsdato ?? ""}
                  on:change={(e) => updateField("revurderingsdato", e.currentTarget.value)}
                />
              {:else}
                {bevilling.revurderingsdato ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap">
              {#if isEditing}
                <input
                  type="date"
                  class={inputClass}
                  value={editableBevilling.befordringsudvalg ?? ""}
                  on:change={(e) => updateField("befordringsudvalg", e.currentTarget.value)}
                />
              {:else}
                {bevilling.befordringsudvalg ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap min-w-64">
              {#if isEditing}
                <select
                  class={largeSelectClass}
                  value={editableBevilling.hjemmel_id ?? ""}
                  on:change={(e) => updateField("hjemmel_id", numberOrNull(e.currentTarget.value))}
                >
                  <option value="">Vælg</option>

                  {#each lookupOptions.hjemler ?? [] as option}
                    <option value={option.id}>
                      {option.label}
                    </option>
                  {/each}
                </select>
              {:else}
                {bevilling.hjemmel_tekst ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap min-w-64">
              {#if isEditing}
                <select
                  class={largeSelectClass}
                  value={editableBevilling.afgoerelsesbrev_id ?? ""}
                  on:change={(e) => updateField("afgoerelsesbrev_id", numberOrNull(e.currentTarget.value))}
                >
                  <option value="">Vælg</option>

                  {#each lookupOptions.afgoerelsesbreve ?? [] as option}
                    <option value={option.id}>
                      {option.label}
                    </option>
                  {/each}
                </select>
              {:else}
                {bevilling.afgoerelsesbrev_tekst ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap min-w-52">
              {#if isEditing}
                <select
                  class={mediumSelectClass}
                  value={editableBevilling.sagsbehandler_id ?? ""}
                  on:change={(e) => updateField("sagsbehandler_id", numberOrNull(e.currentTarget.value))}
                >
                  <option value="">Vælg</option>

                  {#each lookupOptions.sagsbehandlere ?? [] as option}
                    <option value={option.id}>
                      {option.label}
                    </option>
                  {/each}
                </select>
              {:else}
                {bevilling.sagsbehandler_tekst ?? ""}
              {/if}
            </td>


            <td class="px-3 py-2 whitespace-nowrap min-w-52">
              {#if isEditing}
                <select
                  class={mediumSelectClass}
                  value={editableBevilling.ppr_sagsbehandler_id ?? ""}
                  on:change={(e) => updateField("ppr_sagsbehandler_id", numberOrNull(e.currentTarget.value))}
                >
                  <option value="">Vælg</option>

                  {#each lookupOptions.pprSagsbehandlere ?? [] as option}
                    <option value={option.id}>
                      {option.label}
                    </option>
                  {/each}
                </select>
              {:else}
                {bevilling.ppr_sagsbehandler_tekst ?? ""}
              {/if}
            </td>

          </tr>


          {#if isExpanded}

            <tr>
              <td></td>
              <td></td>

              <td colspan="15" class="pb-4 pt-2">
                <KoerselsraekkeTable
                  rows={bevilling.koerselsraekker ?? []}
                  lookupOptions={lookupOptions}
                  onSaveKoerselsraekke={onSaveKoerselsraekke}
                  onCreateKoerselsraekke={(updates) => onCreateKoerselsraekke(bevilling.bevilling_id, updates)}
                />
              </td>
            </tr>

          {/if}

        {/each}

      {/if}

    </tbody>

  </table>

</div>