<script lang="ts">
  import { page } from "$app/stores";

  import { backendFetch } from "$lib/client/backendFetch";

  // Which template process to refresh. Matches the {process} route param on
  // the backend (currently only "afgoerelsesbreve" is supported).
  export let process = "afgoerelsesbreve";

  // Extra classes so the button fits both the case page and the revurdering
  // header (e.g. different padding / text size).
  let extraClass = "px-4 py-2 text-sm";
  export { extraClass as class };

  let updating = false;

  // Refreshing template data writes to rpa.Templates, so it needs the same
  // roles as any other change. Resolved by the backend from EDIT_ROLES; the
  // endpoint enforces it with RequireEdit regardless of what the button shows.
  $: canEdit = $page.data.user?.can_edit ?? false;

  async function updateTemplateData() {
    if (updating || !canEdit) return;

    updating = true;

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

        alert(message);
        return;
      }

      const result = await response.json();

      alert(result?.message ?? "Skabelondata blev opdateret.");
    } catch (error) {
      alert("Kunne ikke opdatere skabelondata - prøv igen.");
    } finally {
      updating = false;
    }
  }
</script>

<button
  type="button"
  disabled={updating || !canEdit}
  class="{extraClass} font-medium text-white rounded transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
  style="background-color: #032A42;"
  on:click={updateTemplateData}
>
  {updating ? "Opdaterer..." : "Opdater skabelondata"}
</button>
