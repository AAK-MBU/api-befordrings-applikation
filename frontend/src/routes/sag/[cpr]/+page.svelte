<script lang="ts">
  import DataTable from "$lib/components/DataTable.svelte";

	import KoerselsraekkeTable from "$lib/components/KoerselsraekkeTable.svelte";

	import EditCell from "$lib/components/cells/EditCell.svelte";
	import DeleteCell from "$lib/components/cells/DeleteCell.svelte";

  import { statusBadgeClasses } from "$lib/tableColumnConfig";
  
  export let data;


	let creatingKoerselsraekkeFor: number | null = null;
	let newKoerselsraekke: any = {};

	let editingBevillingId: number | null = null;
	let editableBevilling: any = {};
  
	let { stamdata, parents, citizenBevillinger } = data;
  
  let activeTab = "stamdata";
  
  let isEditing = false;
  
  let editableStamdata = { ...stamdata };
  
  const stamdataColumns = [
    { key: "sags_id", label: "Sags-ID", editable: false },
    { key: "status", label: "Status",
      render: (row: any) => {
        const value = row.status ?? "";
        const lower = value.toLowerCase();

        const colorClass =
          statusBadgeClasses[lower] ?? statusBadgeClasses.default;

        return `
          <span class="inline-flex items-center rounded-full px-3 py-1 text-xs font-medium ${colorClass}">
            ${value}
          </span>
        `;
      }
    },
    { key: "folkeregisteradresse", label: "Folkeregisteradresse" },
    { key: "skole", label: "Skole" },
    { key: "skolematrikel", label: "Skolematrikel" },
    { key: "gaaafstand_km", label: "Afstand (km)" },
    { key: "klasseart", label: "Klasseart" },
    { key: "klassebetegnelse", label: "Klasse" },
    { key: "personligt_klassetrin", label: "Klassetrin" },
    { key: "sfo", label: "SFO" },
    { key: "bopaelsdistrikt", label: "Bopælsdistrikt" }
  ];

  const parentsColumns = [
    { key: "navn", label: "Navn" },
    { key: "cpr", label: "Cpr-nummer" },
    { key: "folkeregisteradresse", label: "Folkeregisteradresse" },
    { key: "foraeldremyndig", label: "Forældremyndighed" },
    { key: "navne_og_adressebeskyttelse", label: "Beskyttelse" },
  ];

  const bevillingColumns = [


		{
			key: "edit",
			label: "",
			filterable: false,
			component: EditCell
		},

		{
			key: "delete",
			label: "",
			filterable: false,
			component: DeleteCell
		},

    {
      key: "status",
      label: "Status",
      render: (row: any) => {
        const value = row.status ?? "";
        const lower = value.toLowerCase();

        const colorClass =
          statusBadgeClasses[lower] ?? statusBadgeClasses.default;

        return `
          <span class="inline-flex items-center rounded-full px-3 py-1 text-xs font-medium ${colorClass}">
            ${value}
          </span>
        `;
      }
    },
    { key: "sagsbehandlingsdato", label: "Sagsbehandlingsdato" },
    { key: "adresse_for_bevilling", label: "Bevillingsadresse" },
    { key: "skole", label: "Skole" },
    { key: "gaaafstand_km", label: "Gåafstand (km)" },
    { key: "hjaelpemidler", label: "Hjælpemidler" },
    { key: "afstandskriterie_dato", label: "Afstandskriterie dato" },
    { key: "afstandskriterie_klassetrin", label: "Afstandskriterie klassetrin" },
    { key: "ansoeger_relation", label: "Ansøger relation" },
    { key: "revurdering", label: "Revurdering" },
    { key: "befordringsudvalg", label: "Befordringsudvalg" },
    { key: "hjemmel", label: "Hjemmel" },
    { key: "afgoerelsesbrev", label: "Afgørelsesbrev" },
    { key: "sagsbehandler", label: "Sagsbehandler" },
    { key: "ppr_ansvarlig", label: "PPR ansvarlig" },

  ];

  async function save() {

		console.log("SENDING:", editableStamdata);

    const res = await fetch(
      `http://localhost:8000/citizen/stamdata/${stamdata.barnets_cpr}`,
      {
        method: "PUT",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify(editableStamdata)
      }
    );

    if (!res.ok) {
      alert("Noget gik galt");
      return;
    }

    Object.assign(stamdata, editableStamdata);

    isEditing = false;
  }

    let showBevillingModal = false;

    let newBevilling = {
        barnets_fulde_navn: stamdata.barnets_fulde_navn,
        status: "Aktiv",
        sagsbehandlingsdato: "",
        adresse_for_bevilling: "Test Adresse 123",
        skole: "Test Skole",
        gaaafstand_km: "10",
        hjaelpemidler: "Ingen",
        afstandskriterie_dato: "2026-03-01",
        afstandskriterie_klassetrin: "5",
        ansoeger_relation: "Forælder",
        revurdering: "2026-06-01",
        befordringsudvalg: "2026-06-01",
        hjemmel: "§26",
        afgoerelsesbrev: "Standard",
        sagsbehandler: "Test Sagsbehandler",
        ppr_ansvarlig: "Test PPR"
    };

    async function submitNewBevilling() {

        try {

            const res = await fetch(
                `http://localhost:8000/bevilling/create_bevilling/${stamdata.barnets_cpr}`,
                {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify(newBevilling)
                }
            );

            console.log("FETCH DONE", res);

            if (!res.ok) {
                console.error("Response not OK", res);
                alert("Kunne ikke oprette bevilling");

                return;
            }

            const created = await res.json();

            console.log("CREATED:", created);

            citizenBevillinger = [created, ...citizenBevillinger];

            showBevillingModal = false;

        } catch (err) {

            console.error("FETCH ERROR:", err);

            alert("Fetch fejlede - se console");

        }

    }

    function handleDeleteClick(event: MouseEvent | KeyboardEvent) {

        const target = event.target as HTMLElement;

        if (target.tagName === "BUTTON" && target.dataset.id) {

            const id = Number(target.dataset.id);

            deleteBevilling(id);

        }

    }


    async function deleteBevilling(bevilling_id: number) {

        const confirmed = confirm("Er du sikker på at du vil slette bevillingen?");

        if (!confirmed) return;

        try {

            const res = await fetch(
                `http://localhost:8000/bevilling/${bevilling_id}`,
                {
                    method: "DELETE"
                }
            );

            if (!res.ok) {
                alert("Kunne ikke slette bevilling");
                return;
            }

            // 👇 remove from UI instantly
            citizenBevillinger = citizenBevillinger.filter((b: any) => b.bevilling_id !== bevilling_id);

        } catch (err) {

            console.error(err);

            alert("Fejl ved sletning");

        }

    }


	function handleEdit(row: any) {

		editingBevillingId = row.bevilling_id;

		editableBevilling = { ...row };

	}

	function handleCancel() {

		editingBevillingId = null;
		editableBevilling = {};

	}

	async function handleSave(row: any) {

		try {

			console.log("SENDING:", editableBevilling);

			const res = await fetch(
				`http://localhost:8000/bevilling/${row.bevilling_id}`,
				{
					method: "PUT",
					headers: {
						"Content-Type": "application/json"
					},
					body: JSON.stringify(editableBevilling)
				}
			);

			if (!res.ok) {
				alert("Kunne ikke opdatere");
				return;
			}

			// update UI
			citizenBevillinger = citizenBevillinger.map((b: any) =>
				b.bevilling_id === row.bevilling_id
					? { ...b, ...editableBevilling }
					: b
			);

			editingBevillingId = null;

		} catch (err) {

			console.error(err);

		}

	}


	function handleInputChange(key: string, value: any) {

		editableBevilling = {
			...editableBevilling,
			[key]: value
		};

	}

	function handleStamdataChange(key: string, value: any) {

		editableStamdata = {
			...editableStamdata,
			[key]: value
		};

	}

	function handleNewKoerselsraekkeChange(key: string, value: any) {

		newKoerselsraekke = {
			...newKoerselsraekke,
			[key]: value
		};

	}



	function handleCreateKoerselsraekke(bevilling_id: number) {

		creatingKoerselsraekkeFor = bevilling_id;

		newKoerselsraekke = {
			tidspunkt: "",
			koerselstype: "",
			koerselstype_tillaeg: "",
			bevilget_koereafstand_pr_vej: "",
			dage: "",
			bevilling_fra: "",
			bevilling_til: "",
			taxa_id: "",
			kommentar: ""
		};

	}



	async function handleSaveNewKoerselsraekke(bevilling_id: number) {

		try {

			const res = await fetch(
				`http://localhost:8000/bevilling/create_koerselsraekke/${bevilling_id}`,
				{
					method: "POST",
					headers: {
						"Content-Type": "application/json"
					},
					body: JSON.stringify(newKoerselsraekke)
				}
			);

			if (!res.ok) {
				alert("Kunne ikke oprette");
				return;
			}

			const created = await res.json();

			citizenBevillinger = citizenBevillinger.map((b: any) =>
				b.bevilling_id === bevilling_id
					? {
							...b,
							koerselsraekker: [
								...(b.koerselsraekker ?? []),
								created
							]
						}
					: b
			);

			creatingKoerselsraekkeFor = null;
			newKoerselsraekke = {};

		} catch (err) {

			console.error(err);

		}

	}

	function handleCancelNewKoerselsraekke() {

		creatingKoerselsraekkeFor = null;
		newKoerselsraekke = {};

	}



</script>


<!-- TABS -->
<div class="mb-4 border-b">
  <button
    class="mr-4 pb-2"
    class:font-bold={activeTab === "stamdata"}
    on:click={() => (activeTab = "stamdata")}
  >
    Stamdata
  </button>

  <button
    class="pb-2"
    class:font-bold={activeTab === "bevillinger"}
    on:click={() => (activeTab = "bevillinger")}
  >
    Bevillinger
  </button>
</div>


<!-- HEADER -->
<div class="bg-white p-6 rounded border mb-6">

  {#if stamdata.navne_adresse_beskyttelse}
    <div class="bg-red-100 text-red-700 px-3 py-2 mb-4 rounded">
      Vær opmærksom på at barnet har navne- og/eller adressebeskyttelse
    </div>
  {/if}

  <h2 class="text-lg font-semibold">
    {stamdata.barnets_fulde_navn}
    <span class="ml-2 text-gray-600 font-normal">
      {stamdata.barnets_cpr}
    </span>
  </h2>

</div>



{#if activeTab === "stamdata"}

  <!-- ACTION BUTTONS -->
  <div class="mb-4 flex gap-2">

    {#if !isEditing}
      <button
        class="bg-blue-500 text-white px-4 py-2 rounded"
        on:click={() => isEditing = true}
      >
        Rediger
      </button>
    {:else}
      <button
        class="bg-green-500 text-white px-4 py-2 rounded"
        on:click={save}
      >
        Gem
      </button>

      <button
        class="bg-gray-300 px-4 py-2 rounded"
        on:click={() => {
          isEditing = false;
          editableStamdata = { ...stamdata };
        }}
      >
        Annuller
      </button>
    {/if}

  </div>

  <!-- TABLE -->
  <DataTable
		data={[stamdata]}
		columns={stamdataColumns}
		filterable={false}
		editableRow={editableStamdata}
		isEditing={isEditing}
	  onInputChange={handleStamdataChange}
  />

  <!-- PARENTS stays as-is -->
  <div class="bg-white p-6 rounded border mt-6">

    <h2 class="text-lg font-semibold mb-4">
      Oplysninger om forældre
    </h2>

    <!-- TABLE -->
    <DataTable
      data={parents}
      columns={parentsColumns}
      filterable={false}
    />

  </div>

{/if}



{#if activeTab === "bevillinger"}

  <!-- ACTION BUTTONS -->
  <div class="mb-4 flex justify-end gap-2">

        <button
            class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
            on:click={() => showBevillingModal = true}
        >
            + Ny bevilling
        </button>

  </div>

    <div
        on:click={handleDeleteClick}
        role="button"
        tabindex="0"
        on:keydown={(e) => e.key === "Enter" && handleDeleteClick(e)}
    >

        <DataTable
            data={citizenBevillinger}
            columns={bevillingColumns}
            filterable={true}
            expandable={true}
						deleteBevilling={deleteBevilling}
						onEdit={handleEdit}
						onSave={handleSave}
						onCancel={handleCancel}
						editingBevillingId={editingBevillingId}
						editableRow={editableBevilling}
						renderExpanded={KoerselsraekkeTable}

						onCreate={handleCreateKoerselsraekke}

						creatingFor={creatingKoerselsraekkeFor}
						newRow={newKoerselsraekke}

						onInputChange={handleNewKoerselsraekkeChange}
						onSaveNew={handleSaveNewKoerselsraekke}
						onCancelNew={handleCancelNewKoerselsraekke}


        />

    </div>


    {#if showBevillingModal}

        <div class="fixed inset-0 bg-black/30 flex items-center justify-center">

            <div class="bg-white p-6 rounded w-[600px] max-h-[80vh] overflow-y-auto">

                <h2 class="text-lg font-semibold mb-4">
                    Opret bevilling
                </h2>

                <!-- Example fields -->
                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Adresse for bevilling"
                    bind:value={newBevilling.adresse_for_bevilling}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Skole"
                    bind:value={newBevilling.skole}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Gåafstand (km)"
                    bind:value={newBevilling.gaaafstand_km}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Hjælpemidler"
                    bind:value={newBevilling.hjaelpemidler}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Afstandskriterie dato"
                    bind:value={newBevilling.afstandskriterie_dato}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Afstandskriterie klassetrin"
                    bind:value={newBevilling.afstandskriterie_klassetrin}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Ansøger relation"
                    bind:value={newBevilling.ansoeger_relation}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Revurdering"
                    bind:value={newBevilling.revurdering}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Befordringsudvalg"
                    bind:value={newBevilling.befordringsudvalg}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Hjemme"
                    bind:value={newBevilling.hjemmel}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Afgørelsesbrev"
                    bind:value={newBevilling.afgoerelsesbrev}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="Sagsbehandler"
                    bind:value={newBevilling.sagsbehandler}
                />

                <input
                    class="border p-2 w-full mb-2"
                    placeholder="PPR ansvarlig"
                    bind:value={newBevilling.ppr_ansvarlig}
                />


                <!-- Add more fields gradually -->

                <div class="flex justify-end gap-2 mt-4">

                    <button
                        class="bg-gray-300 px-4 py-2 rounded"
                        on:click={() => showBevillingModal = false}
                    >
                        Annuller
                    </button>

                    <button
                        class="bg-green-500 text-white px-4 py-2 rounded"
                        on:click={submitNewBevilling}
                    >
                        Gem
                    </button>

                </div>

            </div>

        </div>

    {/if}


{/if}
