<script lang="ts">
  import { invalidateAll } from "$app/navigation";
  import ReadOnlyNotice from "$lib/components/ReadOnlyNotice.svelte";
  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import { backendFetch } from "$lib/client/backendFetch";
  import { formatDanishDate, getStatusBadgeClass, formatCpr } from "$lib/tableColumnConfig";

  export let data;

  $: ansoegninger = data.ansoegninger ?? [];
  $: sagsbehandlere = data.sagsbehandlere ?? [];
  $: pprSagsbehandlere = data.pprSagsbehandlere ?? [];
  // Layout data flows into page data, so the signed-in user is available here.
  // can_edit is resolved by the backend from EDIT_ROLES — see GET /me.
  $: canEdit = data.user?.can_edit ?? false;

  let assignError: string | null = null;

  $: overOneWeek = ansoegninger.filter(a => (daysSince(a.ansoegningsdato) ?? 0) >= 7).length;
  $: overTwoWeeks = ansoegninger.filter(a => (daysSince(a.ansoegningsdato) ?? 0) >= 10).length;

  async function handleDropdownChange(event: Event) {
    const target = event.target as HTMLSelectElement;
    if (!target.dataset.bevillingId || !target.dataset.field) return;

    const bevillingId = target.dataset.bevillingId;
    const field = target.dataset.field;
    const value = target.value === "" ? null : Number(target.value);

    // A <select> shows the new option the moment it is picked, before anything
    // has been saved. If the write is refused the displayed value is a lie, so
    // put it back — otherwise the page claims an assignment that does not exist
    // until the next reload silently undoes it.
    const revert = () => {
      target.value = target.dataset.current ?? "";
    };

    assignError = null;

    const res = await backendFetch(`/bevilling/${bevillingId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ [field]: value }),
    });

    if (!res.ok) {
      revert();

      let message = "Tildelingen kunne ikke gemmes";

      try {
        const body = await res.json();
        const detail = body?.detail?.message ?? body?.detail;

        if (typeof detail === "string") {
          message = detail;
        }
      } catch {
        // Keep the fallback; a non-JSON body has nothing better to offer.
      }

      assignError = message;
      console.error(`Failed to update bevilling ${bevillingId}:`, res.status, message);

      return;
    }

    await invalidateAll();
  }

  function daysSince(dateStr: string | null | undefined): number | null {
    if (!dateStr) return null;
    const diff = Date.now() - new Date(dateStr).getTime();
    return Math.floor(diff / (1000 * 60 * 60 * 24));
  }

  function waitingLabel(days: number | null): string {
    if (days === null) return "—";
    if (days === 0) return "I dag";
    if (days === 1) return "1 dag";
    return `${days} dage`;
  }

  function waitingBadgeStyle(days: number | null): string {
    if (days === null) return "background:#e5e7eb;color:#6b7280;";
    if (days >= 10) return "background:#fee2e2;color:#dc2626;";
    if (days >= 7)  return "background:#fef9c3;color:#ca8a04;";
    return "background:#dbeafe;color:#1d4ed8;";
  }

  function rowUrgencyStyle(row: any): string {
    const days = daysSince(row.ansoegningsdato);
    if (days === null) return "";
    if (days >= 10) return "box-shadow: inset 4px 0 0 #dc2626;";
    if (days >= 7)  return "box-shadow: inset 4px 0 0 #ca8a04;";
    return "box-shadow: inset 4px 0 0 #3b82f6;";
  }

  function buildSelect(
    bevillingId: number,
    field: string,
    currentId: number | null,
    options: { id: number; label: string }[],
    placeholder: string
  ): string {
    const opts = options
      .map(o => `<option value="${o.id}" ${currentId === o.id ? "selected" : ""}>${o.label}</option>`)
      .join("");

    // data-current lets a refused change be put back where it was.
    // The disabled attribute is a courtesy, not a control: require_edit on the
    // backend is what actually refuses the write.
    return `<select
      data-bevilling-id="${bevillingId}"
      data-field="${field}"
      data-current="${currentId ?? ""}"
      ${canEdit ? "" : "disabled"}
      ${canEdit ? "" : 'title="Du har ikke rettigheder til at ændre tildeling"'}
      class="w-full border border-gray-300 rounded px-2 py-1 text-sm bg-white focus:border-blue-400 focus:outline-none disabled:bg-gray-100 disabled:text-gray-400 disabled:cursor-not-allowed"
    >
      <option value="">${placeholder}</option>
      ${opts}
    </select>`;
  }

  $: columns = [
    {
      key: "adresseringsnavn",
      label: "Navn",
      render: (row: any) => `
        <a href="/sag/${row.cpr_elev}" class="text-sky-600 font-medium hover:underline">
          ${row.adresseringsnavn ?? ""}
        </a>
      `
    },
    {
      key: "ansoegningsdato",
      label: "Ventetid",
      filterable: false,
      render: (row: any) => {
        const days = daysSince(row.ansoegningsdato);
        return `<span style="display:inline-block;padding:2px 10px;border-radius:9999px;font-size:0.75rem;font-weight:600;${waitingBadgeStyle(days)}">${waitingLabel(days)}</span>`;
      }
    },
    {
      key: "status_tekst",
      label: "Status",
      filterType: "select",
      multiSelect: true,
      render: (row: any) => {
        const status = row.status_tekst ?? "";
        return `<span class="inline-block px-2 py-0.5 rounded text-xs font-medium ${getStatusBadgeClass(status)}">${status}</span>`;
      }
    },
    {
      key: "cpr_elev",
      label: "CPR",
      render: (row: any) => formatCpr(row.cpr_elev)
    },
    {
      key: "esdh_noegle",
      label: "Sags-ID",
      render: (row: any) => `
        <a href="/sag/${row.cpr_elev}" class="text-sky-600 hover:underline">
          ${row.esdh_noegle ?? ""}
        </a>
      `
    },
    {
      key: "ansoegningsdato",
      label: "Ansøgningsdato",
      render: (row: any) => formatDanishDate(row.ansoegningsdato)
    },
    {
      key: "foerste_koersel_dato",
      label: "Første kørselsdato",
      render: (row: any) => formatDanishDate(row.foerste_koersel_dato)
    },
    {
      key: "ansoegningstype",
      label: "Ansøgningstype"
    },
    {
      key: "sagsbehandler_id",
      label: "Sagsbehandler",
      filterable: false,
      render: (row: any) => buildSelect(
        row.bevilling_id,
        "sagsbehandler_id",
        row.sagsbehandler_id,
        sagsbehandlere,
        "— Vælg —"
      )
    },
    {
      key: "ppr_sagsbehandler_id",
      label: "PPR ansvarlig",
      filterable: false,
      render: (row: any) => buildSelect(
        row.bevilling_id,
        "ppr_sagsbehandler_id",
        row.ppr_sagsbehandler_id,
        pprSagsbehandlere,
        "— Vælg —"
      )
    },
  ] satisfies DataTableColumn[];
</script>


<svelte:head>
  <title>Befordring – Nye ansøgninger</title>
</svelte:head>


<section>

  <!-- Page header -->
  <div class="flex items-start justify-between mb-6">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Nye ansøgninger</h1>
      <p class="text-sm text-gray-500 mt-0.5">Ansøgninger der afventer behandling</p>
    </div>
  </div>


  <ReadOnlyNotice />


  {#if assignError}
    <div class="mb-6 flex items-start gap-3 rounded-lg border border-red-200 bg-red-50 px-4 py-3">
      <p class="text-sm text-red-700 flex-1">{assignError}</p>
      <button
        type="button"
        class="text-sm font-medium text-red-700 hover:underline shrink-0"
        on:click={() => (assignError = null)}
      >
        Luk
      </button>
    </div>
  {/if}


  <!-- Summary card -->
  <div class="bg-white border border-gray-300 rounded-lg shadow px-6 py-5 mb-6 flex items-center gap-8">
    <div>
      <p class="text-4xl font-bold text-gray-900">{ansoegninger.length}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Afventer</p>
    </div>

    <div class="h-10 w-px bg-gray-200"></div>

    <div>
      <p class="text-2xl font-bold {overTwoWeeks > 0 ? 'text-red-600' : 'text-gray-400'}">{overTwoWeeks}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Venter over 10 dage</p>
    </div>

    <div class="h-10 w-px bg-gray-200"></div>

    <div>
      <p class="text-2xl font-bold" style={overOneWeek > 0 ? 'color:#ca8a04;' : 'color:#9ca3af;'}>{overOneWeek}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Venter over 7 dage</p>
    </div>
  </div>


  {#if ansoegninger.length === 0}

    <!-- Empty state -->
    <div class="bg-white border border-gray-300 rounded-lg shadow px-6 py-16 text-center">
      <div class="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center mx-auto mb-4">
        <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
        </svg>
      </div>
      <p class="text-gray-700 font-semibold">Ingen nye ansøgninger</p>
      <p class="text-sm text-gray-400 mt-1">Alle ansøgninger er behandlet.</p>
    </div>

  {:else}

    <!-- Applications table -->
    <div class="mb-3 px-3 py-2 bg-white rounded-lg border border-gray-300 shadow-sm flex items-center gap-2.5">
      <div class="w-2.5 h-2.5 rounded-full bg-blue-500 flex-shrink-0"></div>
      <h2 class="font-semibold text-gray-700">Nye ansøgninger</h2>
      <span
        class="ml-auto inline-flex items-center justify-center min-w-[1.5rem] h-6 px-2 rounded-full text-white text-xs font-bold"
        style="background-color: #032A42;"
      >
        {ansoegninger.length}
      </span>
    </div>

    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div
      class="bg-white border border-gray-300 rounded-lg overflow-hidden shadow-sm mb-6"
      on:change={handleDropdownChange}
    >
      <DataTable
        data={ansoegninger}
        columns={columns}
        filterable={true}
        rowStyle={rowUrgencyStyle}
      />
    </div>

  {/if}

</section>
