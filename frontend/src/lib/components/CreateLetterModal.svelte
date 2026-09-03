<script lang="ts">
  // The single "Opret brev" modal. Both the student page and the revurdering
  // page mount this, so the fields, the validation and the payload can only
  // ever be one thing — they used to be two divergent copies, and the
  // revurdering copy silently omitted koersel_startdato and
  // dato_for_seneste_bevilling from the queued letter.
  //
  // The caller supplies only what genuinely differs — which student, which
  // bevillinger — and reacts to `created` to refresh its own view.

  import { createEventDispatcher } from "svelte";

  import { backendFetch } from "$lib/client/backendFetch";
  import { firstInvalidDate } from "$lib/dates";

  export let open = false;
  export let cpr = "";
  export let bevillinger: any[] = [];

  const dispatch = createEventDispatcher();

  let selectedLetterBevillingId = "";
  let letterType = "";
  let koerselStartdato = "";
  let datoForSenesteBevilling = "";
  let befordringsudvalgResultat = "";
  let tidligereAfgoerelseDato = "";
  let ophoersdato = "";
  let creatingLetter = false;

  $: selectedBevilling = (bevillinger ?? []).find(
    (bevilling: any) => String(bevilling.bevilling_id) === selectedLetterBevillingId
  );

  $: harBefordringsudvalg =
    selectedBevilling?.befordringsudvalg !== null &&
    selectedBevilling?.befordringsudvalg !== undefined &&
    selectedBevilling?.befordringsudvalg !== "";

  $: erOphoert = selectedBevilling?.status_tekst === "Ophørt";

  // The letter's "startdato for kørsel" is the day the kørsel actually begins:
  // the earliest gyldig_fra across the bevilling's kørselsrækker. ISO dates
  // compare correctly as strings, so no Date parsing is needed. Soft-deleted
  // rækker are already filtered out by view_Bevilling_Koerselsraekker.
  function earliestGyldigFra(bevilling: any): string {
    const datoer: string[] = (bevilling?.koerselsraekker ?? [])
      .map((koersel: any) => koersel?.gyldig_fra)
      .filter(Boolean)
      .map((dato: string) => String(dato).slice(0, 10));

    return datoer.length === 0
      ? ""
      : datoer.reduce((tidligste, dato) => (dato < tidligste ? dato : tidligste));
  }

  // Prefill on a *change of bevilling* only. The caller reloads its data after
  // a letter is created, which rebuilds selectedBevilling without the id
  // changing — a bare assignment would wipe a date typed by hand.
  let prefilledStartdatoFor = "";
  $: if (selectedLetterBevillingId !== prefilledStartdatoFor) {
    prefilledStartdatoFor = selectedLetterBevillingId;
    koerselStartdato = earliestGyldigFra(selectedBevilling);
  }

  function resetForm() {
    selectedLetterBevillingId = "";
    letterType = "";
    koerselStartdato = "";
    datoForSenesteBevilling = "";
    befordringsudvalgResultat = "";
    tidligereAfgoerelseDato = "";
    ophoersdato = "";
    prefilledStartdatoFor = "";
  }

  // Clear on the way *in*, so a modal reopened after a cancel never shows the
  // previous student's answers.
  let wasOpen = false;
  $: if (open !== wasOpen) {
    wasOpen = open;
    if (open) resetForm();
  }

  function close() {
    open = false;
    resetForm();
  }

  // Every field is required except dato_for_seneste_bevilling — and a field
  // that is not shown is not required, which is why each conditional check
  // repeats the same flag that gates its markup.
  function firstValidationError(): string | null {
    if (!selectedLetterBevillingId) return "Vælg en bevilling";
    if (!letterType) return "Vælg hvad brevet er i forbindelse med";
    if (!koerselStartdato) return "Angiv startdato for kørsel";
    if (harBefordringsudvalg && !befordringsudvalgResultat) return "Vælg resultat af befordringsudvalgsmøde";
    if (harBefordringsudvalg && !tidligereAfgoerelseDato) return "Angiv dato for tidligere afgørelse";
    if (erOphoert && !ophoersdato) return "Vælg ophørsdato";

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

    if (invalidDate) return "Angiv en gyldig dato (åååå-mm-dd).";

    return null;
  }

  async function handleCreateLetter() {
    const validationError = firstValidationError();

    if (validationError) {
      alert(validationError);
      return;
    }

    creatingLetter = true;

    const payload = {
      brev_i_forbindelse_med: letterType,
      koersel_startdato: koerselStartdato || null,
      dato_for_seneste_bevilling: datoForSenesteBevilling || null,
      befordringsudvalg_resultat: harBefordringsudvalg ? befordringsudvalgResultat : null,
      dato_for_tidligere_afgoerelse: harBefordringsudvalg ? tidligereAfgoerelseDato : null,
      ophoersdato: erOphoert ? ophoersdato : null,
    };

    try {
      const response = await backendFetch(
        `/bevilling/create_letter/${cpr}/${selectedLetterBevillingId}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        }
      );

      if (!response.ok) {
        let message = "Kunne ikke oprette brev";

        try {
          const errorData = await response.json();
          message = errorData?.detail?.message ?? errorData?.detail ?? message;
        } catch {
          // Keep fallback message
        }

        alert(message);
        return;
      }

      const result = await response.json();

      alert(`Brev er sat i kø. Reference: ${result.reference}`);

      const bevillingId = Number(selectedLetterBevillingId);

      await backendFetch(`/aktivitet/${cpr}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          aktivitetstype: "Brev oprettet",
          kommentar: `Bevilling ID: ${bevillingId}`,
          relateret_bevilling_id: bevillingId,
          udfoert_af: null,
        }),
      });

      close();
      dispatch("created", { cpr, bevillingId });
    } finally {
      creatingLetter = false;
    }
  }

  const labelClass = "block text-sm font-medium text-gray-700";
  const fieldClass = "mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm";
</script>

<svelte:window
  on:keydown={(e) => {
    if (open && e.key === "Escape") close();
  }}
/>

{#if open}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" role="presentation">
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
        <label class={labelClass}>
          Vælg bevilling *
          <select class={fieldClass} bind:value={selectedLetterBevillingId}>
            <option value="">Vælg bevilling</option>
            {#each bevillinger ?? [] as bevilling}
              <option value={String(bevilling.bevilling_id)}>
                Bevilling #{bevilling.bevilling_id} – {bevilling.status_tekst ?? "Ukendt status"}
              </option>
            {/each}
          </select>
        </label>

        <label class={labelClass}>
          Brevet er i forbindelse med en: *
          <select class={fieldClass} bind:value={letterType}>
            <option value="">Vælg</option>
            <option value="ansøgning">Ansøgning</option>
            <option value="revurdering">Revurdering</option>
            <option value="midlertidig kørsel">Midlertidig kørsel</option>
          </select>
        </label>

        <label class={labelClass}>
          Startdato for kørsel *
          <input type="date" max="9999-12-31" class={fieldClass} bind:value={koerselStartdato} />
          <span class="mt-1 block text-xs font-normal text-gray-500">
            Udfyldes automatisk med den tidligste "gyldig fra" på bevillingens kørselsrækker.
          </span>
        </label>

        <label class={labelClass}>
          Dato for seneste bevilling
          <input type="date" max="9999-12-31" class={fieldClass} bind:value={datoForSenesteBevilling} />
        </label>

        {#if harBefordringsudvalg}
          <label class={labelClass}>
            Resultat af befordringsudvalgsmøde *
            <select class={fieldClass} bind:value={befordringsudvalgResultat}>
              <option value="">Vælg</option>
              <option value="Befordringsudvalg: Afslag / fastholdelse">Befordringsudvalg: Afslag / fastholdelse</option>
              <option value="Befordringsudvalg: Ændring i bevilling">Befordringsudvalg: Ændring i bevilling</option>
            </select>
          </label>
          <label class={labelClass}>
            Dato for tidligere afgørelse *
            <input type="date" max="9999-12-31" class={fieldClass} bind:value={tidligereAfgoerelseDato} />
          </label>
        {/if}

        {#if erOphoert}
          <label class={labelClass}>
            Ophørsdato *
            <input type="date" max="9999-12-31" class={fieldClass} bind:value={ophoersdato} />
          </label>
        {/if}
      </div>

      <div class="flex justify-end gap-3 border-t border-gray-200 px-8 py-5 bg-gray-50 rounded-b-lg">
        <button
          type="button"
          class="px-5 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-white transition-colors"
          on:click={close}
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
