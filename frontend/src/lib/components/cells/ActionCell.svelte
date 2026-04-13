<script lang="ts">
  export let row: any;

  export let onDelete: (id: number) => void;

  export let onEdit: (row: any) => void;
  export let onSave: (row: any) => void;
  export let onCancel: () => void;

  export let isEditing: boolean = false;
</script>

{#if isEditing}

  <button
    class="text-green-600 mr-2 hover:underline"
    on:click={() => onSave(row)}
  >
    Gem
  </button>

  <button
    class="text-gray-500 hover:underline"
    on:click={onCancel}
  >
    Annuller
  </button>

{:else}

  <button
    class="text-blue-600 mr-2 hover:underline"
    on:click={() => onEdit(row)}
  >
    ✏️
  </button>

  <button
    class="text-red-600 hover:underline"
    on:click={() => onDelete(row.bevilling_id)}
  >
    🗑️
  </button>

{/if}
