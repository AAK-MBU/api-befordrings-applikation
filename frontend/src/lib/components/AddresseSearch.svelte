<script lang="ts">
  import { onDestroy } from "svelte";
  import { backendFetch } from "$lib/client/backendFetch";

  // -----------------------------------------------------------------------
  // Props
  // -----------------------------------------------------------------------

  /** The currently selected address ID — bind this in the parent. */
  export let adresseId: number | null = null;

  /** Text to display in the input for the current selection. */
  export let adresseTekst: string = "";

  /** Tailwind classes for the <input> element. */
  export let inputClass: string =
    "w-full border border-gray-300 rounded px-3 py-2 text-sm focus:border-blue-400 focus:ring-0";

  /**
   * Called when the selection changes.
   * Receives the full result object on selection, or null when the field is cleared.
   */
  export let onSelect: (result: {
    adresse_id: number;
    adresse_tekst: string;
    latitude: number;
    longitude: number;
  } | null) => void = () => {};


  // -----------------------------------------------------------------------
  // Internal state
  // -----------------------------------------------------------------------

  type AdresseResult = {
    adresse_id: number;
    adresse_tekst: string;
    latitude: number;
    longitude: number;
  };

  let inputValue = adresseTekst;
  let results: AdresseResult[] = [];
  let isOpen = false;
  let loading = false;
  let searched = false;
  let debounceTimer: ReturnType<typeof setTimeout>;
  let activeIndex = -1;
  let inputEl: HTMLInputElement | null = null;

  // The <ul> is moved directly onto document.body with position:fixed applied
  // to the element itself, so no parent overflow or stacking context can clip
  // or misplace it.  A capturing scroll listener keeps it in sync when the
  // modal container (overflow-y:auto) scrolls.
  let listEl: HTMLUListElement | null = null;

  // Keep the input in sync if the parent updates adresseTekst externally
  // (e.g. when copying from a source bevilling).
  $: inputValue = adresseTekst;


  // -----------------------------------------------------------------------
  // Portal helpers
  // -----------------------------------------------------------------------

  /** Re-positions the floating <ul> under the input using live viewport coords. */
  function positionList() {
    if (!inputEl || !listEl) return;
    const rect = inputEl.getBoundingClientRect();
    listEl.style.top   = `${rect.bottom + 4}px`;
    listEl.style.left  = `${rect.left}px`;
    listEl.style.width = `${rect.width}px`;
  }

  onDestroy(() => {
    listEl?.remove();
  });


  // -----------------------------------------------------------------------
  // Handlers
  // -----------------------------------------------------------------------

  function handleInput(e: Event) {
    const value = (e.currentTarget as HTMLInputElement).value;
    inputValue = value;

    clearTimeout(debounceTimer);
    results = [];
    isOpen = false;
    searched = false;

    if (value.length < 2) {
      loading = false;
      return;
    }

    loading = true;
    debounceTimer = setTimeout(async () => {
      try {
        const res = await backendFetch(
          `/adresse/search?q=${encodeURIComponent(value)}`
        );
        if (res.ok) {
          results = await res.json();
          activeIndex = -1;
          if (results.length > 0) {
            isOpen = true;
          }
        }
      } finally {
        loading = false;
        searched = true;
      }
    }, 300);
  }

  function handleKeydown(e: KeyboardEvent) {
    if (!isOpen && e.key !== "Escape") return;

    if (e.key === "ArrowDown") {
      e.preventDefault();
      activeIndex = activeIndex < results.length - 1 ? activeIndex + 1 : 0;
      scrollActiveIntoView();
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      activeIndex = activeIndex > 0 ? activeIndex - 1 : results.length - 1;
      scrollActiveIntoView();
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (activeIndex >= 0 && activeIndex < results.length) {
        selectResult(results[activeIndex]);
      }
    } else if (e.key === "Escape") {
      e.preventDefault();
      isOpen = false;
      activeIndex = -1;
      inputValue = adresseTekst;
    }
  }

  function scrollActiveIntoView() {
    setTimeout(() => {
      const item = listEl?.children[activeIndex] as HTMLElement | undefined;
      item?.scrollIntoView({ block: "nearest" });
    }, 0);
  }

  function handleBlur() {
    // Delay so mousedown on a result item fires before blur closes the list.
    setTimeout(() => {
      isOpen = false;
      searched = false;

      if (inputValue.trim() === "") {
        // User explicitly cleared the field — remove the selection.
        adresseId    = null;
        adresseTekst = "";
        onSelect(null);
      } else if (inputValue !== adresseTekst) {
        // Typed something partial without picking — revert to last confirmed text.
        inputValue = adresseTekst;
      }
    }, 150);
  }

  function selectResult(result: AdresseResult) {
    adresseId    = result.adresse_id;
    adresseTekst = result.adresse_tekst;
    inputValue   = result.adresse_tekst;
    results      = [];
    isOpen       = false;
    onSelect(result);
  }

  /**
   * Svelte action: moves the <ul> directly onto document.body with
   * position:fixed so it escapes every overflow / stacking-context ancestor.
   *
   * capture:true on the scroll listener means it fires for scroll events on
   * ANY element — including the overflow-y:auto modal container — so the
   * dropdown stays pinned to the input while the modal is scrolled.
   */
  function portal(node: HTMLUListElement) {
    listEl = node;

    node.style.position = "fixed";
    node.style.zIndex   = "9999";
    node.style.margin   = "0";

    document.body.appendChild(node);
    positionList(); // position after appending so it's in the DOM

    window.addEventListener("scroll", positionList, { capture: true, passive: true });
    window.addEventListener("resize", positionList, { passive: true });

    return {
      destroy() {
        window.removeEventListener("scroll", positionList, true);
        window.removeEventListener("resize", positionList);
        node.remove();
        listEl = null;
      },
    };
  }
</script>


<div class="relative">
  <input
    bind:this={inputEl}
    type="text"
    class={inputClass}
    value={inputValue}
    placeholder="Søg adresse..."
    autocomplete="off"
    on:input={handleInput}
    on:blur={handleBlur}
    on:keydown={handleKeydown}
  />

  {#if loading}
    <span class="absolute right-2.5 top-1/2 -translate-y-1/2 text-[11px] text-gray-400 pointer-events-none">
      Søger…
    </span>
  {/if}

  {#if isOpen && results.length > 0}
    <ul
      use:portal
      class="bg-white border border-gray-200 rounded shadow-lg max-h-56 overflow-y-auto"
    >
      {#each results as result, i}
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2 text-sm focus:outline-none
                   {i === activeIndex ? 'bg-blue-100 text-blue-900' : 'hover:bg-blue-50'}"
            on:mousedown|preventDefault={() => selectResult(result)}
            on:mousemove={() => { activeIndex = i; }}
          >
            {result.adresse_tekst}
          </button>
        </li>
      {/each}
    </ul>
  {:else if !loading && inputValue.length >= 2 && searched}
    <ul use:portal class="bg-white border border-gray-200 rounded shadow-lg">
      <li class="px-3 py-2 text-sm text-gray-400 italic">Ingen adresser fundet</li>
    </ul>
  {/if}
</div>
