<script lang="ts">
  import { invalidateAll } from "$app/navigation";

  import { backendFetch } from "$lib/client/backendFetch";

  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import BevillingTable from "$lib/components/BevillingTable.svelte";
  import {
    getStatusBadgeClass,
  } from "$lib/tableColumnConfig";

  export let data;


  // -----------------------------
  // Page state
  // -----------------------------

  let letterType = "";
  let befordringsudvalgResultat = "";

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

  let { stamdata, parents, bevillinger, lookupOptions } = data;

  let activeTab = "stamdata";

  let editingStamdata = false;
  let editableStamdata = { ...stamdata };

  let showCreateBevillingModal = false;


  $: if (data && !editingStamdata) {
    stamdata = data.stamdata;
    parents = data.parents;
    bevillinger = data.bevillinger;
    lookupOptions = data.lookupOptions;

    editableStamdata = { ...data.stamdata };
  }


  // -----------------------------
  // Create bevilling state
  // -----------------------------

  function getEmptyBevilling() {
    return {
      adresse_for_bevilling: "Testvej 123, 8000 Aarhus C",
      matrikel_id: "1",
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

  const stamdataColumns: DataTableColumn[] = [
    {
      key: "esdh_noegle",
      label: "Sags-ID",
      editable: false,
      render: (row) => `
        <a href="#" class="text-sky-600 underline">
          ${row.esdh_noegle ?? ""}
        </a>
      `
    },
    {
      key: "status_tekst",
      label: "Status",
      editable: false,
      render: (row) => `
        <span class="inline-block px-3 py-1 ${getStatusBadgeClass(row.status_tekst)}">
          ${row.status_tekst ?? ""}
        </span>
      `
    },
    {
      key: "adresse_tekst",
      label: "Folkeregisteradresse",
      editable: false
    },
    {
      key: "skolematrikel",
      label: "Skolematrikel",
      editable: false
    },
    {
      key: "skoleafstand",
      label: "Korteste gåafstand mellem elevens adresse og skole (km)",
      editable: true
    },
    {
      key: "klasseart",
      label: "Klasseart",
      editable: true
    },
    {
      key: "klassebetegnelse",
      label: "Klassebetegnelse",
      editable: true
    },
    {
      key: "elevklassetrin",
      label: "Personligt klassetrin",
      editable: true
    },
    {
      key: "sfo",
      label: "SFO",
      editable: true
    },
    {
      key: "bopaelsdistrikt",
      label: "Bopælsdistrikt",
      editable: true
    }
  ];


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
      key: "foraeldremyndighed",
      label: "Forældremyndig",
      render: (row) => row.foraeldremyndighed ? "Ja" : "Nej"
    },
    {
      key: "navne_adresse_beskyttelse",
      label: "Navne- og adressebeskyttelse",
      render: (row) => row.navne_adresse_beskyttelse ? "Ja" : "Nej"
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
  }


  function resetCreateBevillingForm() {
    newBevilling = getEmptyBevilling();

    selectedBegrundelser = [];
    begrundelseSelectValue = "";
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
  // Stamdata handlers
  // -----------------------------

  function handleEditStamdata(row: any) {
    editingStamdata = true;
    editableStamdata = { ...row };
  }


  function handleCancelStamdata() {
    editingStamdata = false;
    editableStamdata = { ...stamdata };
  }


  function handleStamdataChange(key: string, value: any) {
    editableStamdata = {
      ...editableStamdata,
      [key]: value
    };
  }


  async function handleSaveStamdata() {
    const updates = {
      skoleafstand: editableStamdata.skoleafstand,
      klasseart: editableStamdata.klasseart,
      elevklassetrin: editableStamdata.elevklassetrin,
      klassebetegnelse: editableStamdata.klassebetegnelse,
      sfo: editableStamdata.sfo,
      bopaelsdistrikt: editableStamdata.bopaelsdistrikt
    };

    const response = await backendFetch(`/citizen/stamdata/${stamdata.cpr}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(updates)
    });

    if (!response.ok) {
      alert("Kunne ikke gemme stamdata");
      return;
    }

    stamdata = {
      ...stamdata,
      ...updates
    };

    bevillinger = bevillinger.map((bevilling: any) => {
      return {
        ...bevilling,
        skoleafstand: updates.skoleafstand
      };
    });

    editableStamdata = { ...stamdata };
    editingStamdata = false;
  }


  // -----------------------------
  // Bevilling handlers
  // -----------------------------

  async function handleCreateBevilling() {
    const payload = {
      adresse_for_bevilling: emptyToNull(newBevilling.adresse_for_bevilling),
      matrikel_id: numberOrNull(newBevilling.matrikel_id),
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

        message =
          errorData?.detail?.message ??
          errorData?.detail ??
          message;
      } catch {
        // If backend does not return JSON, keep the fallback message
      }

      alert(message);
      return;
    }

    const result = await response.json();

    showStatusReasonIfAny(result);

    await invalidateAll();

    activeTab = "bevillinger";
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

    if (selectedLetterBevillingIsOphoert && !ophoersdato) {
      alert("Vælg ophørsdato");
      return;
    }

    creatingLetter = true;

    const payload = {
      brev_i_forbindelse_med: letterType,

      befordringsudvalg_resultat: selectedLetterBevillingHasBefordringsudvalg
        ? befordringsudvalgResultat
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

    activeTab = "bevillinger";

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

    activeTab = "bevillinger";

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

    activeTab = "bevillinger";

    return true;
  }
</script>


<section class="bg-white min-h-screen px-10 py-8">

  <h1 class="text-2xl font-bold mb-28">
    Forside – Konkret sag -
    <span class="underline">
      {activeTab === "stamdata" ? "Stamdata" : "Bevillinger"}
    </span>
  </h1>


  <nav class="flex border border-gray-300 bg-gray-100 mb-6">

    <button
      type="button"
      class="px-8 py-3 border-r border-gray-300"
      class:bg-white={activeTab === "stamdata"}
      class:font-semibold={activeTab === "stamdata"}
      on:click={() => activeTab = "stamdata"}
    >
      Stamdata
    </button>

    <button
      type="button"
      class="px-8 py-3 border-r border-gray-300 text-sky-600"
      class:bg-white={activeTab === "bevillinger"}
      class:font-semibold={activeTab === "bevillinger"}
      class:text-black={activeTab === "bevillinger"}
      on:click={() => activeTab = "bevillinger"}
    >
      Bevillinger
    </button>

  </nav>


  {#if stamdata?.navne_adresse_beskyttelse}
    <div class="inline-block bg-red-100 text-red-900 px-1 mb-4 text-sm">
      Vær opmærksom på at barnet har navne- og/eller adressebeskyttelse
    </div>
  {/if}


  <div class="mb-4 flex items-baseline gap-6">

    <h2 class="text-xl font-bold">
      {stamdata?.adresseringsnavn ?? ""}
    </h2>

    <span class="text-sm">
      {stamdata?.cpr ?? ""}
    </span>

  </div>


  {#if activeTab === "stamdata"}

    <DataTable
      data={[stamdata]}
      columns={stamdataColumns}
      filterable={false}
      editable={true}
      editingRowId={editingStamdata ? stamdata.cpr : null}
      editableRow={editableStamdata}
      getRowId={(row) => row.cpr}
      onEdit={handleEditStamdata}
      onSave={handleSaveStamdata}
      onCancel={handleCancelStamdata}
      onInputChange={handleStamdataChange}
    />


    <div class="mt-6">

      <h2 class="font-bold mb-3">
        Oplysninger om forældre
      </h2>

      <DataTable
        data={parents}
        columns={parentColumns}
        filterable={false}
      />

    </div>


    <button
      type="button"
      class="mt-24 inline-flex items-center gap-2 rounded border border-gray-300 px-3 py-1 text-sm shadow-sm"
    >
      🟩 Excel
    </button>

  {/if}


  {#if activeTab === "bevillinger"}

    <div class="mb-4 flex items-start justify-between">

      <h2 class="text-xl font-bold">
        Bevillinger
      </h2>

      <div class="flex flex-col gap-2">

        <button
          type="button"
          class="rounded bg-sky-500 px-4 py-2 text-sm text-white hover:bg-sky-600"
          on:click={() => showCreateBevillingModal = true}
        >
          + Ny bevilling
        </button>

        <button
          type="button"
          class="rounded bg-sky-500 px-4 py-2 text-sm text-white hover:bg-sky-600"
          on:click={() => showCreateLetterModal = true}
        >
          + Opret brev
        </button>

      </div>

    </div>


    {#if showCreateBevillingModal}
      <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/30">

        <div class="w-[700px] max-h-[80vh] overflow-y-auto bg-white p-6 shadow-lg">

          <h2 class="mb-4 text-lg font-bold">
            Opret ny bevilling
          </h2>

          <div class="grid grid-cols-2 gap-4">

            <label class="text-sm col-span-2">
              Adresse for bevilling
              <input
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.adresse_for_bevilling}
              />
            </label>

            <label class="text-sm">
              Matrikel
              <select
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.matrikel_id}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.skolematrikler ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm">
              Hjemmel
              <select
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.hjemmel_id}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.hjemler ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm">
              Afgørelsesbrev
              <select
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.afgoerelsesbrev_id}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.afgoerelsesbreve ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm">
              Revurdering
              <input
                type="date"
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.revurderingsdato}
              />
            </label>

            <label class="text-sm">
              Befordringsudvalg
              <input
                type="date"
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.befordringsudvalg}
              />
            </label>

            <label class="text-sm">
              ESDH-nøgle
              <input
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.esdh_noegle}
              />
            </label>

            <label class="text-sm">
              Sagsbehandler
              <select
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.sagsbehandler_id}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.sagsbehandlere ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm">
              PPR ansvarlig
              <select
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.ppr_sagsbehandler_id}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.pprSagsbehandlere ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm">
              Ansøgningsdato
              <input
                type="date"
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.ansoegningsdato}
              />
            </label>

            <label class="text-sm">
              Sagsbehandlingsdato
              <input
                type="date"
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.sagsbehandlingsdato}
              />
            </label>

            <label class="text-sm">
              Ansøger relation
              <input
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.relation_til_barnet}
              />
            </label>

            <label class="text-sm">
              Dato for første kørsel
              <input
                type="date"
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.foerste_koersel_dato}
              />
            </label>

            <label class="text-sm">
              Ansøgningstype
              <select
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.ansoegningstype}
              >
                <option value="">Vælg ansøgningstype</option>
                <option value="Kørsel">Kørsel</option>
                <option value="Midlertidig kørsel">Midlertidig kørsel</option>
                <option value="Skolebus">Skolebus</option>
              </select>
            </label>

            <label class="text-sm">
              Afstandskriterie dato
              <input
                type="date"
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.afstandskriterie_dato}
              />
            </label>

            <label class="text-sm">
              Afstandskriterie klassetrin
              <input
                type="number"
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.afstandskriterie_klassetrin}
              />
            </label>

            <label class="text-sm col-span-2">
              Begrundelse

              <div class="mt-1 border p-2">

                <div class="mb-2 flex flex-wrap gap-1.5">
                  {#each selectedBegrundelser as begrundelse}
                    <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2.5 py-1.5 text-sm">
                      {begrundelse}

                      <button
                        type="button"
                        class="ml-1 text-sm font-semibold text-red-600 hover:text-red-800"
                        on:click={() => removeBegrundelse(begrundelse)}
                      >
                        X
                      </button>
                    </span>
                  {/each}
                </div>

                <select
                  class="w-full border px-2 py-1"
                  bind:value={begrundelseSelectValue}
                  on:change={addBegrundelse}
                >
                  <option value="">Tilføj begrundelse</option>

                  {#each begrundelseOptions.filter((option) => !selectedBegrundelser.includes(option)) as option}
                    <option value={option}>
                      {option}
                    </option>
                  {/each}
                </select>

              </div>
            </label>

          </div>

          <div class="mt-6 flex justify-end gap-2">

            <button
              type="button"
              class="border px-4 py-2"
              on:click={() => {
                showCreateBevillingModal = false;
                resetCreateBevillingForm();
              }}
            >
              Annullér
            </button>

            <button
              type="button"
              class="bg-green-600 px-4 py-2 text-white"
              on:click={handleCreateBevilling}
            >
              Opret
            </button>

          </div>

        </div>

      </div>
    {/if}


    {#if showCreateLetterModal}
      <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/30">

        <div class="w-[600px] bg-white p-6 shadow-lg">

          <h2 class="mb-4 text-lg font-bold">
            Opret brev
          </h2>

          <label class="text-sm">
            Vælg bevilling

            <select
              class="mt-1 w-full border px-2 py-1"
              bind:value={selectedLetterBevillingId}
            >
              <option value="">Vælg bevilling</option>

              {#each bevillinger ?? [] as bevilling}
                <option value={String(bevilling.bevilling_id)}>
                  {bevilling.status_tekst ?? "Ukendt status"}
                  -
                  {bevilling.adresse_for_bevilling ?? "Ingen adresse"}
                </option>
              {/each}
            </select>
          </label>

          <label class="mt-4 block text-sm">
            Brevet er i forbindelse med en:

            <select
              class="mt-1 w-full border px-2 py-1"
              bind:value={letterType}
            >
              <option value="">Vælg</option>
              <option value="ansøgning">Ansøgning</option>
              <option value="revurdering">Revurdering</option>
              <option value="midlertidig kørsel">Midlertidig kørsel</option>
            </select>
          </label>

          {#if selectedLetterBevillingHasBefordringsudvalg}
            <label class="text-sm">
              Resultat af befordringsudvalgsmøde

              <select
                class="mt-1 w-full border px-2 py-1"
                bind:value={befordringsudvalgResultat}
              >
                <option value="">Vælg</option>
                <option value="Befordringsudvalg: Afslag / fastholdelse">
                  Befordringsudvalg: Afslag / fastholdelse
                </option>
                <option value="Befordringsudvalg: Ændring i bevilling">
                  Befordringsudvalg: Ændring i bevilling
                </option>
              </select>
            </label>
          {/if}

          {#if selectedLetterBevillingIsOphoert}
            <label class="text-sm">
              Ophørsdato

              <input
                type="date"
                class="mt-1 w-full border px-2 py-1"
                bind:value={ophoersdato}
              />
            </label>
          {/if}

          <div class="mt-6 flex justify-end gap-2">

            <button
              type="button"
              class="border px-4 py-2"
              on:click={() => {
                showCreateLetterModal = false;
                selectedLetterBevillingId = "";
                letterType = "";
              }}
            >
              Annullér
            </button>

            <button
              type="button"
              class="bg-green-600 px-4 py-2 text-white disabled:opacity-50"
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
    />


    <button
      type="button"
      class="mt-8 inline-flex items-center gap-2 rounded border border-gray-300 px-3 py-1 text-sm shadow-sm"
    >
      🟩 Excel
    </button>

  {/if}

</section>