<script lang="ts">
  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import { getStatusBadgeClass } from "$lib/tableColumnConfig";

  export let data;

  const columns: DataTableColumn[] = [
    {
      key: "navn",
      label: "Navn",
      render: (row) => `
        <a href="/sag/${row.cpr}" class="text-sky-600 font-medium hover:underline">
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
        <span class="inline-block px-2 py-0.5 rounded text-xs font-medium ${getStatusBadgeClass(row.status)}">
          ${row.status ?? ""}
        </span>
      `
    },
    {
      key: "esdh_noegle",
      label: "Sags-ID",
      render: (row) => `
        <a href="#" class="text-sky-600 hover:underline">
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
  ];

  $: activeCount = data.activeBevillinger?.length ?? 0;
  $: fejletCount = data.fejledeBevillinger?.length ?? 0;
  $: totalCount = activeCount + fejletCount;
</script>


<section>

  <!-- Page header -->
  <div class="flex items-start justify-between mb-6">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Overblik</h1>
      <p class="text-sm text-gray-500 mt-0.5">Bevillingsoversigt - Aarhus Kommune</p>
    </div>
    <button
      type="button"
      class="inline-flex items-center gap-2 px-4 py-2 text-sm border border-gray-300 rounded bg-white hover:bg-gray-50 shadow-sm text-gray-700"
    >
      <svg class="w-4 h-4 text-green-600" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z" clip-rule="evenodd" />
      </svg>
      Eksporter Excel
    </button>
  </div>


  <!-- Stat cards -->
  <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">

    <div class="bg-white border border-gray-300 rounded-lg shadow px-6 py-5 flex items-center justify-between">
      <div>
        <p class="text-4xl font-bold text-gray-900">{activeCount}</p>
        <p class="text-xs uppercase tracking-widest text-gray-400 mt-2">Aktive</p>
      </div>
      <svg class="w-8 h-8 text-gray-200" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
      </svg>
    </div>

    <div class="bg-white border border-gray-300 rounded-lg shadow px-6 py-5 flex items-center justify-between">
      <div>
        <p class="text-4xl font-bold text-gray-900">{fejletCount}</p>
        <p class="text-xs uppercase tracking-widest text-gray-400 mt-2">Fejlede</p>
      </div>
      <svg class="w-8 h-8 text-red-200" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
        <circle cx="12" cy="12" r="9" />
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4m0 4h.01" />
      </svg>
    </div>

    <div class="bg-white border border-gray-300 rounded-lg shadow px-6 py-5 flex items-center justify-between">
      <div>
        <p class="text-4xl font-bold text-gray-900">{totalCount}</p>
        <p class="text-xs uppercase tracking-widest text-gray-400 mt-2">I alt</p>
      </div>
      <svg class="w-8 h-8 text-gray-200" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 10h16M4 14h10" />
      </svg>
    </div>

  </div>


  <!-- Active grants section -->
  <div class="mb-6">
    <div class="flex items-center gap-2.5 mb-3 px-3 py-2 bg-white rounded-lg border border-gray-300 shadow-sm">
      <div class="w-2.5 h-2.5 rounded-full bg-green-500 flex-shrink-0"></div>
      <h2 class="font-semibold text-gray-700">Aktive bevillinger</h2>
      <span
        class="ml-auto inline-flex items-center justify-center min-w-[1.5rem] h-6 px-2 rounded-full text-white text-xs font-bold"
        style="background-color: #032A42;"
      >
        {activeCount}
      </span>
    </div>
    <div class="bg-white border border-gray-300 rounded-lg overflow-hidden shadow-sm">
      <DataTable
        data={data.activeBevillinger}
        columns={columns}
        filterable={true}
      />
    </div>
  </div>


  <!-- Failed grants section -->
  <div class="mb-6">
    <div class="flex items-center gap-2.5 mb-3 px-3 py-2 bg-white rounded-lg border border-gray-300 shadow-sm">
      <div class="w-2.5 h-2.5 rounded-full bg-red-500 flex-shrink-0"></div>
      <h2 class="font-semibold text-gray-700">Fejlede bevillinger</h2>
      <span
        class="ml-auto inline-flex items-center justify-center min-w-[1.5rem] h-6 px-2 rounded-full text-white text-xs font-bold"
        style="background-color: #032A42;"
      >
        {fejletCount}
      </span>
    </div>
    <div class="bg-white border border-gray-300 rounded-lg overflow-hidden shadow-sm">
      <DataTable
        data={data.fejledeBevillinger}
        columns={columns}
        filterable={true}
      />
    </div>
  </div>

</section>
