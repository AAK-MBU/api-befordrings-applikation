<script lang="ts">
  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import { getStatusBadgeClass, formatCpr, revurderingPillHtml } from "$lib/tableColumnConfig";

  export let data;

  const STATUS_ORDER: Record<string, number> = {
  "Aktiv": 0, "Ny": 2, "Påbegyndt": 3,
  "Kommende": 4, "Fejlet": 5, "Ophørt": 6, "Afslag": 7, "Udløbet": 8,
  };

  const columns: DataTableColumn[] = [
    {
      key: "navn",
      label: "Navn",
      filterType: "text",
      render: (row) => `
        <a href="/sag/${row.cpr}" class="text-sky-600 font-medium hover:underline">
          ${row.navn ?? ""}
        </a>
      `
    },
    {
      key: "cpr",
      label: "CPR",
      filterType: "text",
      render: (row: any) => formatCpr(row.cpr)
    },
    {
      key: "status",
      label: "Status",
      filterType: "select",
      multiSelect: true,
      render: (row) => `
        <span class="inline-block px-2 py-0.5 rounded text-xs font-medium ${getStatusBadgeClass(row.status)}">
          ${row.status ?? ""}
        </span>${revurderingPillHtml(row)}
      `
    },
    {
      key: "bevilling_count",
      label: "Bevillinger",
      filterable: false,
      render: (row) => `
        <span class="inline-flex items-center justify-center min-w-[1.5rem] h-5 px-1.5 rounded-full text-xs font-bold bg-slate-100 text-slate-700">
          ${row.bevilling_count ?? 0}
        </span>
      `
    },
    {
      key: "esdh_noegle",
      label: "Sags-ID",
      filterType: "text",
      render: (row) => `
        <a href="#" class="text-sky-600 hover:underline">
          ${row.esdh_noegle ?? ""}
        </a>
      `
    },
    {
      key: "sagsbehandler",
      label: "Sagsbehandler",
      filterType: "select",
      multiSelect: true
    },
    {
      key: "ppr_sagsbehandler",
      label: "PPR ansvarlig",
      filterType: "select",
      multiSelect: true
    },
  ];

  $: sortedBevillinger = [...(data.bevillinger ?? [])].sort((a, b) =>
  (STATUS_ORDER[a.status] ?? 99) - (STATUS_ORDER[b.status] ?? 99)
  );

  $: totalCount = sortedBevillinger.length;

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


  <!-- All bevillinger -->
  <div class="mb-6">
    <div class="flex items-center gap-2.5 mb-3 px-3 py-2 bg-white rounded-lg border border-gray-300 shadow-sm">
      <h2 class="font-semibold text-gray-700">Alle bevillinger</h2>
      <span
        class="ml-auto inline-flex items-center justify-center min-w-[1.5rem] h-6 px-2 rounded-full text-white text-xs font-bold"
        style="background-color: #032A42;"
      >
        {totalCount}
      </span>
    </div>
    <div class="bg-white border border-gray-300 rounded-lg overflow-hidden shadow-sm">
      <DataTable
        data={sortedBevillinger}
        columns={columns}
        filterable={true}
      />
    </div>
  </div>

</section>