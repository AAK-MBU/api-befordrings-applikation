<script lang="ts">
  import { invalidateAll } from "$app/navigation";

  import { backendFetch } from "$lib/client/backendFetch";

  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import BevillingTable from "$lib/components/BevillingTable.svelte";
  import AddresseSearch from "$lib/components/AddresseSearch.svelte";
  import {
    getStatusBadgeClass,
  } from "$lib/tableColumnConfig";

  export let data;


  // -----------------------------
  // Page state
  // -----------------------------

  let letterType = "";
  let befordringsudvalgResultat = "";
  let tidligereAfgoerelseDato = "";
  let transporttidIBus: number | "" = "";
  let skiftMedBus: number | "" = "";

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

  $: selectedLetterBevillingHasSkolerejsekort =
    (selectedLetterBevilling?.koerselsraekker ?? []).some(
      (k: any) => k.befordringstype_tekst === "Skolerejsekort"
    );

  let { stamdata, parents, bevillinger, lookupOptions } = data;

  // sagsaktivitet/sagsforløb temporarily disabled — not fetched in +page.server.ts.
  // Stub kept so the (dead) Sagsforløb tab markup below still compiles.
  let aktiviteter: any[] = [];

  const initialHash = window.location.hash.slice(1);
  let activeTab = (initialHash === "sagsforloeb" || initialHash === "stamdata")
    ? initialHash
    : "stamdata";

  function switchTab(tab: string) {
    activeTab = tab;
    history.replaceState(null, "", `${window.location.pathname}${window.location.search}#${tab}`);
  }

  $: initial = (stamdata?.adresseringsnavn ?? "?").charAt(0).toUpperCase();
  $: anyParentCannotKnowAddress = (parents ?? []).some((p: any) => p.maa_vide_barns_adresse === false);

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


  $: if (data) {
    stamdata = data.stamdata;
    parents = data.parents;
    bevillinger = data.bevillinger;
    lookupOptions = data.lookupOptions;
  }


  // -----------------------------
  // Sagsaktivitet (Sagsforløb tab) — temporarily disabled.
  // Stubs kept so the (dead) Sagsforløb tab markup below still compiles.
  // -----------------------------

  let nyKommentar = "";
  let savingKommentar = false;

  // async function saveKommentar() {
  //   if (!nyKommentar.trim()) {
  //     return;
  //   }

  //   savingKommentar = true;

  //   try {
  //     const response = await backendFetch(`/aktivitet/${stamdata.cpr}`, {
  //       method: "POST",
  //       headers: {
  //         "Content-Type": "application/json"
  //       },
  //       body: JSON.stringify({
  //         aktivitetstype: "Kommentar",
  //         kommentar: nyKommentar,
  //         oprettet_af: "Sagsbehandler"
  //       })
  //     });

  //     if (!response.ok) {
  //       alert("Kunne ikke gemme kommentar");
  //       return;
  //     }

  //     nyKommentar = "";

  //     await invalidateAll();
  //   } finally {
  //     savingKommentar = false;
  //   }
  // }

  function saveKommentar() {
    // no-op — sagsaktivitet/sagsforløb temporarily disabled
  }


  // -----------------------------
  // Create bevilling state
  // -----------------------------

  let skoleType: 'folkeskole' | 'ungdomsuddannelse' | null = null;

  function getEmptyBevilling() {
    return {
      adresse_id: null as number | null,
      adresse_tekst: "",
      matrikel_id: "1",
      ungdomsuddannelse_id: "",
      hjemmel_id: "1",
      afgoerelsesbrev_id: "1",
      revurderingsdato: "2026-06-30",
      befordringsudvalg: "2026-06-20",
      esdh_noegle: "ESDH-TEST-010",
      sagsbehandler_id: "1",
      ppr_sagsbehandler_id: "1",
      ansoegningsdato: "2026-01-01",
      sagsbehandlingsdato: "2026-01-10",
      relation_til_barnet: "Mor",
      foerste_koersel_dato: "2026-02-01",
      ansoegningstype: "Kørsel",
      afstandskriterie_dato: "2026-06-30",
      afstandskriterie_klassetrin: "3",
      begrundelse_fra_formular: "",
      hjaelpemiddel_ids: []
    };
  }


  let newBevilling: any = getEmptyBevilling();

  const begrundelseOptions = [
    "Sygdom",
    "Afstand",
    "Farlig skolevej"
  ];

  let selectedBegrundelser: string[] = [];
  let begrundelseSelectValue = "";


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
      label: "Cpr-nummer"
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
    transporttidIBus = "";
    skiftMedBus = "";
  }


  function resetCreateBevillingForm() {
    newBevilling = getEmptyBevilling();
    skoleType = null;
    selectedBegrundelser = [];
    begrundelseSelectValue = "";
  }


  function prefillFromBevilling(source: any) {
    // Determine school type for the toggle
    skoleType = (source.ungdomsuddannelse_id && !source.matrikel_id)
      ? 'ungdomsuddannelse'
      : 'folkeskole';

    // Re-hydrate the begrundelse multi-select tags from the stored string
    const rawBegrundelse = source.begrundelse_fra_formular ?? "";
    selectedBegrundelser = rawBegrundelse
      .split(", ")
      .filter((b: string) => begrundelseOptions.includes(b));
    begrundelseSelectValue = "";

    newBevilling = {
      // Copied from source — stable fields that carry over to a new bevilling
      adresse_id:                   source.adresse_id   ?? null,
      adresse_tekst:                source.adresse_for_bevilling ?? "",
      matrikel_id:                  source.matrikel_id != null ? String(source.matrikel_id) : "",
      ungdomsuddannelse_id:         source.ungdomsuddannelse_id != null ? String(source.ungdomsuddannelse_id) : "",
      hjemmel_id:                   source.hjemmel_id != null ? String(source.hjemmel_id) : "",
      afgoerelsesbrev_id:           source.afgoerelsesbrev_id != null ? String(source.afgoerelsesbrev_id) : "",
      sagsbehandler_id:             source.sagsbehandler_id != null ? String(source.sagsbehandler_id) : "",
      ppr_sagsbehandler_id:         source.ppr_sagsbehandler_id != null ? String(source.ppr_sagsbehandler_id) : "",
      relation_til_barnet:          source.relation_til_barnet ?? "",
      ansoegningstype:              source.ansoegningstype ?? "",
      afstandskriterie_dato:        source.afstandskriterie_dato ? String(source.afstandskriterie_dato).slice(0, 10) : "",
      afstandskriterie_klassetrin:  source.afstandskriterie_klassetrin != null ? String(source.afstandskriterie_klassetrin) : "",
      revurderingsdato:             source.revurderingsdato ? String(source.revurderingsdato).slice(0, 10) : "",
      befordringsudvalg:            source.befordringsudvalg ? String(source.befordringsudvalg).slice(0, 10) : "",
      begrundelse_fra_formular:     rawBegrundelse,
      esdh_noegle:                  stamdata?.esdh_noegle ?? "",

      // Always blank — must be set fresh for every new bevilling
      ansoegningsdato:      "",
      sagsbehandlingsdato:  "",
      foerste_koersel_dato: "",

      hjaelpemiddel_ids: []
    };
  }


  // -----------------------------
  // Begrundelse helpers
  // -----------------------------

  function addBegrundelse() {
    if (begrundelseSelectValue === "") {
      return;
    }

    if (!selectedBegrundelser.includes(begrundelseSelectValue)) {
      selectedBegrundelser = [
        ...selectedBegrundelser,
        begrundelseSelectValue
      ];
    }

    newBevilling.begrundelse_fra_formular = selectedBegrundelser.join(", ");

    begrundelseSelectValue = "";
  }


  function removeBegrundelse(value: string) {
    selectedBegrundelser = selectedBegrundelser.filter(
      (existingValue) => existingValue !== value
    );

    newBevilling.begrundelse_fra_formular = selectedBegrundelser.join(", ");
  }


  // -----------------------------
  // Bevilling handlers
  // -----------------------------

  async function handleCreateBevilling() {
    const isMidlertidig = newBevilling.ansoegningstype === "Midlertidig kørsel";

    const payload = {
      adresse_id: newBevilling.adresse_id,
      matrikel_id: (isMidlertidig && skoleType === 'ungdomsuddannelse')
        ? null
        : numberOrNull(newBevilling.matrikel_id),
      ungdomsuddannelse_id: (isMidlertidig && skoleType === 'ungdomsuddannelse')
        ? numberOrNull(newBevilling.ungdomsuddannelse_id)
        : null,

      hjemmel_id: numberOrNull(newBevilling.hjemmel_id),
      afgoerelsesbrev_id: numberOrNull(newBevilling.afgoerelsesbrev_id),

      revurderingsdato: emptyToNull(newBevilling.revurderingsdato),
      befordringsudvalg: emptyToNull(newBevilling.befordringsudvalg),
      esdh_noegle: emptyToNull(newBevilling.esdh_noegle),

      sagsbehandler_id: numberOrNull(newBevilling.sagsbehandler_id),
      ppr_sagsbehandler_id: numberOrNull(newBevilling.ppr_sagsbehandler_id),

      ansoegningsdato: emptyToNull(newBevilling.ansoegningsdato),
      sagsbehandlingsdato: emptyToNull(newBevilling.sagsbehandlingsdato),
      relation_til_barnet: emptyToNull(newBevilling.relation_til_barnet),
      foerste_koersel_dato: emptyToNull(newBevilling.foerste_koersel_dato),
      ansoegningstype: emptyToNull(newBevilling.ansoegningstype),

      afstandskriterie_dato: emptyToNull(newBevilling.afstandskriterie_dato),
      afstandskriterie_klassetrin: numberOrNull(newBevilling.afstandskriterie_klassetrin),
      begrundelse_fra_formular: emptyToNull(newBevilling.begrundelse_fra_formular),

      hjaelpemiddel_ids: newBevilling.hjaelpemiddel_ids ?? []
    };

    const statusText = encodeURIComponent("Påbegyndt");

    const response = await backendFetch(
      `/bevilling/create_bevilling/${stamdata.cpr}?status_text=${statusText}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify(payload)
      }
    );

    if (!response.ok) {
      let message = "Kunne ikke oprette bevilling";

      try {
        const errorData = await response.json();
        console.error("Opret bevilling fejlede:", response.status, errorData);

        if (typeof errorData?.detail?.message === "string") {
          message = errorData.detail.message;
        } else if (typeof errorData?.detail === "string") {
          message = errorData.detail;
        } else if (Array.isArray(errorData?.detail)) {
          // FastAPI validation error — join all messages
          message = errorData.detail.map((e: any) => e.msg ?? JSON.stringify(e)).join("\n");
        }
      } catch {
        console.error("Opret bevilling fejlede (ikke JSON):", response.status);
      }

      alert(`Fejl ${response.status}: ${message}`);
      return;
    }

    const result = await response.json();

    showStatusReasonIfAny(result);

    await invalidateAll();

    switchTab("stamdata");
    showCreateBevillingModal = false;
    resetCreateBevillingForm();
  }


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

    if (selectedLetterBevillingHasSkolerejsekort && transporttidIBus === "") {
      alert("Angiv transporttid i bus");
      return;
    }

    if (selectedLetterBevillingHasSkolerejsekort && skiftMedBus === "") {
      alert("Angiv antal skift med bus");
      return;
    }

    creatingLetter = true;

    const payload = {
      brev_i_forbindelse_med: letterType,

      befordringsudvalg_resultat: selectedLetterBevillingHasBefordringsudvalg
        ? befordringsudvalgResultat
        : null,

      dato_for_tidligere_afgoerelse: selectedLetterBevillingHasBefordringsudvalg
        ? tidligereAfgoerelseDato
        : null,

      ophoersdato: selectedLetterBevillingIsOphoert
        ? ophoersdato
        : null,

      transporttid_i_bus: selectedLetterBevillingHasSkolerejsekort
        ? Number(transporttidIBus)
        : null,

      skift_med_bus: selectedLetterBevillingHasSkolerejsekort
        ? Number(skiftMedBus)
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

      showCreateLetterModal = false;
      resetCreateLetterForm();

    } finally {
      creatingLetter = false;
    }
  }


  async function handleSaveBevilling(bevillingId: number, updates: any) {
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

      alert(message);

      return false;
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
      alert("Bevilling blev gemt, men hjælpemidler kunne ikke gemmes");
      return false;
    }

    showStatusReasonIfAny(bevillingResult);

    await invalidateAll();

    switchTab("stamdata");

    return true;
  }


  // -----------------------------
  // Kørselsrække handlers
  // -----------------------------

  async function handleCreateKoerselsraekke(bevillingId: number, updates: any) {
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
      alert("Kunne ikke oprette kørselsrække");
      return false;
    }

    const result = await response.json();

    showStatusReasonIfAny(result);

    await invalidateAll();

    switchTab("stamdata");

    return true;
  }


  async function handleFinalizeKoerselsraekke(koerselId: number) {
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
      alert(message);
      return false;
    }

    await invalidateAll();
    return true;
  }


  async function handleSaveKoerselsraekke(koerselId: number, updates: any) {
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

      alert(message);
      return false;
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
      alert("Kørselsrække blev gemt, men kørselstype tillæg kunne ikke gemmes");
      return false;
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
      alert("Kørselsrække blev gemt, men dage kunne ikke gemmes");
      return false;
    }

    showStatusReasonIfAny(koerselsraekkeResult);

    await invalidateAll();

    switchTab("stamdata");

    return true;
  }
</script>

<svelte:window on:keydown={(e) => {
  if (e.key !== 'Escape') return;
  if (showCreateBevillingModal) {
    showCreateBevillingModal = false;
    resetCreateBevillingForm();
  }
  if (showCreateLetterModal) {
    showCreateLetterModal = false;
    resetCreateLetterForm();
  }
}} />

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
        </div>
        <p class="text-sm text-gray-500 mt-0.5">
          <span class="font-mono">{stamdata?.cpr ?? ""}</span>
          {#if studentAge !== null}
            <span class="mx-1.5 text-gray-300">·</span>{studentAge} år
          {/if}
          {#if stamdata?.adresse_tekst}
            <span class="mx-1.5 text-gray-300">·</span>{stamdata.adresse_tekst}
          {/if}
        </p>
      </div>
    </div>

    <!-- Tab buttons -->
    <div class="flex gap-2 shrink-0">
      <button
        type="button"
        class="px-4 py-2 text-sm font-medium rounded border transition-colors"
        style={activeTab === "stamdata"
          ? "background-color: #032A42; color: #ffffff; border-color: #032A42;"
          : "background-color: #ffffff; color: #374151; border-color: #d1d5db;"}
        on:click={() => switchTab("stamdata")}
      >
        Stamdata
      </button>

      <!-- Sagsforløb tab temporarily disabled
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
      -->
    </div>

  </div>


  <!-- STAMDATA TAB -->
  {#if activeTab === "stamdata"}

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


  {/if}


  <!-- BEVILLINGER (shown in stamdata tab) -->
  {#if activeTab === "stamdata"}

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
        on:click={() => {
          if (bevillinger && bevillinger.length > 0) {
            prefillFromBevilling(bevillinger[0]);
          } else {
            resetCreateBevillingForm();
          }
          showCreateBevillingModal = true;
        }}
      >
        + Ny bevilling
      </button>

      <button
        type="button"
        class="px-4 py-2 text-sm font-medium bg-purple-600 hover:bg-purple-700 text-white rounded transition-colors"
        on:click={() => showCreateLetterModal = true}
      >
        + Opret brev
      </button>
      </div>
    </div>


    <!-- Create bevilling modal -->
    {#if showCreateBevillingModal}
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <div
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        on:click|self={() => { showCreateBevillingModal = false; resetCreateBevillingForm(); }}
        role="presentation"
      >
        <div
          class="w-[750px] max-h-[90vh] overflow-y-auto bg-white rounded-lg shadow-2xl"
          role="dialog"
          aria-modal="true"
          aria-label="Opret ny bevilling"
          tabindex="-1"
        >

          <div class="sticky top-0 z-10 px-8 py-5 border-b border-gray-200" style="background-color: #032A42;">
            <h2 class="text-lg font-bold text-white">Opret ny bevilling</h2>
            <p class="mt-0.5 text-sm" style="color: rgba(255,255,255,0.7);">Udfyld alle obligatoriske felter</p>
          </div>

          <div class="p-8">
            <div class="grid grid-cols-2 gap-5">

              <!-- STEP 1: Ansøgningstype (always first) -->
              <label class="text-sm font-medium text-gray-700 col-span-2">
                Ansøgningstype *
                <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.ansoegningstype}>
                  <option value="">Vælg ansøgningstype</option>
                  <option value="Kørsel">Kørsel</option>
                  <option value="Midlertidig kørsel">Midlertidig kørsel</option>
                  <option value="Skolebus">Skolebus</option>
                </select>
              </label>

              <!-- STEP 2: School selection -->
              {#if newBevilling.ansoegningstype === "Midlertidig kørsel"}

                <!-- Toggle between folkeskole and ungdomsuddannelse -->
                <div class="col-span-2">
                  <p class="text-sm font-medium text-gray-700 mb-2">Skole type *</p>
                  <div class="flex gap-2">
                    <button
                      type="button"
                      class="flex-1 py-2 text-sm font-medium rounded border transition-colors"
                      style={skoleType === 'folkeskole'
                        ? 'background-color: #032A42; color: #fff; border-color: #032A42;'
                        : 'background-color: #fff; color: #374151; border-color: #d1d5db;'}
                      on:click={() => skoleType = 'folkeskole'}
                    >
                      Folkeskole
                    </button>
                    <button
                      type="button"
                      class="flex-1 py-2 text-sm font-medium rounded border transition-colors"
                      style={skoleType === 'ungdomsuddannelse'
                        ? 'background-color: #032A42; color: #fff; border-color: #032A42;'
                        : 'background-color: #fff; color: #374151; border-color: #d1d5db;'}
                      on:click={() => skoleType = 'ungdomsuddannelse'}
                    >
                      Ungdomsuddannelse
                    </button>
                  </div>
                </div>

                {#if skoleType === 'folkeskole'}
                  <label class="text-sm font-medium text-gray-700 col-span-2">
                    Folkeskole (matrikel)
                    <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.matrikel_id}>
                      <option value="">Vælg</option>
                      {#each lookupOptions.skolematrikler ?? [] as option}
                        <option value={String(option.id)}>{option.label}</option>
                      {/each}
                    </select>
                  </label>
                {:else if skoleType === 'ungdomsuddannelse'}
                  <label class="text-sm font-medium text-gray-700 col-span-2">
                    Ungdomsuddannelse
                    <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.ungdomsuddannelse_id}>
                      <option value="">Vælg</option>
                      {#each lookupOptions.ungdomsuddannelser ?? [] as option}
                        <option value={String(option.id)}>{option.label}</option>
                      {/each}
                    </select>
                  </label>
                {/if}

              {:else if newBevilling.ansoegningstype}

                <!-- All other types: always folkeskole -->
                <label class="text-sm font-medium text-gray-700 col-span-2">
                  Folkeskole (matrikel)
                  <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.matrikel_id}>
                    <option value="">Vælg</option>
                    {#each lookupOptions.skolematrikler ?? [] as option}
                      <option value={String(option.id)}>{option.label}</option>
                    {/each}
                  </select>
                </label>

              {/if}

              <!-- REST OF FORM: shown after school is resolved -->
              {#if (newBevilling.ansoegningstype && newBevilling.ansoegningstype !== "Midlertidig kørsel") || (newBevilling.ansoegningstype === "Midlertidig kørsel" && skoleType !== null)}

              <label class="text-sm font-medium text-gray-700 col-span-2">
                Adresse for bevilling
                <div class="mt-1.5">
                  <AddresseSearch
                    adresseId={newBevilling.adresse_id}
                    adresseTekst={newBevilling.adresse_tekst}
                    onSelect={(result) => {
                      newBevilling = {
                        ...newBevilling,
                        adresse_id:    result?.adresse_id    ?? null,
                        adresse_tekst: result?.adresse_tekst ?? "",
                      };
                    }}
                  />
                </div>
              </label>

              <label class="text-sm font-medium text-gray-700">
                Hjemmel
                <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.hjemmel_id}>
                  <option value="">Vælg</option>
                  {#each lookupOptions.hjemler ?? [] as option}
                    <option value={String(option.id)}>{option.label}</option>
                  {/each}
                </select>
              </label>

              <label class="text-sm font-medium text-gray-700">
                Afgørelsesbrev
                <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.afgoerelsesbrev_id}>
                  <option value="">Vælg</option>
                  {#each lookupOptions.afgoerelsesbreve ?? [] as option}
                    <option value={String(option.id)}>{option.label}</option>
                  {/each}
                </select>
              </label>

              <label class="text-sm font-medium text-gray-700">
                Revurdering
                <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.revurderingsdato} />
              </label>

              <label class="text-sm font-medium text-gray-700">
                Befordringsudvalg
                <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.befordringsudvalg} />
              </label>

              <label class="text-sm font-medium text-gray-700">
                ESDH-nøgle
                <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.esdh_noegle} />
              </label>

              <label class="text-sm font-medium text-gray-700">
                Sagsbehandler
                <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.sagsbehandler_id}>
                  <option value="">Vælg</option>
                  {#each lookupOptions.sagsbehandlere ?? [] as option}
                    <option value={String(option.id)}>{option.label}</option>
                  {/each}
                </select>
              </label>

              <label class="text-sm font-medium text-gray-700">
                PPR ansvarlig
                <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.ppr_sagsbehandler_id}>
                  <option value="">Vælg</option>
                  {#each lookupOptions.pprSagsbehandlere ?? [] as option}
                    <option value={String(option.id)}>{option.label}</option>
                  {/each}
                </select>
              </label>

              <label class="text-sm font-medium text-gray-700">
                Sagsbehandlingsdato
                <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.sagsbehandlingsdato} />
              </label>

              <label class="text-sm font-medium text-gray-700">
                Ansøger relation
                <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.relation_til_barnet} />
              </label>

              <label class="text-sm font-medium text-gray-700">
                Dato for første kørsel
                <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.foerste_koersel_dato} />
              </label>

              <label class="text-sm font-medium text-gray-700">
                Afstandskriterie dato
                <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.afstandskriterie_dato} />
              </label>

              <label class="text-sm font-medium text-gray-700">
                Afstandskriterie klassetrin
                <input type="number" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.afstandskriterie_klassetrin} />
              </label>

              <label class="text-sm font-medium text-gray-700 col-span-2">
                Begrundelse
                <div class="mt-1.5 border border-gray-300 rounded p-3">
                  <div class="mb-2 flex flex-wrap gap-1.5">
                    {#each selectedBegrundelser as begrundelse}
                      <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                        {begrundelse}
                        <button type="button" class="ml-1 text-red-500 hover:text-red-700 font-bold" on:click={() => removeBegrundelse(begrundelse)}>×</button>
                      </span>
                    {/each}
                  </div>
                  <select class="w-full border border-gray-300 rounded px-2 py-1.5 text-sm" bind:value={begrundelseSelectValue} on:change={addBegrundelse}>
                    <option value="">Tilføj begrundelse</option>
                    {#each begrundelseOptions.filter((opt) => !selectedBegrundelser.includes(opt)) as opt}
                      <option value={opt}>{opt}</option>
                    {/each}
                  </select>
                </div>
              </label>

              {/if}

            </div>
          </div>

          <div class="flex justify-end gap-3 border-t border-gray-200 px-8 py-5">
            <button
              type="button"
              class="px-5 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
              on:click={() => { showCreateBevillingModal = false; resetCreateBevillingForm(); }}
            >
              Annullér
            </button>
            <button
              type="button"
              disabled={!newBevilling.adresse_id}
              class="px-5 py-2 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-green-600"
              on:click={handleCreateBevilling}
            >
              Opret bevilling
            </button>
          </div>

        </div>
      </div>
    {/if}


    <!-- Create letter modal -->
    {#if showCreateLetterModal}
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <div
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        on:click|self={() => { showCreateLetterModal = false; resetCreateLetterForm(); }}
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
                    {bevilling.status_tekst ?? "Ukendt status"} - {bevilling.adresse_for_bevilling ?? bevilling.adresse_tekst ?? "Ingen adresse"}
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
              <label class="block text-sm font-medium text-gray-700">
                Dato for tidligere afgørelse
                <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={tidligereAfgoerelseDato} />
              </label>
            {/if}

            {#if selectedLetterBevillingHasSkolerejsekort}
              <label class="block text-sm font-medium text-gray-700">
                Transporttid i bus (i minutter)
                <input type="number" min="0" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={transporttidIBus} />
              </label>
              <label class="block text-sm font-medium text-gray-700">
                Skift med bus (antal)
                <input type="number" min="0" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={skiftMedBus} />
              </label>
            {/if}

            {#if selectedLetterBevillingIsOphoert}
              <label class="block text-sm font-medium text-gray-700">
                Ophørsdato
                <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={ophoersdato} />
              </label>
            {/if}
          </div>

          <div class="flex justify-end gap-3 border-t border-gray-200 px-8 py-5 bg-gray-50 rounded-b-lg">
            <button
              type="button"
              class="px-5 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-white transition-colors"
              on:click={() => { showCreateLetterModal = false; selectedLetterBevillingId = ""; letterType = ""; }}
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


  <!-- SAGSFORLØB TAB — temporarily disabled -->
  {#if false && activeTab === "sagsforloeb"}

    <!-- Ny kommentar -->
    <div class="bg-white border border-gray-300 rounded-lg shadow px-4 md:px-6 py-5 mb-4">
      <h2 class="font-semibold text-gray-800 mb-3">Ny kommentar</h2>

      <textarea
        bind:value={nyKommentar}
        rows="4"
        class="w-full border border-gray-300 rounded px-3 py-2 text-sm"
        placeholder="Skriv kommentar..."
      ></textarea>

      <div class="mt-3">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium text-white rounded transition-colors disabled:opacity-50"
          style="background-color: #032A42;"
          on:click={saveKommentar}
          disabled={savingKommentar}
        >
          {savingKommentar ? "Gemmer..." : "Gem kommentar"}
        </button>
      </div>
    </div>

    <!-- Aktiviteter -->
    <div class="bg-white border border-gray-300 rounded-lg shadow px-4 md:px-6 py-5 mb-4">
      <div class="flex items-center gap-3 mb-4">
        <h2 class="font-semibold text-gray-800">Aktiviteter</h2>
        <span
          class="inline-flex items-center justify-center min-w-[1.5rem] h-5 px-1.5 rounded-full text-xs font-bold"
          style="background-color: #dbeafe; color: #1d4ed8;"
        >
          {aktiviteter?.length ?? 0}
        </span>
      </div>

      {#if !aktiviteter || aktiviteter.length === 0}

        <div class="text-sm text-gray-500">
          Ingen aktiviteter registreret endnu.
        </div>

      {:else}

        <div class="space-y-3">
          {#each aktiviteter as aktivitet}

            <div class="border border-gray-200 rounded-lg p-4">

              <div class="flex justify-between items-start mb-2">
                <div>
                  <span class="inline-block px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700">
                    {aktivitet.aktivitetstype}
                  </span>
                  <span class="ml-2 text-xs text-gray-500">
                    {aktivitet.oprettet_af ?? "System"}
                  </span>
                </div>

                <div class="text-xs text-gray-500">
                  {new Date(aktivitet.oprettet_tidspunkt).toLocaleString("da-DK")}
                </div>
              </div>

              {#if aktivitet.kommentar}
                <div class="mt-2 text-sm text-gray-800 whitespace-pre-wrap">
                  {aktivitet.kommentar}
                </div>
              {/if}

            </div>

          {/each}
        </div>

      {/if}
    </div>

  {/if}

</section>