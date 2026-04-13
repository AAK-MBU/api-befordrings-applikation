<script lang="ts">
  export let row: any;

  export let onEdit: (row: any) => void;
  export let onSave: (row: any) => void;
  export let onCancel: () => void;

  export let isEditing: boolean = false;
</script>

{#if isEditing}

  <button
    class="text-green-600 hover:underline"
    on:click={() => onSave(row)}
  >
    ✔️
  </button>

  <button
    class="text-gray-500 hover:underline ml-1"
    on:click={onCancel}
  >
    ❌
  </button>

{:else}

  <button
    class="text-blue-600 hover:underline"
    on:click={() => onEdit(row)}
  >
    ✏️
  </button>

{/if}