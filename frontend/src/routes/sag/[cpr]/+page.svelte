<script lang="ts">
  import { env as publicEnv } from "$env/dynamic/public";
  import { invalidateAll } from "$app/navigation";

  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import BevillingTable from "$lib/components/BevillingTable.svelte";
  import { getStatusBadgeClass } from "$lib/tableColumnConfig";

  export let data;

  const API_URL = publicEnv.PUBLIC_API_BASE_URL;


  // -----------------------------
  // Page state
  // -----------------------------

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
      status_id: "",
      adresse_for_bevilling: "",
      matrikel_id: "",
      hjemmel_id: "",
      afgoerelsesbrev_id: "",
      revurderingsdato: "",
      befordringsudvalg: "",
      esdh_noegle: "",
      sagsbehandler_id: "",
      ppr_sagsbehandler_id: "",
      ansoegningsdato: "",
      sagsbehandlingsdato: "",
      relation_til_barnet: "",
      foerste_koersel_dato: "",
      ansoegningstype: "",
      afstandskriterie_dato: "",
      afstandskriterie_klassetrin: "",
      begrundelse_fra_formular: "",
      noter: "",
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


  function resetCreateBevillingForm() {
    newBevilling = getEmptyBevilling();

    selectedBegrundelser = [];
    begrundelseSelectValue = "";
  }


  function getMirroredStamdataStatus(updatedBevillinger: any[]) {
    const activeBevilling = updatedBevillinger.find((bevilling: any) =>
      String(bevilling.status_tekst ?? "").toLowerCase() === "aktiv"
    );

    if (activeBevilling) {
      return {
        status_tekst: activeBevilling.status_tekst,
        bevilling_id: activeBevilling.bevilling_id
      };
    }

    const latestUpdatedBevilling = [...updatedBevillinger].sort((a: any, b: any) => {
      const aDate = new Date(
        a.updated_at ?? a.created_at ?? a.sagsbehandlingsdato ?? 0
      ).getTime();

      const bDate = new Date(
        b.updated_at ?? b.created_at ?? b.sagsbehandlingsdato ?? 0
      ).getTime();

      return bDate - aDate;
    })[0];

    return {
      status_tekst: latestUpdatedBevilling?.status_tekst ?? "",
      bevilling_id: latestUpdatedBevilling?.bevilling_id ?? null
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

    const response = await fetch(`${API_URL}/citizen/stamdata/${stamdata.cpr}`, {
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
      status_id: numberOrNull(newBevilling.status_id),
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
      noter: emptyToNull(newBevilling.noter),

      hjaelpemiddel_ids: newBevilling.hjaelpemiddel_ids ?? []
    };

    const response = await fetch(`${API_URL}/bevilling/create_bevilling/${stamdata.cpr}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      alert("Kunne ikke oprette bevilling");
      return;
    }

    await invalidateAll();

    activeTab = "bevillinger";
    showCreateBevillingModal = false;
    resetCreateBevillingForm();
  }


  async function handleSaveBevilling(bevillingId: number, updates: any) {
    const { hjaelpemiddel_ids, ...bevillingUpdates } = updates;

    const bevillingResponse = await fetch(`${API_URL}/bevilling/${bevillingId}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(bevillingUpdates)
    });

    if (!bevillingResponse.ok) {
      alert("Kunne ikke gemme bevilling");
      return false;
    }

    const hjaelpemidlerResponse = await fetch(`${API_URL}/bevilling/${bevillingId}/hjaelpemidler`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        hjaelpemiddel_ids: hjaelpemiddel_ids ?? []
      })
    });

    if (!hjaelpemidlerResponse.ok) {
      alert("Bevilling blev gemt, men hjælpemidler kunne ikke gemmes");
      return false;
    }

    const statusOption = lookupOptions.statuser?.find(
      (option: any) => option.id === bevillingUpdates.status_id
    );

    const matrikelOption = lookupOptions.skolematrikler?.find(
      (option: any) => option.id === bevillingUpdates.matrikel_id
    );

    const hjemmelOption = lookupOptions.hjemler?.find(
      (option: any) => option.id === bevillingUpdates.hjemmel_id
    );

    const afgoerelsesbrevOption = lookupOptions.afgoerelsesbreve?.find(
      (option: any) => option.id === bevillingUpdates.afgoerelsesbrev_id
    );

    const sagsbehandlerOption = lookupOptions.sagsbehandlere?.find(
      (option: any) => option.id === bevillingUpdates.sagsbehandler_id
    );

    const pprSagsbehandlerOption = lookupOptions.pprSagsbehandlere?.find(
      (option: any) => option.id === bevillingUpdates.ppr_sagsbehandler_id
    );

    const selectedHjaelpemidler = lookupOptions.hjaelpemidler?.filter(
      (option: any) => hjaelpemiddel_ids?.includes(option.id)
    ) ?? [];

    const hjaelpemidlerText = selectedHjaelpemidler
      .map((option: any) => option.label)
      .join(", ");

    const hjaelpemiddelIdsText = selectedHjaelpemidler
      .map((option: any) => option.id)
      .join(",");

    const updatedAt = new Date().toISOString();

    const updatedBevillinger = bevillinger.map((bevilling: any) => {
      if (bevilling.bevilling_id !== bevillingId) {
        return bevilling;
      }

      return {
        ...bevilling,
        ...bevillingUpdates,

        updated_at: updatedAt,

        hjaelpemiddel_ids: hjaelpemiddelIdsText,
        hjaelpemidler: hjaelpemidlerText,

        status_tekst: statusOption?.label ?? bevilling.status_tekst,
        matrikel_navn: matrikelOption?.label ?? bevilling.matrikel_navn,
        hjemmel_tekst: hjemmelOption?.label ?? bevilling.hjemmel_tekst,
        afgoerelsesbrev_tekst: afgoerelsesbrevOption?.label ?? bevilling.afgoerelsesbrev_tekst,
        sagsbehandler_tekst: sagsbehandlerOption?.label ?? bevilling.sagsbehandler_tekst,
        ppr_sagsbehandler_tekst: pprSagsbehandlerOption?.label ?? bevilling.ppr_sagsbehandler_tekst
      };
    });

    bevillinger = updatedBevillinger;

    const mirroredStatus = getMirroredStamdataStatus(updatedBevillinger);

    stamdata = {
      ...stamdata,
      status_tekst: mirroredStatus.status_tekst,
      bevilling_id: mirroredStatus.bevilling_id
    };

    editableStamdata = {
      ...editableStamdata,
      status_tekst: mirroredStatus.status_tekst,
      bevilling_id: mirroredStatus.bevilling_id
    };

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

    const response = await fetch(`${API_URL}/bevilling/create_koerselsraekke/${bevillingId}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        ...koerselsraekkeData,
        tillaeg_ids: tillaeg_ids ?? [],
        dag_ids: dag_ids ?? []
      })
    });

    if (!response.ok) {
      alert("Kunne ikke oprette kørselsrække");
      return false;
    }

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

    const response = await fetch(`${API_URL}/bevilling/koerselsraekke/${koerselId}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(koerselsraekkeUpdates)
    });

    if (!response.ok) {
      alert("Kunne ikke gemme kørselsrække");
      return false;
    }

    const tillaegResponse = await fetch(`${API_URL}/bevilling/koerselsraekke/${koerselId}/tillaeg`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        tillaeg_ids: tillaeg_ids ?? []
      })
    });

    if (!tillaegResponse.ok) {
      alert("Kørselsrække blev gemt, men kørselstype tillæg kunne ikke gemmes");
      return false;
    }

    const dageResponse = await fetch(`${API_URL}/bevilling/koerselsraekke/${koerselId}/dage`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        dag_ids: dag_ids ?? []
      })
    });

    if (!dageResponse.ok) {
      alert("Kørselsrække blev gemt, men dage kunne ikke gemmes");
      return false;
    }

    const tidspunktOption = lookupOptions.tidspunkter?.find(
      (option: any) => option.id === koerselsraekkeUpdates.tidspunkt_id
    );

    const koerselstypeOption = lookupOptions.koerselstyper?.find(
      (option: any) => option.id === koerselsraekkeUpdates.befordringstype_id
    );

    const selectedTillaeg = lookupOptions.koerselstypeTillaeg?.filter(
      (option: any) => tillaeg_ids?.includes(option.id)
    ) ?? [];

    const selectedDage = lookupOptions.dage?.filter(
      (option: any) => dag_ids?.includes(option.id)
    ) ?? [];

    const tillaegText = selectedTillaeg
      .map((option: any) => option.label)
      .join(", ");

    const tillaegIdsText = selectedTillaeg
      .map((option: any) => option.id)
      .join(",");

    const dageText = selectedDage
      .map((option: any) => option.label)
      .join(", ");

    const dagIdsText = selectedDage
      .map((option: any) => option.id)
      .join(",");

    bevillinger = bevillinger.map((bevilling: any) => {
      return {
        ...bevilling,

        koerselsraekker: (bevilling.koerselsraekker ?? []).map((koerselsraekke: any) => {
          if (koerselsraekke.koersel_id !== koerselId) {
            return koerselsraekke;
          }

          return {
            ...koerselsraekke,
            ...koerselsraekkeUpdates,

            tidspunkt_tekst: tidspunktOption?.label ?? koerselsraekke.tidspunkt_tekst,
            befordringstype_tekst: koerselstypeOption?.label ?? koerselsraekke.befordringstype_tekst,

            tillaeg_ids: tillaegIdsText,
            tillaeg_tekst: tillaegText,

            dag_ids: dagIdsText,
            dage: dageText
          };
        })
      };
    });

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

    <div class="mb-4 flex items-center justify-between">

      <h2 class="text-xl font-bold">
        Bevillinger
      </h2>

      <button
        type="button"
        class="rounded bg-sky-500 px-4 py-2 text-sm text-white hover:bg-sky-600"
        on:click={() => showCreateBevillingModal = true}
      >
        + Ny bevilling
      </button>

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
              Status
              <select
                class="mt-1 w-full border px-2 py-1"
                bind:value={newBevilling.status_id}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.statuser ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
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
              Begrundelse fra formular

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

            <label class="text-sm col-span-2">
              Noter
              <textarea
                class="mt-1 w-full border px-2 py-1"
                rows="3"
                bind:value={newBevilling.noter}
              ></textarea>
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
              Annuller
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