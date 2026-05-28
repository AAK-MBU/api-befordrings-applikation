<script lang="ts">
  import { invalidateAll } from "$app/navigation";
  import { backendFetch } from "$lib/client/backendFetch";
  import { formatDanishDate, getStatusBadgeClass } from "$lib/tableColumnConfig";
  import KoerselsraekkeTable from "$lib/components/KoerselsraekkeTable.svelte";

  export let data;

  $: revurderinger        = data.revurderinger        ?? [];
  $: koerselstyper        = data.koerselstyper        ?? [];
  $: tidspunkter          = data.tidspunkter          ?? [];
  $: hjemler              = data.hjemler              ?? [];
  $: afgoerelsesbreve     = data.afgoerelsesbreve     ?? [];
  $: koerselstypeTillaeg  = data.koerselstypeTillaeg  ?? [];
  $: dage                 = data.dage                 ?? [];

  $: lookupOptions = {
    koerselstyper,
    tidspunkter,
    koerselstypeTillaeg,
    dage,
  };

  // ---------------------------------------------------------------------------
  // School filter
  // ---------------------------------------------------------------------------

  let selectedSkole = "";
  let selectedSagsbehandler = "";
  let selectedPprSagsbehandler = "";

  $: uniqueSkoler           = [...new Set(revurderinger.map((b: any) => b.skole_navn).filter(Boolean))].sort() as string[];
  $: uniqueSagsbehandlere   = [...new Set(revurderinger.map((b: any) => b.sagsbehandler_tekst).filter(Boolean))].sort() as string[];
  $: uniquePprSagsbehandlere = [...new Set(revurderinger.map((b: any) => b.ppr_sagsbehandler_tekst).filter(Boolean))].sort() as string[];

  $: filteredRevurderinger = revurderinger.filter((b: any) => {
    if (selectedSkole            && b.skole_navn            !== selectedSkole)            return false;
    if (selectedSagsbehandler    && b.sagsbehandler_tekst   !== selectedSagsbehandler)    return false;
    if (selectedPprSagsbehandler && b.ppr_sagsbehandler_tekst !== selectedPprSagsbehandler) return false;
    return true;
  });

  $: anyFilterActive = !!(selectedSkole || selectedSagsbehandler || selectedPprSagsbehandler);

  // ---------------------------------------------------------------------------
  // Summary stats (based on full unfiltered list)
  // ---------------------------------------------------------------------------

  $: overskredet    = revurderinger.filter((b: any) => (daysUntil(b.revurderingsdato) ?? 0) < 0).length;
  $: indenFor30Dage = revurderinger.filter((b: any) => { const d = daysUntil(b.revurderingsdato); return d !== null && d >= 0 && d <= 30; }).length;

  // ---------------------------------------------------------------------------
  // Urgency helpers
  // ---------------------------------------------------------------------------

  function daysUntil(dateStr: string | null): number | null {
    if (!dateStr) return null;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const target = new Date(dateStr);
    return Math.floor((target.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
  }

  function urgencyColor(revurderingsdato: string | null): string {
    const d = daysUntil(revurderingsdato);
    if (d === null) return "#6b7280";
    if (d < 0)     return "#dc2626";
    if (d <= 30)   return "#ca8a04";
    return "#3b82f6";
  }

  function urgencyLabel(revurderingsdato: string | null): string {
    const d = daysUntil(revurderingsdato);
    if (d === null) return "Ingen dato";
    if (d < 0)     return `${Math.abs(d)} dage overskredet`;
    if (d === 0)   return "I dag";
    if (d === 1)   return "I morgen";
    return `Om ${d} dage`;
  }

  // ---------------------------------------------------------------------------
  // Expand / collapse
  // ---------------------------------------------------------------------------

  let expandedIds = new Set<number>();

  function toggleExpand(id: number) {
    if (expandedIds.has(id)) {
      expandedIds.delete(id);
    } else {
      expandedIds.add(id);
    }
    expandedIds = expandedIds;
  }

  function expandAll() {
    expandedIds = new Set(filteredRevurderinger.map((b: any) => b.bevilling_id));
  }

  function collapseAll() {
    expandedIds = new Set();
  }

  $: allExpanded = filteredRevurderinger.length > 0 && filteredRevurderinger.every((b: any) => expandedIds.has(b.bevilling_id));

  // ---------------------------------------------------------------------------
  // Koerselsraekke handlers (delegated to KoerselsraekkeTable component)
  // ---------------------------------------------------------------------------

  async function handleSaveKoerselsraekke(koerselId: number, updates: any): Promise<boolean> {
    const res = await backendFetch(`/bevilling/koerselsraekke/${koerselId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(updates),
    });
    if (!res.ok) return false;
    await invalidateAll();
    return true;
  }

  async function handleCreateKoerselsraekke(bevillingId: number, updates: any): Promise<boolean> {
    const res = await backendFetch(`/bevilling/create_koerselsraekke/${bevillingId}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(updates),
    });
    if (!res.ok) return false;
    await invalidateAll();
    return true;
  }

  async function handleFinalizeKoerselsraekke(koerselId: number): Promise<boolean> {
    const res = await backendFetch(`/bevilling/koerselsraekke/${koerselId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ final: true }),
    });
    if (!res.ok) return false;
    await invalidateAll();
    return true;
  }


  // ---------------------------------------------------------------------------
  // PPR toggle
  // ---------------------------------------------------------------------------

  async function togglePpr(bevillingId: number, current: boolean | null) {
    const res = await backendFetch(`/bevilling/${bevillingId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ revurderet_af_ppr: !current }),
    });
    if (!res.ok) {
      console.error("Failed to update revurderet_af_ppr:", res.status, await res.text());
      return;
    }
    await invalidateAll();
  }

  // ---------------------------------------------------------------------------
  // Bevilling field editing (hjemmel, afgørelsesbrev, afstandskriterie_dato)
  // ---------------------------------------------------------------------------

  let editingBevillingFields: number | null = null;
  let editFields = {
    hjemmel_id: null as number | null,
    afgoerelsesbrev_id: null as number | null,
    afstandskriterie_dato: "",
    revurderingsdato: "",
  };

  function startEditFields(bev: any) {
    editingBevillingFields = bev.bevilling_id;
    editFields = {
      hjemmel_id: bev.hjemmel_id ?? null,
      afgoerelsesbrev_id: bev.afgoerelsesbrev_id ?? null,
      afstandskriterie_dato: bev.afstandskriterie_dato ? bev.afstandskriterie_dato.slice(0, 10) : "",
      revurderingsdato: bev.revurderingsdato ? bev.revurderingsdato.slice(0, 10) : "",
    };
  }

  function cancelEditFields() {
    editingBevillingFields = null;
  }

  async function saveEditFields(bevillingId: number) {
    const payload: Record<string, any> = {
      hjemmel_id: editFields.hjemmel_id,
      afgoerelsesbrev_id: editFields.afgoerelsesbrev_id,
      afstandskriterie_dato: editFields.afstandskriterie_dato || null,
      revurderingsdato: editFields.revurderingsdato || null,
    };
    const res = await backendFetch(`/bevilling/${bevillingId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      console.error("Failed to update bevilling fields:", res.status, await res.text());
      return;
    }
    cancelEditFields();
    await invalidateAll();
  }
</script>


<svelte:head>
  <title>Befordring – Revurdering</title>
</svelte:head>


<section>

  <!-- Page header -->
  <div class="flex items-center justify-between mb-5 flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Revurdering</h1>
      <p class="text-sm text-gray-500 mt-0.5">Bevillinger der afventer revurdering</p>
    </div>

    <div class="flex items-center gap-4 flex-wrap">

      <!-- School filter -->
      {#if uniqueSkoler.length > 0}
        <select
          class="min-w-[180px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white"
          bind:value={selectedSkole}
        >
          <option value="">Alle skoler ({revurderinger.length})</option>
          {#each uniqueSkoler as skole}
            {@const count = revurderinger.filter((b: any) => b.skole_navn === skole).length}
            <option value={skole}>{skole} ({count})</option>
          {/each}
        </select>
      {/if}

      <!-- Sagsbehandler filter -->
      {#if uniqueSagsbehandlere.length > 0}
        <select
          class="min-w-[160px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white"
          bind:value={selectedSagsbehandler}
        >
          <option value="">Alle sagsbehandlere</option>
          {#each uniqueSagsbehandlere as sb}
            {@const count = revurderinger.filter((b: any) => b.sagsbehandler_tekst === sb).length}
            <option value={sb}>{sb} ({count})</option>
          {/each}
        </select>
      {/if}

      <!-- PPR sagsbehandler filter -->
      {#if uniquePprSagsbehandlere.length > 0}
        <select
          class="min-w-[160px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white"
          bind:value={selectedPprSagsbehandler}
        >
          <option value="">Alle PPR sagsbehandlere</option>
          {#each uniquePprSagsbehandlere as ppr}
            {@const count = revurderinger.filter((b: any) => b.ppr_sagsbehandler_tekst === ppr).length}
            <option value={ppr}>{ppr} ({count})</option>
          {/each}
        </select>
      {/if}

      <!-- Reset filters -->
      {#if anyFilterActive}
        <button
          type="button"
          class="text-xs font-medium text-gray-500 hover:text-red-600 flex items-center gap-1 transition-colors whitespace-nowrap"
          on:click={() => { selectedSkole = ""; selectedSagsbehandler = ""; selectedPprSagsbehandler = ""; }}
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
          Nulstil filtre
        </button>
      {/if}

      <!-- Expand/collapse toggle -->
      {#if filteredRevurderinger.length > 0}
        <button
          type="button"
          class="text-xs font-medium text-sky-700 hover:underline whitespace-nowrap"
          on:click={() => allExpanded ? collapseAll() : expandAll()}
        >
          {allExpanded ? 'Fold alle' : 'Udvid alle'}
        </button>
      {/if}

      <!-- Count badge -->
      <span class="text-sm font-bold text-gray-500">
        {filteredRevurderinger.length}{anyFilterActive ? ` / ${revurderinger.length}` : ''} sager
      </span>

    </div>
  </div>


  <!-- Summary card -->
  <div class="bg-white border border-gray-300 rounded-lg shadow px-6 py-5 mb-5 flex items-center gap-8">
    <div>
      <p class="text-4xl font-bold text-gray-900">{revurderinger.length}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Sager</p>
    </div>

    <div class="h-10 w-px bg-gray-200"></div>

    <div>
      <p class="text-2xl font-bold" style={overskredet > 0 ? 'color:#dc2626;' : 'color:#9ca3af;'}>{overskredet}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Overskredet</p>
    </div>

    <div class="h-10 w-px bg-gray-200"></div>

    <div>
      <p class="text-2xl font-bold" style={indenFor30Dage > 0 ? 'color:#ca8a04;' : 'color:#9ca3af;'}>{indenFor30Dage}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Inden for 30 dage</p>
    </div>
  </div>


  {#if filteredRevurderinger.length === 0}

    <div class="bg-white border border-gray-300 rounded-lg shadow px-6 py-16 text-center">
      <div class="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center mx-auto mb-4">
        <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
        </svg>
      </div>
      {#if selectedSkole}
        <p class="text-gray-700 font-semibold">Ingen sager for denne skole</p>
        <p class="text-sm text-gray-400 mt-1">{selectedSkole}</p>
      {:else}
        <p class="text-gray-700 font-semibold">Ingen sager til revurdering</p>
        <p class="text-sm text-gray-400 mt-1">Alle bevillinger er opdaterede.</p>
      {/if}
    </div>

  {:else}

    <div>

      {#each filteredRevurderinger as bev, i}

        {@const color = urgencyColor(bev.revurderingsdato)}
        {@const label = urgencyLabel(bev.revurderingsdato)}
        {@const isExpanded = expandedIds.has(bev.bevilling_id)}
        {@const activeKoerselstyper = [...new Set((bev.koerselsraekker ?? []).filter((k: any) => !k.final).map((k: any) => k.befordringstype_tekst).filter(Boolean))]}

        <div class="border border-gray-200 bg-white overflow-hidden {isExpanded ? 'rounded-lg shadow-sm my-2' : i > 0 ? '-mt-px' : ''}">

          <!-- Collapsed row — always visible -->
          <div
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-gray-50 transition-colors select-none"
            style="border-left: 3px solid {color};"
            on:click={() => toggleExpand(bev.bevilling_id)}
            role="button"
            tabindex="0"
            on:keydown={(e) => e.key === 'Enter' && toggleExpand(bev.bevilling_id)}
          >

            <!-- Expand chevron -->
            <svg
              class="w-4 h-4 text-gray-400 shrink-0 transition-transform duration-150 {isExpanded ? 'rotate-90' : ''}"
              fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
            </svg>

            <!-- Name + CPR + school -->
            <div class="min-w-0 w-52 shrink-0 flex flex-col justify-center">
              <div class="flex items-center gap-2">
                <a
                  href="/sag/{bev.cpr_elev}"
                  class="font-semibold text-sky-700 hover:underline text-sm whitespace-nowrap"
                  on:click|stopPropagation
                >
                  {bev.adresseringsnavn ?? "—"}
                </a>
              </div>
              <div class="flex items-center gap-1.5 mt-0.5">
                <span class="text-gray-400 text-xs whitespace-nowrap">{bev.cpr_elev}</span>
                {#if bev.skole_navn}
                  <span class="text-gray-300 text-xs">·</span>
                  <span class="text-gray-500 text-xs whitespace-nowrap truncate">{bev.skole_navn}</span>
                {/if}
              </div>
              {#if activeKoerselstyper.length > 0}
                <div class="flex items-center gap-1 mt-1 flex-wrap">
                  {#each activeKoerselstyper as type}
                    <span class="px-1.5 rounded text-[10px] font-medium bg-teal-50 text-teal-700 border border-teal-100 leading-5">
                      {type}
                    </span>
                  {/each}
                </div>
              {/if}
            </div>

            <!-- Summary chips — columns compress gracefully when space is constrained -->
            <div class="hidden lg:flex flex-1 items-center min-w-0 overflow-hidden px-2">
              <div class="flex flex-col min-w-0 min-w-[90px] w-[110px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Revurderingsdato</span>
                <span class="text-xs text-gray-600 truncate">{formatDanishDate(bev.revurderingsdato) ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[80px] w-[130px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Klasseart</span>
                <span class="text-xs text-gray-600 truncate">{bev.klasseart ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[60px] w-[80px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Klassetrin</span>
                <span class="text-xs text-gray-600 truncate">{bev.klassebetegnelse ?? (bev.elevklassetrin ? `Trin ${bev.elevklassetrin}` : '—')}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[80px] w-[110px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Sagsbehandler</span>
                <span class="text-xs text-gray-600 truncate">{bev.sagsbehandler_tekst ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[80px] w-[130px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">PPR sagsbehandler</span>
                <span class="text-xs text-gray-600 truncate">{bev.ppr_sagsbehandler_tekst ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[60px] w-[80px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Gåafstand</span>
                <span class="text-xs text-gray-600 truncate">
                  {bev.gaaafstand_km != null ? Number(bev.gaaafstand_km).toFixed(1) + ' km' : '—'}
                </span>
              </div>
            </div>

            <!-- Urgency badge -->
            <div class="flex items-center gap-2 shrink-0">
              <span
                class="text-[11px] font-semibold px-2 py-0.5 rounded-full whitespace-nowrap"
                style="background:{color}18; color:{color};"
              >
                {label}
              </span>
            </div>

            <!-- PPR badge / button -->
            <div class="shrink-0" on:click|stopPropagation>
              <button
                type="button"
                class="text-[11px] font-semibold px-2 py-0.5 rounded-full border transition-colors whitespace-nowrap
                  {bev.revurderet_af_ppr
                    ? 'bg-green-100 border-green-300 text-green-700 hover:bg-green-200'
                    : 'bg-gray-100 border-gray-300 text-gray-500 hover:bg-gray-200'}"
                on:click={() => togglePpr(bev.bevilling_id, bev.revurderet_af_ppr)}
              >
                {bev.revurderet_af_ppr ? '✓ PPR revurderet' : 'PPR ikke revurderet'}
              </button>
            </div>

          </div>


          <!-- Expanded panel -->
          {#if isExpanded}
            {@const isEditingFields = editingBevillingFields === bev.bevilling_id}
            <div class="border-t border-gray-100" style="border-left: 3px solid {color};">

              <!-- Details grid -->
              <div class="px-6 py-4 bg-gray-50 grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-x-6 gap-y-3">

                <div>
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Klasseart</p>
                  <p class="text-xs text-gray-700">{bev.klasseart ?? "—"}</p>
                </div>

                <div>
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Klasse / trin</p>
                  <p class="text-xs text-gray-700">
                    {bev.klassebetegnelse ?? "—"}{#if bev.elevklassetrin}&nbsp;· trin {bev.elevklassetrin}{/if}
                  </p>
                </div>

                <div class="col-span-2 sm:col-span-1">
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Adresse</p>
                  <p class="text-xs text-gray-700 truncate" title={bev.folkeregister_adresse}>{bev.folkeregister_adresse ?? "—"}</p>
                </div>

                <div>
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Gåafstand</p>
                  <p class="text-xs text-gray-700">
                    {bev.gaaafstand_km != null ? Number(bev.gaaafstand_km).toFixed(1) + ' km' : '—'}
                  </p>
                </div>

                <div>
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Hjemmel</p>
                  {#if isEditingFields}
                    <select
                      class="w-full border border-gray-300 rounded pl-1.5 pr-6 py-0.5 text-xs focus:border-blue-400 focus:ring-0 bg-white"
                      value={editFields.hjemmel_id ?? ""}
                      on:change={(e) => editFields = { ...editFields, hjemmel_id: e.currentTarget.value ? Number(e.currentTarget.value) : null }}
                    >
                      <option value="">—</option>
                      {#each hjemler as opt}
                        <option value={opt.id}>{opt.label}</option>
                      {/each}
                    </select>
                  {:else}
                    <p class="text-xs text-gray-700">{bev.hjemmel_tekst ?? "—"}</p>
                  {/if}
                </div>

                <div>
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Afgørelsesbrev</p>
                  {#if isEditingFields}
                    <select
                      class="w-full border border-gray-300 rounded pl-1.5 pr-6 py-0.5 text-xs focus:border-blue-400 focus:ring-0 bg-white"
                      value={editFields.afgoerelsesbrev_id ?? ""}
                      on:change={(e) => editFields = { ...editFields, afgoerelsesbrev_id: e.currentTarget.value ? Number(e.currentTarget.value) : null }}
                    >
                      <option value="">—</option>
                      {#each afgoerelsesbreve as opt}
                        <option value={opt.id}>{opt.label}</option>
                      {/each}
                    </select>
                  {:else}
                    <p class="text-xs text-gray-700">{bev.afgoerelsesbrev_tekst ?? "—"}</p>
                  {/if}
                </div>

                <div>
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Afstandskriterie dato</p>
                  {#if isEditingFields}
                    <input
                      type="date"
                      class="border border-gray-300 rounded px-1.5 py-0.5 text-xs focus:border-blue-400 focus:ring-0"
                      bind:value={editFields.afstandskriterie_dato}
                    />
                  {:else}
                    <p class="text-xs text-gray-700">{formatDanishDate(bev.afstandskriterie_dato) ?? "—"}</p>
                  {/if}
                </div>

                <div>
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">PPR Sagsbehandler</p>
                  <p class="text-xs text-gray-700">{bev.ppr_sagsbehandler_tekst ?? "—"}</p>
                </div>

                <div>
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Sagsbehandler</p>
                  <p class="text-xs text-gray-700">{bev.sagsbehandler_tekst ?? "—"}</p>
                </div>

                <div>
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Revurderingsdato</p>
                  {#if isEditingFields}
                    <input
                      type="date"
                      class="w-full border border-gray-300 rounded px-1.5 py-0.5 text-xs focus:border-blue-400 focus:ring-0"
                      bind:value={editFields.revurderingsdato}
                    />
                  {:else}
                    <p class="text-xs text-gray-700">{formatDanishDate(bev.revurderingsdato) ?? "—"}</p>
                  {/if}
                </div>

              </div>

              <!-- Actions bar — clearly tied to the fields above, before koerselsrækker -->
              <div class="px-6 py-2.5 border-t border-gray-200 bg-gray-50 flex items-center gap-3 flex-wrap">
                <a
                  href="/sag/{bev.cpr_elev}"
                  class="text-xs font-medium text-sky-700 hover:underline"
                >
                  Gå til sag →
                </a>

                <span class="text-gray-300 text-xs">|</span>

                {#if editingBevillingFields === bev.bevilling_id}
                  <button
                    type="button"
                    class="text-xs font-medium text-white bg-green-600 hover:bg-green-700 px-3 py-1 rounded transition-colors"
                    on:click={() => saveEditFields(bev.bevilling_id)}
                  >
                    Gem ændringer
                  </button>
                  <button
                    type="button"
                    class="text-xs font-medium text-gray-500 hover:text-gray-700"
                    on:click={cancelEditFields}
                  >
                    Annullér
                  </button>
                {:else}
                  <button
                    type="button"
                    class="text-xs font-medium text-gray-500 hover:text-sky-700 flex items-center gap-1"
                    on:click={() => startEditFields(bev)}
                  >
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15.232 5.232l3.536 3.536M9 13l6.586-6.586a2 2 0 112.828 2.828L11.828 15.828a2 2 0 01-1.414.586H9v-2a2 2 0 01.586-1.414z" />
                    </svg>
                    Rediger felter
                  </button>
                {/if}
              </div>

              <!-- Koerselsraekker -->
              <div class="border-t-2 border-gray-300 bg-gray-100">
                <div class="px-6 py-2.5 border-b border-gray-300">
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500">Kørselsrækker</p>
                </div>
                <div class="px-6 py-4">
                  <KoerselsraekkeTable
                    rows={bev.koerselsraekker ?? []}
                    lookupOptions={lookupOptions}
                    adresseForBevilling={bev.adresse_for_bevilling ?? ""}
                    matrikelId={bev.matrikel_id ?? null}
                    onSaveKoerselsraekke={handleSaveKoerselsraekke}
                    onCreateKoerselsraekke={(updates) => handleCreateKoerselsraekke(bev.bevilling_id, updates)}
                    onFinalizeKoerselsraekke={handleFinalizeKoerselsraekke}
                  />
                </div>
              </div>

            </div>
          {/if}

        </div>

      {/each}

    </div>

  {/if}

</section>
