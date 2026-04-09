<script lang="ts">
  export let data;

  const { sagsbehandlere } = data;
</script>

<h1 class="text-2xl font-bold mb-4">
  Sagsbehandlere
</h1>

<table class="w-full border">
  <thead>
    <tr class="border-b">
      <th class="p-2">Kode</th>
      <th class="p-2">Navn</th>
      <th class="p-2">Beskrivelse</th>
      <th class="p-2">Status</th>
    </tr>
  </thead>

  <tbody>
    {#each sagsbehandlere as s}
      <tr class="border-b">
        <td class="p-2">{s.Sagsbehandlerkode}</td>
        <td class="p-2">{s.Navn}</td>
        <td class="p-2">{s.Beskrivelse}</td>
        <td class="p-2">
          {#if s.Aktiv}
            <span class="text-green-600">Aktiv</span>
          {:else}
            <span class="text-gray-400">Inaktiv</span>
          {/if}
        </td>
      </tr>
    {/each}
  </tbody>
</table>