
<script lang="ts">
  import favicon from '$lib/assets/speedometer.png';
  import "../app.css";
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { backendFetch } from '$lib/client/backendFetch';

  let { children, data } = $props();

  const tabs = [
    { href: '/', label: 'Overblik' },
    { href: '/nye-ansoegninger', label: 'Nye ansøgninger' },
    { href: '/revurdering', label: 'Revurdering' },
    { href: '/rapporter', label: 'Rapporter' },
  ];

  const currentPath = $derived($page.url.pathname);

  function isActive(tab: { href: string }) {
    if (tab.href === '/') return currentPath === '/';
    return currentPath.startsWith(tab.href);
  }

  // --- Dark mode toggle ---
  let isDark = $state(false);

  onMount(() => {
    isDark = localStorage.getItem('darkMode') === 'true';
    document.documentElement.classList.toggle('dark', isDark);
  });

  function toggleDark() {
    isDark = !isDark;
    document.documentElement.classList.toggle('dark', isDark);
    localStorage.setItem('darkMode', String(isDark));
  }

  // --- Global search ---
  let searchQuery = $state('');
  let searchResults = $state<any[]>([]);
  let searchOpen = $state(false);
  let searchLoading = $state(false);
  let searchFocused = $state(false);
  let debounceTimer: ReturnType<typeof setTimeout> | null = null;
  let highlightedIndex = $state(-1);

  function onSearchInput() {
    if (debounceTimer) clearTimeout(debounceTimer);
    highlightedIndex = -1;

    if (searchQuery.trim().length < 2) {
      searchResults = [];
      searchOpen = false;
      searchLoading = false;
      return;
    }

    searchLoading = true;
    debounceTimer = setTimeout(async () => {
      try {
        const res = await backendFetch(`/overview/search?q=${encodeURIComponent(searchQuery.trim())}`);
        if (res.ok) {
          searchResults = await res.json();
          searchOpen = searchResults.length > 0;
        }
      } catch {
        searchResults = [];
        searchOpen = false;
      } finally {
        searchLoading = false;
      }
    }, 280);
  }

  function selectResult(cpr: string) {
    searchQuery = '';
    searchResults = [];
    searchOpen = false;
    searchFocused = false;
    highlightedIndex = -1;
    goto(`/sag/${cpr}`);
  }

  function closeSearch() {
    // Small delay so a click on a result registers before closing
    setTimeout(() => {
      searchOpen = false;
      highlightedIndex = -1;
    }, 150);
  }

  function onSearchKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      searchOpen = false;
      highlightedIndex = -1;
      (e.currentTarget as HTMLInputElement).blur();
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      highlightedIndex = Math.min(highlightedIndex + 1, searchResults.length - 1);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      highlightedIndex = Math.max(highlightedIndex - 1, -1);
    } else if (e.key === 'Enter' && highlightedIndex >= 0) {
      e.preventDefault();
      selectResult(searchResults[highlightedIndex].cpr_elev);
    } else if (e.key === 'Enter' && searchResults.length === 1) {
      e.preventDefault();
      selectResult(searchResults[0].cpr_elev);
    }
  }
</script>

<nav style="background-color: #032A42; box-shadow: 0 2px 8px rgba(0,0,0,0.3);" class="px-4 md:px-8">
  <div class="flex items-center flex-wrap" style="min-height: 60px;">

    <div class="flex items-center gap-3 mr-6 md:mr-10 shrink-0 py-3">
      <div class="w-8 h-8 rounded flex items-center justify-center overflow-hidden" style="background-color: #2ab4a0;">
        <img src={favicon} alt="" class="w-5 h-5" style="filter: brightness(0) invert(1);" />
      </div>
      <div class="leading-none">
        <p class="font-bold text-sm tracking-widest" style="color: #ffffff;">BEFORDRING</p>
        <p class="text-[10px] tracking-wider mt-0.5" style="color: #7ec8e3;">AARHUS KOMMUNE</p>
      </div>
    </div>

    <ul class="flex flex-wrap">
      {#each tabs as tab}
        {@const active = isActive(tab)}
        <li>
          <a
            href={tab.href}
            class="flex items-center px-3 md:px-5 py-4 text-sm font-medium border-b-2 transition-colors"
            style={active
              ? 'color: #ffffff; border-color: #ffffff;'
              : 'color: rgba(255,255,255,0.6); border-color: transparent;'}
          >
            {tab.label}
          </a>
        </li>
      {/each}
    </ul>

    <!-- Global search -->
    <div class="ml-auto pl-4 relative">
      <div class="relative">
        <!-- Search icon -->
        <svg
          class="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 pointer-events-none"
          style="color: rgba(255,255,255,0.5);"
          fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"
        >
          <circle cx="11" cy="11" r="8"/><path stroke-linecap="round" d="M21 21l-4.35-4.35"/>
        </svg>

        <!-- Spinner (while loading) -->
        {#if searchLoading}
          <svg
            class="absolute right-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 animate-spin"
            style="color: rgba(255,255,255,0.5);"
            fill="none" viewBox="0 0 24 24"
          >
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
          </svg>
        {/if}

        <input
          type="search"
          placeholder="Søg navn eller CPR…"
          autocomplete="off"
          bind:value={searchQuery}
          oninput={onSearchInput}
          onfocus={() => { searchFocused = true; if (searchResults.length > 0) searchOpen = true; }}
          onblur={closeSearch}
          onkeydown={onSearchKeydown}
          class="w-52 pl-8 pr-3 py-1.5 rounded text-xs transition-all outline-none focus:w-64"
          style="
            background: rgba(255,255,255,0.1);
            border: 1px solid rgba(255,255,255,0.2);
            color: #ffffff;
          "
        />
      </div>

      <!-- Results dropdown -->
      {#if searchOpen && searchResults.length > 0}
        <div
          class="absolute right-0 top-full mt-1.5 w-80 bg-white rounded-lg shadow-2xl border border-gray-200 overflow-hidden z-50"
        >
          {#each searchResults as result, i}
            <!-- svelte-ignore a11y_click_events_have_key_events -->
            <div
              role="option"
              aria-selected={highlightedIndex === i}
              class="flex items-center justify-between px-4 py-3 cursor-pointer transition-colors border-b border-gray-100 last:border-0
                {highlightedIndex === i ? 'bg-blue-50' : 'hover:bg-gray-50'}"
              onmousedown={(e) => { e.preventDefault(); selectResult(result.cpr_elev); }}
              onmouseenter={() => highlightedIndex = i}
            >
              <div class="min-w-0">
                <p class="text-sm font-semibold text-gray-900 truncate">{result.adresseringsnavn ?? '—'}</p>
                <p class="text-xs text-gray-400 mt-0.5">{result.cpr_elev}</p>
              </div>
              <span class="ml-3 shrink-0 text-[11px] font-medium text-gray-400 bg-gray-100 px-2 py-0.5 rounded-full whitespace-nowrap">
                {result.bevilling_count} {result.bevilling_count === 1 ? 'bevilling' : 'bevillinger'}
              </span>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Dark mode toggle -->
    <div class="pl-2">
      <button
        type="button"
        title={isDark ? 'Skift til lyst tema' : 'Skift til mørkt tema'}
        onclick={toggleDark}
        class="w-8 h-8 flex items-center justify-center rounded-full transition-colors hover:bg-white/10"
        style="color: rgba(255,255,255,0.7);"
      >
        {#if isDark}
          <!-- Sun icon -->
          <svg class="w-4.5 h-4.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="5"/>
            <path stroke-linecap="round" d="M12 2v2M12 20v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M2 12h2M20 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/>
          </svg>
        {:else}
          <!-- Moon icon -->
          <svg class="w-4.5 h-4.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 12.79A9 9 0 1111.21 3a7 7 0 009.79 9.79z"/>
          </svg>
        {/if}
      </button>
    </div>

  </div>
</nav>

<div class="px-4 md:px-8 py-4 md:py-6">
  {@render children()}
</div>

<svelte:head>
  <link rel="icon" href={favicon} />
</svelte:head>
