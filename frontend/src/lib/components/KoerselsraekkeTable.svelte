<script lang="ts">

  export let row: any;
  export let onCreate: (bevilling_id: number) => void;

	export let creatingFor: number | null;
	export let newRow: any;
	export let onInputChange: (key: string, value: any) => void;
	export let onSaveNew: (bevilling_id: number) => void;
	export let onCancelNew: () => void;


</script>

<div class="text-sm">

  <table class="w-full text-xs text-gray-600">

    <thead class="bg-gray-50 text-gray-500 text-xs uppercase tracking-wide">
      <tr>
        <th class="px-4 py-2 text-left">Tidspunkt</th>
        <th class="px-4 py-2 text-left">Kørselstype</th>
        <th class="px-4 py-2 text-left">Tillæg</th>
        <th class="px-4 py-2 text-left">Afstand</th>
        <th class="px-4 py-2 text-left">Dage</th>
        <th class="px-4 py-2 text-left">Fra</th>
        <th class="px-4 py-2 text-left">Til</th>
        <th class="px-4 py-2 text-left">Taxa</th>
        <th class="px-4 py-2 text-left">Kommentar</th>
      </tr>
    </thead>

    <tbody>
      {#each row.koerselsraekker ?? [] as k}
        <tr>
          <td class="p-2">{k.tidspunkt}</td>
          <td class="p-2">{k.koerselstype}</td>
          <td class="p-2">{k.koerselstype_tillaeg}</td>
          <td class="p-2">{k.bevilget_koereafstand_pr_vej}</td>
          <td class="p-2">{k.dage}</td>
          <td class="p-2">{k.bevilling_fra}</td>
          <td class="p-2">{k.bevilling_til}</td>
          <td class="p-2">{k.taxa_id}</td>
          <td class="p-2">{k.kommentar}</td>
        </tr>
      {/each}
        {#if creatingFor === row.bevilling_id}

        <tr class="bg-yellow-50">

        <td class="p-2">
            <input bind:value={newRow.tidspunkt} on:input={(e) => onInputChange("tidspunkt", e.target.value)} />
        </td>

        <td class="p-2">
            <input bind:value={newRow.koerselstype} on:input={(e) => onInputChange("koerselstype", e.target.value)} />
        </td>

        <td class="p-2">
            <input bind:value={newRow.koerselstype_tillaeg} on:input={(e) => onInputChange("koerselstype_tillaeg", e.target.value)} />
        </td>

        <td class="p-2">
            <input bind:value={newRow.bevilget_koereafstand_pr_vej} on:input={(e) => onInputChange("bevilget_koereafstand_pr_vej", e.target.value)} />
        </td>

        <td class="p-2">
            <input bind:value={newRow.dage} on:input={(e) => onInputChange("dage", e.target.value)} />
        </td>

        <td class="p-2">
            <input bind:value={newRow.bevilling_fra} />
        </td>

        <td class="p-2">
            <input bind:value={newRow.bevilling_til} />
        </td>

        <td class="p-2">
            <input bind:value={newRow.taxa_id} />
        </td>

        <td class="p-2">
            <input bind:value={newRow.kommentar} />
        </td>

        </tr>

        <tr>
        <td colspan="9" class="p-2">

            <button
            class="text-green-600 mr-2"
            on:click={() => onSaveNew(row.bevilling_id)}
            >
            Gem
            </button>

            <button
            class="text-gray-500"
            on:click={onCancelNew}
            >
            Annuller
            </button>

        </td>
        </tr>

        {/if}
    </tbody>

  </table>

  <!-- 🔥 BUTTON -->
  <div class="mt-3">

    <button
      class="text-blue-600 hover:underline text-sm"
      on:click={() => onCreate(row.bevilling_id)}
    >
      + Ny kørselsrække
    </button>

  </div>

</div>