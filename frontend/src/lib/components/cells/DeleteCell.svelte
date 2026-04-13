<script lang="ts">
  export let row: any;
  export let onDelete: (id: number) => void;
</script>

<button
  class="text-red-600 hover:underline"
  on:click={() => onDelete(row.bevilling_id)}
>
  🗑️
</button>