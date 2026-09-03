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

  // "Alle" first rather than wherever its id happens to fall.
  $: sortedDage = [...options].sort((a, b) => {
    if (a.label === 'Alle') return -1;
    if (b.label === 'Alle') return 1;
    return Number(a.id) - Number(b.id);
  });

  function toggle(id: number | string) {
    const n = Number(id);
    selected = selected.includes(n)
      ? selected.filter((existing) => existing !== n)
      : [...selected, n];
  }
</script>

<div class="flex flex-wrap gap-1">
  {#each sortedDage as option}
    <button
      type="button"
      aria-pressed={selected.includes(Number(option.id))}
      class="px-2 py-1.5 text-xs rounded border transition-colors {selected.includes(Number(option.id))
        ? 'bg-[#032A42] text-white border-[#032A42]'
        : 'bg-white text-gray-600 border-gray-300 hover:border-gray-400'}"
      on:click={() => toggle(option.id)}
    >
      {DAG_SHORT[option.label] ?? option.label}
    </button>
  {/each}
</div>
