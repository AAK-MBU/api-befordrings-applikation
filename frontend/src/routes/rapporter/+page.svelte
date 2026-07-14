
<script lang="ts">
  const reports = [
    { label: "Elevbefordring (oversigt) Standardrapport", href: "https://lismbu.adm.aarhuskommune.dk/SASStoredProcess/do?_program=/Aarhus/MBU/LIS/System/LIS&lisaction=rapframe&indk=001993470574233&org=819718&pertype=REGNSKABSAAR&periode=2026&min_id=866388" },
    { label: "Elevbefordring (taxa og minibus) Standardrapport", href: "https://lismbu.adm.aarhuskommune.dk/SASStoredProcess/do?_program=/Aarhus/MBU/LIS/System/LIS&lisaction=rapframe&indk=001894629216178&org=819718&pertype=REGNSKABSAAR&periode=2026&min_id=866388" },
    { label: "Elevbefordring (buskort) Standardrapport", href: "https://lismbu.adm.aarhuskommune.dk/SASStoredProcess/do?_program=/Aarhus/MBU/LIS/System/LIS&lisaction=rapframe&indk=001991385148085&org=819718&pertype=REGNSKABSAAR&periode=2026&min_id=866388" },
  ];
</script>

<div class="p-8 max-w-2xl">
  <h1 class="text-2xl font-semibold text-gray-800 mb-6">Rapporter</h1>
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
</div>
