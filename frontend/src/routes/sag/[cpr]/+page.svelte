<script lang="ts">
  import { invalidateAll } from "$app/navigation";

  import { backendFetch } from "$lib/client/backendFetch";

  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import BevillingTable from "$lib/components/BevillingTable.svelte";
  import UpdateTemplateButton from "$lib/components/UpdateTemplateButton.svelte";
  import ParterTable from "$lib/components/ParterTable.svelte";
  import CreateBevillingModal from "$lib/components/CreateBevillingModal.svelte";
  import {
    getStatusBadgeClass,
    formatCpr,
  } from "$lib/tableColumnConfig";
  import { firstInvalidDate } from "$lib/dates";

  export let data;


  // -----------------------------
  // Page state
  // -----------------------------

  let letterType = "";
  let befordringsudvalgResultat = "";
  let tidligereAfgoerelseDato = "";
  let koerselStartdato = "";
  let datoForSenesteBevilling = "";

  let creatingLetter = false;
  let showCreateLetterModal = false;
  let selectedLetterBevillingId = "";
  let ophoersdato = "";

  $: selectedLetterBevilling = bevillinger.find(
    (bevilling: any) => String(bevilling.bevilling_id) === selectedLetterBevillingId
  );

  $: selectedLetterBevillingHasBefordringsudvalg =
    selectedLetterBevilling?.befordringsudvalg !== null &&
    selectedLetterBevilling?.befordringsudvalg !== undefined &&
    selectedLetterBevilling?.befordringsudvalg !== "";

  $: selectedLetterBevillingIsOphoert =
    selectedLetterBevilling?.status_tekst == "Ophørt";

  let { stamdata, parents, parter, bevillinger, lookupOptions, aktiviteter } = data;

  const initialHash = window.location.hash.slice(1);
  const validTabs = ["elev", "parter", "sagsforloeb"];
  let activeTab = validTabs.includes(initialHash) ? initialHash : "elev";

  function switchTab(tab: string) {
    activeTab = tab;
    history.replaceState(null, "", `${window.location.pathname}${window.location.search}#${tab}`);
  }

  $: initial = (stamdata?.adresseringsnavn ?? "?").charAt(0).toUpperCase();
  $: anyParentCannotKnowAddress = (parents ?? []).some((p: any) => p.maa_vide_barns_adresse === false);

  $: anyPprRevurderet = (bevillinger as any[]).some((b) => b.revurderet_af_ppr);
  $: anyBrRevurderet  = (bevillinger as any[]).some((b) => b.revurderet_af_br);
  $: anyRevurdering   = (bevillinger as any[]).some((b) => b.revurdering);

  // If any bevilling is Aktiv, always show Aktiv.
  // Otherwise show the status of the bevilling with the latest gyldig_til
  // across its koerselsraekker (bevillinger are already sorted that way).
  $: displayStatus = (() => {
    const active = (bevillinger as any[]).find((b) => b.status_tekst === "Aktiv");
    if (active) return active.status_tekst;
    const first = (bevillinger as any[])[0];
    return first?.status_tekst ?? stamdata?.status_tekst ?? null;
  })();

  // Derive age from the first 6 digits of the CPR (DDMMYY).
  // Century: if YY <= current two-digit year the person was born this century,
  // otherwise last century. Correct for all school-age children.
  function ageFromCpr(cpr: string): number | null {
    if (!cpr || cpr.length < 10) return null;
    const dd  = parseInt(cpr.slice(0, 2), 10);
    const mm  = parseInt(cpr.slice(2, 4), 10);
    const yy  = parseInt(cpr.slice(4, 6), 10);
    const now = new Date();
    const century   = yy <= (now.getFullYear() % 100) ? 2000 : 1900;
    const birthDate = new Date(century + yy, mm - 1, dd);
    let age = now.getFullYear() - birthDate.getFullYear();
    if (
      now.getMonth() < birthDate.getMonth() ||
      (now.getMonth() === birthDate.getMonth() && now.getDate() < birthDate.getDate())
    ) age--;
    return isNaN(age) ? null : age;
  }

  $: studentAge = ageFromCpr(stamdata?.cpr ?? "");

  let showCreateBevillingModal = false;
  let createBevillingMode: 'kopi' | 'tom' = 'kopi';


  $: if (data) {
    stamdata = data.stamdata;
    parents = data.parents;
    parter = data.parter;
    bevillinger = data.bevillinger;
    lookupOptions = data.lookupOptions;
    aktiviteter = data.aktiviteter;
  }


  // -----------------------------
  // Sagsaktivitet (Sagsforløb tab)
  // -----------------------------

  let nyKommentar = "";
  let savingKommentar = false;

  async function saveKommentar() {
    if (!nyKommentar.trim()) {
      return;
    }

    savingKommentar = true;

    try {
      const response = await backendFetch(`/aktivitet/${stamdata.cpr}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          aktivitetstype: "Kommentar",
          kommentar: nyKommentar,
          udfoert_af: null,
        })
      });

      if (!response.ok) {
        alert("Kunne ikke gemme kommentar");
        return;
      }

      nyKommentar = "";

      await invalidateAll();
    } finally {
      savingKommentar = false;
    }
  }

  function getDisplayLabel(type: string): string {
    if (type.startsWith("Status sat til ")) return "Status opdateret";
    const map: Record<string, string> = {
      "PPR Revurderet":         "PPR vurderet",
      "BR Revurderet":          "BR vurderet",
      "PPR revurderet fjernet": "PPR vurderet fjernet",
      "BR revurderet fjernet":  "BR vurderet fjernet",
    };
    return map[type] ?? type;
  }

  function getCategory(type: string): string {
    if (type.startsWith("Status sat til ")) return "Status opdateret";
    return getDisplayLabel(type);
  }

  function feedStyle(aktivitet: any): { border: string; icon: string; badgeBg: string; badgeText: string; cardBg: string } {
    const type = aktivitet.aktivitetstype ?? "";
    if (type === "PPR Revurderet" || type === "BR Revurderet") {
      return { border: "border-l-green-500", icon: "check",    badgeBg: "bg-green-100",  badgeText: "text-green-800",  cardBg: "bg-gray-50" };
    }
    if (type === "PPR revurderet fjernet" || type === "BR revurderet fjernet") {
      return { border: "border-l-gray-300",  icon: "xmark",    badgeBg: "bg-gray-100",   badgeText: "text-gray-600",   cardBg: "bg-gray-50" };
    }
    if (type === "Kommentar") {
      return { border: "border-l-blue-500",  icon: "chat",     badgeBg: "bg-blue-500",   badgeText: "text-white",      cardBg: "bg-blue-50" };
    }
    if (type === "Brev oprettet") {
      return { border: "border-l-gray-300",  icon: "envelope", badgeBg: "bg-gray-100",   badgeText: "text-gray-600",   cardBg: "bg-gray-50" };
    }
    if (type.startsWith("Status sat til ")) {
      return { border: "border-l-slate-400", icon: "status",   badgeBg: "bg-slate-100",  badgeText: "text-slate-700",  cardBg: "bg-gray-50" };
    }
    return   { border: "border-l-gray-300",  icon: "gear",     badgeBg: "bg-gray-100",   badgeText: "text-gray-600",   cardBg: "bg-gray-50" };
  }

  // Feed filters
  let filterTypes: string[] = [];
  let filterFra = "";
  let filterTil = "";
  let filterUdfoertAf: string[] = [];
  let openDropdown: "type" | "sender" | null = null;
  let sortAsc = false;

  const feedMinDate = new Date(new Date().getFullYear() - 10, new Date().getMonth(), new Date().getDate()).toISOString().slice(0, 10);
  const feedMaxDate = new Date(new Date().getFullYear() + 10, new Date().getMonth(), new Date().getDate()).toISOString().slice(0, 10);

  $: uniqueCategories = [...new Set<string>((aktiviteter ?? []).map((a: any) => getCategory(a.aktivitetstype ?? "")))].sort((a: string, b: string) => a.localeCompare(b, "da"));
  $: uniqueSenders = [...new Set<string>((aktiviteter ?? []).map((a: any) => a.udfoert_af ?? "").filter(Boolean))].sort((a: string, b: string) => a.localeCompare(b, "da"));
  $: feedHasActiveFilters = filterTypes.length > 0 || filterFra !== "" || filterTil !== "" || filterUdfoertAf.length > 0;

  $: filteredAktiviteter = (() => {
    const list = (aktiviteter ?? []).filter((a: any) => {
      if (filterTypes.length > 0 && !filterTypes.includes(getCategory(a.aktivitetstype ?? ""))) return false;
      if (filterFra) {
        const ts = new Date(a.oprettet_tidspunkt);
        const fra = new Date(filterFra);
        if (ts < fra) return false;
      }
      if (filterTil) {
        const ts = new Date(a.oprettet_tidspunkt);
        const til = new Date(filterTil);
        til.setHours(23, 59, 59, 999);
        if (ts > til) return false;
      }
      if (filterUdfoertAf.length > 0 && !filterUdfoertAf.includes(a.udfoert_af ?? "")) return false;
      return true;
    });
    return sortAsc ? [...list].reverse() : list;
  })();

  function clearFeedFilters() {
    filterTypes = [];
    filterFra = "";
    filterTil = "";
    filterUdfoertAf = [];
  }




  // -----------------------------
  // Table columns
  // -----------------------------

  const parentColumns: DataTableColumn[] = [
    {
      key: "adresseringsnavn",
      label: "Navn"
    },
    {
      key: "cpr_foraelder",
      label: "Cpr-nummer",
      render: (row) => formatCpr(row.cpr_foraelder)
    },
    {
      key: "adresse_tekst",
      label: "Folkeregisteradresse"
    },
    {
      key: "relation",
      label: "Relation"
    },
    {
      key: "navne_adresse_beskyttelse",
      label: "Navne- og adressebeskyttelse",
      render: (row) => row.navne_adresse_beskyttelse ? "Ja" : "Nej"
    },
    {
      key: "maa_vide_barns_adresse",
      label: "Må vide barnets adresse",
      filterable: false,
      render: (row: any) => {
        const val: boolean = row.maa_vide_barns_adresse;
        return `<span class="text-[11px] font-semibold px-2.5 py-0.5 rounded-full border whitespace-nowrap ${val ? 'bg-green-100 border-green-300 text-green-700' : 'bg-gray-100 border-gray-300 text-gray-500'}">${val ? 'Ja' : 'Nej'}</span>`;
      }
    }
  ];




  // -----------------------------
  // Small helpers
  // -----------------------------

  function getStatusReason(result: any) {
    return (
      result?.status?.status_reason ??
      result?.status_reason ??
      null
    );
  }


  function showStatusReasonIfAny(result: any) {
    const statusReason = getStatusReason(result);

    if (!statusReason) {
      return;
    }

    alert(statusReason);
  }

  function emptyToNull(value: any) {
    if (value === "") {
      return null;
    }

    return value;
  }


  function numberOrNull(value: any) {
    if (value === "") {
      return null;
    }

    return Number(value);
  }


  function resetCreateLetterForm() {
    selectedLetterBevillingId = "";
    letterType = "";
    befordringsudvalgResultat = "";
    tidligereAfgoerelseDato = "";
    koerselStartdato = "";
    datoForSenesteBevilling = "";
  }


  // -----------------------------
  // Bevilling handlers
  // -----------------------------

  async function handleCreateLetter() {
    if (!selectedLetterBevillingId) {
      alert("Vælg en bevilling");
      return;
    }

    if (!letterType) {
      alert("Vælg hvad brevet er i forbindelse med");
      return;
    }

    if (selectedLetterBevillingHasBefordringsudvalg && !befordringsudvalgResultat) {
      alert("Vælg resultat af befordringsudvalgsmøde");
      return;
    }

    if (selectedLetterBevillingHasBefordringsudvalg && !tidligereAfgoerelseDato) {
      alert("Angiv dato for tidligere afgørelse");
      return;
    }

    if (selectedLetterBevillingIsOphoert && !ophoersdato) {
      alert("Vælg ophørsdato");
      return;
    }

    const invalidDate = firstInvalidDate(
      {
        koersel_startdato: koerselStartdato,
        dato_for_seneste_bevilling: datoForSenesteBevilling,
        dato_for_tidligere_afgoerelse: tidligereAfgoerelseDato,
        ophoersdato,
      },
      [
        "koersel_startdato",
        "dato_for_seneste_bevilling",
        "dato_for_tidligere_afgoerelse",
        "ophoersdato",
      ],
    );

    if (invalidDate) {
      alert("Angiv en gyldig dato (åååå-mm-dd).");
      return;
    }

    creatingLetter = true;

    const payload = {
      brev_i_forbindelse_med: letterType,

      koersel_startdato: koerselStartdato || null,

      dato_for_seneste_bevilling: datoForSenesteBevilling || null,

      befordringsudvalg_resultat: selectedLetterBevillingHasBefordringsudvalg
        ? befordringsudvalgResultat
        : null,

      dato_for_tidligere_afgoerelse: selectedLetterBevillingHasBefordringsudvalg
        ? tidligereAfgoerelseDato
        : null,

      ophoersdato: selectedLetterBevillingIsOphoert
        ? ophoersdato
        : null
    };

    try {
      const response = await backendFetch(
        `/bevilling/create_letter/${stamdata.cpr}/${selectedLetterBevillingId}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json"
          },
          body: JSON.stringify(payload)
        }
      );

      if (!response.ok) {
        let message = "Kunne ikke oprette brev";

        try {
          const errorData = await response.json();

          message =
            errorData?.detail?.message ??
            errorData?.detail ??
            message;
        } catch {
          // Keep fallback message
        }

        alert(message);
        return;
      }

      const result = await response.json();

      alert(`Brev er sat i kø. Reference: ${result.reference}`);

      await backendFetch(`/aktivitet/${stamdata.cpr}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          aktivitetstype: "Brev oprettet",
          kommentar: `Bevilling ID: ${selectedLetterBevillingId}`,
          relateret_bevilling_id: Number(selectedLetterBevillingId),
          udfoert_af: null,
        })
      });

      showCreateLetterModal = false;
      resetCreateLetterForm();
      await invalidateAll();

    } finally {
      creatingLetter = false;
    }
  }


  async function handleSaveBevilling(bevillingId: number, updates: any): Promise<string | null> {
    const { hjaelpemiddel_ids, ...bevillingUpdates } = updates;

    const bevillingResponse = await backendFetch(`/bevilling/${bevillingId}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(bevillingUpdates)
    });

    if (!bevillingResponse.ok) {
      let message = "Kunne ikke gemme bevilling";

      try {
        const errorData = await bevillingResponse.json();

        message =
          errorData?.detail?.message ??
          errorData?.detail ??
          message;
      } catch {
        // Keep fallback message if backend response is not JSON
      }

      return message;
    }

    const bevillingResult = await bevillingResponse.json();

    const hjaelpemidlerResponse = await backendFetch(
      `/bevilling/${bevillingId}/hjaelpemidler`,
      {
        method: "PUT",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          hjaelpemiddel_ids: hjaelpemiddel_ids ?? []
        })
      }
    );

    if (!hjaelpemidlerResponse.ok) {
      return "Bevilling blev gemt, men hjælpemidler kunne ikke gemmes";
    }

    showStatusReasonIfAny(bevillingResult);

    await invalidateAll();

    switchTab("elev");

    return null;
  }


  // -----------------------------
  // Kørselsrække handlers
  // -----------------------------

  async function handleCreateKoerselsraekke(bevillingId: number, updates: any): Promise<string | null> {
    const {
      tillaeg_ids,
      dag_ids,
      ...koerselsraekkeData
    } = updates;

    const response = await backendFetch(
      `/bevilling/create_koerselsraekke/${bevillingId}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          ...koerselsraekkeData,
          tillaeg_ids: tillaeg_ids ?? [],
          dag_ids: dag_ids ?? []
        })
      }
    );

    if (!response.ok) {
      let message = "Kunne ikke oprette kørselsrække";
      try {
        const errorData = await response.json();
        message = errorData?.detail?.message ?? errorData?.detail ?? message;
      } catch { /* keep fallback */ }
      return message;
    }

    const result = await response.json();

    showStatusReasonIfAny(result);

    await invalidateAll();

    switchTab("elev");

    return null;
  }


  async function handleFinalizeKoerselsraekke(koerselId: number): Promise<string | null> {
    const response = await backendFetch(`/bevilling/koerselsraekke/${koerselId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ final: true })
    });

    if (!response.ok) {
      let message = "Kunne ikke afslutte kørselsrækken";
      try {
        const err = await response.json();
        message = err?.detail ?? message;
      } catch { /* keep fallback */ }
      return message;
    }

    await invalidateAll();
    return null;
  }


  async function handleSaveKoerselsraekke(koerselId: number, updates: any): Promise<string | null> {
    const {
      tillaeg_ids,
      dag_ids,
      ...koerselsraekkeUpdates
    } = updates;

    const response = await backendFetch(`/bevilling/koerselsraekke/${koerselId}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(koerselsraekkeUpdates)
    });

    if (!response.ok) {
      let message = "Kunne ikke gemme kørselsrække";

      try {
        const errorData = await response.json();

        message =
          errorData?.detail?.message ??
          errorData?.detail ??
          message;
      } catch {
        // Keep fallback message
      }

      return message;
    }

    const koerselsraekkeResult = await response.json();

    const tillaegResponse = await backendFetch(
      `/bevilling/koerselsraekke/${koerselId}/tillaeg`,
      {
        method: "PUT",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          tillaeg_ids: tillaeg_ids ?? []
        })
      }
    );

    if (!tillaegResponse.ok) {
      return "Kørselsrække blev gemt, men kørselstype tillæg kunne ikke gemmes";
    }

    const dageResponse = await backendFetch(
      `/bevilling/koerselsraekke/${koerselId}/dage`,
      {
        method: "PUT",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          dag_ids: dag_ids ?? []
        })
      }
    );

    if (!dageResponse.ok) {
      return "Kørselsrække blev gemt, men dage kunne ikke gemmes";
    }

    showStatusReasonIfAny(koerselsraekkeResult);

    await invalidateAll();

    switchTab("elev");

    return null;
  }


  async function handleDeleteBevilling(bevillingId: number): Promise<string | null> {
    const response = await backendFetch(`/bevilling/${bevillingId}`, {
      method: "DELETE"
    });

    if (!response.ok) {
      let message = "Kunne ikke slette bevilling";
      try {
        const errorData = await response.json();
        message = errorData?.detail?.message ?? errorData?.detail ?? message;
      } catch { /* keep fallback */ }
      return message;
    }

    await invalidateAll();
    return null;
  }


  async function handleDeleteKoerselsraekke(koerselId: number): Promise<string | null> {
    const response = await backendFetch(`/bevilling/koerselsraekke/${koerselId}`, {
      method: "DELETE"
    });

    if (!response.ok) {
      let message = "Kunne ikke slette kørselsrække";
      try {
        const errorData = await response.json();
        message = errorData?.detail?.message ?? errorData?.detail ?? message;
      } catch { /* keep fallback */ }
      return message;
    }

    await invalidateAll();
    return null;
  }
</script>

<svelte:window
  on:keydown={(e) => {
    if (e.key !== 'Escape') return;
    if (openDropdown) { openDropdown = null; return; }
    if (showCreateBevillingModal) { showCreateBevillingModal = false; }
    if (showCreateLetterModal) { showCreateLetterModal = false; resetCreateLetterForm(); }
  }}
  on:click={(e) => {
    if (openDropdown && !(e.target as Element)?.closest?.('.feed-filter-dropdown')) {
      openDropdown = null;
    }
  }}
/>

<section>

  <!-- Protection warning -->
  {#if stamdata?.navne_adresse_beskyttelse}
    <div class="mb-4 rounded-lg border-l-4 border-red-500 bg-red-50 p-4 text-red-900">
      <p class="mt-0.5 text-xs">Vær opmærksom på at barnet har navne- og/eller adressebeskyttelse.</p>
    </div>
  {/if}

  <!-- Parent address restriction warning -->
  {#if anyParentCannotKnowAddress}
    <div class="mb-4 rounded-lg border-l-4 border-amber-500 bg-amber-50 p-4 text-amber-900">
      <p class="mt-0.5 text-xs">En eller flere forældre/værger må <strong>ikke</strong> oplyses om barnets adresse.</p>
    </div>
  {/if}


  <!-- Person header card -->
  <div class="bg-white border border-gray-300 rounded-lg shadow px-4 md:px-6 py-5 mb-4 flex flex-col md:flex-row md:items-center gap-4 md:gap-0 justify-between">

    <div class="flex items-center gap-4">
      <!-- Avatar -->
      <div
        class="w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-xl shrink-0"
        style="background-color: #4a6e8a;"
      >
        {initial}
      </div>

      <div>
        <div class="flex items-center gap-2.5">
          <h1 class="text-xl font-bold text-gray-900">{stamdata?.adresseringsnavn ?? ""}</h1>
          {#if displayStatus}
            <span class="inline-block px-2 py-0.5 rounded text-xs font-medium {getStatusBadgeClass(displayStatus)}">
              {displayStatus}
            </span>
          {/if}
          {#if anyRevurdering}
            <span class="ml-1.5 inline-block px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-700">
              Revurdering
            </span>
          {/if}
        </div>
        <p class="text-sm text-gray-500 mt-0.5">
          <span class="font-mono">{formatCpr(stamdata?.cpr)}</span>
          {#if studentAge !== null}
            <span class="mx-1.5 text-gray-300">·</span>{studentAge} år
          {/if}
        </p>
      </div>
    </div>

    <!-- Tab buttons -->
    <div class="flex gap-2 shrink-0">
      <button
        type="button"
        class="px-4 py-2 text-sm font-medium rounded border transition-colors"
        style={activeTab === "elev"
          ? "background-color: #032A42; color: #ffffff; border-color: #032A42;"
          : "background-color: #ffffff; color: #374151; border-color: #d1d5db;"}
        on:click={() => switchTab("elev")}
      >
        Elev
      </button>

      <button
        type="button"
        class="px-4 py-2 text-sm font-medium rounded border transition-colors"
        style={activeTab === "parter"
          ? "background-color: #032A42; color: #ffffff; border-color: #032A42;"
          : "background-color: #ffffff; color: #374151; border-color: #d1d5db;"}
        on:click={() => switchTab("parter")}
      >
        Parter
      </button>

      <button
        type="button"
        class="px-4 py-2 text-sm font-medium rounded border transition-colors"
        style={activeTab === "sagsforloeb"
          ? "background-color: #032A42; color: #ffffff; border-color: #032A42;"
          : "background-color: #ffffff; color: #374151; border-color: #d1d5db;"}
        on:click={() => switchTab("sagsforloeb")}
      >
        Sagsforløb
      </button>
    </div>

  </div>


  <!-- ELEV TAB -->
  {#if activeTab === "elev"}

    <!-- Elevoplysninger card -->
    <div class="bg-white border border-gray-300 rounded-lg shadow px-4 md:px-6 py-5 mb-4">

      <div class="mb-6">
        <h2 class="font-semibold text-gray-800">Elevoplysninger</h2>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-5 gap-x-6 gap-y-5">

        <!-- SAGS-ID -->
        <div>
          <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Sags-ID</p>
          <span class="inline-block px-2 py-0.5 rounded bg-slate-100 text-slate-700 text-xs font-mono font-medium">
            {stamdata?.esdh_noegle ?? "—"}
          </span>
        </div>

        <!-- FOLKEREGISTERADRESSE -->
        <div>
          <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Folkeregisteradresse</p>
          <p class="text-sm text-gray-800">{stamdata?.adresse_tekst ?? "—"}</p>
        </div>

        <!-- SKOLEKODE -->
        <div>
          <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Skolekode</p>
          <p class="text-sm text-gray-800">{stamdata?.skolekode || "—"}</p>
        </div>

        <!-- SKOLE -->
        <div>
          <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Skole</p>
          <p class="text-sm text-gray-800">{stamdata?.skole_navn ?? stamdata?.skolematrikel ?? "—"}</p>
          {#if stamdata?.skole_type}
            <span class="inline-block mt-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-slate-100 text-slate-600">
              {stamdata.skole_type}
            </span>
          {/if}
        </div>

        <!-- SKOLEAFSTAND -->
        <div>
          <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Skoleafstand (km)</p>
          <p class="text-sm text-gray-800">{stamdata?.skoleafstand ?? "—"}</p>
        </div>

        <!-- KLASSEART -->
        <div>
          <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Klasseart</p>
          <p class="text-sm text-gray-800">{stamdata?.klasseart ?? "—"}</p>
        </div>

        <!-- KLASSEBETEGNELSE -->
        <div>
          <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Klassebetegnelse</p>
          <p class="text-sm text-gray-800">{stamdata?.klassebetegnelse ?? "—"}</p>
        </div>

        <!-- PERSONLIGT KLASSETRIN -->
        <div>
          <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Personligt klassetrin</p>
          <p class="text-sm text-gray-800">{stamdata?.elevklassetrin ?? "—"}</p>
        </div>

        <!-- SFO -->
        <div>
          <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">SFO</p>
          <p class="text-sm text-gray-800">{stamdata?.sfo ?? "—"}</p>
        </div>

        <!-- BOPÆLSDISTRIKT -->
        <div>
          <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Bopælsdistrikt</p>
          <p class="text-sm text-gray-800">{stamdata?.bopaelsdistrikt ?? "—"}</p>
        </div>

      </div>
    </div>


  {/if}


  <!-- PARTER TAB -->
  {#if activeTab === "parter"}

    <!-- Oplysninger om forældre -->
    <div class="bg-white border border-gray-300 rounded-lg shadow px-4 md:px-6 py-5 mb-4">
      <div class="flex items-center gap-2 mb-4">
        <div class="w-2.5 h-2.5 rounded-full bg-green-500 flex-shrink-0"></div>
        <h2 class="font-semibold text-gray-800">Oplysninger om forældre</h2>
      </div>
      <DataTable
          data={parents}
          columns={parentColumns}
          filterable={false}
        />
    </div>

    <!-- Øvrige parter (ikke-forældremyndige, som må orienteres) -->
    <div class="bg-white border border-gray-300 rounded-lg shadow px-4 md:px-6 py-5 mb-4">
      <div class="flex items-center gap-2 mb-4">
        <div class="w-2.5 h-2.5 rounded-full bg-slate-400 flex-shrink-0"></div>
        <h2 class="font-semibold text-gray-800">Øvrige parter</h2>
      </div>
      <ParterTable cpr={stamdata.cpr} parter={parter} />
    </div>

  {/if}


  <!-- BEVILLINGER (shown in Elev tab) -->
  {#if activeTab === "elev"}

    <!-- Bevillinger section header -->
    <div class="flex items-center justify-between mb-4 mt-2">
      <div class="flex items-center gap-3">
        <h2 class="text-lg font-semibold text-gray-900">Bevillinger</h2>
        <span
          class="inline-flex items-center justify-center min-w-[1.5rem] h-5 px-1.5 rounded-full text-xs font-bold"
          style="background-color: #dbeafe; color: #1d4ed8;"
        >
          {bevillinger?.length ?? 0}
        </span>
      </div>

      <div class="flex gap-2">
      <button
        type="button"
        class="px-4 py-2 text-sm font-medium text-white rounded transition-colors"
        style="background-color: #032A42;"
        on:click={() => { createBevillingMode = 'kopi'; showCreateBevillingModal = true; }}
      >
        + Ny bevilling fra kopi
      </button>

      <button
        type="button"
        class="px-4 py-2 text-sm font-medium text-white rounded transition-colors"
        style="background-color: #032A42;"
        on:click={() => { createBevillingMode = 'tom'; showCreateBevillingModal = true; }}
      >
        + Ny bevilling fra tom
      </button>

      <button
        type="button"
        class="px-4 py-2 text-sm font-medium bg-purple-600 hover:bg-purple-700 text-white rounded transition-colors"
        on:click={() => showCreateLetterModal = true}
      >
        + Opret brev
      </button>

      <UpdateTemplateButton class="px-4 py-2 text-sm" />
      </div>
    </div>


    <!-- Create bevilling modal -->
    {#if showCreateBevillingModal}
      <CreateBevillingModal
        cpr={stamdata.cpr}
        mode={createBevillingMode}
        existingBevillinger={bevillinger ?? []}
        {lookupOptions}
        on:created={async () => { showCreateBevillingModal = false; await invalidateAll(); }}
        on:cancel={() => { showCreateBevillingModal = false; }}
      />
    {/if}


    <!-- Create letter modal -->
    {#if showCreateLetterModal}
      <!-- Backdrop is non-dismissing: close only via Escape or the Annullér button. -->
      <div
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        role="presentation"
      >
        <div
          class="w-[560px] bg-white rounded-lg shadow-2xl"
          role="dialog"
          aria-modal="true"
          aria-label="Opret brev"
          tabindex="-1"
        >

          <div class="px-8 py-5 border-b border-gray-200 rounded-t-lg" style="background-color: #6d28d9;">
            <h2 class="text-lg font-bold text-white">Opret brev</h2>
            <p class="mt-0.5 text-sm" style="color: rgba(255,255,255,0.7);">Vælg bevilling og brevtype</p>
          </div>

          <div class="p-8 space-y-5">
            <label class="block text-sm font-medium text-gray-700">
              Vælg bevilling
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={selectedLetterBevillingId}>
                <option value="">Vælg bevilling</option>
                {#each bevillinger ?? [] as bevilling}
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

            <label class="block text-sm font-medium text-gray-700">
              Startdato for kørsel
              <input type="date" max="9999-12-31" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={koerselStartdato} />
            </label>

            <label class="block text-sm font-medium text-gray-700">
              Dato for seneste bevilling
              <input type="date" max="9999-12-31" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={datoForSenesteBevilling} />
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
              <label class="block text-sm font-medium text-gray-700">
                Dato for tidligere afgørelse
                <input type="date" max="9999-12-31" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={tidligereAfgoerelseDato} />
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
            <button
              type="button"
              class="px-5 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-white transition-colors"
              on:click={() => { showCreateLetterModal = false; resetCreateLetterForm(); }}
            >
              Annullér
            </button>
            <button
              type="button"
              class="px-5 py-2 text-sm font-medium bg-purple-600 hover:bg-purple-700 text-white rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              disabled={creatingLetter}
              on:click={handleCreateLetter}
            >
              {creatingLetter ? "Opretter..." : "Opret brev"}
            </button>
          </div>

        </div>
      </div>
    {/if}


    <BevillingTable
      bevillinger={bevillinger}
      lookupOptions={lookupOptions}
      onSaveBevilling={handleSaveBevilling}
      onSaveKoerselsraekke={handleSaveKoerselsraekke}
      onCreateKoerselsraekke={handleCreateKoerselsraekke}
      onFinalizeKoerselsraekke={handleFinalizeKoerselsraekke}
      onDeleteBevilling={handleDeleteBevilling}
      onDeleteKoerselsraekke={handleDeleteKoerselsraekke}
    />

    <div class="mt-4">
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

  {/if}


  <!-- SAGSFORLØB TAB -->
  {#if activeTab === "sagsforloeb"}

    <!-- PPR / BR revurderet status banner -->
    {#if anyPprRevurderet || anyBrRevurderet}
      <div class="bg-green-50 border border-green-300 rounded-lg px-4 py-3 mb-4 flex items-center gap-3 flex-wrap">
        <svg class="w-4 h-4 text-green-600 shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="text-sm font-medium text-green-800">Revurderet:</p>
        {#if anyPprRevurderet}
          <span class="px-2 py-0.5 rounded-full text-xs font-semibold bg-green-100 text-green-800 border border-green-300">✓ PPR revurderet</span>
        {/if}
        {#if anyBrRevurderet}
          <span class="px-2 py-0.5 rounded-full text-xs font-semibold bg-green-100 text-green-800 border border-green-300">✓ BR revurderet</span>
        {/if}
      </div>
    {/if}

    <!-- Ny kommentar -->
    <div class="bg-white border border-gray-300 rounded-lg shadow px-4 md:px-6 py-5 mb-4">
      <h2 class="font-semibold text-gray-800 mb-3">Tilføj kommentar</h2>

      <textarea
        bind:value={nyKommentar}
        rows="3"
        class="w-full border border-gray-300 rounded px-3 py-2 text-sm focus:border-blue-400 focus:ring-0 resize-none"
        placeholder="Skriv kommentar..."
      ></textarea>

      <div class="mt-2">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium text-white rounded transition-colors disabled:opacity-50 bg-blue-500"
          on:click={saveKommentar}
          disabled={savingKommentar || !nyKommentar.trim()}
        >
          {savingKommentar ? "Gemmer..." : "Gem kommentar"}
        </button>
      </div>
    </div>

    <!-- Timeline feed -->
    <div class="bg-white border border-gray-300 rounded-lg shadow px-4 md:px-6 py-5 mb-4">

      <!-- Header -->
      <div class="flex items-center gap-3 mb-4">
        <h2 class="font-semibold text-gray-800">Sagsforløb</h2>
        <span class="inline-flex items-center justify-center min-w-[1.5rem] h-5 px-1.5 rounded-full text-xs font-bold bg-blue-100 text-blue-800">
          {filteredAktiviteter.length}{feedHasActiveFilters && (aktiviteter?.length ?? 0) > 0 ? `/${aktiviteter.length}` : ""}
        </span>
        <!-- Sort toggle -->
        <button
          type="button"
          class="ml-auto flex items-center gap-1 text-xs text-gray-500 hover:text-gray-700"
          on:click={() => sortAsc = !sortAsc}
        >
          {#if sortAsc}
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3 4h13M3 8h9m-9 4h6m4 0
l4-4m0 0l4 4m-4-4v12"/></svg>
            Ældste først
          {:else}
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3 4h13M3 8h9m-9 4h9m5-4
v12m0 0l-4-4m4 4l4-4"/></svg>
            Nyeste først
          {/if}
        </button>
      </div>

      <!-- Filters -->
      <div class="flex flex-wrap gap-2 mb-3">

        <!-- Aktivitetstype dropdown -->
        <div class="relative feed-filter-dropdown">
          <button
            type="button"
            class="relative min-w-[160px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 bg-white hover:border-gray-400 text-left"
            on:click|stopPropagation={() => openDropdown = openDropdown === "type" ? null : "type"}
          >
            {filterTypes.length > 0 ? filterTypes.join(", ") : "Alle typer"}
            <svg class="absolute right-1.5 top-1/2 -translate-y-1/2 w-3 h-3 text-gray-400 pointer-events-none" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path
stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/></svg>
          </button>
          {#if openDropdown === "type"}
            <div class="absolute top-full left-0 mt-1 z-50 bg-white border border-gray-200 rounded shadow-lg min-w-[170px] py-1">
              {#each uniqueCategories as cat}
                <label class="flex items-center gap-2 px-3 py-1.5 hover:bg-gray-50 cursor-pointer text-xs text-gray-700">
                  <input
                    type="checkbox"
                    checked={filterTypes.includes(cat)}
                    on:change={() => {
                      filterTypes = filterTypes.includes(cat)
                        ? filterTypes.filter(t => t !== cat)
                        : [...filterTypes, cat];
                    }}
                    class="rounded border-gray-300 text-blue-500"
                  />
                  {cat}
                </label>
              {/each}
            </div>
          {/if}
        </div>


        <!-- Udført af dropdown -->
        <div class="relative feed-filter-dropdown">
          <button
            type="button"
            class="relative min-w-[160px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 bg-white hover:border-gray-400 text-left"
            on:click|stopPropagation={() => openDropdown = openDropdown === "sender" ? null : "sender"}
          >
            {filterUdfoertAf.length > 0 ? filterUdfoertAf.join(", ") : "Alle afsendere"}
            <svg class="absolute right-1.5 top-1/2 -translate-y-1/2 w-3 h-3 text-gray-400 pointer-events-none" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path
stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/></svg>
          </button>
          {#if openDropdown === "sender"}
            <div class="absolute top-full left-0 mt-1 z-50 bg-white border border-gray-200 rounded shadow-lg min-w-[170px] py-1">
              {#each uniqueSenders as sender}
                <label class="flex items-center gap-2 px-3 py-1.5 hover:bg-gray-50 cursor-pointer text-xs text-gray-700">
                  <input
                    type="checkbox"
                    checked={filterUdfoertAf.includes(sender)}
                    on:change={() => {
                      filterUdfoertAf = filterUdfoertAf.includes(sender)
                        ? filterUdfoertAf.filter(s => s !== sender)
                        : [...filterUdfoertAf, sender];
                    }}
                    class="rounded border-gray-300 text-blue-500"
                  />
                  {sender}
                </label>
              {/each}
            </div>
          {/if}
        </div>

        <!-- Periode -->
        <div class="flex items-center gap-1.5">
          <span class="text-xs text-gray-500">Dato fra</span>
          <input
            type="date"
            bind:value={filterFra}
            min={feedMinDate}
            max={feedMaxDate}
            class="border border-gray-300 rounded px-2 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white"
          />
          <span class="text-xs text-gray-500">Til</span>
          <input
            type="date"
            bind:value={filterTil}
            min={feedMinDate}
            max={feedMaxDate}
            class="border border-gray-300 rounded px-2 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white"
          />
        </div>

      </div>

      <!-- Active filter bar -->
      {#if feedHasActiveFilters}
        <div class="flex items-center justify-between px-3 py-1.5 mb-3 rounded-md bg-sky-50 border border-sky-100 text-xs text-sky-700">
          <span>Aktive filtre · viser {filteredAktiviteter.length} af {aktiviteter?.length ?? 0}</span>
          <button type="button" on:click={clearFeedFilters} class="font-medium hover:underline">Ryd filtre</button>
        </div>
      {/if}

      {#if filteredAktiviteter.length === 0}
        <p class="text-sm text-gray-400 italic">
          {feedHasActiveFilters ? "Ingen aktiviteter matcher de valgte filtre." : "Ingen aktiviteter registreret endnu."}
        </p>
      {:else}
        <div class="space-y-3">
          {#each filteredAktiviteter as aktivitet}
            {@const style = feedStyle(aktivitet)}
            <div class="border-l-4 {style.border} {style.cardBg} border border-gray-100 rounded-r-lg px-4 py-3">
              <div class="flex items-start justify-between gap-2">

                <!-- Left: icon + badge + bevilling pill -->
                <div class="flex items-center gap-2 flex-wrap">
                  {#if style.icon === "check"}
                    <svg class="w-3.5 h-3.5 text-green-600 shrink-0" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                  {:else if style.icon === "xmark"}
                    <svg class="w-3.5 h-3.5 text-gray-500 shrink-0" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  {:else if style.icon === "chat"}
                    <svg class="w-3.5 h-3.5 text-blue-600 shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                    </svg>
                  {:else if style.icon === "envelope"}
                    <svg class="w-3.5 h-3.5 text-gray-500 shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                    </svg>
                  {:else if style.icon === "status"}
                    <svg class="w-3.5 h-3.5 text-slate-500 shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M7 16V4m0 0L3 8m4-4l4 4M17 8v12m0 0l4-4m-4 4l-4-4" />
                    </svg>
                  {:else}
                    <svg class="w-3.5 h-3.5 text-gray-500 shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                  {/if}
                  <span class="px-2 py-0.5 rounded text-xs font-medium {style.badgeBg} {style.badgeText}">
                    {getDisplayLabel(aktivitet.aktivitetstype ?? "")}
                  </span>
                  {#if aktivitet.relateret_bevilling_id}
                    <span class="text-xs text-gray-500 bg-gray-100 px-1.5 py-0.5 rounded">Bevilling #{aktivitet.relateret_bevilling_id}</span>
                  {/if}
                </div>

                <!-- Right: timestamp + sender -->
                <div class="flex flex-col items-end shrink-0 text-right gap-0.5">
                  <span class="text-xs text-gray-500 whitespace-nowrap">
                    {new Date(aktivitet.oprettet_tidspunkt).toLocaleString("da-DK")}
                  </span>
                  {#if aktivitet.udfoert_af}
                    {#if aktivitet.udfoert_af === "System"}
                      <span class="text-xs italic text-gray-500">System</span>
                    {:else}
                      <span class="text-xs font-medium text-gray-700">{aktivitet.udfoert_af}</span>
                    {/if}
                  {/if}
                </div>

              </div>
              {#if aktivitet.kommentar}
                <p
                  class="mt-2 text-sm whitespace-pre-wrap"
                  class:text-blue-900={aktivitet.aktivitetstype === 'Kommentar'}
                  class:text-gray-800={aktivitet.aktivitetstype !== 'Kommentar'}
                >{aktivitet.kommentar}</p>
              {/if}
            </div>
          {/each}
        </div>
      {/if}
    </div>

  {/if}

</section>