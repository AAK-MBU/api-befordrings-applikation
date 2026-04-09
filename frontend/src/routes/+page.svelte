<script lang="ts">
  import { browser } from "$app/environment";

  import { Table } from "@flowbite-svelte-plugins/datatable";

  import products from "$lib/data/products.json";

  // importér vores nye config
  import { overblikTableOptions } from "$lib/tableColumnSetup";

  const filterOptions = overblikTableOptions;
</script>

<br />
<h1 class="text-2xl font-bold mb-3">
  Overblik over alle bevillinger
</h1>

<p class="mb-6 text-gray-700">
  Filtrer per kolonne eller brug global søgning
</p>

<div class="bg-white border border-slate-200 rounded-lg p-4">
  {#if browser}
    <Table
      class="w-full"
      items={products}
      dataTableOptions={filterOptions}
    />
  {/if}
</div>