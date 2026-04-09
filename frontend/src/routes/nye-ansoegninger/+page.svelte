
<!-- Testing load of data from overblik +page.server.js aka from DatabaseSync, har ikke noget med nye ansogninger at gøre -->

<script lang="ts">
  import { Table } from "@flowbite-svelte-plugins/datatable";
  import products from "$lib/data/products.json";
  import { overblikTableOptions } from "$lib/tableColumnSetup";

  export let data;

  const filterOptions = overblikTableOptions;
</script>




<svelte:head>
    <title>Befordringer - Oversigt</title>
</svelte:head>

<div>
    <h1>Alle Befordringer</h1>
    <p>Her kan du se en oversigt over alle dine registrerede befordringer.</p>
    <br/>

        <div class="tabel-container">
            <table>
                <thead>
                    <tr>
                        <th>Dato</th>
                        <th>Medarbejder</th>
                        <th>Fra</th>
                        <th>Til</th>
                        <th>Km</th>
                    </tr>
                </thead>
                <tbody>
                    {#each data.befordringer as befordring (befordring.id)}
                        <tr>
                            <td>{befordring.dato}</td>
                            <td>{befordring.medarbejder_id}</td>
                            <td class="adresse">{befordring.fra_adresse}</td>
                            <td class="adresse">{befordring.til_adresse}</td>
                            <td>{befordring.afstand_km}</td>
                        </tr>
                    {/each}
                </tbody>
            </table>
        </div>
</div>




<br />
<h1 class="text-2xl font-bold mb-3">
  Overblik over alle bevillinger
</h1>

<p class="mb-6 text-gray-700">
  Filtrer per kolonne eller brug global søgning
</p>

<div class="bg-white border border-slate-200 rounded-lg p-4">
  <Table
    class="w-full"
    items={products}
    dataTableOptions={filterOptions}
  />
</div>