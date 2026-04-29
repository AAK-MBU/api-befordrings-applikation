<script lang="ts">
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

  const inputClass = "border px-2 py-1 text-sm";
  const selectClass = "min-w-44 border px-2 py-1 pr-8 text-sm";
  const wideSelectClass = "min-w-52 border px-2 py-1 pr-8 text-sm";
  const multiSelectClass = "min-w-56 border px-2 py-1 pr-8 text-sm";
  const tagClass = "inline-flex items-center gap-1 rounded bg-slate-100 px-2.5 py-1.5 text-sm";
  const removeTagButtonClass = "ml-1 text-sm font-semibold text-red-600 hover:text-red-800";


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

  function numberOrNull(value: string) {
    if (value === "") {
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

    return [
      ...currentIds,
      id
    ];
  }


  function removeId(currentIds: number[], id: number) {
    return currentIds.filter(
      (existingId) => existingId !== Number(id)
    );
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
      bevilget_koereafstand_pr_vej: Number(editableKoerselsraekke.bevilget_koereafstand_pr_vej),
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
    newKoerselsraekke = getEmptyKoerselsraekke();

    newSelectedTillaegIds = [];
    newSelectedDagIds = [];

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

    if (!newKoerselsraekke.bevilget_koereafstand_pr_vej) {
      alert("Bevilget køreafstand skal udfyldes");
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


<table class="text-sm border-collapse ml-14 mt-2">

  <thead>
    <tr class="bg-gray-100 text-left">
      <th class="px-3 py-2 font-medium whitespace-nowrap">Handling</th>
      <th class="px-3 py-2 font-medium whitespace-nowrap">Tidspunkt</th>
      <th class="px-3 py-2 font-medium whitespace-nowrap">Kørselstype</th>
      <th class="px-3 py-2 font-medium whitespace-nowrap">Kørselstype tillæg</th>
      <th class="px-3 py-2 font-medium whitespace-nowrap">Bevilget køreafstand pr. vej (km)</th>
      <th class="px-3 py-2 font-medium whitespace-nowrap">Dage</th>
      <th class="px-3 py-2 font-medium whitespace-nowrap">Bevilling fra</th>
      <th class="px-3 py-2 font-medium whitespace-nowrap">Bevilling til</th>
      <th class="px-3 py-2 font-medium whitespace-nowrap">Taxa-ID</th>
      <th class="px-3 py-2 font-medium whitespace-nowrap">Kommentar</th>
    </tr>
  </thead>


  <tbody>

    {#if rows.length === 0 && !isCreating}
      <tr>
        <td colspan="10" class="px-3 py-3 text-gray-500">
          Ingen kørselsrækker fundet.
        </td>
      </tr>
    {/if}


    {#each rows as row}

      {@const isEditing = editingKoerselId === row.koersel_id}

      <tr class="border-b border-gray-100">

        <td class="px-3 py-2 whitespace-nowrap">
          {#if isEditing}
            <button
              type="button"
              class="text-green-700 hover:underline mr-2"
              on:click={() => saveEdit(row)}
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
              on:click={() => startEdit(row)}
            >
              Redigér
            </button>
          {/if}
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          {#if isEditing}
            <select
              class={selectClass}
              value={editableKoerselsraekke.tidspunkt_id ?? ""}
              on:change={(e) => updateField("tidspunkt_id", numberOrNull(e.currentTarget.value))}
            >
              <option value="">Vælg</option>

              {#each lookupOptions.tidspunkter ?? [] as option}
                <option value={option.id}>
                  {option.label}
                </option>
              {/each}
            </select>
          {:else}
            {row.tidspunkt_tekst ?? ""}
          {/if}
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          {#if isEditing}
            <select
              class={wideSelectClass}
              value={editableKoerselsraekke.befordringstype_id ?? ""}
              on:change={(e) => updateField("befordringstype_id", numberOrNull(e.currentTarget.value))}
            >
              <option value="">Vælg</option>

              {#each lookupOptions.koerselstyper ?? [] as option}
                <option value={option.id}>
                  {option.label}
                </option>
              {/each}
            </select>
          {:else}
            {row.befordringstype_tekst ?? ""}
          {/if}
        </td>


        <td class="px-3 py-2 whitespace-nowrap min-w-72">
          {#if isEditing}

            <div class="mb-2 flex flex-wrap gap-1.5">
              {#each selectedTillaegIds as selectedId}
                <span class={tagClass}>
                  {getTillaegLabel(selectedId)}

                  <button
                    type="button"
                    class={removeTagButtonClass}
                    on:click={() => removeTillaeg(selectedId)}
                  >
                    X
                  </button>
                </span>
              {/each}
            </div>

            <select
              class={multiSelectClass}
              bind:value={tillaegSelectValue}
              on:change={addTillaeg}
            >
              <option value="">Tilføj tillæg</option>

              {#each availableTillaeg as option}
                <option value={String(option.id)}>
                  {option.label}
                </option>
              {/each}
            </select>

          {:else}
            {row.tillaeg_tekst ?? ""}
          {/if}
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          {#if isEditing}
            <input
              type="number"
              step="0.1"
              class={`${inputClass} w-28`}
              value={editableKoerselsraekke.bevilget_koereafstand_pr_vej ?? ""}
              on:change={(e) => updateField("bevilget_koereafstand_pr_vej", e.currentTarget.value)}
            />
          {:else}
            {row.bevilget_koereafstand_pr_vej ?? ""}
          {/if}
        </td>


        <td class="px-3 py-2 whitespace-nowrap min-w-72">
          {#if isEditing}

            <div class="mb-2 flex flex-wrap gap-1.5">
              {#each selectedDagIds as selectedId}
                <span class={tagClass}>
                  {getDagLabel(selectedId)}

                  <button
                    type="button"
                    class={removeTagButtonClass}
                    on:click={() => removeDag(selectedId)}
                  >
                    X
                  </button>
                </span>
              {/each}
            </div>

            <select
              class={multiSelectClass}
              bind:value={dagSelectValue}
              on:change={addDag}
            >
              <option value="">Tilføj dag</option>

              {#each availableDage as option}
                <option value={String(option.id)}>
                  {option.label}
                </option>
              {/each}
            </select>

          {:else}
            {row.dage ?? ""}
          {/if}
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          {#if isEditing}
            <input
              type="date"
              class={inputClass}
              value={editableKoerselsraekke.gyldig_fra ?? ""}
              on:change={(e) => updateField("gyldig_fra", e.currentTarget.value)}
            />
          {:else}
            {row.gyldig_fra ?? ""}
          {/if}
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          {#if isEditing}
            <input
              type="date"
              class={inputClass}
              value={editableKoerselsraekke.gyldig_til ?? ""}
              on:change={(e) => updateField("gyldig_til", e.currentTarget.value)}
            />
          {:else}
            {row.gyldig_til ?? ""}
          {/if}
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          {#if isEditing}
            <input
              class={`${inputClass} min-w-32`}
              value={editableKoerselsraekke.taxa_id ?? ""}
              on:change={(e) => updateField("taxa_id", e.currentTarget.value)}
            />
          {:else}
            {row.taxa_id ?? ""}
          {/if}
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          {#if isEditing}
            <input
              class={`${inputClass} min-w-56`}
              value={editableKoerselsraekke.kommentar ?? ""}
              on:change={(e) => updateField("kommentar", e.currentTarget.value)}
            />
          {:else}
            {row.kommentar ?? ""}
          {/if}
        </td>

      </tr>

    {/each}


    {#if isCreating}
      <tr class="border-b border-gray-100 bg-sky-50">

        <td class="px-3 py-2 whitespace-nowrap">
          <button
            type="button"
            class="text-green-700 hover:underline mr-2"
            on:click={saveNew}
          >
            Gem
          </button>

          <button
            type="button"
            class="text-red-600 hover:underline"
            on:click={cancelCreate}
          >
            Annullér
          </button>
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          <select
            class={selectClass}
            value={newKoerselsraekke.tidspunkt_id ?? ""}
            on:change={(e) => updateNewField("tidspunkt_id", numberOrNull(e.currentTarget.value))}
          >
            <option value="">Vælg</option>

            {#each lookupOptions.tidspunkter ?? [] as option}
              <option value={option.id}>
                {option.label}
              </option>
            {/each}
          </select>
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          <select
            class={wideSelectClass}
            value={newKoerselsraekke.befordringstype_id ?? ""}
            on:change={(e) => updateNewField("befordringstype_id", numberOrNull(e.currentTarget.value))}
          >
            <option value="">Vælg</option>

            {#each lookupOptions.koerselstyper ?? [] as option}
              <option value={option.id}>
                {option.label}
              </option>
            {/each}
          </select>
        </td>


        <td class="px-3 py-2 whitespace-nowrap min-w-72">

          <div class="mb-2 flex flex-wrap gap-1.5">
            {#each newSelectedTillaegIds as selectedId}
              <span class={tagClass}>
                {getTillaegLabel(selectedId)}

                <button
                  type="button"
                  class={removeTagButtonClass}
                  on:click={() => removeNewTillaeg(selectedId)}
                >
                  X
                </button>
              </span>
            {/each}
          </div>

          <select
            class={multiSelectClass}
            bind:value={newTillaegSelectValue}
            on:change={addNewTillaeg}
          >
            <option value="">Tilføj tillæg</option>

            {#each availableNewTillaeg as option}
              <option value={String(option.id)}>
                {option.label}
              </option>
            {/each}
          </select>

        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          <input
            type="number"
            step="0.1"
            class={`${inputClass} w-28`}
            value={newKoerselsraekke.bevilget_koereafstand_pr_vej ?? ""}
            on:change={(e) => updateNewField("bevilget_koereafstand_pr_vej", e.currentTarget.value)}
          />
        </td>


        <td class="px-3 py-2 whitespace-nowrap min-w-72">

          <div class="mb-2 flex flex-wrap gap-1.5">
            {#each newSelectedDagIds as selectedId}
              <span class={tagClass}>
                {getDagLabel(selectedId)}

                <button
                  type="button"
                  class={removeTagButtonClass}
                  on:click={() => removeNewDag(selectedId)}
                >
                  X
                </button>
              </span>
            {/each}
          </div>

          <select
            class={multiSelectClass}
            bind:value={newDagSelectValue}
            on:change={addNewDag}
          >
            <option value="">Tilføj dag</option>

            {#each availableNewDage as option}
              <option value={String(option.id)}>
                {option.label}
              </option>
            {/each}
          </select>

        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          <input
            type="date"
            class={inputClass}
            value={newKoerselsraekke.gyldig_fra ?? ""}
            on:change={(e) => updateNewField("gyldig_fra", e.currentTarget.value)}
          />
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          <input
            type="date"
            class={inputClass}
            value={newKoerselsraekke.gyldig_til ?? ""}
            on:change={(e) => updateNewField("gyldig_til", e.currentTarget.value)}
          />
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          <input
            class={`${inputClass} min-w-32`}
            value={newKoerselsraekke.taxa_id ?? ""}
            on:change={(e) => updateNewField("taxa_id", e.currentTarget.value)}
          />
        </td>


        <td class="px-3 py-2 whitespace-nowrap">
          <input
            class={`${inputClass} min-w-56`}
            value={newKoerselsraekke.kommentar ?? ""}
            on:change={(e) => updateNewField("kommentar", e.currentTarget.value)}
          />
        </td>

      </tr>
    {/if}


    {#if !isCreating}
      <tr>
        <td colspan="10" class="px-3 py-3">
          <button
            type="button"
            class="text-sky-600 hover:underline"
            on:click={startCreate}
          >
            + Ny kørselsrække
          </button>
        </td>
      </tr>
    {/if}

  </tbody>

</table>