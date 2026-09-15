<script lang="ts">
  // Forsendelse: letters that have been created but not yet sent.
  //
  // Creating a letter queues an ATS work item and produces a document; it does
  // NOT post anything to the parents. This page is that gap — a worklist a
  // caseworker clears by actually sending the letters and ticking them off.

  import { invalidateAll } from "$app/navigation";

  import { page } from "$app/stores";
  import { backendFetch } from "$lib/client/backendFetch";
  import { formatCpr } from "$lib/tableColumnConfig";
  import ReadOnlyNotice from "$lib/components/ReadOnlyNotice.svelte";

  export let data;

  $: forsendelser = data.forsendelser ?? [];
  $: canEdit = $page.data.user?.can_edit ?? false;

  let selectedIds: number[] = [];
  let isSaving = false;
  let actionError: string | null = null;

  // Selection is keyed on brev_id and pruned whenever the list reloads, so a
  // letter someone else marked sent cannot stay selected and be acted on again.
  $: {
    const visible = new Set(forsendelser.map((f: any) => f.brev_id));
    selectedIds = selectedIds.filter((id) => visible.has(id));
  }

  $: allSelected = forsendelser.length > 0 && selectedIds.length === forsendelser.length;

  function toggle(id: number) {
    selectedIds = selectedIds.includes(id)
      ? selectedIds.filter((existing) => existing !== id)
      : [...selectedIds, id];
  }

  function toggleAll() {
    selectedIds = allSelected ? [] : forsendelser.map((f: any) => f.brev_id);
  }

  async function markAfsendt(ids: number[]) {
    if (isSaving || ids.length === 0) return;

    isSaving = true;
    actionError = null;

    try {
      const res = await backendFetch("/brev/afsendt", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ brev_ids: ids, afsendt: true }),
      });

      if (!res.ok) {
        let message = "Kunne ikke markere brevene som afsendt";

        try {
          const err = await res.json();
          message = err?.detail?.message ?? err?.detail ?? message;
        } catch {
          // keep fallback
        }

        actionError = message;
        return;
      }

      selectedIds = [];
      await invalidateAll();
    } finally {
      isSaving = false;
    }
  }

  // A letter sitting unsent for a fortnight is a backlog, not a queue.
  function ventetClass(dage: number): string {
    if (dage >= 14) return "bg-red-100 text-red-700 border border-red-200";
    if (dage >= 7) return "bg-amber-100 text-amber-800 border border-amber-200";
    return "bg-gray-100 text-gray-600 border border-gray-200";
  }

  function formatTidspunkt(value: string | null | undefined): string {
    if (!value) return "—";

    const parsed = new Date(value);

    if (Number.isNaN(parsed.getTime())) return String(value);

    return parsed.toLocaleString("da-DK", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  }
</script>

<svelte:head><title>Forsendelse</title></svelte:head>

<div class="p-8">
  <div class="flex items-baseline justify-between mb-1">
    <h1 class="text-2xl font-semibold text-gray-800">Forsendelse</h1>
    <span class="text-sm text-gray-500">
      {forsendelser.length}
      {forsendelser.length === 1 ? "brev afventer" : "breve afventer"}
    </span>
  </div>

  <p class="text-sm text-gray-500 mb-6 max-w-3xl">
    Breve der er oprettet, men endnu ikke sendt til forældrene. Når brevet er
    sendt, markeres det her — så forsvinder det fra listen.
  </p>

  <ReadOnlyNotice />

  {#if actionError}
    <div class="mb-4 px-3 py-2 text-sm text-red-700 bg-red-50 border border-red-200 rounded">
      {actionError}
    </div>
  {/if}

  {#if forsendelser.length === 0}
    <p class="text-sm text-gray-400 italic">Ingen breve afventer forsendelse.</p>
  {:else}
    <!-- Bulk bar: only present when something is selected, so it never sits
         there as a disabled control taking up space. -->
    {#if selectedIds.length > 0}
      <div class="mb-3 flex items-center gap-3 px-4 py-2.5 bg-blue-50 border border-blue-200 rounded">
        <span class="text-sm text-blue-900">
          {selectedIds.length} valgt
        </span>
        <button
          type="button"
          disabled={!canEdit || isSaving}
          class="px-3 py-1.5 text-sm font-medium bg-[#032A42] text-white rounded hover:bg-[#04374f] transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          on:click={() => markAfsendt(selectedIds)}
        >
          {isSaving ? "Markerer..." : "Markér som afsendt"}
        </button>
        <button
          type="button"
          class="text-sm text-blue-700 hover:underline"
          on:click={() => (selectedIds = [])}
        >
          Ryd valg
        </button>
      </div>
    {/if}

    <div class="overflow-x-auto border border-gray-200 rounded-lg">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50 border-b border-gray-200">
          <tr class="text-left text-[10px] font-bold uppercase tracking-wider text-gray-500">
            <th class="px-3 py-2 w-10">
              <input
                type="checkbox"
                checked={allSelected}
                disabled={!canEdit}
                on:change={toggleAll}
                class="rounded border-gray-300 text-blue-500"
                aria-label="Vælg alle"
              />
            </th>
            <th class="px-3 py-2">Elev</th>
            <th class="px-3 py-2">Bevilling</th>
            <th class="px-3 py-2">Afgørelsesbrev</th>
            <th class="px-3 py-2">Oprettet</th>
            <th class="px-3 py-2">Ventet</th>
            <th class="px-3 py-2 text-right">Handling</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          {#each forsendelser as brev (brev.brev_id)}
            <tr class="hover:bg-gray-50" class:bg-blue-50={selectedIds.includes(brev.brev_id)}>
              <td class="px-3 py-2.5">
                <input
                  type="checkbox"
                  checked={selectedIds.includes(brev.brev_id)}
                  disabled={!canEdit}
                  on:change={() => toggle(brev.brev_id)}
                  class="rounded border-gray-300 text-blue-500"
                  aria-label="Vælg brev"
                />
              </td>

              <td class="px-3 py-2.5">
                <a href="/sag/{brev.cpr_elev}" class="text-sky-600 font-medium hover:underline">
                  {brev.adresseringsnavn ?? "—"}
                </a>
                <span class="block text-xs text-gray-400">{formatCpr(brev.cpr_elev)}</span>
              </td>

              <td class="px-3 py-2.5 whitespace-nowrap">
                <!-- Løbenummer, matching the badge on the bevilling card. The
                     system id follows in grey for bug reports. -->
                {brev.loebenummer != null ? `Bevilling ${brev.loebenummer}` : `Bevilling #${brev.bevilling_id}`}
                <span class="font-mono text-[11px] text-gray-400 ml-1">#{brev.bevilling_id}</span>
                {#if brev.esdh_noegle}
                  <span class="block font-mono text-[11px] text-gray-400">{brev.esdh_noegle}</span>
                {/if}
              </td>

              <td class="px-3 py-2.5">
                {brev.afgoerelsesbrev_tekst ?? "—"}
                {#if brev.brev_i_forbindelse_med}
                  <span class="block text-xs text-gray-400">{brev.brev_i_forbindelse_med}</span>
                {/if}
              </td>

              <td class="px-3 py-2.5 whitespace-nowrap text-gray-600">
                {formatTidspunkt(brev.oprettet_tidspunkt)}
                {#if brev.oprettet_af}
                  <span class="block text-xs text-gray-400">{brev.oprettet_af}</span>
                {/if}
              </td>

              <td class="px-3 py-2.5 whitespace-nowrap">
                <span class="inline-block px-2 py-0.5 rounded text-xs font-medium {ventetClass(brev.dage_ventet ?? 0)}">
                  {brev.dage_ventet ?? 0}
                  {(brev.dage_ventet ?? 0) === 1 ? "dag" : "dage"}
                </span>
              </td>

              <td class="px-3 py-2.5 text-right">
                <button
                  type="button"
                  disabled={!canEdit || isSaving}
                  class="px-2.5 py-1 text-xs font-medium border border-gray-300 rounded hover:bg-white transition-colors disabled:opacity-40 disabled:cursor-not-allowed whitespace-nowrap"
                  on:click={() => markAfsendt([brev.brev_id])}
                >
                  Markér som afsendt
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>
