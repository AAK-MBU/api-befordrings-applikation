<script>
  export let row;
  export let editableRow;
  export let isEditing;
  export let columnKey;
</script>

{#if isEditing}
  <input
    class="border p-1 w-full"
    bind:value={editableRow[columnKey]}
  />
{:else}
  {row[columnKey]}
{/if}