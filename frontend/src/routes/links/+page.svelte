
<script lang="ts">
  import ReadOnlyNotice from "$lib/components/ReadOnlyNotice.svelte";
  import UpdateTemplateButton from "$lib/components/UpdateTemplateButton.svelte";

  const reports = [
    { label: "Elevbefordring (oversigt) Standardrapport", href: "https://lismbu.adm.aarhuskommune.dk/SASStoredProcess/do?_program=/Aarhus/MBU/LIS/System/LIS&lisaction=rapframe&indk=001993470574233&org=819718&pertype=REGNSKABSAAR&periode=2026&min_id=866388" },
    { label: "Elevbefordring (taxa og minibus) Standardrapport", href: "https://lismbu.adm.aarhuskommune.dk/SASStoredProcess/do?_program=/Aarhus/MBU/LIS/System/LIS&lisaction=rapframe&indk=001894629216178&org=819718&pertype=REGNSKABSAAR&periode=2026&min_id=866388" },
    { label: "Elevbefordring (buskort) Standardrapport", href: "https://lismbu.adm.aarhuskommune.dk/SASStoredProcess/do?_program=/Aarhus/MBU/LIS/System/LIS&lisaction=rapframe&indk=001991385148085&org=819718&pertype=REGNSKABSAAR&periode=2026&min_id=866388" },
    { label: "Optiruns rapport", href: "https://aarhus-office.optiruns.dk/app/report" },
  ];

  // The source workbook the "Opdater skabelondata" button imports from. Kept
  // here rather than inline in the markup: the URL carries & separators and
  // percent-encoded braces that are easy to mangle when editing markup.
  const skabelonExcelHref =
    "https://aarhuskommune.sharepoint.com/:x:/r/teams/BudgetogRegnskab-Samarbejdsprojekter-Befordring/_layouts/15/Doc.aspx" +
    "?sourcedoc=%7BEC07ADD1-9E62-4650-A08C-6175BB84DAEC%7D" +
    "&file=Afg%C3%B8relsesbreve.xlsx&action=default&mobileredirect=true";

  const externalLinkClass =
    "inline-flex items-center gap-2 text-blue-600 hover:text-blue-800 hover:underline";
</script>

<div class="p-8 max-w-2xl">
  <h1 class="text-2xl font-semibold text-gray-800 mb-6">Links</h1>

  <ReadOnlyNotice />
  <ul class="space-y-3">
    {#each reports as report}
      <li>
        <a
          href={report.href}
          target="_blank"
          rel="noopener noreferrer"
          class="flex items-center gap-2 text-blue-600 hover:text-blue-800 hover:underline"
        >
          {report.label}
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M14 3h7m0 0v7m0-7L10 14M5 5H3a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-2" />
          </svg>
        </a>
      </li>
    {/each}
  </ul>

  <section class="mt-10 border-t border-gray-200 pt-6">
    <h2 class="text-base font-semibold text-gray-800">Skabelondata</h2>

    <a
      href={skabelonExcelHref}
      target="_blank"
      rel="noopener noreferrer"
      class="{externalLinkClass} mt-2 text-sm"
    >
      Afgørelsesbreve.xlsx (skabelontekster)
      <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M14 3h7m0 0v7m0-7L10 14M5 5H3a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-2" />
      </svg>
    </a>

    <p class="text-sm text-gray-500 mt-3 mb-4">
      Henter de nyeste skabeloner for afgørelsesbreve fra SharePoint ind i
      systemet. Kør den, når skabelonerne er blevet rettet.
    </p>

    <UpdateTemplateButton class="px-4 py-2 text-sm" />
  </section>

  <section class="mt-10 border-t border-gray-200 pt-6">
    <h2 class="text-base font-semibold text-gray-800">Kørselsgodtgørelse</h2>
    <p class="text-sm text-gray-500 mt-1 mb-4">
      Liste over alle, der på nuværende tidspunkt modtager kørselsgodtgørelse for
      egen befordring — én linje pr. modtager, uanset hvor mange kørselsrækker
      eller børn det drejer sig om. Listen dannes ud fra dagens dato.
    </p>

    <!-- A plain link, not a fetch: the browser sends the session cookie and
         owns the save dialog. data-sveltekit-reload keeps the client router
         from intercepting it and trying to render a CSV as a page. -->
    <a
      href="/links/modtagere.csv"
      data-sveltekit-reload
      class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium bg-[#032A42] text-white rounded hover:bg-[#04374f] transition-colors"
    >
      <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2M7 10l5 5 5-5M12 15V3" />
      </svg>
      Hent modtagerliste (CSV)
    </a>
  </section>
</div>
