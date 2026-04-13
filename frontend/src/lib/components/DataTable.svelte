<script lang="ts">

  export let onCreate: (bevilling_id: number) => void = () => {};

  export let isEditing: boolean = false;

  export let onEdit: (row: any) => void = () => {};
  export let onSave: (row: any) => void = () => {};
  export let onCancel: () => void = () => {};
  export let editingBevillingId: number | null = null;

  export let data: any = [];
  export let columns: any = [];

  export let onInputChange: (key: string, value: any) => void = () => {};

  export let deleteBevilling: (id: number) => void = () => {};

  export let filterable = true;

  export let editableRow: any = null;

  export let expandable = false;
  export let renderExpanded: ((row: any) => string) | null = null;

	export let creatingFor: number | null = null;
	export let newRow: any = {};

	export let onSaveNew: (bevilling_id: number) => void = () => {};
	export let onCancelNew: () => void = () => {};


  let filters: Record<string, string> = {};

  let expandedRows = new Set<number>();

  function toggleRow(index: number) {
    if (expandedRows.has(index)) {
      expandedRows.delete(index);
    } else {
      expandedRows.add(index);
    }

    expandedRows = new Set(expandedRows);
  }

  $: filteredData = data.filter((row: any) => {
    if (filterable) {
      return columns.every((col: any) => {
        const value = String(row[col.key] ?? "").toLowerCase();
        const filter = filters[col.key]?.toLowerCase() ?? "";
        return value.includes(filter);
      });
    }
    return true;
  });
</script>

<div class="bg-white p-4 rounded-lg shadow-sm border">

  <div class="overflow-x-auto">

    <table class="w-full text-sm text-left border-collapse">

      <!-- HEADER -->
      <thead class="bg-gray-100 text-gray-600 text-xs uppercase tracking-wide">
        <tr>
          {#if expandable}
            <th class="px-4 py-3"></th>
          {/if}

          {#each columns as col}
            <th class="px-4 py-3 font-semibold text-gray-700 whitespace-nowrap">
              {col.label}
            </th>
          {/each}
        </tr>

        <!-- FILTER ROW -->
        {#if filterable}
          <tr>
            {#if expandable}
              <td></td>
            {/if}

            {#each columns as col}
              <td class="px-4 py-3">

                {#if col.filterable === false}
                  <!-- empty cell -->
                {:else}
                  <input
                    type="text"
                    placeholder={`Søg`}
                    class="border rounded px-2 py-1 w-full text-sm"
                    value={filters[col.key] ?? ""}
                    on:input={(e) => {
                      const target = e.target as HTMLInputElement;
                      filters = {
                        ...filters,
                        [col.key]: target.value
                      };
                    }}
                  />
                {/if}

              </td>
            {/each}
          </tr>
        {/if}
      </thead>

      <!-- BODY -->
      <tbody class="divide-y divide-gray-100">

        {#each filteredData as row, index}

          <!-- MAIN ROW -->
          <tr
            class="hover:bg-gray-50 transition border border-gray-200 border-b-0"
          >

            {#if expandable}
              <td class="px-4 py-4 align-top">
                <button
                  class="text-blue-600 text-xs font-medium hover:underline"
                  on:click={() => toggleRow(index)}
                >
                  {expandedRows.has(index) ? "Skjul detaljer" : "Vis detaljer"}
                </button>
              </td>
            {/if}

            {#each columns as col}
              <td class="px-4 py-5 whitespace-nowrap text-gray-800">

                {#if col.component}

                  <svelte:component
                    this={col.component}
                    {row}

                    onDelete={deleteBevilling}
                    onEdit={onEdit}
                    onSave={onSave}
                    onCancel={onCancel}

                    newRow={newRow}

                    onInputChange={onInputChange}
                    onSaveNew={onSaveNew}
                    onCancelNew={onCancelNew}

                    isEditing={editingBevillingId === row.bevilling_id}

                  />

                {:else if (isEditing || editingBevillingId === row.bevilling_id) && col.key !== "actions" && col.editable !== false}
                  <input
                    class="border px-2 py-1 w-full"
                    value={editableRow?.[col.key] ?? row[col.key]}
                    on:input={(e) => {
                      const target = e.target as HTMLInputElement;

                      onInputChange(col.key, target.value);
                    }}
                  />

                {:else if col.render}
                  {@html col.render(row)}


                {:else}
                  {row[col.key]}
                {/if}

              </td>
            {/each}

          </tr>

          <!-- EXPANDED ROW -->
          {#if expandable && expandedRows.has(index)}

            <tr>
                <td colspan={columns.length + (expandable ? 1 : 0)} class="bg-gray-50">

                <div class="ml-6 mr-4 mb-3 mt-1 p-3 bg-white border border-gray-200 rounded-md shadow-sm">

                    <div class="ml-4 border-l-2 border-gray-300 pl-4">

                    {#if renderExpanded}
                      <svelte:component
                        this={renderExpanded}
                        {row}

                        onCreate={onCreate}

                        creatingFor={creatingFor}
                        newRow={newRow}

                        onInputChange={onInputChange}
                        onSaveNew={onSaveNew}
                        onCancelNew={onCancelNew}
                      />
                    {:else}
                        <div class="text-sm text-gray-500">
                        No expanded content
                        </div>
                    {/if}

                    </div>

                </div>

                </td>
            </tr>

          {/if}

        {/each}

      </tbody>

    </table>

  </div>

</div>