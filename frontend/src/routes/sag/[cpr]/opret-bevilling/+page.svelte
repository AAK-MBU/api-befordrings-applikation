<script lang="ts">
  /**
   * "Opret bevilling" as a page of its own, so it can be opened in a separate
   * browser window and moved to another screen while the sag page stays
   * readable. Same component the sag page mounts inline — only how it is
   * closed differs.
   */

  import { onMount } from "svelte";
  import { goto } from "$app/navigation";
  import { page } from "$app/stores";

  import CreateBevillingModal from "$lib/components/CreateBevillingModal.svelte";
  import { sendSagBesked } from "$lib/sagKanal";

  export let data;

  // ?mode=kopi mirrors the sag page's "Ny bevilling fra kopi" button. As there,
  // the source bevilling is not fixed in advance: the form opens on the active
  // one and offers the rest in a dropdown.
  $: mode = ($page.url.searchParams.get("mode") === "kopi" ? "kopi" : "tom") as "kopi" | "tom";

  // Opened from the button, this is a popup and window.close() works. Opened
  // from a pasted link it is an ordinary tab, where close() is blocked — then
  // the way back is the case itself.
  let erPopup = false;

  onMount(() => {
    erPopup = window.opener !== null && window.opener !== window;
  });

  function luk() {
    if (erPopup) {
      window.close();
      return;
    }

    goto(`/sag/${data.cpr}`);
  }

  function efterOprettelse() {
    // Sent before closing: the sag page reloads itself so the new bevilling is
    // on screen there by the time this window disappears.
    sendSagBesked({ type: "bevilling-oprettet", cpr: data.cpr });
    luk();
  }
</script>

<svelte:head>
  <title>Opret bevilling — {data.stamdata?.adresseringsnavn ?? data.cpr}</title>
</svelte:head>

<CreateBevillingModal
  cpr={data.stamdata.cpr}
  {mode}
  existingBevillinger={data.bevillinger ?? []}
  elevklassetrin={data.stamdata?.elevklassetrin ?? null}
  skoleafstand={data.stamdata?.skoleafstand ?? null}
  parter={data.recipients}
  lookupOptions={data.lookupOptions}
  standalone
  on:created={efterOprettelse}
  on:cancel={luk}
/>
