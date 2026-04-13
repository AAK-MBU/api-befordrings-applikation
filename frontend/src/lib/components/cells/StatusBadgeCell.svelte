<script>
  import { statusBadgeClasses } from "$lib/tableColumnConfig";

  export let row;

  const value = row.status ?? "";
  const lower = value.toLowerCase();

  const colorClass =
    statusBadgeClasses[lower] ?? statusBadgeClasses.default;
</script>

<span class="inline-flex items-center rounded-full px-3 py-1 text-xs font-medium {colorClass}">
  {value}
</span>