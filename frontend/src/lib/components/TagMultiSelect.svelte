<script lang="ts">
  // Inline multi-select: selected values render as chips *inside* the control,
  // and the option list is an absolutely-positioned overlay so opening it never
  // pushes surrounding fields down. Two-way bind the `selected` id array.

  export let options: { id: number | string; label: string }[] = [];
  export let selected: number[] = [];
  export let placeholder = "Vælg";

  let open = false;
  let query = "";
  let container: HTMLDivElement;
  let inputEl: HTMLInputElement;

  $: available = options.filter(
    (o) =>
      !selected.includes(Number(o.id)) &&
      String(o.label).toLowerCase().includes(query.toLowerCase())
  );

  function labelFor(id: number): string {
    return options.find((o) => Number(o.id) === Number(id))?.label ?? String(id);
  }

  function add(id: number | string) {
    const n = Number(id);
    if (!selected.includes(n)) {
      selected = [...selected, n];
    }
    query = "";
    inputEl?.focus();
  }

  function remove(id: number) {
    selected = selected.filter((existing) => existing !== Number(id));
  }

  function onWindowClick(event: MouseEvent) {
    if (container && !container.contains(event.target as Node)) {
      open = false;
    }
  }
</script>

<svelte:window on:click={onWindowClick} />

<div class="relative" bind:this={container}>
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div
    class="flex flex-wrap items-center gap-1.5 min-h-[38px] w-full border border-gray-300 rounded px-2 py-1 text-sm cursor-text focus-within:border-blue-400"
    on:click={() => { open = true; inputEl?.focus(); }}
  >
    {#each selected as id}
      <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-0.5 text-xs">
        {labelFor(id)}
        <button
          type="button"
          class="text-red-500 hover:text-red-700 font-bold leading-none"
          on:click|stopPropagation={() => remove(id)}
        >×</button>
      </span>
    {/each}

    <input
      bind:this={inputEl}
      bind:value={query}
      class="flex-1 min-w-[60px] border-0 p-0 bg-transparent text-sm focus:ring-0 focus:outline-none"
      placeholder={selected.length === 0 ? placeholder : ""}
      on:focus={() => (open = true)}
      on:keydown={(e) => {
        if (e.key === "Backspace" && query === "" && selected.length) {
          selected = selected.slice(0, -1);
        } else if (e.key === "Enter" && available.length) {
          e.preventDefault();
          add(available[0].id);
        } else if (e.key === "Escape") {
          open = false;
        }
      }}
    />

    <svg class="ml-auto w-4 h-4 text-gray-400 shrink-0 pointer-events-none" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
    </svg>
  </div>

  {#if open && available.length > 0}
    <div class="absolute z-20 mt-1 w-full max-h-56 overflow-auto bg-white border border-gray-300 rounded shadow-lg">
      {#each available as option}
        <button
          type="button"
          class="block w-full text-left px-3 py-1.5 text-sm hover:bg-blue-50"
          on:click|stopPropagation={() => add(option.id)}
        >
          {option.label}
        </button>
      {/each}
    </div>
  {/if}
</div>
