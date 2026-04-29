<script lang="ts">
  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import { getStatusBadgeClass } from "$lib/tableColumnConfig";

  export let data;

  const columns: DataTableColumn[] = [
    {
      key: "navn",
      label: "Navn",
      render: (row) => `
        <a
          href="/sag/${row.cpr}"
          class="text-sky-600 underline"
        >
          ${row.navn ?? ""}
        </a>
      `
    },
    {
      key: "cpr",
      label: "CPR"
    },
    {
      key: "status",
      label: "Status",
      render: (row) => `
        <span class="inline-block px-3 py-1 ${getStatusBadgeClass(row.status)}">
          ${row.status ?? ""}
        </span>
      `
    },
    {
      key: "esdh_noegle",
      label: "Sags-ID",
      render: (row) => `
        <a
          href="#"
          class="text-sky-600 underline"
        >
          ${row.esdh_noegle ?? ""}
        </a>
      `
    },
    {
      key: "sagsbehandler",
      label: "Sagsbehandler"
    },
    {
      key: "ppr_sagsbehandler",
      label: "PPR ansvarlig"
    },
    {
      key: "noter",
      label: "Noter"
    }
  ];
</script>


<section class="bg-white min-h-screen px-14 py-8">

  <h1 class="text-2xl font-bold mb-28">
    Forside - <span class="underline">Overblik</span>
  </h1>


  <div class="border border-gray-200">

    <div class="bg-gray-100 px-3 py-2 font-semibold text-sm">
      Overblik over aktive bevillinger
    </div>

    <DataTable
      data={data.activeBevillinger}
      columns={columns}
      filterable={true}
    />

  </div>

  
  <br>


  <div class="border border-gray-200">

    <div class="bg-gray-100 px-3 py-2 font-semibold text-sm">
      Overblik over ikke-aktive bevillinger
    </div>

    <DataTable
      data={data.notActiveBevillinger}
      columns={columns}
      filterable={true}
    />

  </div>  


  <button
    type="button"
    class="mt-32 inline-flex items-center gap-2 rounded border border-gray-300 px-3 py-1 text-sm shadow-sm"
  >
    🟩 Excel
  </button>

</section>