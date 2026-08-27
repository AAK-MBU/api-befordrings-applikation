  <script lang="ts">
    import { invalidateAll } from "$app/navigation";
    import { backendFetch } from "$lib/client/backendFetch";
    import { formatDanishDate, getStatusBadgeClass, formatCpr, getBefordringstypeBadgeClass } from "$lib/tableColumnConfig";
    import BevillingTable from "$lib/components/BevillingTable.svelte";
    import CreateBevillingModal from "$lib/components/CreateBevillingModal.svelte";
    import ReadOnlyNotice from "$lib/components/ReadOnlyNotice.svelte";
    import { filterHjemler, filterAfgoerelsesbreve } from "$lib/lookupFilters";

    export let data;

    // can_edit is resolved by the backend from EDIT_ROLES (see GET /me), so
    // the UI cannot drift from what require_edit actually enforces.
    $: canEdit = data.user?.can_edit ?? false;

    $: revurderinger        = data.revurderinger        ?? [];
    $: koerselstyper        = data.koerselstyper        ?? [];
    $: tidspunkter          = data.tidspunkter          ?? [];
    $: hjemler              = data.hjemler              ?? [];
    $: afgoerelsesbreve     = data.afgoerelsesbreve     ?? [];
    $: koerselstypeTillaeg  = data.koerselstypeTillaeg  ?? [];
    $: dage                 = data.dage                 ?? [];
    $: statuser             = data.statuser             ?? [];
    $: skolematrikler       = data.skolematrikler       ?? [];
    $: sagsbehandlere       = data.sagsbehandlere       ?? [];
    $: pprSagsbehandlere    = data.pprSagsbehandlere    ?? [];
    $: hjaelpemidler        = data.hjaelpemidler        ?? [];
    $: ungdomsuddannelser   = data.ungdomsuddannelser   ?? [];
    $: rutetyper            = data.rutetyper            ?? [];

    $: lookupOptions = {
      koerselstyper, tidspunkter, koerselstypeTillaeg, dage,
      statuser, skolematrikler, hjemler, afgoerelsesbreve,
      sagsbehandlere, pprSagsbehandlere, hjaelpemidler, ungdomsuddannelser,
      rutetyper,
    };

    let selectedSkole = "";
    let selectedSagsbehandler = "";
    let selectedPprSagsbehandler = "";
    let selectedKoerselstype = "";

    const defaultToDate = (() => {
      const d = new Date();
      d.setMonth(d.getMonth() + 1);
      return d.toISOString().slice(0, 10);
    })();
    let filterFromDate = "";
    let filterToDate = defaultToDate;
    let quickFilter: null | "overskredet" | "inden30" = null;

    $: uniqueSkoler            = [...new Set(revurderinger.map((b: any) => b.skole_navn).filter(Boolean))].sort() as string[];
    $: uniqueSagsbehandlere    = [...new Set(revurderinger.map((b: any) => b.sagsbehandler_tekst).filter(Boolean))].sort() as string[];
    $: uniquePprSagsbehandlere = [...new Set(revurderinger.map((b: any) => b.ppr_sagsbehandler_tekst).filter(Boolean))].sort() as string[];
    $: uniqueKoerselstyper     = [...new Set(
      revurderinger.flatMap((b: any) =>
        (b.koerselsraekker ?? [])
          .filter((k: any) => !k.final)
          .map((k: any) => k.befordringstype_tekst)
          .filter(Boolean)
      )
    )].sort() as string[];

    $: filteredRevurderinger = revurderinger.filter((b: any) => {
      if (selectedSkole            && b.skole_navn              !== selectedSkole)            return false;
      if (selectedSagsbehandler    && b.sagsbehandler_tekst     !== selectedSagsbehandler)    return false;
      if (selectedPprSagsbehandler && b.ppr_sagsbehandler_tekst !== selectedPprSagsbehandler) return false;

      if (selectedKoerselstype) {
        const types = (b.koerselsraekker ?? [])
          .filter((k: any) => !k.final)
          .map((k: any) => k.befordringstype_tekst);
        if (!types.includes(selectedKoerselstype)) return false;
      }

      if (b.revurderingsdato) {
        if (filterFromDate && b.revurderingsdato < filterFromDate) return false;
        if (filterToDate   && b.revurderingsdato > filterToDate)   return false;
      }

      if (quickFilter === "overskredet") {
        if ((daysUntil(b.revurderingsdato) ?? 0) >= 0) return false;
      }
      if (quickFilter === "inden30") {
        const d = daysUntil(b.revurderingsdato);
        if (d === null || d < 0 || d > 30) return false;
      }

      return true;
    });

    $: anyFilterActive = !!(selectedSkole || selectedSagsbehandler || selectedPprSagsbehandler
                            || selectedKoerselstype || filterFromDate
                            || filterToDate !== defaultToDate || quickFilter);

    $: overskredet    = revurderinger.filter((b: any) => (daysUntil(b.revurderingsdato) ?? 0) < 0).length;
    $: indenFor30Dage = revurderinger.filter((b: any) => { const d = daysUntil(b.revurderingsdato); return d !== null && d >= 0 && d <= 30; }).length;

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

    let expandedIds = new Set<number>();

    function toggleExpand(id: number) {
      if (expandedIds.has(id)) {
        expandedIds.delete(id);
      } else {
        expandedIds.add(id);
        const bev = revurderinger.find((r: any) => r.bevilling_id === id);
        if (bev) {
          if (!aktiviteterByCpr[bev.cpr_elev]) loadAktiviteter(bev.cpr_elev);
          if (!bevillingerByCpr[bev.cpr_elev]) loadBevillinger(bev.cpr_elev);
        }
      }
      expandedIds = new Set(expandedIds);
    }

    function expandAll() {
      expandedIds = new Set(filteredRevurderinger.map((b: any) => b.bevilling_id));
      filteredRevurderinger.forEach((bev: any) => {
        if (!aktiviteterByCpr[bev.cpr_elev]) loadAktiviteter(bev.cpr_elev);
        if (!bevillingerByCpr[bev.cpr_elev]) loadBevillinger(bev.cpr_elev);
      });
    }

    function collapseAll() {
      expandedIds = new Set();
    }

    $: allExpanded = filteredRevurderinger.length > 0 && filteredRevurderinger.every((b: any) => expandedIds.has(b.bevilling_id));

    function emptyToNull(value: any) { return value === "" ? null : value; }
    function numberOrNull(value: any) { return value === "" ? null : Number(value); }

    async function handleSaveBevilling(bevillingId: number, updates: any): Promise<string | null> {
      const { hjaelpemiddel_ids, ...bevillingUpdates } = updates;
      const res = await backendFetch(`/bevilling/${bevillingId}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(bevillingUpdates),
      });
      if (!res.ok) {
        let message = "Kunne ikke gemme bevilling";
        try { const err = await res.json(); message = err?.detail?.message ?? err?.detail ?? message; } catch { /* keep fallback */ }
        return message;
      }
      await backendFetch(`/bevilling/${bevillingId}/hjaelpemidler`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ hjaelpemiddel_ids: hjaelpemiddel_ids ?? [] }),
      });
      await invalidateAll();
      return null;
    }

    async function handleSaveKoerselsraekke(koerselId: number, updates: any): Promise<string | null> {
      const { tillaeg_ids, dag_ids, ...rest } = updates;
      const r1 = await backendFetch(`/bevilling/koerselsraekke/${koerselId}`, {
        method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify(rest),
      });
      if (!r1.ok) {
        let message = "Kunne ikke gemme kørselsrække";
        try { const err = await r1.json(); message = err?.detail?.message ?? err?.detail ?? message; } catch { /* keep fallback */ }
        return message;
      }
      const r2 = await backendFetch(`/bevilling/koerselsraekke/${koerselId}/tillaeg`, {
        method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ tillaeg_ids: tillaeg_ids ?? [] }),
      });
      if (!r2.ok) return "Kørselsrække gemt, men tillæg kunne ikke gemmes";
      const r3 = await backendFetch(`/bevilling/koerselsraekke/${koerselId}/dage`, {
        method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ dag_ids: dag_ids ?? [] }),
      });
      if (!r3.ok) return "Kørselsrække gemt, men dage kunne ikke gemmes";
      await invalidateAll();
      return null;
    }

    async function handleCreateKoerselsraekke(bevillingId: number, updates: any): Promise<string | null> {
      const res = await backendFetch(`/bevilling/create_koerselsraekke/${bevillingId}`, {
        method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(updates),
      });
      if (!res.ok) {
        let message = "Kunne ikke oprette kørselsrække";
        try { const err = await res.json(); message = err?.detail?.message ?? err?.detail ?? message; } catch { /* keep fallback */ }
        return message;
      }
      await invalidateAll();
      return null;
    }

    async function handleFinalizeKoerselsraekke(koerselId: number): Promise<string | null> {
      const res = await backendFetch(`/bevilling/koerselsraekke/${koerselId}`, {
        method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ final: true }),
      });
      if (!res.ok) {
        let message = "Kunne ikke afslutte kørselsrækken";
        try { const err = await res.json(); message = err?.detail ?? message; } catch { /* keep fallback */ }
        return message;
      }
      await invalidateAll();
      return null;
    }



    async function togglePpr(bevillingId: number, cpr: string, current: boolean | null) {
      const res = await backendFetch(`/bevilling/${bevillingId}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ revurderet_af_ppr: !current }),
      });
      if (!res.ok) { console.error("Failed to update revurderet_af_ppr:", res.status); return; }
      await loadAktiviteter(cpr);
      await invalidateAll();
    }

    let brConfirmFor: { bevillingId: number; cpr: string; current: boolean | null } | null = null;
    let pprConfirmFor: { bevillingId: number; cpr: string; current: boolean | null } | null = null;

    function openBrConfirm(bevillingId: number, cpr: string, current: boolean | null) {
      if (current) { toggleBr(bevillingId, cpr, current); return; }
      brConfirmFor = { bevillingId, cpr, current };
    }

    function openPprConfirm(bevillingId: number, cpr: string, current: boolean | null) {
      if (current) { togglePpr(bevillingId, cpr, current); return; }
      pprConfirmFor = { bevillingId, cpr, current };
    }

    async function toggleBr(bevillingId: number, cpr: string, current: boolean | null) {
      const res = await backendFetch(`/bevilling/${bevillingId}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ revurderet_af_br: !current }),
      });
      if (!res.ok) { console.error("Failed to update revurderet_af_br:", res.status); return; }
      await loadAktiviteter(cpr);
      await invalidateAll();
    }

    let aktiviteterByCpr: Record<string, any[]> = {};
    let loadingAktiviteterCpr = new Set<string>();

    async function loadAktiviteter(cpr: string) {
      loadingAktiviteterCpr.add(cpr);
      loadingAktiviteterCpr = new Set(loadingAktiviteterCpr);
      try {
        const res = await backendFetch(`/aktivitet/${cpr}`);
        if (res.ok) {
          aktiviteterByCpr[cpr] = await res.json();
          aktiviteterByCpr = { ...aktiviteterByCpr };
        }
      } finally {
        loadingAktiviteterCpr.delete(cpr);
        loadingAktiviteterCpr = new Set(loadingAktiviteterCpr);
      }
    }

    let expandedCommentsBevIds = new Set<number>();

    let copiedCpr: string | null = null;

    async function copyCpr(cpr: string, e: Event) {
      e.stopPropagation();
      await navigator.clipboard.writeText(cpr.replace(/\D/g, ''));
      copiedCpr = cpr;
      setTimeout(() => { copiedCpr = null; }, 1500);
    }

    function toggleComments(bevillingId: number) {
      if (expandedCommentsBevIds.has(bevillingId)) {
        expandedCommentsBevIds.delete(bevillingId);
      } else {
        expandedCommentsBevIds.add(bevillingId);
      }
      expandedCommentsBevIds = new Set(expandedCommentsBevIds);
    }

    let showCommentModal = false;
    let commentModalCpr = "";
    let commentModalBevillingId: number | null = null;
    let newComment = "";
    let savingComment = false;

    let inlineComments: Record<number, string> = {};
    let savingInlineCommentIds = new Set<number>();

    async function saveInlineComment(cpr: string, bevillingId: number) {
      const kommentar = (inlineComments[bevillingId] ?? "").trim();
      if (!kommentar) return;
      savingInlineCommentIds.add(bevillingId);
      savingInlineCommentIds = new Set(savingInlineCommentIds);
      try {
        const res = await backendFetch(`/aktivitet/${cpr}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ aktivitetstype: "Kommentar", kommentar, udfoert_af: null, relateret_bevilling_id: bevillingId }),
        });
        if (res.ok) {
          inlineComments = { ...inlineComments, [bevillingId]: "" };
          await loadAktiviteter(cpr);
        }
      } finally {
        savingInlineCommentIds.delete(bevillingId);
        savingInlineCommentIds = new Set(savingInlineCommentIds);
      }
    }

    function openCommentModal(cpr: string, bevillingId: number) {
      commentModalCpr = cpr;
      commentModalBevillingId = bevillingId;
      newComment = "";
      showCommentModal = true;
    }

    async function saveComment() {
      const kommentar = newComment.trim();
      if (!kommentar) return;
      savingComment = true;
      try {
        const res = await backendFetch(`/aktivitet/${commentModalCpr}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            aktivitetstype: "Kommentar",
            kommentar,
            udfoert_af: null,
            relateret_bevilling_id: commentModalBevillingId,
          }),
        });
        if (res.ok) {
          newComment = "";
          showCommentModal = false;
          await loadAktiviteter(commentModalCpr);
          await invalidateAll();
        }
      } finally {
        savingComment = false;
      }
    }

    let bevillingerByCpr: Record<string, any[]> = {};
    let loadingBevillingerCpr = new Set<string>();

    async function loadBevillinger(cpr: string) {
      loadingBevillingerCpr.add(cpr);
      loadingBevillingerCpr = new Set(loadingBevillingerCpr);
      try {
        const res = await backendFetch(`/bevilling/get_student_bevillinger/${cpr}`);
        if (!res.ok) return;
        const bevillinger = await res.json();
        const withKoersels = await Promise.all(
          bevillinger.map(async (b: any) => {
            const kr = await backendFetch(`/bevilling/get_bevilling_koerselsraekker/${b.bevilling_id}`);
            return { ...b, koerselsraekker: kr.ok ? await kr.json() : [] };
          })
        );
        bevillingerByCpr[cpr] = withKoersels;
        bevillingerByCpr = { ...bevillingerByCpr };
      } finally {
        loadingBevillingerCpr.delete(cpr);
        loadingBevillingerCpr = new Set(loadingBevillingerCpr);
      }
    }

    let showCreateBevillingModal = false;
    let bevillingModalCpr = "";
    let createBevillingModalMode: 'kopi' | 'tom' | null = null;

    function openCreateBevillingModal(cpr: string, mode: 'kopi' | 'tom') {
      bevillingModalCpr = cpr;
      createBevillingModalMode = mode;
      showCreateBevillingModal = true;
    }

    let showCreateLetterModal = false;
    let letterModalCpr = "";
    let letterType = "";
    let befordringsudvalgResultat = "";
    let selectedLetterBevillingId = "";
    let ophoersdato = "";
    let creatingLetter = false;

    $: selectedLetterBevilling = selectedLetterBevillingId
      ? (bevillingerByCpr[letterModalCpr] ?? []).find((b: any) => String(b.bevilling_id) === selectedLetterBevillingId)
      : null;
    $: selectedLetterBevillingHasBefordringsudvalg = !!(selectedLetterBevilling?.befordringsudvalg);
    $: selectedLetterBevillingIsOphoert = selectedLetterBevilling?.status_tekst === "Ophørt";

    function openCreateLetterModal(cpr: string) {
      letterModalCpr = cpr;
      letterType = "";
      befordringsudvalgResultat = "";
      selectedLetterBevillingId = "";
      ophoersdato = "";
      showCreateLetterModal = true;
    }

    async function handleCreateLetter() {
      if (!selectedLetterBevillingId) { alert("Vælg en bevilling"); return; }
      if (!letterType) { alert("Vælg hvad brevet er i forbindelse med"); return; }
      if (selectedLetterBevillingHasBefordringsudvalg && !befordringsudvalgResultat) { alert("Vælg resultat af befordringsudvalgsmøde"); return; }
      if (selectedLetterBevillingIsOphoert && !ophoersdato) { alert("Vælg ophørsdato"); return; }

      creatingLetter = true;
      try {
        const payload = {
          brev_i_forbindelse_med: letterType,
          befordringsudvalg_resultat: selectedLetterBevillingHasBefordringsudvalg ? befordringsudvalgResultat : null,
          ophoersdato: selectedLetterBevillingIsOphoert ? ophoersdato : null,
        };
        const res = await backendFetch(
          `/bevilling/create_letter/${letterModalCpr}/${selectedLetterBevillingId}`,
          { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) }
        );
        if (!res.ok) {
          let message = "Kunne ikke oprette brev";
          try { const err = await res.json(); message = err?.detail?.message ?? err?.detail ?? message; } catch { /* keep fallback */ }
          alert(message);
          return;
        }
        const result = await res.json();
        alert(`Brev er sat i kø. Reference: ${result.reference}`);
        await backendFetch(`/aktivitet/${letterModalCpr}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            aktivitetstype: "Brev oprettet",
            kommentar: `Bevilling ID: ${selectedLetterBevillingId}`,
            relateret_bevilling_id: Number(selectedLetterBevillingId),
            udfoert_af: null,
          }),
        });
        showCreateLetterModal = false;
        await loadAktiviteter(letterModalCpr);
        await invalidateAll();
      } finally {
        creatingLetter = false;
      }
    }

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

    function cancelEditFields() { editingBevillingFields = null; }

    async function saveEditFields(bevillingId: number) {
      const res = await backendFetch(`/bevilling/${bevillingId}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          hjemmel_id: editFields.hjemmel_id,
          afgoerelsesbrev_id: editFields.afgoerelsesbrev_id,
          afstandskriterie_dato: editFields.afstandskriterie_dato || null,
          revurderingsdato: editFields.revurderingsdato || null,
        }),
      });
      if (!res.ok) { console.error("Failed to update bevilling fields:", res.status); return; }
      cancelEditFields();
      await invalidateAll();
    }
  </script>


<svelte:window on:keydown={(e) => {
  if (e.key !== 'Escape') return;
  if (showCreateBevillingModal) { showCreateBevillingModal = false; }
  if (showCreateLetterModal) { showCreateLetterModal = false; }
  if (showCommentModal) { showCommentModal = false; }
  if (pprConfirmFor) { pprConfirmFor = null; }
  if (brConfirmFor) { brConfirmFor = null; }
}} />

<svelte:head>
  <title>Befordring – Revurdering</title>
</svelte:head>


{#if pprConfirmFor}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" role="dialog" aria-modal="true" tabindex="-1">
    <div class="bg-white rounded-xl shadow-2xl w-full max-w-md overflow-hidden">
      <div class="flex items-center justify-between px-5 py-4" style="background:#032A42;">
        <h3 class="text-sm font-semibold text-white">PPR vurderet</h3>
        <button type="button" aria-label="Luk" class="text-white/70 hover:text-white" on:click={() => (pprConfirmFor = null)}>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="px-5 py-5 text-sm text-gray-700 space-y-3">
        <p>Sørg for at du er helt færdig med vurderingen før du godkender.</p>
        <p class="font-semibold text-gray-900">Sagen er vurderet</p>
      </div>
      <div class="flex justify-end gap-2 px-5 py-4 border-t border-gray-100">
        <button type="button" class="px-4 py-2 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-lg" on:click={() => (pprConfirmFor = null)}>Annullér</button>
        <button type="button" class="px-4 py-2 text-sm font-medium text-white bg-green-600 hover:bg-green-700 rounded-lg"
          on:click={async () => { if (pprConfirmFor) { await togglePpr(pprConfirmFor.bevillingId, pprConfirmFor.cpr, pprConfirmFor.current); pprConfirmFor = null; } }}>Godkend</button>
      </div>
    </div>
  </div>
{/if}


{#if brConfirmFor}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" role="dialog" aria-modal="true" tabindex="-1">
    <div class="bg-white rounded-xl shadow-2xl w-full max-w-md overflow-hidden">
      <div class="flex items-center justify-between px-5 py-4" style="background:#032A42;">
        <h3 class="text-sm font-semibold text-white">BR vurderet</h3>
        <button type="button" aria-label="Luk" class="text-white/70 hover:text-white" on:click={() => (brConfirmFor = null)}>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="px-5 py-5 text-sm text-gray-700 space-y-3">
        <p>Sagen forsvinder fra denne side når du godkender vurderingen. Sørg derfor for at du er helt færdig med vurderingen og har oprettet brev.</p>
        <p class="font-semibold text-gray-900">Sagen er vurderet</p>
      </div>
      <div class="flex justify-end gap-2 px-5 py-4 border-t border-gray-100">
        <button type="button" class="px-4 py-2 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-lg" on:click={() => (brConfirmFor = null)}>Annullér</button>
        <button type="button" class="px-4 py-2 text-sm font-medium text-white bg-green-600 hover:bg-green-700 rounded-lg"
          on:click={async () => { if (brConfirmFor) { await toggleBr(brConfirmFor.bevillingId, brConfirmFor.cpr, brConfirmFor.current); brConfirmFor = null; } }}>Godkend</button>
      </div>
    </div>
  </div>
{/if}


{#if showCreateBevillingModal && bevillingModalCpr && createBevillingModalMode}
  <CreateBevillingModal
    cpr={bevillingModalCpr}
    mode={createBevillingModalMode}
    existingBevillinger={bevillingerByCpr[bevillingModalCpr] ?? []}
    {lookupOptions}
    on:created={async () => { showCreateBevillingModal = false; await loadBevillinger(bevillingModalCpr); await invalidateAll(); }}
    on:cancel={() => { showCreateBevillingModal = false; }}
  />
{/if}


{#if showCreateLetterModal}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" role="presentation">
    <div class="w-[560px] bg-white rounded-lg shadow-2xl" role="dialog" aria-modal="true" tabindex="-1">

      <div class="px-8 py-5 border-b border-gray-200 rounded-t-lg" style="background-color: #6d28d9;">
        <h2 class="text-lg font-bold text-white">Opret brev</h2>
        <p class="mt-0.5 text-sm" style="color: rgba(255,255,255,0.7);">Vælg bevilling og brevtype</p>
      </div>

      <div class="p-8 space-y-5">
        <label class="block text-sm font-medium text-gray-700">
          Vælg bevilling
          <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={selectedLetterBevillingId}>
            <option value="">Vælg bevilling</option>
            {#each bevillingerByCpr[letterModalCpr] ?? [] as bevilling}
              <option value={String(bevilling.bevilling_id)}>
                Bevilling #{bevilling.bevilling_id} – {bevilling.status_tekst ?? "Ukendt status"}
              </option>
            {/each}
          </select>
        </label>

        <label class="block text-sm font-medium text-gray-700">
          Brevet er i forbindelse med en:
          <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={letterType}>
            <option value="">Vælg</option>
            <option value="ansøgning">Ansøgning</option>
            <option value="revurdering">Revurdering</option>
            <option value="midlertidig kørsel">Midlertidig kørsel</option>
          </select>
        </label>

        {#if selectedLetterBevillingHasBefordringsudvalg}
          <label class="block text-sm font-medium text-gray-700">
            Resultat af befordringsudvalgsmøde
            <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={befordringsudvalgResultat}>
              <option value="">Vælg</option>
              <option value="Befordringsudvalg: Afslag / fastholdelse">Befordringsudvalg: Afslag / fastholdelse</option>
              <option value="Befordringsudvalg: Ændring i bevilling">Befordringsudvalg: Ændring i bevilling</option>
            </select>
          </label>
        {/if}

        {#if selectedLetterBevillingIsOphoert}
          <label class="block text-sm font-medium text-gray-700">
            Ophørsdato
            <input type="date" max="9999-12-31" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={ophoersdato} />
          </label>
        {/if}
      </div>

      <div class="flex justify-end gap-3 border-t border-gray-200 px-8 py-5 bg-gray-50 rounded-b-lg">
        <button type="button" class="px-5 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
          on:click={() => { showCreateLetterModal = false; }}>Annullér</button>
        <button type="button" disabled={creatingLetter}
          class="px-5 py-2 text-sm font-medium bg-purple-600 hover:bg-purple-700 text-white rounded transition-colors disabled:opacity-50"
          on:click={handleCreateLetter}>
          {creatingLetter ? "Opretter..." : "Opret brev"}
        </button>
      </div>

    </div>
  </div>
{/if}


{#if showCommentModal}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" role="presentation">
    <div class="w-full max-w-md bg-white rounded-lg shadow-2xl" role="dialog" aria-modal="true" tabindex="-1">
      <div class="px-6 py-4 border-b border-gray-200" style="background-color: #032A42;">
        <h2 class="text-base font-bold text-white">Tilføj kommentar</h2>
      </div>
      <div class="p-6">
        <textarea rows="4" class="w-full border border-gray-300 rounded px-3 py-2 text-sm resize-none focus:border-blue-400 focus:ring-0"
          placeholder="Skriv kommentar..." bind:value={newComment}></textarea>
      </div>
      <div class="flex justify-end gap-3 border-t border-gray-200 px-6 py-4 bg-gray-50 rounded-b-lg">
        <button type="button" class="px-4 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
          on:click={() => { showCommentModal = false; }}>Annullér</button>
        <button type="button" disabled={savingComment || !newComment.trim()}
          class="px-4 py-2 text-sm font-medium text-white rounded transition-colors disabled:opacity-50"
          style="background-color: #032A42;"
          on:click={saveComment}>
          {savingComment ? "Gemmer..." : "Gem kommentar"}
        </button>
      </div>
    </div>
  </div>
{/if}


<section>

  <ReadOnlyNotice />

  <div class="flex items-center justify-between mb-5 flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Revurdering</h1>
      <p class="text-sm text-gray-500 mt-0.5">Bevillinger der afventer revurdering</p>
    </div>

    <div class="flex items-center gap-4 flex-wrap">

      {#if uniqueSkoler.length > 0}
        <select class="min-w-[180px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white" bind:value={selectedSkole}>
          <option value="">Alle skoler ({revurderinger.length})</option>
          {#each uniqueSkoler as skole}
            {@const count = revurderinger.filter((b: any) => b.skole_navn === skole).length}
            <option value={skole}>{skole} ({count})</option>
          {/each}
        </select>
      {/if}

      {#if uniqueSagsbehandlere.length > 0}
        <select class="min-w-[160px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white" bind:value={selectedSagsbehandler}>
          <option value="">Alle sagsbehandlere</option>
          {#each uniqueSagsbehandlere as sb}
            {@const count = revurderinger.filter((b: any) => b.sagsbehandler_tekst === sb).length}
            <option value={sb}>{sb} ({count})</option>
          {/each}
        </select>
      {/if}

      {#if uniquePprSagsbehandlere.length > 0}
        <select class="min-w-[160px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white" bind:value={selectedPprSagsbehandler}>
          <option value="">Alle PPR sagsbehandlere</option>
          {#each uniquePprSagsbehandlere as ppr}
            {@const count = revurderinger.filter((b: any) => b.ppr_sagsbehandler_tekst === ppr).length}
            <option value={ppr}>{ppr} ({count})</option>
          {/each}
        </select>
      {/if}

      {#if uniqueKoerselstyper.length > 0}
        <select class="min-w-[160px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white" bind:value={selectedKoerselstype}>
          <option value="">Alle kørselstyper</option>
          {#each uniqueKoerselstyper as type}
            {@const count = revurderinger.filter((b: any) =>
              (b.koerselsraekker ?? []).filter((k: any) => !k.final).some((k: any) => k.befordringstype_tekst === type)
            ).length}
            <option value={type}>{type} ({count})</option>
          {/each}
        </select>
      {/if}

      <div class="flex items-center gap-1.5">
        <span class="text-xs text-gray-500 whitespace-nowrap">Dato fra</span>
        <input type="date" bind:value={filterFromDate} class="border border-gray-300 rounded px-2 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white" />
        <span class="text-xs text-gray-500">til</span>
        <input type="date" bind:value={filterToDate} class="border border-gray-300 rounded px-2 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white" />
      </div>

      {#if anyFilterActive}
        <button type="button"
          class="text-xs font-medium text-gray-500 hover:text-red-600 flex items-center gap-1 transition-colors whitespace-nowrap"
          on:click={() => { selectedSkole = ""; selectedSagsbehandler = ""; selectedPprSagsbehandler = ""; selectedKoerselstype = ""; filterFromDate = ""; filterToDate = defaultToDate; quickFilter = null; }}>
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
          Nulstil filtre
        </button>
      {/if}

      {#if filteredRevurderinger.length > 0}
        <button type="button" class="text-xs font-medium text-sky-700 hover:underline whitespace-nowrap"
          on:click={() => allExpanded ? collapseAll() : expandAll()}>
          {allExpanded ? 'Fold alle' : 'Udvid alle'}
        </button>
      {/if}

      <span class="text-sm font-bold text-gray-500">
        {filteredRevurderinger.length}{anyFilterActive ? ` / ${revurderinger.length}` : ''} sager
      </span>

    </div>
  </div>


  <div class="bg-white border border-gray-300 rounded-lg shadow px-6 py-5 mb-5 flex items-center gap-8">
    <button type="button"
      class="flex flex-col items-center rounded px-2 py-1 -mx-2 -my-1 transition-colors"
      class:hover:bg-gray-100={quickFilter !== null}
      class:cursor-pointer={quickFilter !== null}
      class:cursor-default={quickFilter === null}
      on:click={() => { if (quickFilter !== null) quickFilter = null; }}>
      <p class="text-3xl font-bold text-gray-900">{revurderinger.length}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Sager</p>
    </button>
    <div class="h-10 w-px bg-gray-200"></div>
    <button type="button"
      class="flex flex-col items-center hover:bg-red-50 transition-colors rounded px-2 py-1 -mx-2 -my-1"
      class:ring-2={quickFilter === 'overskredet'}
      class:ring-red-400={quickFilter === 'overskredet'}
      on:click={() => { quickFilter = quickFilter === 'overskredet' ? null : 'overskredet'; }}>
      <p class="text-3xl font-bold" style={overskredet > 0 ? 'color:#dc2626;' : 'color:#9ca3af;'}>{overskredet}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Overskredet</p>
    </button>
    <div class="h-10 w-px bg-gray-200"></div>
    <button type="button"
      class="flex flex-col items-center hover:bg-yellow-50 transition-colors rounded px-2 py-1 -mx-2 -my-1"
      class:ring-2={quickFilter === 'inden30'}
      class:ring-yellow-400={quickFilter === 'inden30'}
      on:click={() => { quickFilter = quickFilter === 'inden30' ? null : 'inden30'; }}>
      <p class="text-3xl font-bold" style={indenFor30Dage > 0 ? 'color:#ca8a04;' : 'color:#9ca3af;'}>{indenFor30Dage}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Inden for 30 dage</p>
    </button>
  </div>


  {#if filteredRevurderinger.length === 0}

    <div class="bg-white border border-gray-300 rounded-lg shadow px-6 py-16 text-center">
      {#if anyFilterActive}
        <div class="w-12 h-12 rounded-full bg-gray-100 flex items-center justify-center mx-auto mb-4">
          <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
        </div>
        <p class="text-gray-700 font-semibold">Ingen sager matcher de valgte filtre</p>
        <p class="text-sm text-gray-400 mt-1">Fjern alle filtre på én gang ved at trykke <span class="font-medium text-gray-500">Nulstil filtre</span> i øverste højre hjørne.</p>
      {:else}
        <div class="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center mx-auto mb-4">
          <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
          </svg>
        </div>
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

        <div class="overflow-hidden transition-colors {isExpanded ? 'border border-gray-300 bg-gray-100 rounded-lg shadow-md my-2' : 'border border-gray-200 bg-white' + (i > 0 ? ' -mt-px' : '')}">

          <div
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-gray-50 transition-colors select-none"
            style="border-left: 3px solid {color};"
            on:click={() => toggleExpand(bev.bevilling_id)}
            role="button"
            tabindex="0"
            on:keydown={(e) => e.key === 'Enter' && toggleExpand(bev.bevilling_id)}
          >

            <svg class="w-4 h-4 text-gray-400 shrink-0 transition-transform duration-150 {isExpanded ? 'rotate-90' : ''}"
              fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
            </svg>

            <div class="min-w-0 w-64 shrink-0 flex flex-col justify-center">
              <div class="flex items-center gap-2 flex-wrap">
                <a href="/sag/{bev.cpr_elev}" class="font-semibold text-sky-700 hover:underline text-sm whitespace-nowrap" on:click|stopPropagation>
                  {bev.adresseringsnavn ?? "—"}
                </a>
                <div class="flex items-center gap-1">
                  <span class="text-gray-400 text-xs whitespace-nowrap">{formatCpr(bev.cpr_elev)}</span>
                  <button type="button" class="text-gray-300 hover:text-gray-500 transition-colors" title="Kopiér CPR"
                    on:click={(e) => copyCpr(bev.cpr_elev, e)}>
                    {#if copiedCpr === bev.cpr_elev}
                      <svg class="w-3 h-3 text-green-500" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                      </svg>
                    {:else}
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                      </svg>
                    {/if}
                  </button>
                </div>
              </div>
              {#if bev.skole_navn}
                <span class="text-gray-500 text-[13px] mt-0.5 mb-1 leading-snug">{bev.skole_navn}</span>
              {/if}
              {#if activeKoerselstyper.length > 0}
                <div class="flex items-center gap-1 mt-1 flex-wrap">
                  {#each activeKoerselstyper as type}
                    <span class="px-2 py-0.5 rounded text-[11px] font-medium {getBefordringstypeBadgeClass(type as string)}">{type}</span>
                  {/each}
                </div>
              {/if}
            </div>

            <div class="hidden lg:flex flex-1 items-center min-w-0 overflow-hidden px-2">
              <div class="flex flex-col min-w-0 min-w-[80px] w-[130px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Klasseart</span>
                <span class="text-xs text-gray-600 truncate">{bev.klasseart ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[60px] w-[80px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Klassetrin</span>
                <span class="text-xs text-gray-600 truncate">{bev.klassebetegnelse ?? (bev.elevklassetrin ? `Trin ${bev.elevklassetrin}` : '—')}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[60px] w-[80px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Gåafstand</span>
                <span class="text-xs text-gray-600 truncate">{bev.gaaafstand_km != null ? Number(bev.gaaafstand_km).toFixed(1) + ' km' : '—'}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[80px] w-[130px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">PPR sagsbehandler</span>
                <span class="text-xs text-gray-600 truncate">{bev.ppr_sagsbehandler_tekst ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[80px] w-[110px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Sagsbehandler</span>
                <span class="text-xs text-gray-600 truncate">{bev.sagsbehandler_tekst ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[90px] w-[110px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Revurderingsdato</span>
                <span class="text-xs text-gray-600 truncate">{formatDanishDate(bev.revurderingsdato) ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[90px] w-[110px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Udløbsdato</span>
                <span class="text-xs text-gray-600 truncate">{formatDanishDate(bev.gyldig_til) ?? "—"}</span>
              </div>
              {#if bev.statusbemaerkning}
                <div class="flex flex-col min-w-0 flex-1 pl-2 border-l border-amber-200 ml-2">
                  <span class="text-[9px] font-bold uppercase tracking-wider text-amber-500 leading-none mb-0.5">Årsag</span>
                  <span class="text-xs text-amber-700 truncate" title={bev.statusbemaerkning}>{bev.statusbemaerkning}</span>
                </div>
              {/if}
            </div>

            <div class="flex items-center gap-2 shrink-0">
              <span class="text-[11px] font-semibold px-2 py-0.5 rounded-full whitespace-nowrap" style="background:{color}18; color:{color};">
                {label}
              </span>
            </div>

            <div class="shrink-0 flex items-center gap-1.5">
              <button type="button" title="PPR vurderet"
                class="flex items-center gap-1.5 border-2 rounded px-3 py-1.5 text-xs font-medium transition-all whitespace-nowrap
                  {bev.revurderet_af_ppr ? 'bg-green-600 border-green-600 text-white shadow-sm' : 'bg-white border-gray-300 text-gray-500 hover:border-green-400 hover:text-green-600'}"
                on:click|stopPropagation={() => openPprConfirm(bev.bevilling_id, bev.cpr_elev, bev.revurderet_af_ppr)}>
                <div class="w-3.5 h-3.5 rounded border flex items-center justify-center shrink-0
                  {bev.revurderet_af_ppr ? 'bg-white/20 border-white/60' : 'border-gray-300'}">
                  {#if bev.revurderet_af_ppr}
                    <svg class="w-2.5 h-2.5 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                  {/if}
                </div>
                PPR vurderet
              </button>

              <button type="button" title="BR vurderet"
                class="flex items-center gap-1.5 border-2 rounded px-3 py-1.5 text-xs font-medium transition-all whitespace-nowrap
                  {bev.revurderet_af_br ? 'bg-green-600 border-green-600 text-white shadow-sm' : 'bg-white border-gray-300 text-gray-500 hover:border-green-400 hover:text-green-600'}"
                on:click|stopPropagation={() => openBrConfirm(bev.bevilling_id, bev.cpr_elev, bev.revurderet_af_br)}>
                <div class="w-3.5 h-3.5 rounded border flex items-center justify-center shrink-0
                  {bev.revurderet_af_br ? 'bg-white/20 border-white/60' : 'border-gray-300'}">
                  {#if bev.revurderet_af_br}
                    <svg class="w-2.5 h-2.5 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                  {/if}
                </div>
                BR vurderet
              </button>
            </div>

          </div>


          {#if isExpanded}
            {@const isEditingFields = editingBevillingFields === bev.bevilling_id}
            {@const commentsOpen = expandedCommentsBevIds.has(bev.bevilling_id)}
            <div class="border-t border-gray-100" style="border-left: 3px solid {color};">

              {#if bev.statusbemaerkning}
                <div class="px-6 py-3 bg-amber-50 border-b border-amber-200 flex items-start gap-2.5">
                  <svg class="w-4 h-4 text-amber-500 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
                  </svg>
                  <div>
                    <p class="text-[10px] font-bold uppercase tracking-wider text-amber-600 mb-0.5">Årsag til revurdering</p>
                    <p class="text-sm text-amber-900">{bev.statusbemaerkning}</p>
                  </div>
                </div>
              {/if}

              <div class="bg-gray-100">
                <div class="px-6 py-2.5 flex items-center justify-between gap-3">
                  <div class="flex items-center gap-2">
                    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500">Elevdata</p>
                    <span class="text-gray-300 text-[10px]">|</span>
                    <a href="/sag/{bev.cpr_elev}" class="flex items-center gap-0.5 text-xs font-medium text-sky-600 hover:text-sky-800 transition-colors">
                      Gå til sag
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
                      </svg>
                    </a>
                  </div>
                  {#if isEditingFields}
                    <div class="flex items-center gap-2">
                      <button type="button" class="px-3 py-1.5 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded transition-colors"
                        on:click={() => saveEditFields(bev.bevilling_id)}>Gem ændringer</button>
                      <button type="button" class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors bg-white"
                        on:click={cancelEditFields}>Annullér</button>
                    </div>
                  {:else}
                    <button type="button" class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors bg-white"
                      on:click={() => startEditFields(bev)}>Redigér</button>
                  {/if}
                </div>
                <div class="px-4 pb-3">
                  <div class="bg-white border border-gray-300 rounded-lg shadow overflow-hidden">
                    <div class="px-6 py-5 grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-x-6 gap-y-5">

                      <div>
                        <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Klasseart</p>
                        <p class="text-sm text-gray-800">{bev.klasseart ?? "—"}</p>
                      </div>

                      <div>
                        <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Klasse / trin</p>
                        <p class="text-sm text-gray-800">
                          {bev.klassebetegnelse ?? "—"}{#if bev.elevklassetrin}&nbsp;· trin {bev.elevklassetrin}{/if}
                        </p>
                      </div>

                      <div class="col-span-2 sm:col-span-1">
                        <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Adresse</p>
                        <p class="text-sm text-gray-800 truncate" title={bev.folkeregister_adresse}>{bev.folkeregister_adresse ?? "—"}</p>
                      </div>

                      <div>
                        <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Gåafstand</p>
                        <p class="text-sm text-gray-800">{bev.gaaafstand_km != null ? Number(bev.gaaafstand_km).toFixed(1) + ' km' : '—'}</p>
                      </div>

                      <div>
                        <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Hjemmel</p>
                        {#if isEditingFields}
                          {@const editSkoleType = bev.ungdomsuddannelse_id && !bev.matrikel_id ? 'ungdomsuddannelse' : 'folkeskole'}
                          <select class="w-full border border-gray-300 rounded pl-1.5 pr-6 py-0.5 text-xs focus:border-blue-400 focus:ring-0 bg-white"
                            value={editFields.hjemmel_id ?? ""}
                            on:change={(e) => editFields = { ...editFields, hjemmel_id: e.currentTarget.value ? Number(e.currentTarget.value) : null }}>
                            <option value="">—</option>
                            {#each filterHjemler(hjemler, bev.ansoegningstype, editSkoleType) as opt}
                              <option value={opt.id}>{opt.label}</option>
                            {/each}
                          </select>
                        {:else}
                          <p class="text-sm text-gray-800">{bev.hjemmel_tekst ?? "—"}</p>
                        {/if}
                      </div>

                      <div>
                        <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Afgørelsesbrev</p>
                        {#if isEditingFields}
                          {@const editSkoleType = bev.ungdomsuddannelse_id && !bev.matrikel_id ? 'ungdomsuddannelse' : 'folkeskole'}
                          <select class="w-full border border-gray-300 rounded pl-1.5 pr-6 py-0.5 text-xs focus:border-blue-400 focus:ring-0 bg-white"
                            value={editFields.afgoerelsesbrev_id ?? ""}
                            on:change={(e) => editFields = { ...editFields, afgoerelsesbrev_id: e.currentTarget.value ? Number(e.currentTarget.value) : null }}>
                            <option value="">—</option>
                            {#each filterAfgoerelsesbreve(afgoerelsesbreve, bev.ansoegningstype, editSkoleType) as opt}
                              <option value={opt.id}>{opt.label}</option>
                            {/each}
                          </select>
                        {:else}
                          <p class="text-sm text-gray-800">{bev.afgoerelsesbrev_tekst ?? "—"}</p>
                        {/if}
                      </div>

                      <div>
                        <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Afstandskriterie dato</p>
                        {#if isEditingFields}
                          <input type="date" max="9999-12-31" class="border border-gray-300 rounded px-1.5 py-0.5 text-xs focus:border-blue-400 focus:ring-0" bind:value={editFields.afstandskriterie_dato} />
                        {:else}
                          <p class="text-sm text-gray-800">{formatDanishDate(bev.afstandskriterie_dato) ?? "—"}</p>
                        {/if}
                      </div>

                      <div>
                        <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">PPR Sagsbehandler</p>
                        <p class="text-sm text-gray-800">{bev.ppr_sagsbehandler_tekst ?? "—"}</p>
                      </div>

                      <div>
                        <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Sagsbehandler</p>
                        <p class="text-sm text-gray-800">{bev.sagsbehandler_tekst ?? "—"}</p>
                      </div>

                      <div>
                        <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Revurderingsdato</p>
                        {#if isEditingFields}
                          <input type="date" max="9999-12-31" class="w-full border border-gray-300 rounded px-1.5 py-0.5 text-xs focus:border-blue-400 focus:ring-0" bind:value={editFields.revurderingsdato} />
                        {:else}
                          <p class="text-sm text-gray-800">{formatDanishDate(bev.revurderingsdato) ?? "—"}</p>
                        {/if}
                      </div>

                    </div>
                  </div>
                </div>
              </div>

              <div class="border-t border-gray-200 bg-blue-50">
                <div class="px-6 py-2.5 flex items-center gap-3 cursor-pointer select-none transition-colors hover:bg-blue-100 {commentsOpen ? 'border-b border-blue-200' : ''}"
                  role="button" tabindex="0"
                  on:click={() => toggleComments(bev.bevilling_id)}
                  on:keydown={(e) => e.key === 'Enter' && toggleComments(bev.bevilling_id)}>
                  <svg class="w-4 h-4 text-blue-400 shrink-0 transition-transform duration-150 {commentsOpen ? 'rotate-180' : ''}" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
                  </svg>
                  <div class="flex items-center gap-2">
                    <p class="text-[10px] font-bold uppercase tracking-wider text-blue-700">Kommentarer</p>
                    <svg class="w-3.5 h-3.5 text-blue-400 shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                    </svg>
                    <span class="text-blue-300 text-[10px]">|</span>
                    <a href="/sag/{bev.cpr_elev}#sagsforloeb" class="flex items-center gap-0.5 text-xs font-medium text-sky-600 hover:text-sky-800 transition-colors" on:click|stopPropagation>
                      Sagsforløb
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
                      </svg>
                    </a>
                  </div>
                </div>

                {#if commentsOpen}
                  <div class="px-6 py-3">
                    {#if loadingAktiviteterCpr.has(bev.cpr_elev)}
                      <p class="text-xs text-gray-400 italic">Henter kommentarer...</p>
                    {:else}
                      {@const comments = (aktiviteterByCpr[bev.cpr_elev] ?? []).filter((a: any) => a.aktivitetstype === 'Kommentar').slice(0, 3)}
                      {#if comments.length > 0}
                        <div class="space-y-2 mb-3">
                          {#each comments as akt}
                            <div class="border-l-4 border-l-blue-400 bg-white rounded-r px-2.5 py-2 shadow-sm">
                              <div class="flex items-center justify-between gap-2 mb-0.5">
                                <span class="text-[11px] font-medium text-gray-700">{akt.udfoert_af ?? "System"}</span>
                                <span class="text-[10px] text-gray-400 whitespace-nowrap">{new Date(akt.oprettet_tidspunkt).toLocaleString("da-DK")}</span>
                              </div>
                              {#if akt.kommentar}
                                <p class="text-xs text-gray-600 whitespace-pre-wrap line-clamp-3">{akt.kommentar}</p>
                              {/if}
                            </div>
                          {/each}
                        </div>
                      {/if}
                      <div class="mt-1 flex items-end gap-2">
                        <textarea class="flex-1 border border-gray-300 rounded px-3 py-2 text-sm resize-none focus:border-blue-400 focus:ring-0 bg-white"
                          rows="2" placeholder="Skriv kommentar..." bind:value={inlineComments[bev.bevilling_id]}></textarea>
                        <button type="button"
                          class="px-3 text-xs font-medium bg-blue-600 hover:bg-blue-700 text-white rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed shrink-0 self-stretch"
                          disabled={savingInlineCommentIds.has(bev.bevilling_id) || !(inlineComments[bev.bevilling_id]?.trim())}
                          on:click={() => saveInlineComment(bev.cpr_elev, bev.bevilling_id)}>
                          {savingInlineCommentIds.has(bev.bevilling_id) ? "Gemmer..." : "Gem kommentar"}
                        </button>
                      </div>
                    {/if}
                  </div>
                {/if}
              </div>

              <div class="border-t-2 border-gray-300 bg-gray-100">
                <div class="px-6 py-2.5 border-b border-gray-300 flex items-center justify-between gap-3 flex-wrap">
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500">Bevillinger</p>
                  <div class="flex items-center gap-2">
                    <button type="button"
                      disabled={!canEdit || !(bevillingerByCpr[bev.cpr_elev]?.length > 0)}
                      class="px-3 py-1.5 text-xs font-medium text-white rounded transition-colors whitespace-nowrap disabled:opacity-40 disabled:cursor-not-allowed"
                      style="background-color: #032A42;"
                      on:click={() => openCreateBevillingModal(bev.cpr_elev, 'kopi')}>
                      + Ny bevilling fra kopi
                    </button>
                    <button type="button"
                      disabled={!canEdit}
                      class="px-3 py-1.5 text-xs font-medium text-white rounded transition-colors whitespace-nowrap disabled:opacity-40 disabled:cursor-not-allowed"
                      style="background-color: #032A42;"
                      on:click={() => openCreateBevillingModal(bev.cpr_elev, 'tom')}>
                      + Ny bevilling fra tom
                    </button>
                    <button type="button"
                      disabled={!canEdit}
                      class="px-3 py-1.5 text-xs font-medium bg-purple-600 hover:bg-purple-700 text-white rounded transition-colors flex items-center gap-1 whitespace-nowrap disabled:opacity-40 disabled:cursor-not-allowed"
                      on:click={() => openCreateLetterModal(bev.cpr_elev)}>
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                      </svg>
                      + Opret brev
                    </button>
                  </div>
                </div>

                <div class="px-6 py-4">
                  {#if loadingBevillingerCpr.has(bev.cpr_elev)}
                    <p class="text-xs text-gray-400 italic">Henter bevillinger...</p>
                  {:else if bevillingerByCpr[bev.cpr_elev]}
                    <BevillingTable
                      bevillinger={bevillingerByCpr[bev.cpr_elev]}
                      lookupOptions={lookupOptions}
                      readonlyKoerselsraekker={true}
                      onSaveBevilling={async (id, updates) => {
                        const error = await handleSaveBevilling(id, updates);
                        if (!error) await loadBevillinger(bev.cpr_elev);
                        return error;
                      }}
                      onCreateKoerselsraekke={async (id, updates) => {
                        const error = await handleCreateKoerselsraekke(id, updates);
                        if (!error) await loadBevillinger(bev.cpr_elev);
                        return error;
                      }}
                      onSaveKoerselsraekke={async (id, updates) => {
                        const error = await handleSaveKoerselsraekke(id, updates);
                        if (!error) await loadBevillinger(bev.cpr_elev);
                        return error;
                      }}
                      onFinalizeKoerselsraekke={async (id) => {
                        const error = await handleFinalizeKoerselsraekke(id);
                        if (!error) await loadBevillinger(bev.cpr_elev);
                        return error;
                      }}
                    />
                  {:else}
                    <p class="text-xs text-gray-400 italic">Ingen bevillinger fundet.</p>
                  {/if}
                </div>
              </div>

            </div>
          {/if}

        </div>

      {/each}

    </div>

  {/if}

</section>