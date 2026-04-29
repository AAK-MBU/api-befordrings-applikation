
<script lang="ts">
  import favicon from '$lib/assets/speedometer.png'; //<!-- ændrer hvilket icon der bruges i browserfanen.  -->;
  import "../app.css"; 
  import { page } from '$app/stores';
  import { derived } from 'svelte/store';
  // import { Navbar, NavBrand, NavLi, NavUl, NavHamburger, ImagePlaceholder, Skeleton, TextPlaceholder } from "flowbite-svelte";
  
  // props fra sveltekit (+layout.svelte)
  let { children, data } = $props();
  
  // Definér dine tabs
  const tabs = [
    { href: '/', label: 'Overblik' },
    { href: '/nye-ansoegninger', label: 'Nye ansøgninger' },
    { href: '/revurdering', label: 'Revurdering' },
    { href: '/rapporter', label: 'Rapporter' },
  ];

  // Reaktiv variabel — opdateres automatisk ved navigation
  const currentPath = $derived($page.url.pathname);
  
  // Current path from SvelteKit
  //const currentPath = data.url.pathname;
</script>


<!-- <div class="px-8 pt-4"> -->

<div class="px-8 pt-4">
  <div class="flex place-items-center justify-between gap-4">
    <!-- App-titel -->
    <div>
      <h1 class="text-2xl font-bold text-slate-600">
        BEFORDRINGSAPP
      </h1>
    </div>

  <!-- Ændrer font ting i tabs oversigten -->
    <ul class="relative z-10 flex flex-wrap text-lg font-medium text-center text-body border-b border-slate-300"> 
      {#each tabs as tab}
        <li class="me-2 ">
          {#if currentPath === tab.href}
            <!-- Aktiv tab -->
            <a
              href={tab.href}
              aria-current="page"
              class="inline-block px-5 py-3 
                    rounded-t-md 
                    bg-slate-300
                    text-black
                    border-x border-t border-slate-300
                    border-b-0"
            >        
              {tab.label}
            </a>
          {:else}
            <!-- Inaktiv tab -->
            <a
              href={tab.href}
              class="inline-block px-5 py-3 rounded-t-md text-gray-600 hover:bg-slate-200 hover:text-gray-900 transition-all"
            >
              {tab.label}
            </a>
          {/if}
        </li>
      {/each}
    </ul>

    <!-- App-titel, til høøjre når den står hernede -->
    <!-- <div class = "text-right">
      <h1 class="text-2xl font-bold text-slate-600">
        BEFORDRINGSAPP
      </h1>
    </div> -->

  </div>
 </div>
<!-- Indhold fra +page.svelte --> 
<!-- Gets content from + page.svelte file - content (children) with padding so it isn't hidden behind navbar -->
<!-- pt er y aksen/horisontal spacing fra top, px er x aksen/vertikal spacing fra venstre, formentlig -->

<!-- Indholdskortet, der "hænger sammen" med aktiv tab -->
<div class="px-8">
  <main
    class="relative z-0 pt-6 px-6 
           bg-slate-300 
           border-x border-b border-slate-300 
           rounded-b-lg
           min-h-screen"
  >
    {@render children()}
  </main>
</div>

<!-- <main class="relative z-0 pt-10 px-8">  -->
  <!-- {@render children()} -->
<!-- </main> -->

<svelte:head>
  <link rel="icon" href={favicon} />
</svelte:head>

