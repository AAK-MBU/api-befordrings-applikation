<script lang="ts">
  // -----------------------------
  // Types
  // -----------------------------

  export type DataTableColumn = {
    key: string;
    label: string;
    filterable?: boolean;
    editable?: boolean;
    render?: (row: any) => string;
    class?: string;
  };


  // -----------------------------
  // Props
  // -----------------------------

  export let data: any[] = [];
  export let columns: DataTableColumn[] = [];

  export let filterable = true;
  export let emptyMessage = "Ingen data fundet";

  export let editable = false;
  export let editingRowId: string | number | null = null;
  export let editableRow: any = null;

  export let getRowId: (row: any, index: number) => string | number = (_row, index) => index;

  export let onEdit: (row: any) => void = () => {};
  export let onSave: (row: any) => void = () => {};
  export let onCancel: () => void = () => {};
  export let onInputChange: (key: string, value: any) => void = () => {};


  // -----------------------------
  // Table state
  // -----------------------------

  let filters: Record<string, string> = {};


  // -----------------------------
  // Derived data
  // -----------------------------

  $: filteredData = data.filter((row) => {
    if (!filterable) {
      return true;
    }

    return columns.every((column) => {
      if (column.filterable === false) {
        return true;
      }

      const rowValue = String(row[column.key] ?? "").toLowerCase();
      const filterValue = String(filters[column.key] ?? "").toLowerCase();

      return rowValue.includes(filterValue);
    });
  });
</script>


<div class="w-full overflow-x-auto">

  <table class="w-full text-sm text-left border-collapse">

    <thead>

      <!-- Column headers -->
      <tr class="bg-gray-100 text-gray-800">

        {#if editable}
          <th class="px-3 py-2 font-semibold whitespace-nowrap"></th>
        {/if}

        {#each columns as column}
          <th class={`px-3 py-2 font-semibold whitespace-normal min-w-36 ${column.class ?? ""}`}>
            {column.label}
          </th>
        {/each}

      </tr>


      <!-- Optional filter row -->
      {#if filterable}
        <tr class="bg-white">

          {#if editable}
            <td class="px-2 py-1 border-b border-gray-200"></td>
          {/if}

          {#each columns as column}
            <td class="px-2 py-1 border-b border-gray-200">

              {#if column.filterable !== false}
                <input
                  type="text"
                  class="w-full border border-gray-300 px-2 py-1 text-sm"
                  bind:value={filters[column.key]}
                />
              {/if}

            </td>
          {/each}

        </tr>
      {/if}

    </thead>


    <tbody>

      {#if filteredData.length === 0}

        <tr>
          <td
            colspan={columns.length + (editable ? 1 : 0)}
            class="px-3 py-6 text-center text-gray-500"
          >
            {emptyMessage}
          </td>
        </tr>

      {:else}

        {#each filteredData as row, index}

          {@const rowId = getRowId(row, index)}
          {@const isEditing = editingRowId === rowId}

          <tr class="border-b border-gray-100 hover:bg-gray-50">

            {#if editable}
              <td class="px-3 py-2 whitespace-nowrap">

                {#if isEditing}
                  <button
                    type="button"
                    class="text-green-600 hover:underline mr-2"
                    on:click={() => onSave(row)}
                  >
                    Gem
                  </button>

                  <button
                    type="button"
                    class="text-red-500 hover:underline"
                    on:click={onCancel}
                  >
                    Annullér
                  </button>
                {:else}
                  <button
                    type="button"
                    class="text-sky-600 hover:underline"
                    on:click={() => onEdit(row)}
                  >
                    Redigér
                  </button>
                {/if}

              </td>
            {/if}


            {#each columns as column}

              <td class={`px-3 py-2 whitespace-nowrap ${column.class ?? ""}`}>

                {#if isEditing && column.editable === true}

                  <input
                    class="min-w-44 w-full border border-gray-300 px-2 py-1 text-sm"
                    value={editableRow?.[column.key] ?? ""}
                    on:input={(event) => {
                      const target = event.target as HTMLInputElement;
                      onInputChange(column.key, target.value);
                    }}
                  />

                {:else if column.render}

                  {@html column.render(row)}

                {:else}

                  {row[column.key] ?? ""}

                {/if}

              </td>

            {/each}

          </tr>

        {/each}

      {/if}

    </tbody>

  </table>

</div>