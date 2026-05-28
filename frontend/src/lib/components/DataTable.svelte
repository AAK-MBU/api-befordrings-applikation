<script lang="ts">
  // -----------------------------
  // Types
  // -----------------------------

  import {
    tablePrimaryActionButtonClass,
    tableSaveActionButtonClass,
    tableCancelActionButtonClass
  } from "$lib/tableColumnConfig";

  export type DataTableColumn = {
    key: string;
    label: string;
    filterable?: boolean;
    editable?: boolean;
    render?: (row: any) => string;
    class?: string;
    selectOptions?: { value: string | number; label: string }[];
    inputType?: string;
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

  export let rowStyle: ((row: any) => string) | null = null;


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

  <table class="w-full text-sm text-gray-700 border-collapse">

    <thead>

      <!-- Column headers -->
      <tr class="text-white" style="background-color: #032A42;">

        {#if editable}
          <th class="px-4 py-3 font-semibold whitespace-nowrap text-left sticky left-0 z-10" style="background-color: #032A42;"></th>
        {/if}

        {#each columns as column}
          <th class={`px-4 py-3 font-semibold whitespace-normal min-w-36 text-left ${column.class ?? ""}`}>
            {column.label}
          </th>
        {/each}

      </tr>


      <!-- Optional filter row -->
      {#if filterable}
        <tr class="bg-gray-100 border-b border-gray-300">

          {#if editable}
            <td class="px-3 py-2 sticky left-0 z-10 bg-gray-100"></td>
          {/if}

          {#each columns as column}
            <td class="px-3 py-2">

              {#if column.filterable !== false}
                <input
                  type="text"
                  placeholder="Søg..."
                  class="w-full border border-gray-200 rounded px-2 py-1 text-xs focus:border-blue-400 focus:ring-0 transition-colors bg-white"
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
            class="px-4 py-8 text-center text-gray-500 bg-gray-50"
          >
            {emptyMessage}
          </td>
        </tr>

      {:else}

        {#each filteredData as row, index}

          {@const rowId = getRowId(row, index)}
          {@const isEditing = editingRowId === rowId}
          {@const rowBg = index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}

          <tr class={`group border-b border-gray-200 hover:bg-blue-50 transition-colors ${rowBg}`} style={rowStyle ? rowStyle(row) : ""}>

            {#if editable}
              <td class={`px-4 py-3 whitespace-nowrap sticky left-0 z-10 ${rowBg} group-hover:bg-blue-50 transition-colors`}>

                {#if isEditing}
                  <button
                    type="button"
                    class={tableSaveActionButtonClass}
                    on:click={() => onSave(row)}
                  >
                    Gem
                  </button>

                  <button
                    type="button"
                    class={tableCancelActionButtonClass}
                    on:click={onCancel}
                  >
                    Annullér
                  </button>
                {:else}
                  <button
                    type="button"
                    class={tablePrimaryActionButtonClass}
                    on:click={() => onEdit(row)}
                  >
                    Redigér
                  </button>
                {/if}

              </td>
            {/if}


            {#each columns as column}

              <td class={`px-4 py-3 whitespace-nowrap ${column.class ?? ""}`}>

                {#if isEditing && column.editable === true}

                  {#if column.selectOptions}
                    <select
                      class="min-w-44 border-2 border-gray-300 rounded px-2 py-1 text-sm focus:border-blue-500 focus:ring-0 bg-white"
                      value={editableRow?.[column.key] ?? ""}
                      on:change={(event) => {
                        const target = event.target as HTMLSelectElement;
                        const val = target.value === "" ? null : Number(target.value);
                        onInputChange(column.key, val);
                      }}
                    >
                      <option value="">— Vælg —</option>
                      {#each column.selectOptions as opt}
                        <option value={opt.value}>{opt.label}</option>
                      {/each}
                    </select>
                  {:else}
                    <input
                      type={column.inputType ?? "text"}
                      class="min-w-44 w-full border-2 border-gray-300 rounded px-2 py-1 text-sm focus:border-blue-500 focus:ring-0"
                      value={editableRow?.[column.key] ?? ""}
                      on:input={(event) => {
                        const target = event.target as HTMLInputElement;
                        onInputChange(column.key, target.value || null);
                      }}
                    />
                  {/if}

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