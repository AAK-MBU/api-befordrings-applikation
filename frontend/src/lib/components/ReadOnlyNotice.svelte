<script lang="ts">
  import { env as publicEnv } from "$env/dynamic/public";
  import { page } from "$app/stores";

  /**
   * Explains, once per page, why the edit controls are greyed out.
   *
   * A page-level notice rather than a tooltip on each disabled control: a
   * disabled button fires no mouse events and drops out of the tab order, so
   * its title attribute is unreliable and assistive technology skips it. This
   * sits in the document flow, so the reason is always reachable.
   *
   * Read from $page.data rather than a module-level store — during SSR a
   * module-level store is shared between concurrent requests, which would leak
   * one user's permissions into another's render. $page is request-scoped.
   */
  $: canEdit = $page.data.user?.can_edit ?? false;

  const systemregisterUrl = publicEnv.PUBLIC_SYSTEMREGISTER_URL;
</script>

{#if !canEdit}
  <div
    class="mb-6 flex items-start gap-3 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3"
    role="status"
  >
    <svg
      class="w-5 h-5 text-amber-600 shrink-0 mt-0.5"
      fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"
      aria-hidden="true"
    >
      <path
        stroke-linecap="round" stroke-linejoin="round"
        d="M12 9v4m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"
      />
    </svg>

    <div class="text-sm">
      <p class="font-semibold text-amber-900">Du har kun læseadgang</p>
      <p class="mt-0.5 text-amber-800">
        Du kan se alle oplysninger, men ikke oprette, ændre eller slette.
        Skriveadgang tildeles centralt — ansøg gennem
        {#if systemregisterUrl}
          <a class="underline font-medium" href={systemregisterUrl}>Systemregisteret</a>.
        {:else}
          Systemregisteret.
        {/if}
      </p>
    </div>
  </div>
{/if}
