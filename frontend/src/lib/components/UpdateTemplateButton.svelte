<script lang="ts">
  import { page } from "$app/stores";

  import { backendFetch } from "$lib/client/backendFetch";

  // Which template process to refresh. Matches the {process} route param on
  // the backend (currently only "afgoerelsesbreve" is supported).
  export let process = "afgoerelsesbreve";

  // Extra classes so the button fits wherever it is mounted (e.g. different
  // padding / text size).
  let extraClass = "px-4 py-2 text-sm";
  export { extraClass as class };

  let updating = false;

  // Outcome of the last run, shown as a bar under the button rather than a
  // browser alert. Persists until the next click — the import is infrequent
  // and slow enough that the caseworker wants to be able to look back at it.
  let resultMessage: string | null = null;
  let resultOk = false;

  // Refreshing template data writes to rpa.Templates, so it needs the same
  // roles as any other change. Resolved by the backend from EDIT_ROLES; the
  // endpoint enforces it with RequireEdit regardless of what the button shows.
  $: canEdit = $page.data.user?.can_edit ?? false;

  async function updateTemplateData() {
    if (updating || !canEdit) return;

    updating = true;
    resultMessage = null;

    try {
      const response = await backendFetch(
        `/templates_handler/update_template_data/${process}`,
        { method: "GET" }
      );

      if (!response.ok) {
        let message = "Kunne ikke opdatere skabelondata";

        try {
          const errorData = await response.json();
          message = errorData?.detail?.message ?? errorData?.detail ?? message;
        } catch {
          // Keep fallback message
        }

        resultMessage = message;
        resultOk = false;
        return;
      }

      const result = await response.json();

      resultMessage = result?.message ?? "Skabelondata blev opdateret.";
      resultOk = true;
    } catch (error) {
      resultMessage = "Kunne ikke opdatere skabelondata - prøv igen.";
      resultOk = false;
    } finally {
      updating = false;
    }
  }
</script>

<div>
  <button
    type="button"
    disabled={updating || !canEdit}
    class="{extraClass} font-medium text-white rounded transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
    style="background-color: #032A42;"
    on:click={updateTemplateData}
  >
    {updating ? "Opdaterer..." : "Opdater skabelondata"}
  </button>

  {#if resultMessage}
    <div
      class="mt-3 px-3 py-2 text-sm rounded border {resultOk
        ? 'text-green-800 bg-green-50 border-green-200'
        : 'text-red-700 bg-red-50 border-red-200'}"
      role={resultOk ? "status" : "alert"}
    >
      {resultMessage}
    </div>
  {/if}
</div>
