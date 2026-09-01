<script lang="ts">
  import { page } from "$app/stores";
  import { invalidateAll } from "$app/navigation";
  import { backendFetch } from "$lib/client/backendFetch";
  import { formatCpr } from "$lib/tableColumnConfig";
  import AddresseSearch from "$lib/components/AddresseSearch.svelte";

  export let cpr: string;
  export let parter: any[] = [];

  // Fixed relation options (was free text).
  const RELATION_OPTIONS = ["Værge", "Plejefamilie", "Adoptiv Far/Mor", "Andet"];

  type Draft = {
    fulde_navn: string;
    cpr_nummer: string;
    adresse_id: string | null;
    adresse_tekst: string;
    relation: string;
    telefonnummer: string;
  };

  const emptyDraft = (): Draft => ({
    fulde_navn: "",
    cpr_nummer: "",
    adresse_id: null,
    adresse_tekst: "",
    relation: "",
    telefonnummer: "",
  });

  // Address is picked from the shared Adresse search (same as bevillinger).
  function onAddresse(result: { adresse_id: any; adresse_tekst: string } | null) {
    draft = {
      ...draft,
      adresse_id: result?.adresse_id ?? null,
      adresse_tekst: result?.adresse_tekst ?? "",
    };
  }

  // editingId: a part_id when editing that row, "new" when adding, null otherwise.
  let editingId: number | "new" | null = null;
  let draft: Draft = emptyDraft();
  let saving = false;

  let confirmingDeleteId: number | null = null;
  let deleting = false;

  const inputClass =
    "w-full border border-gray-300 rounded px-2 py-1 text-sm focus:border-blue-400 focus:ring-0 bg-white";

  // -----------------------------
  // Filtering + default sort
  // -----------------------------

  const filterKeys = ["fulde_navn", "cpr_nummer", "adresse", "relation", "telefonnummer"] as const;
  type FilterKey = (typeof filterKeys)[number];

  const emptyFilters = (): Record<FilterKey, string> => ({
    fulde_navn: "",
    cpr_nummer: "",
    adresse: "",
    relation: "",
    telefonnummer: "",
  });

  let filters: Record<FilterKey, string> = emptyFilters();

  $: hasActiveFilters = filterKeys.some((k) => filters[k].trim() !== "");

  function clearFilters() {
    filters = emptyFilters();
  }

  // Per-column searchable text. Cpr matches both the raw digits and the
  // dash-formatted version so either search works.
  function searchable(p: any): Record<FilterKey, string> {
    return {
      fulde_navn: p.fulde_navn ?? "",
      cpr_nummer: `${p.cpr_nummer ?? ""} ${p.cpr_nummer ? formatCpr(p.cpr_nummer) : ""}`,
      adresse: p.adresse_tekst ?? "",
      relation: p.relation ?? "",
      telefonnummer: p.telefonnummer ?? "",
    };
  }

  function matchesFilters(p: any): boolean {
    const s = searchable(p);
    return filterKeys.every((key) => {
      const f = filters[key].trim().toLowerCase();
      return f === "" || String(s[key]).toLowerCase().includes(f);
    });
  }

  // Default sort: name ascending (Danish collation), blank names last.
  function byNameAsc(a: any, b: any): number {
    const an = (a.fulde_navn ?? "").trim();
    const bn = (b.fulde_navn ?? "").trim();
    if (an === "" && bn === "") return 0;
    if (an === "") return 1;
    if (bn === "") return -1;
    return an.localeCompare(bn, "da");
  }

  // The row currently being edited is always kept visible so it can't vanish
  // mid-edit if a filter would otherwise exclude it.
  $: displayed = [...parter]
    .filter((p) => editingId === p.part_id || matchesFilters(p))
    .sort(byNameAsc);

  // -----------------------------
  // CRUD
  // -----------------------------

  function startAdd() {
    editingId = "new";
    draft = emptyDraft();
  }

  function startEdit(p: any) {
    editingId = p.part_id;
    draft = {
      fulde_navn: p.fulde_navn ?? "",
      cpr_nummer: p.cpr_nummer ?? "",
      adresse_id: p.adresse_id ?? null,
      adresse_tekst: p.adresse_tekst ?? "",
      relation: p.relation ?? "",
      telefonnummer: p.telefonnummer ?? "",
    };
  }

  function cancel() {
    editingId = null;
    draft = emptyDraft();
  }

  // Blank optional fields are stored as NULL.
  const toNull = (v: string) => (v.trim() === "" ? null : v.trim());
  // cpr_nummer column is VARCHAR(10) — keep digits only, capped at 10.
  const cprDigits = (v: string) => {
    const digits = v.replace(/\D/g, "").slice(0, 10);
    return digits === "" ? null : digits;
  };

  /**
   * The server's reason for refusing, or `fallback` when it gave none usable.
   *
   * Worth surfacing rather than reporting a generic failure: an authorisation
   * refusal explains that rights are granted centrally, which the user can act
   * on, whereas "Kunne ikke gemme part" tells them nothing. FastAPI puts the
   * text in `detail`, but validation errors make that an array — anything that
   * is not a string falls back rather than rendering as "[object Object]".
   */
  async function refusalReason(res: Response, fallback: string): Promise<string> {
    try {
      const body = await res.json();
      const detail = body?.detail?.message ?? body?.detail;

      return typeof detail === "string" ? detail : fallback;
    } catch {
      return fallback;
    }
  }


  // From $page rather than a prop — see ReadOnlyNotice for why not a store.
  $: canEdit = $page.data.user?.can_edit ?? false;


  async function save() {
    if (saving) return;
    saving = true;

    try {
      const body = JSON.stringify({
        fulde_navn: toNull(draft.fulde_navn),
        cpr_nummer: cprDigits(draft.cpr_nummer),
        adresse_id: draft.adresse_id,
        relation: toNull(draft.relation),
        telefonnummer: toNull(draft.telefonnummer),
      });

      const res =
        editingId === "new"
          ? await backendFetch(`/part/${cpr}`, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body,
            })
          : await backendFetch(`/part/${editingId}`, {
              method: "PUT",
              headers: { "Content-Type": "application/json" },
              body,
            });

      if (!res.ok) {
        alert(await refusalReason(res, "Kunne ikke gemme part"));
        return;
      }

      editingId = null;
      draft = emptyDraft();
      await invalidateAll();
    } finally {
      saving = false;
    }
  }

  async function doDelete() {
    if (deleting || confirmingDeleteId === null) return;
    deleting = true;

    try {
      const res = await backendFetch(`/part/${confirmingDeleteId}`, { method: "DELETE" });

      if (!res.ok) {
        alert(await refusalReason(res, "Kunne ikke slette part"));
        return;
      }

      confirmingDeleteId = null;
      await invalidateAll();
    } finally {
      deleting = false;
    }
  }
</script>

<svelte:window on:keydown={(e) => { if (e.key === 'Escape' && confirmingDeleteId !== null) confirmingDeleteId = null; }} />

<div class="w-full overflow-x-auto">
  {#if hasActiveFilters}
    <div class="flex items-center justify-between px-3 py-1.5 mb-2 rounded-md bg-sky-50 border border-sky-100 text-xs text-sky-700">
      <span>Aktive filtre</span>
      <button type="button" on:click={clearFilters} class="font-medium hover:underline">Ryd filtre</button>
    </div>
  {/if}

  <table class="w-full text-sm text-gray-700 border-collapse">
    <thead>
      <tr class="text-white text-left" style="background-color: #032A42;">
        <th class="px-3 py-2 font-semibold min-w-40">Navn</th>
        <th class="px-3 py-2 font-semibold min-w-32">Cpr-nummer</th>
        <th class="px-3 py-2 font-semibold min-w-48">Adresse</th>
        <th class="px-3 py-2 font-semibold min-w-32">Relation</th>
        <th class="px-3 py-2 font-semibold min-w-32">Telefon</th>
        <th class="px-3 py-2 font-semibold text-right whitespace-nowrap">Handling</th>
      </tr>

      <!-- Filter / search row -->
      <tr class="bg-gray-100 border-b border-gray-300">
        {#each filterKeys as key}
          <td class="px-3 py-2 align-top">
            <input
              type="text"
              placeholder="Søg..."
              class="h-7 w-full border border-gray-200 rounded px-2 text-xs focus:border-blue-400 focus:ring-0 bg-white"
              bind:value={filters[key]}
            />
          </td>
        {/each}
        <td class="px-3 py-2"></td>
      </tr>
    </thead>

    <tbody>
      {#if editingId === "new"}
        <tr class="border-b border-gray-200 bg-blue-50/40">
          <td class="px-3 py-2"><input class={inputClass} bind:value={draft.fulde_navn} placeholder="Fulde navn" /></td>
          <td class="px-3 py-2"><input class={inputClass} bind:value={draft.cpr_nummer} placeholder="Cpr-nummer" /></td>
          <td class="px-3 py-2">
            <AddresseSearch adresseId={draft.adresse_id} adresseTekst={draft.adresse_tekst} inputClass={inputClass} onSelect={onAddresse} />
          </td>
          <td class="px-3 py-2">
            <select class={inputClass} bind:value={draft.relation}>
              <option value="">Vælg</option>
              {#each RELATION_OPTIONS as opt}
                <option value={opt}>{opt}</option>
              {/each}
            </select>
          </td>
          <td class="px-3 py-2"><input class={inputClass} bind:value={draft.telefonnummer} placeholder="Telefon" /></td>
          <td class="px-3 py-2 text-right whitespace-nowrap">
            <button type="button" disabled={saving} class="px-3 py-1 text-xs font-medium bg-green-600 hover:bg-green-700 text-white rounded disabled:opacity-50" on:click={save}>
              {saving ? "Gemmer..." : "Gem"}
            </button>
            <button type="button" class="ml-1 px-3 py-1 text-xs font-medium border border-gray-300 rounded hover:bg-gray-50" on:click={cancel}>Annullér</button>
          </td>
        </tr>
      {/if}

      {#each displayed as p}
        <tr class="border-b border-gray-200 hover:bg-blue-50/40">
          {#if editingId === p.part_id}
            <td class="px-3 py-2"><input class={inputClass} bind:value={draft.fulde_navn} placeholder="Fulde navn" /></td>
            <td class="px-3 py-2"><input class={inputClass} bind:value={draft.cpr_nummer} placeholder="Cpr-nummer" /></td>
            <td class="px-3 py-2">
              <AddresseSearch adresseId={draft.adresse_id} adresseTekst={draft.adresse_tekst} inputClass={inputClass} onSelect={onAddresse} />
            </td>
            <td class="px-3 py-2">
              <select class={inputClass} bind:value={draft.relation}>
                <option value="">Vælg</option>
                {#each RELATION_OPTIONS as opt}
                  <option value={opt}>{opt}</option>
                {/each}
              </select>
            </td>
            <td class="px-3 py-2"><input class={inputClass} bind:value={draft.telefonnummer} placeholder="Telefon" /></td>
            <td class="px-3 py-2 text-right whitespace-nowrap">
              <button type="button" disabled={saving} class="px-3 py-1 text-xs font-medium bg-green-600 hover:bg-green-700 text-white rounded disabled:opacity-50" on:click={save}>
                {saving ? "Gemmer..." : "Gem"}
              </button>
              <button type="button" class="ml-1 px-3 py-1 text-xs font-medium border border-gray-300 rounded hover:bg-gray-50" on:click={cancel}>Annullér</button>
            </td>
          {:else}
            <td class="px-3 py-2">{p.fulde_navn ?? "—"}</td>
            <td class="px-3 py-2 font-mono">{p.cpr_nummer ? formatCpr(p.cpr_nummer) : "—"}</td>
            <td class="px-3 py-2">{p.adresse_tekst ?? "—"}</td>
            <td class="px-3 py-2">{p.relation ?? "—"}</td>
            <td class="px-3 py-2">{p.telefonnummer ?? "—"}</td>
            <td class="px-3 py-2 text-right whitespace-nowrap">
              <button type="button" disabled={editingId !== null || !canEdit} class="px-3 py-1 text-xs font-medium border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed" on:click={() => startEdit(p)}>Redigér</button>
              <button type="button" disabled={editingId !== null || !canEdit} class="ml-1 px-3 py-1 text-xs font-medium text-red-600 border border-red-200 rounded hover:bg-red-50 disabled:opacity-40 disabled:cursor-not-allowed" on:click={() => (confirmingDeleteId = p.part_id)}>Slet</button>
            </td>
          {/if}
        </tr>
      {/each}

      {#if displayed.length === 0 && editingId !== "new"}
        <tr>
          <td colspan="6" class="px-4 py-6 text-center text-gray-500 bg-gray-50">
            {hasActiveFilters ? "Ingen parter matcher filteret." : "Ingen parter tilføjet endnu."}
          </td>
        </tr>
      {/if}
    </tbody>
  </table>

  <div class="mt-3">
    <button
      type="button"
      disabled={editingId !== null || !canEdit}
      class="px-4 py-2 text-sm font-medium text-white rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
      style="background-color: #032A42;"
      on:click={startAdd}
    >
      + Tilføj part
    </button>
  </div>
</div>

{#if confirmingDeleteId !== null}
  <!-- Backdrop is non-dismissing: close only via Escape or the Annullér button. -->
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" role="presentation">
    <div class="w-[420px] bg-white rounded-lg shadow-2xl" role="dialog" aria-modal="true" tabindex="-1">
      <div class="px-6 py-5 border-b border-gray-200">
        <h2 class="text-base font-semibold text-gray-900">Slet part</h2>
      </div>
      <div class="px-6 py-5">
        <p class="text-sm text-gray-700">Er du sikker på, at du vil slette denne part?</p>
      </div>
      <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200 bg-gray-50 rounded-b-lg">
        <button type="button" class="px-4 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-white transition-colors" on:click={() => (confirmingDeleteId = null)}>
          Annullér
        </button>
        <button type="button" disabled={deleting} class="px-4 py-2 text-sm font-medium bg-red-600 hover:bg-red-700 text-white rounded transition-colors disabled:opacity-50" on:click={doDelete}>
          {deleting ? "Sletter..." : "Slet"}
        </button>
      </div>
    </div>
  </div>
{/if}
