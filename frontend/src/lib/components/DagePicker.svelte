<script lang="ts">
  // Weekday picker: every day is on screen as a toggle chip, so picking days is
  // one click per day with no dropdown to open and no chip list to read back.
  // Two-way bind the `selected` id array.

  export let options: { id: number | string; label: string }[] = [];
  export let selected: number[] = [];

  // Short labels keep all six chips on one line inside a grid column.
  const DAG_SHORT: Record<string, string> = {
    'Mandag': 'Man', 'Tirsdag': 'Tirs', 'Onsdag': 'Ons',
    'Torsdag': 'Tors', 'Fredag': 'Fre', 'Alle': 'Alle',
  };

  const isAlle = (option: { label: string }) => option.label === 'Alle';

  // "Alle" first rather than wherever its id happens to fall.
  $: sortedDage = [...options].sort((a, b) => {
    if (isAlle(a)) return -1;
    if (isAlle(b)) return 1;
    return Number(a.id) - Number(b.id);
  });

  // "Alle" and the individual days are mutually exclusive: "Alle + Tirsdag" has
  // no meaning, so whichever kind is picked first greys out the other.
  $: alleIds = options.filter(isAlle).map((o) => Number(o.id));
  $: alleValgt = selected.some((id) => alleIds.includes(id));
  $: dageValgt = selected.some((id) => !alleIds.includes(id));

  // Derived here in the script, not by calling a helper from the template.
  // Svelte compiles `{@const x = isDisabled(option)}` to a derived that reads
  // the call inside $.untrack(), so nothing the helper touches is a dependency:
  // it computes once on first render and never updates again.
  //
  // A selected chip is never disabled — otherwise a row that somehow holds both
  // kinds (older data, an import) could never be untangled.
  $: chips = sortedDage.map((option) => {
    const valgt = selected.includes(Number(option.id));
    return {
      id: option.id,
      tekst: DAG_SHORT[option.label] ?? option.label,
      valgt,
      deaktiveret: valgt ? false : (isAlle(option) ? dageValgt : alleValgt),
      forklaring: isAlle(option)
        ? "Kan ikke vælges, når enkelte dage er valgt"
        : "Kan ikke vælges, når 'Alle' er valgt",
    };
  });

  function toggle(id: number | string) {
    const n = Number(id);
    selected = selected.includes(n)
      ? selected.filter((existing) => existing !== n)
      : [...selected, n];
  }
</script>

<div class="flex flex-wrap gap-1">
  {#each chips as chip}
    <button
      type="button"
      aria-pressed={chip.valgt}
      disabled={chip.deaktiveret}
      title={chip.deaktiveret ? chip.forklaring : undefined}
      class="px-2 py-1.5 text-xs rounded border transition-colors {chip.valgt
        ? 'bg-[#032A42] text-white border-[#032A42]'
        : chip.deaktiveret
          ? 'bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed'
          : 'bg-white text-gray-600 border-gray-300 hover:border-gray-400'}"
      on:click={() => toggle(chip.id)}
    >
      {chip.tekst}
    </button>
  {/each}
</div>
