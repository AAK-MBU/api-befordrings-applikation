<script lang="ts">
  /**
   * "Opret brev" as a page of its own — same arrangement as opret-bevilling,
   * so the letter can be written in a window beside the case rather than on
   * top of it.
   */

  import { onMount } from "svelte";
  import { goto } from "$app/navigation";

  import CreateLetterModal from "$lib/components/CreateLetterModal.svelte";
  import { sendSagBesked } from "$lib/sagKanal";

  export let data;

  // The modal closes itself by setting this to false — on Luk, on Escape, and
  // on the backdrop. Whichever way it went, this window has no further purpose.
  let open = true;

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

  $: if (!open) luk();

  // Unlike the bevilling form this does not close on success: the modal swaps
  // to a panel showing the GO reference, which is the only place it appears.
  // So this only tells the sag page to reload — the caseworker closes the
  // window once they have read it.
  function efterOprettelse() {
    sendSagBesked({ type: "brev-oprettet", cpr: data.cpr });
  }
</script>

<svelte:head>
  <title>Opret brev — {data.stamdata?.adresseringsnavn ?? data.cpr}</title>
</svelte:head>

<CreateLetterModal
  bind:open
  cpr={data.stamdata.cpr}
  bevillinger={data.bevillinger}
  standalone
  on:created={efterOprettelse}
/>
