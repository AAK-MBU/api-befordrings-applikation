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

  // A selected chip is never disabled — otherwise a row that somehow holds both
  // kinds (older data, an import) could never be untangled.
  function isDisabled(option: { id: number | string; label: string }): boolean {
    if (selected.includes(Number(option.id))) return false;
    return isAlle(option) ? dageValgt : alleValgt;
  }

  function toggle(id: number | string) {
    const n = Number(id);
    selected = selected.includes(n)
      ? selected.filter((existing) => existing !== n)
      : [...selected, n];
  }
</script>

<div class="flex flex-wrap gap-1">
  {#each sortedDage as option}
    {@const valgt = selected.includes(Number(option.id))}
    {@const deaktiveret = isDisabled(option)}
    <button
      type="button"
      aria-pressed={valgt}
      disabled={deaktiveret}
      title={deaktiveret
        ? (isAlle(option)
            ? "Kan ikke vælges, når enkelte dage er valgt"
            : "Kan ikke vælges, når 'Alle' er valgt")
        : undefined}
      class="px-2 py-1.5 text-xs rounded border transition-colors {valgt
        ? 'bg-[#032A42] text-white border-[#032A42]'
        : deaktiveret
          ? 'bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed'
          : 'bg-white text-gray-600 border-gray-300 hover:border-gray-400'}"
      on:click={() => toggle(option.id)}
    >
      {DAG_SHORT[option.label] ?? option.label}
    </button>
  {/each}
</div>
