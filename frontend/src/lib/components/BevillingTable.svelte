<script lang="ts">
  import { page } from "$app/stores";
  import { onMount } from "svelte";
  import KoerselsraekkeTable from "$lib/components/KoerselsraekkeTable.svelte";
  import AddresseSearch from "$lib/components/AddresseSearch.svelte";

  import {
    getStatusBadgeClass,
    formatDanishDate,
  } from "$lib/tableColumnConfig";
  import { filterHjemler, filterAfgoerelsesbreve, isMidlertidigKoersel } from "$lib/lookupFilters";
  import {
    AFSTANDSKRITERIE_KLASSETRIN,
    beregnAfstandskriterieDato,
    beregnAfstandskriterieKlassetrin
  } from "$lib/afstandskriterie";

  import { ansoegerRelationOptions } from "$lib/ansoegerRelation";
  import { isEgenbefordring as typeIsEgenbefordring } from "$lib/koerselstype";
  import { afstandFraKoordinater } from "$lib/client/afstand";
  const minDate = new Date(new Date().getFullYear() - 10, 0, 1).toISOString().slice(0, 10);
  const maxDate = new Date(new Date().getFullYear() + 10, 11, 31).toISOString().slice(0, 10);

  function isDateOutOfRange(value: string | null | undefined): boolean {
    return !!value && (value < minDate || value > maxDate);
  }

  // -----------------------------
  // Props
  // -----------------------------

  export let bevillinger: any[] = [];

  export let lookupOptions: any = {
    statuser: [],
    skolematrikler: [],
    hjemler: [],
    afgoerelsesbreve: [],
    sagsbehandlere: [],
    pprSagsbehandlere: [],
    hjaelpemidler: []
  };

  export let onSaveBevilling: (
    bevillingId: number,
    updates: any
  ) => Promise<string | null>;

  export let onSaveKoerselsraekke: (
    koerselId: number,
    updates: any
  ) => Promise<string | null> = async () => null;

  export let onCreateKoerselsraekke: (
    bevillingId: number,
    updates: any
  ) => Promise<string | null>;

  export let onFinalizeKoerselsraekke: (
    koerselId: number
  ) => Promise<string | null> = async () => null;

  export let readonlyKoerselsraekker: boolean = false;

  // Optional delete handlers — if not provided, delete buttons are hidden.
  // Wire these up from the parent page only for users with the correct role.
  export let onDeleteBevilling: ((bevillingId: number) => Promise<string | null>) | undefined = undefined;
  export let onDeleteKoerselsraekke: ((koerselId: number) => Promise<string | null>) | undefined = undefined;

  // Parties on the case, passed straight through to KoerselsraekkeTable so the
  // egenbefordring kørselsrække can name who receives the kilometre
  // reimbursement. Empty by default: a page that does not load parter simply
  // gets an empty dropdown rather than an error.
  export let parter: any[] = [];

  // Optional lock handler — if not provided, the lock control is hidden, the
  // same way the delete buttons are. Takes the *target* state so one handler
  // covers both locking and unlocking.
  export let onSetBevillingLock:
    | ((bevillingId: number, final: boolean) => Promise<string | null>)
    | undefined = undefined;

  
  // -----------------------------
  // Table state
  // -----------------------------

  let expandedRows = new Set<number>();

  // On load, auto-expand the active bevilling (or the newest one if none is
  // active) so its kørselsrækker are visible immediately. The others stay
  // collapsed — their status is still shown in the row header.
  onMount(() => {
    const target = bevillinger.find((b) => b.status_tekst === "Aktiv") ?? bevillinger[0];
    if (target?.bevilling_id != null) {
      expandedRows = new Set([target.bevilling_id]);
    }
  });

  let editingBevillingId: number | null = null;
  let editableBevilling: any = {};
  let editError: string | null = null;

  // From $page rather than a prop: this component is nested and a module-level
  // store would be shared across concurrent SSR requests. See ReadOnlyNotice.
  $: canEdit = $page.data.user?.can_edit ?? false;

  let selectedHjaelpemiddelIds: number[] = [];
  let hjaelpemiddelSelectValue = "";

  // -----------------------------
  // Delete state
  // -----------------------------

  let confirmingDeleteBevillingId: number | null = null;
  let isDeleting = false;
  let deleteError: string | null = null;

  async function doDeleteBevilling() {
    if (isDeleting || confirmingDeleteBevillingId === null || !onDeleteBevilling) return;
    isDeleting = true;
    deleteError = null;

    const error = await onDeleteBevilling(confirmingDeleteBevillingId);

    isDeleting = false;

    // deleteError is rendered inside this dialog, so the dialog has to outlive
    // the failure. Closing it first — as this did — discarded the reason and
    // made a refused delete look exactly like a successful one.
    if (error) {
      deleteError = error;
      return;
    }

    confirmingDeleteBevillingId = null;
  }


  // -----------------------------
  // Lock / unlock state
  // -----------------------------

  // Holds the bevilling being confirmed *and* the state it is moving to, so one
  // dialog serves both directions.
  let confirmingLock: { bevillingId: number; final: boolean } | null = null;
  let lockedEditBevilling: any | null = null;
  let isSettingLock = false;
  let lockError: string | null = null;

  async function doSetBevillingLock() {
    if (isSettingLock || confirmingLock === null || !onSetBevillingLock) return;
    isSettingLock = true;
    lockError = null;

    const error = await onSetBevillingLock(confirmingLock.bevillingId, confirmingLock.final);

    isSettingLock = false;

    // Same reasoning as doDeleteBevilling: the error renders inside the dialog,
    // so the dialog has to outlive the failure.
    if (error) {
      lockError = error;
      return;
    }

    confirmingLock = null;
  }


  // -----------------------------
  // Styling
  // -----------------------------

  const inputClass = "border border-gray-300 px-2 py-1 text-sm rounded focus:border-blue-400 focus:ring-0";
  const mediumSelectClass = "w-full border border-gray-300 px-2 py-1 pr-8 text-sm rounded focus:border-blue-400 focus:ring-0";
  const largeSelectClass = "w-full border border-gray-300 px-2 py-1 pr-8 text-sm rounded focus:border-blue-400 focus:ring-0";

  function getStatusBemaerkningClass(status: string | null | undefined): string {
    switch (status) {
      case "Fejlet":       return "bg-red-50 text-red-700 border border-red-200";
      case "Revurdering":  return "bg-amber-50 text-amber-700 border border-amber-200";
      case "Afslag":       return "bg-orange-50 text-orange-700 border border-orange-200";
      case "Ophørt":       return "bg-gray-100 text-gray-600 border border-gray-300";
      case "Udløbet":      return "bg-gray-100 text-gray-600 border border-gray-300";
      default:             return "bg-blue-50 text-blue-700 border border-blue-200";
    }
  }

  function getStatusBemaerkningIcon(status: string | null | undefined): string {
    switch (status) {
      case "Fejlet":      return "error";
      case "Revurdering": return "warning";
      case "Afslag":      return "warning";
      default:            return "info";
    }
  }


  // -----------------------------
  // Derived state
  // -----------------------------

  $: availableHjaelpemidler = (lookupOptions.hjaelpemidler ?? []).filter(
    (option: any) => !selectedHjaelpemiddelIds.includes(Number(option.id))
  );


  // -----------------------------
  // Small helpers
  // -----------------------------

  function numberOrNull(value: string) {
    if (value === "") {
      return null;
    }

    return Number(value);
  }

  function emptyToNull(value: string) {
    if (value === "") {
      return null;
    }

    return value;
  }


  function parseHjaelpemiddelIds(rawValue: string | null | undefined) {
    if (!rawValue) {
      return [];
    }

    return rawValue
      .split(",")
      .map((value) => Number(value))
      .filter((value) => !Number.isNaN(value));
  }


  function getHjaelpemiddelLabel(id: number) {
    const option = lookupOptions.hjaelpemidler?.find(
      (item: any) => Number(item.id) === Number(id)
    );

    return option?.label ?? id;
  }


  // -----------------------------
  // Expand/collapse
  // -----------------------------

  function toggleRow(bevillingId: number) {
    if (expandedRows.has(bevillingId)) {
      expandedRows.delete(bevillingId);
    } else {
      expandedRows.add(bevillingId);
    }

    expandedRows = new Set(expandedRows);
  }


  // -----------------------------
  // Hjælpemiddel selection
  // -----------------------------

  function addHjaelpemiddel() {
    if (hjaelpemiddelSelectValue === "") {
      return;
    }

    const id = Number(hjaelpemiddelSelectValue);

    if (!selectedHjaelpemiddelIds.includes(id)) {
      selectedHjaelpemiddelIds = [
        ...selectedHjaelpemiddelIds,
        id
      ];
    }

    hjaelpemiddelSelectValue = "";
  }


  function removeHjaelpemiddel(id: number) {
    selectedHjaelpemiddelIds = selectedHjaelpemiddelIds.filter(
      (existingId) => existingId !== Number(id)
    );

    hjaelpemiddelSelectValue = "";
  }


  // -----------------------------
  // Egenbefordring auto-recalculation
  // -----------------------------

  // Was a local copy that compared against 'egenbefordring' without stripping
  // whitespace, so it never matched the seeded label "Egen befordring" and this
  // whole recalculation silently did nothing. Now shared with the two forms.
  const isEgenbefordringType = (typeId: number | null | undefined) =>
    typeIsEgenbefordring(lookupOptions.koerselstyper, typeId);

  function parseIds(raw: string | null | undefined): number[] {
    if (!raw) return [];
    return raw.split(',').map(Number).filter(n => !isNaN(n));
  }

  async function recalculateEgenbefordringRows(
    koerselsraekker: any[],
    lat1: number,
    lon1: number,
    matrikel: number
  ) {
    const egenRows = koerselsraekker.filter(k => isEgenbefordringType(k.befordringstype_id));
    if (egenRows.length === 0) return;

    // The address is already geocoded by the caller, so this skips straight to
    // the school lookup. Failures stay silent here on purpose: the bevilling
    // itself saved fine, and this is a best-effort follow-up.
    const { km: distance_km, error } = await afstandFraKoordinater(lat1, lon1, matrikel);
    if (error !== null) return;

    // Update each egenbefordring row
    for (const koersel of egenRows) {
      await onSaveKoerselsraekke(koersel.koersel_id, {
        tidspunkt_id: koersel.tidspunkt_id,
        befordringstype_id: koersel.befordringstype_id,
        bevilget_koereafstand_pr_vej: distance_km,
        gyldig_fra: koersel.gyldig_fra,
        gyldig_til: koersel.gyldig_til,
        taxa_id: koersel.taxa_id,
        kommentar: koersel.kommentar,
        tillaeg_ids: parseIds(koersel.tillaeg_ids),
        dag_ids: parseIds(koersel.dag_ids)
      });
    }
  }


  // -----------------------------
  // Bevilling edit handling
  // -----------------------------

  const manualStatusLabels = ["Afslag", "Ophørt"];

  $: manualStatuser = (lookupOptions.statuser ?? []).filter(
    (s: any) => manualStatusLabels.includes(s.label)
  );

  function startEdit(bevilling: any) {
    // A locked bevilling is not read-only, but editing it should be a decision
    // rather than a reflex — same guard the kørselsrække table puts on its own
    // locked rows.
    if (bevilling.final) {
      lockedEditBevilling = bevilling;
      return;
    }

    beginEdit(bevilling);
  }

  function doLockedEdit() {
    if (!lockedEditBevilling) return;
    const bevilling = lockedEditBevilling;
    lockedEditBevilling = null;
    beginEdit(bevilling);
  }

  function beginEdit(bevilling: any) {
    editingBevillingId = bevilling.bevilling_id;

    // Only pre-select a status if it's one of the manual ones.
    // Otherwise show "Auto" so computed statuses aren't editable.
    const isManualStatus = manualStatusLabels.includes(bevilling.status_tekst);
    editableBevilling = {
      ...bevilling,
      status_id:    isManualStatus ? bevilling.status_id : null,
      // Address fields — adresse_for_bevilling is the text alias from the view
      adresse_id:   bevilling.adresse_id   ?? null,
      adresse_tekst: bevilling.adresse_for_bevilling ?? "",
      adresse_lat:  bevilling.adresse_latitude  ?? null,
      adresse_lon:  bevilling.adresse_longitude ?? null,
    };

    // Derive the afstandskriterie fields where there is nothing to overwrite.
    // A stored value is left alone — it may have been set deliberately — but
    // the computed one is offered next to the field, see brugBeregnet().
    const beregnetKlassetrin = beregnAfstandskriterieKlassetrin(bevilling.elevklassetrin);
    const beregnetDato = beregnAfstandskriterieDato(bevilling.elevklassetrin);

    if (beregnetKlassetrin !== null && editableBevilling.afstandskriterie_klassetrin == null) {
      editableBevilling.afstandskriterie_klassetrin = beregnetKlassetrin;
    }

    if (beregnetDato !== null && !editableBevilling.afstandskriterie_dato) {
      editableBevilling.afstandskriterie_dato = beregnetDato;
    }

    selectedHjaelpemiddelIds = parseHjaelpemiddelIds(
      bevilling.hjaelpemiddel_ids
    );

    hjaelpemiddelSelectValue = "";
  }

  /**
   * The derived afstandskriterie values for the bevilling being edited, or null
   * when there is nothing to offer — no klassetrin to derive from, or the
   * entered values already match.
   *
   * A reactive statement rather than a call in the markup: it is read under two
   * separate fields, and this way both re-evaluate when editableBevilling
   * changes, so the offer disappears from both the moment it is applied.
   */
  $: beregnetForslag = beregnForslag(editableBevilling);

  function beregnForslag(edit: any): { klassetrin: number; dato: string } | null {
    const klassetrin = beregnAfstandskriterieKlassetrin(edit?.elevklassetrin);
    const dato = beregnAfstandskriterieDato(edit?.elevklassetrin);

    if (klassetrin === null || dato === null) {
      return null;
    }

    const uaendret =
      Number(edit.afstandskriterie_klassetrin) === klassetrin &&
      String(edit.afstandskriterie_dato ?? "").slice(0, 10) === dato;

    return uaendret ? null : { klassetrin, dato };
  }

  /** Overwrite both afstandskriterie fields with the derived values. */
  function brugBeregnet() {
    if (!beregnetForslag) return;

    updateField("afstandskriterie_klassetrin", beregnetForslag.klassetrin);
    updateField("afstandskriterie_dato", beregnetForslag.dato);
  }


  function cancelEdit() {
    editingBevillingId = null;
    editableBevilling = {};
    editError = null;

    selectedHjaelpemiddelIds = [];
    hjaelpemiddelSelectValue = "";
  }


  function updateField(key: string, value: any) {
    editableBevilling = {
      ...editableBevilling,
      [key]: value
    };
  }


  async function saveEdit(bevilling: any) {
    editError = null;
    const dateFields: [string | null | undefined, string][] = [
      [editableBevilling.sagsbehandlingsdato,   'Sagsbehandlingsdato'],
      [editableBevilling.afstandskriterie_dato,  'Afstandskriterie dato'],
      [editableBevilling.revurderingsdato,       'Revurderingsdato'],
      [editableBevilling.befordringsudvalg,      'Befordringsudvalg'],
    ];
    for (const [value, label] of dateFields) {
      if (isDateOutOfRange(value)) {
        editError = `${label}: Dato er ugyldig — kontrollér årstallet`;
        return;
      }
    }

    // null status_id means the user selected "Auto" — ask the SP to recalculate
    // freely instead of sending a manual status_id.
    const statusField = editableBevilling.status_id
      ? { status_id: editableBevilling.status_id }
      : { reset_status: true };

    const updates = {
      ...statusField,
      sagsbehandlingsdato: editableBevilling.sagsbehandlingsdato,
      adresse_id: editableBevilling.adresse_id,
      matrikel_id: editableBevilling.matrikel_id,
      afstandskriterie_dato: editableBevilling.afstandskriterie_dato,
      afstandskriterie_klassetrin: editableBevilling.afstandskriterie_klassetrin,
      relation_til_barnet: editableBevilling.relation_til_barnet,
      revurderingsdato: editableBevilling.revurderingsdato,
      befordringsudvalg: editableBevilling.befordringsudvalg,
      hjemmel_id: editableBevilling.hjemmel_id,
      afgoerelsesbrev_id: editableBevilling.afgoerelsesbrev_id,
      sagsbehandler_id: editableBevilling.sagsbehandler_id,
      ppr_sagsbehandler_id: editableBevilling.ppr_sagsbehandler_id,

      // Saving an edit clears the lock, exactly as saveEdit does in
      // KoerselsraekkeTable. Confirming the locked-edit warning only *starts*
      // the edit; the unlock is not written until Gem, so Annullér leaves the
      // bevilling locked. Harmless on a bevilling that was not locked.
      final: false,

      hjaelpemiddel_ids: selectedHjaelpemiddelIds
    };

    const addressChanged = editableBevilling.adresse_id !== bevilling.adresse_id;
    const schoolChanged  = editableBevilling.matrikel_id !== bevilling.matrikel_id;
    const koerselsraekker = [...(bevilling.koerselsraekker ?? [])];
    const newMatrikelId   = editableBevilling.matrikel_id;
    const adresseLat      = editableBevilling.adresse_lat;
    const adresseLon      = editableBevilling.adresse_lon;

    const error = await onSaveBevilling(bevilling.bevilling_id, updates);
    if (error) {
      editError = error;
    } else {
      if ((addressChanged || schoolChanged) && newMatrikelId && adresseLat && adresseLon) {
        await recalculateEgenbefordringRows(koerselsraekker, adresseLat, adresseLon, newMatrikelId);
      }
      cancelEdit();
    }
  }
</script>


<div class="space-y-4">

  {#if bevillinger.length === 0}
    <div class="bg-white border border-gray-200 rounded-lg p-8 text-center text-gray-500 text-sm">
      Ingen bevillinger fundet.
    </div>
  {:else}

    {#each bevillinger as bevilling}

      {@const isEditing = editingBevillingId === bevilling.bevilling_id}
      {@const isExpanded = expandedRows.has(bevilling.bevilling_id)}
      {@const koerselCount = bevilling.koerselsraekker?.length ?? 0}

      <div class="bg-white border border-gray-300 rounded-lg shadow overflow-hidden">

        <!-- Card header -->
        <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <div class="flex items-center gap-3">
            <span class="font-mono text-xs bg-[#032A42] text-white rounded px-2 py-0.5">Bevilling #{bevilling.bevilling_id}</span>
            <span class="text-gray-300 select-none">|</span>
            {#if isEditing}
              <select
                class="border border-gray-300 px-2 py-1 pr-6 text-sm rounded focus:border-blue-400 focus:ring-0"
                value={editableBevilling.status_id ?? ""}
                on:change={(e) => updateField("status_id", numberOrNull(e.currentTarget.value))}
              >
                <option value="">Auto (beregnet automatisk)</option>
                {#each manualStatuser as option}
                  <option value={option.id}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <span class="inline-block px-2 py-0.5 rounded text-xs font-medium {getStatusBadgeClass(bevilling.status_tekst)}">
                {bevilling.status_tekst ?? ""}
              </span>
              {#if bevilling.revurdering}
                <span class="inline-block px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-700" title={bevilling.statusbemaerkning ?? ''}>
                  Revurdering
                </span>
              {/if}
              {#if bevilling.statusbemaerkning}
                <span class="inline-flex items-center gap-1.5 rounded px-2 py-0.5 text-xs font-medium {getStatusBemaerkningClass(bevilling.revurdering ? 'Revurdering' : bevilling.status_tekst)}">
                  {#if getStatusBemaerkningIcon(bevilling.revurdering ? 'Revurdering' : bevilling.status_tekst) === "error"}
                    <!-- X-circle -->
                    <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <circle cx="12" cy="12" r="9"/>
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 9l-6 6M9 9l6 6"/>
                    </svg>
                  {:else if getStatusBemaerkningIcon(bevilling.revurdering ? 'Revurdering' : bevilling.status_tekst) === "warning"}
                    <!-- Triangle warning -->
                    <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v4m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
                    </svg>
                  {:else}
                    <!-- Info circle -->
                    <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <circle cx="12" cy="12" r="9"/>
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 8h.01M12 12v4"/>
                    </svg>
                  {/if}
                  {bevilling.statusbemaerkning}
                </span>
              {/if}
            {/if}
            <span class="font-mono text-sm text-gray-500">{bevilling.esdh_noegle ?? ""}</span>
          </div>

          <div class="flex items-center gap-2">
            {#if isEditing}
              <button
                type="button"
                disabled={!editableBevilling.adresse_id}
                class="px-3 py-1.5 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-green-600"
                on:click={() => saveEdit(bevilling)}
              >
                Gem
              </button>
              <button
                type="button"
                class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                on:click={cancelEdit}
              >
                Annullér
              </button>
              {#if !readonlyKoerselsraekker}
                <button
                  type="button"
                  class="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                  on:click={() => toggleRow(bevilling.bevilling_id)}
                >
                  Kørselsrækker {koerselCount}
                  <span class="text-xs opacity-60">{isExpanded ? "▲" : "▼"}</span>
                </button>
              {/if}
              {#if onDeleteBevilling}
                <span class="w-px h-5 bg-gray-200 mx-1"></span>
                <button
                  type="button"
                  title="Slet bevilling"
                  disabled={!canEdit}
                  class="p-1.5 text-gray-400 hover:text-red-600 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                  on:click={() => { confirmingDeleteBevillingId = bevilling.bevilling_id; deleteError = null; }}
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v
6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              {/if}
            {:else}
              <button
                type="button"
                disabled={!canEdit}
                class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                on:click={() => startEdit(bevilling)}
              >
                Redigér
              </button>
              {#if onSetBevillingLock}
                <span class="w-px h-5 bg-gray-200 mx-1"></span>
                <button
                  type="button"
                  title={bevilling.final ? "Lås bevilling op" : "Lås bevilling"}
                  disabled={!canEdit}
                  class="p-1.5 transition-colors disabled:opacity-40 disabled:cursor-not-allowed {bevilling.final ? 'text-amber-600 hover:text-amber-700' : 'text-gray-400 hover:text-gray-600'}"
                  on:click={() => { confirmingLock = { bevillingId: bevilling.bevilling_id, final: !bevilling.final }; lockError = null; }}
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d={bevilling.final ? "M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" : "M8 11V7a4 4 0 118 0m-4 8v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2z"} />
                  </svg>
                </button>
              {/if}
              {#if !readonlyKoerselsraekker}
                <button
                  type="button"
                  class="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                  on:click={() => toggleRow(bevilling.bevilling_id)}
                >
                  Kørselsrækker {koerselCount}
                  <span class="text-xs opacity-60">{isExpanded ? "▲" : "▼"}</span>
                </button>
              {/if}
            {/if}
          </div>
        </div>


        <!-- Card body: field grid -->
        <div class="px-4 md:px-6 py-5 grid grid-cols-1 sm:grid-cols-2 md:grid-cols-5 gap-x-6 gap-y-5">

          <!-- ANSØGNINGSTYPE -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Ansøgningstype</p>
            <p class="text-sm text-gray-800">{bevilling.ansoegningstype ?? "—"}</p>
          </div>

          <!-- OPRETTET -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Ansøgningsdato</p>
            <p class="text-sm text-gray-800">{formatDanishDate(bevilling.ansoegningsdato?.slice(0, 10))}</p>
          </div>

          <!-- SAGSBEHANDLINGSDATO -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Sagsbehandlingsdato</p>
            {#if isEditing}
              <input
                type="date"
                min={minDate} max={maxDate}
                class={inputClass}
                value={editableBevilling.sagsbehandlingsdato ?? ""}
                on:change={(e) => updateField("sagsbehandlingsdato", emptyToNull(e.currentTarget.value))}
              />
            {:else}
              <p class="text-sm text-gray-800">{formatDanishDate(bevilling.sagsbehandlingsdato)}</p>
            {/if}
          </div>

          <!-- ADRESSE FOR BEVILLING -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Adresse for bevilling</p>
            {#if isEditing}
              <AddresseSearch
                adresseId={editableBevilling.adresse_id}
                adresseTekst={editableBevilling.adresse_tekst ?? ""}
                inputClass={inputClass + " w-full"}
                onSelect={(result) => {
                  editableBevilling = {
                    ...editableBevilling,
                    adresse_id:    result?.adresse_id   ?? null,
                    adresse_tekst: result?.adresse_tekst ?? "",
                    adresse_lat:   result?.latitude      ?? null,
                    adresse_lon:   result?.longitude     ?? null,
                  };
                }}
              />
            {:else}
              <p class="text-sm text-gray-800">{bevilling.adresse_for_bevilling ?? "—"}</p>
            {/if}
          </div>

          <!-- SKOLE -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Skole</p>
            {#if isEditing}
              {#if editableBevilling.ungdomsuddannelse_id && !editableBevilling.matrikel_id}
                <select
                  class={largeSelectClass}
                  value={editableBevilling.ungdomsuddannelse_id ?? ""}
                  on:change={(e) => updateField("ungdomsuddannelse_id", numberOrNull(e.currentTarget.value))}
                >
                  <option value="">Vælg</option>
                  {#each lookupOptions.ungdomsuddannelser ?? [] as option}
                    <option value={option.id}>{option.label}</option>
                  {/each}
                </select>
              {:else}
                <select
                  class={largeSelectClass}
                  value={editableBevilling.matrikel_id ?? ""}
                  on:change={(e) => updateField("matrikel_id", numberOrNull(e.currentTarget.value))}
                >
                  <option value="">Vælg</option>
                  {#each lookupOptions.skolematrikler ?? [] as option}
                    <option value={option.id}>{option.label}</option>
                  {/each}
                </select>
              {/if}
            {:else}
              <p class="text-sm text-gray-800">
                {bevilling.skole_navn ?? bevilling.matrikel_navn ?? bevilling.ungdomsuddannelse_navn ?? "—"}
              </p>
              {#if bevilling.ungdomsuddannelse_id && !bevilling.matrikel_id}
                <span class="inline-block mt-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-slate-100 text-slate-600">
                  Ungdomsuddannelse
                </span>
              {/if}
            {/if}
          </div>

          <!-- HJÆLPEMIDLER -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Hjælpemidler</p>
            {#if isEditing}
              <div class="flex flex-wrap gap-1.5 mb-2">
                {#each selectedHjaelpemiddelIds as selectedId}
                  <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                    {getHjaelpemiddelLabel(selectedId)}
                    <button
                      type="button"
                      class="ml-0.5 text-red-500 hover:text-red-700 font-bold"
                      on:click={() => removeHjaelpemiddel(selectedId)}
                    >×</button>
                  </span>
                {/each}
              </div>
              <select
                class="min-w-44 border border-gray-300 px-2 py-1 pr-6 text-sm rounded"
                bind:value={hjaelpemiddelSelectValue}
                on:change={addHjaelpemiddel}
              >
                <option value="">Tilføj hjælpemiddel</option>
                {#each availableHjaelpemidler as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <p class="text-sm text-gray-800">{bevilling.hjaelpemidler ?? "—"}</p>
            {/if}
          </div>

          <!-- AFSTANDSKRITERIE DATO — not applicable to Midlertidig kørsel -->
          {#if !isMidlertidigKoersel(bevilling.ansoegningstype)}
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Afstandskriterie dato</p>
            {#if isEditing}
              <input
                type="date"
                min={minDate} max={maxDate}
                class={inputClass}
                value={editableBevilling.afstandskriterie_dato ?? ""}
                on:change={(e) => updateField("afstandskriterie_dato", emptyToNull(e.currentTarget.value))}
              />
              {#if beregnetForslag}
                <button
                  type="button"
                  class="mt-1 text-[11px] text-sky-700 hover:text-sky-900 underline decoration-dotted"
                  title="Sætter både dato og klassetrin ud fra elevens klassetrin"
                  on:click={brugBeregnet}
                >
                  Brug beregnet: {formatDanishDate(beregnetForslag.dato)} · klassetrin {beregnetForslag.klassetrin}
                </button>
              {/if}
            {:else}
              <p class="text-sm text-gray-800">{formatDanishDate(bevilling.afstandskriterie_dato)}</p>
            {/if}
          </div>
          {/if}

          <!-- AFSTANDSKRITERIE KLASSETRIN — not applicable to Midlertidig kørsel -->
          {#if !isMidlertidigKoersel(bevilling.ansoegningstype)}
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Afstandskriterie klassetrin</p>
            {#if isEditing}
              <select
                class={mediumSelectClass}
                value={editableBevilling.afstandskriterie_klassetrin ?? ""}
                on:change={(e) => updateField("afstandskriterie_klassetrin", numberOrNull(e.currentTarget.value))}
              >
                <option value="">Vælg</option>
                {#each AFSTANDSKRITERIE_KLASSETRIN as trin}
                  <option value={trin}>{trin}</option>
                {/each}
              </select>
              {#if beregnetForslag}
                <button
                  type="button"
                  class="mt-1 text-[11px] text-sky-700 hover:text-sky-900 underline decoration-dotted"
                  title="Sætter både dato og klassetrin ud fra elevens klassetrin"
                  on:click={brugBeregnet}
                >
                  Brug beregnet: {formatDanishDate(beregnetForslag.dato)} · klassetrin {beregnetForslag.klassetrin}
                </button>
              {/if}
            {:else}
              <p class="text-sm text-gray-800">{bevilling.afstandskriterie_klassetrin ?? "—"}</p>
            {/if}
          </div>
          {/if}

          <!-- ANSØGER RELATION -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Ansøger relation</p>
            {#if isEditing}
              <select
                class={mediumSelectClass}
                value={editableBevilling.relation_til_barnet ?? ""}
                on:change={(e) => updateField("relation_til_barnet", emptyToNull(e.currentTarget.value))}
              >
                <option value="">Vælg</option>
                {#each ansoegerRelationOptions(editableBevilling.relation_til_barnet) as relation}
                  <option value={relation}>{relation}</option>
                {/each}
              </select>
            {:else}
              <p class="text-sm text-gray-800">{bevilling.relation_til_barnet ?? "—"}</p>
            {/if}
          </div>

          <!-- REVURDERING -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Revurdering</p>
            {#if isEditing}
              <input
                type="date"
                min={minDate} max={maxDate}
                class={inputClass}
                value={editableBevilling.revurderingsdato ?? ""}
                on:change={(e) => updateField("revurderingsdato", emptyToNull(e.currentTarget.value))}
              />
            {:else}
              <p class="text-sm text-gray-800">{formatDanishDate(bevilling.revurderingsdato)}</p>
            {/if}
          </div>

          <!-- BEFORDRINGSUDVALG — not applicable to Midlertidig kørsel -->
          {#if !isMidlertidigKoersel(bevilling.ansoegningstype)}
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Befordringsudvalg</p>
            {#if isEditing}
              <input
                type="date"
                min={minDate} max={maxDate}
                class={inputClass}
                value={editableBevilling.befordringsudvalg ?? ""}
                on:change={(e) => updateField("befordringsudvalg", emptyToNull(e.currentTarget.value))}
              />
            {:else}
              <p class="text-sm text-gray-800">{formatDanishDate(bevilling.befordringsudvalg)}</p>
            {/if}
          </div>
          {/if}

          <!-- HJEMMEL -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Hjemmel</p>
            {#if isEditing}
              {@const editSkoleType = editableBevilling.ungdomsuddannelse_id && !editableBevilling.matrikel_id ? 'ungdomsuddannelse' : 'folkeskole'}
              <select
                class={largeSelectClass}
                value={editableBevilling.hjemmel_id ?? ""}
                on:change={(e) => updateField("hjemmel_id", numberOrNull(e.currentTarget.value))}
              >
                <option value="">Vælg</option>
                {#each filterHjemler(lookupOptions.hjemler ?? [], bevilling.ansoegningstype, editSkoleType) as option}
                  <option value={option.id}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <p class="text-sm text-gray-800">{bevilling.hjemmel_tekst ?? "—"}</p>
            {/if}
          </div>

          <!-- AFGØRELSESBREV -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Afgørelsesbrev</p>
            {#if isEditing}
              {@const editSkoleType = editableBevilling.ungdomsuddannelse_id && !editableBevilling.matrikel_id ? 'ungdomsuddannelse' : 'folkeskole'}
              <select
                class={largeSelectClass}
                value={editableBevilling.afgoerelsesbrev_id ?? ""}
                on:change={(e) => updateField("afgoerelsesbrev_id", numberOrNull(e.currentTarget.value))}
              >
                <option value="">Vælg</option>
                {#each filterAfgoerelsesbreve(lookupOptions.afgoerelsesbreve ?? [], bevilling.ansoegningstype, editSkoleType) as option}
                  <option value={option.id}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <p class="text-sm text-gray-800">{bevilling.afgoerelsesbrev_tekst ?? "—"}</p>
            {/if}
          </div>

          <!-- SAGSBEHANDLER -->
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Sagsbehandler</p>
            {#if isEditing}
              <select
                class={mediumSelectClass}
                value={editableBevilling.sagsbehandler_id ?? ""}
                on:change={(e) => updateField("sagsbehandler_id", numberOrNull(e.currentTarget.value))}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.sagsbehandlere ?? [] as option}
                  <option value={option.id}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <p class="text-sm text-gray-800">{bevilling.sagsbehandler_tekst ?? "—"}</p>
            {/if}
          </div>

          <!-- PPR ANSVARLIG — not applicable to Midlertidig kørsel -->
          {#if !isMidlertidigKoersel(bevilling.ansoegningstype)}
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">PPR ansvarlig</p>
            {#if isEditing}
              <select
                class={mediumSelectClass}
                value={editableBevilling.ppr_sagsbehandler_id ?? ""}
                on:change={(e) => updateField("ppr_sagsbehandler_id", numberOrNull(e.currentTarget.value))}
              >
                <option value="">Vælg</option>
                {#each lookupOptions.pprSagsbehandlere ?? [] as option}
                  <option value={option.id}>{option.label}</option>
                {/each}
              </select>
            {:else}
              <p class="text-sm text-gray-800">{bevilling.ppr_sagsbehandler_tekst ?? "—"}</p>
            {/if}
          </div>
          {/if}

        </div>

        {#if isEditing && editError}
          <div class="mx-4 md:mx-6 mb-4 px-3 py-2 text-sm text-red-700 bg-red-50 border border-red-200 rounded">
            {editError}
          </div>
        {/if}


        <!-- Kørselsrækker section (expanded) -->
        {#if isExpanded || readonlyKoerselsraekker}
          <div class="border-t-2 border-gray-300 bg-gray-100">

            <div class="px-6 py-2.5 border-b border-gray-300">
              <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500">Kørselsrækker</p>
            </div>

            <div class="px-6 py-4">
              <KoerselsraekkeTable
                rows={bevilling.koerselsraekker ?? []}
                lookupOptions={lookupOptions}
                adresseForBevilling={bevilling.adresse_for_bevilling ?? ""}
                matrikelId={bevilling.matrikel_id ?? null}
                readonly={readonlyKoerselsraekker}
                onSaveKoerselsraekke={onSaveKoerselsraekke}
                onCreateKoerselsraekke={(updates) => onCreateKoerselsraekke(bevilling.bevilling_id, updates)}
                onFinalizeKoerselsraekke={onFinalizeKoerselsraekke}
                onDeleteKoerselsraekke={onDeleteKoerselsraekke}
                {parter}
                ansoegningstype={bevilling.ansoegningstype ?? ""}
              />
            </div>

          </div>
        {/if}

      </div>

    {/each}

  {/if}

</div>


<svelte:window on:keydown={(e) => {
  if (e.key === 'Escape' && confirmingDeleteBevillingId !== null) confirmingDeleteBevillingId = null;
  if (e.key === 'Escape' && confirmingLock !== null) confirmingLock = null;
  if (e.key === 'Escape' && lockedEditBevilling !== null) lockedEditBevilling = null;
}} />

<!-- Delete bevilling confirmation modal -->
{#if confirmingDeleteBevillingId !== null}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    role="presentation"
  >
    <div
      class="w-[440px] bg-white rounded-lg shadow-2xl"
      role="dialog"
      aria-modal="true"
      tabindex="-1"
    >
      <div class="px-6 py-5 border-b border-gray-200">
        <div class="flex items-center gap-3">
          <div class="w-9 h-9 rounded-full bg-red-100 flex items-center justify-center shrink-0">
            <svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v
6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </div>
          <div>
            <h3 class="text-sm font-semibold text-gray-900">Slet bevilling</h3>
            <p class="text-xs text-gray-500 mt-0.5">Bevilling #{confirmingDeleteBevillingId}</p>
          </div>
        </div>
      </div>
      <div class="px-6 py-4">
        <p class="text-sm text-gray-700">
          Er du sikker på, at du vil slette denne bevilling og alle tilhørende kørselsrækker?
          Bevillingen vil blive skjult for brugere, men bevares i databasen.
        </p>
        {#if deleteError}
          <p class="mt-3 text-sm text-red-600 bg-red-50 border border-red-200 rounded px-3 py-2">{deleteError}</p>
        {/if}
      </div>
      <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200 bg-gray-50 rounded-b-lg">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-100 transition-colors"
          on:click={() => confirmingDeleteBevillingId = null}
        >
          Annullér
        </button>
        <button
          type="button"
          disabled={isDeleting}
          class="px-4 py-2 text-sm font-medium bg-red-600 hover:bg-red-700 text-white rounded transition-colors disabled:opacity-50"
          on:click={doDeleteBevilling}
        >
          {isDeleting ? "Sletter…" : "Slet bevilling"}
        </button>
      </div>
    </div>
  </div>
{/if}


<!-- Lock / unlock bevilling confirmation modal -->
{#if confirmingLock !== null}
  <!-- Backdrop is non-dismissing: close only via Escape or the Annullér button. -->
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    role="presentation"
  >
    <div
      class="w-[440px] bg-white rounded-lg shadow-2xl"
      role="dialog"
      aria-modal="true"
      tabindex="-1"
    >
      <div class="px-6 py-5 border-b border-gray-200">
        <div class="flex items-center gap-3">
          <div class="w-9 h-9 rounded-full bg-amber-100 flex items-center justify-center shrink-0">
            <svg class="w-5 h-5 text-amber-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d={confirmingLock.final ? "M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" : "M8 11V7a4 4 0 118 0m-4 8v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2z"} />
            </svg>
          </div>
          <div>
            <h2 class="text-base font-semibold text-gray-900">
              {confirmingLock.final ? "Lås bevilling" : "Lås bevilling op"}
            </h2>
            <p class="text-xs text-gray-500 mt-0.5">Bevilling #{confirmingLock.bevillingId}</p>
          </div>
        </div>
      </div>

      <div class="px-6 py-5">
        {#if confirmingLock.final}
          <p class="text-sm text-gray-700">
            Bevillingen vil blive markeret som <strong>låst</strong>.
          </p>
          <p class="text-sm text-gray-500 mt-2">
            Er du sikker på, at du vil låse denne bevilling? Den kan låses op igen.
          </p>
        {:else}
          <p class="text-sm text-gray-700">
            Bevillingen vil ikke længere være markeret som <strong>låst</strong>.
          </p>
          <p class="text-sm text-gray-500 mt-2">
            Er du sikker på, at du vil låse denne bevilling op?
          </p>
        {/if}
        {#if lockError}
          <p class="mt-3 text-sm text-red-600 bg-red-50 border border-red-200 rounded px-3 py-2">{lockError}</p>
        {/if}
      </div>

      <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200 bg-gray-50 rounded-b-lg">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-white transition-colors"
          on:click={() => confirmingLock = null}
        >
          Annullér
        </button>
        <button
          type="button"
          disabled={isSettingLock}
          class="px-4 py-2 text-sm font-medium bg-amber-600 hover:bg-amber-700 text-white rounded transition-colors disabled:opacity-50"
          on:click={doSetBevillingLock}
        >
          {#if isSettingLock}
            Gemmer…
          {:else}
            {confirmingLock.final ? "Lås bevilling" : "Lås op"}
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}


<!-- Locked edit confirmation popup -->
{#if lockedEditBevilling !== null}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    role="presentation"
  >
    <div
      class="w-[440px] bg-white rounded-lg shadow-2xl"
      role="dialog"
      aria-modal="true"
      tabindex="-1"
    >
      <div class="px-6 py-5 border-b border-gray-200">
        <div class="flex items-center gap-3">
          <div class="w-9 h-9 rounded-full bg-amber-100 flex items-center justify-center shrink-0">
            <svg class="w-5 h-5 text-amber-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <div>
            <h2 class="text-base font-semibold text-gray-900">Rediger låst bevilling</h2>
            <p class="text-xs text-gray-500 mt-0.5">Kræver bekræftelse</p>
          </div>
        </div>
      </div>

      <div class="px-6 py-5">
        <p class="text-sm text-gray-700">
          Bevillingen er låst. <strong>Husk at sende nyt brev</strong> når du har redigeret i en låst bevilling.
        </p>
        <p class="text-sm text-gray-500 mt-2">
          Er du sikker på, at du vil redigere denne bevilling?
        </p>
      </div>

      <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200 bg-gray-50 rounded-b-lg">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-white transition-colors"
          on:click={() => lockedEditBevilling = null}
        >
          Annullér
        </button>
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium bg-amber-600 hover:bg-amber-700 text-white rounded transition-colors"
          on:click={doLockedEdit}
        >
          Redigér
        </button>
      </div>
    </div>
  </div>
{/if}
