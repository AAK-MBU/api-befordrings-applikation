  <script lang="ts">
    import { invalidateAll } from "$app/navigation";
    import { backendFetch } from "$lib/client/backendFetch";
    import { formatDanishDate, getStatusBadgeClass, formatCpr } from "$lib/tableColumnConfig";
    import BevillingTable from "$lib/components/BevillingTable.svelte";
    import AddresseSearch from "$lib/components/AddresseSearch.svelte";
    import UpdateTemplateButton from "$lib/components/UpdateTemplateButton.svelte";

    export let data;

    $: revurderinger        = data.revurderinger        ?? [];
    $: koerselstyper        = data.koerselstyper        ?? [];
    $: tidspunkter          = data.tidspunkter          ?? [];
    $: hjemler              = data.hjemler              ?? [];
    $: afgoerelsesbreve     = data.afgoerelsesbreve     ?? [];
    $: koerselstypeTillaeg  = data.koerselstypeTillaeg  ?? [];
    $: dage                 = data.dage                 ?? [];
    $: statuser             = data.statuser             ?? [];
    $: skolematrikler       = data.skolematrikler       ?? [];
    $: sagsbehandlere       = data.sagsbehandlere       ?? [];
    $: pprSagsbehandlere    = data.pprSagsbehandlere    ?? [];
    $: hjaelpemidler        = data.hjaelpemidler        ?? [];
    $: ungdomsuddannelser   = data.ungdomsuddannelser   ?? [];

    $: lookupOptions = {
      koerselstyper, tidspunkter, koerselstypeTillaeg, dage,
      statuser, skolematrikler, hjemler, afgoerelsesbreve,
      sagsbehandlere, pprSagsbehandlere, hjaelpemidler, ungdomsuddannelser,
    };

    // ---------------------------------------------------------------------------
    // Filters
    // ---------------------------------------------------------------------------

    let selectedSkole = "";
    let selectedSagsbehandler = "";
    let selectedPprSagsbehandler = "";

    $: uniqueSkoler           = [...new Set(revurderinger.map((b: any) => b.skole_navn).filter(Boolean))].sort() as string[];
    $: uniqueSagsbehandlere   = [...new Set(revurderinger.map((b: any) => b.sagsbehandler_tekst).filter(Boolean))].sort() as string[];
    $: uniquePprSagsbehandlere = [...new Set(revurderinger.map((b: any) => b.ppr_sagsbehandler_tekst).filter(Boolean))].sort() as string[];

    $: filteredRevurderinger = revurderinger.filter((b: any) => {
      if (selectedSkole            && b.skole_navn              !== selectedSkole)            return false;
      if (selectedSagsbehandler    && b.sagsbehandler_tekst     !== selectedSagsbehandler)    return false;
      if (selectedPprSagsbehandler && b.ppr_sagsbehandler_tekst !== selectedPprSagsbehandler) return false;
      return true;
    });

    $: anyFilterActive = !!(selectedSkole || selectedSagsbehandler || selectedPprSagsbehandler);

    // ---------------------------------------------------------------------------
    // Summary stats
    // ---------------------------------------------------------------------------

    $: overskredet    = revurderinger.filter((b: any) => (daysUntil(b.revurderingsdato) ?? 0) < 0).length;
    $: indenFor30Dage = revurderinger.filter((b: any) => { const d = daysUntil(b.revurderingsdato); return d !== null && d >= 0 && d <= 30; }).length;

    // ---------------------------------------------------------------------------
    // Urgency helpers
    // ---------------------------------------------------------------------------

    function daysUntil(dateStr: string | null): number | null {
      if (!dateStr) return null;
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const target = new Date(dateStr);
      return Math.floor((target.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
    }

    function urgencyColor(revurderingsdato: string | null): string {
      const d = daysUntil(revurderingsdato);
      if (d === null) return "#6b7280";
      if (d < 0)     return "#dc2626";
      if (d <= 30)   return "#ca8a04";
      return "#3b82f6";
    }

    function urgencyLabel(revurderingsdato: string | null): string {
      const d = daysUntil(revurderingsdato);
      if (d === null) return "Ingen dato";
      if (d < 0)     return `${Math.abs(d)} dage overskredet`;
      if (d === 0)   return "I dag";
      if (d === 1)   return "I morgen";
      return `Om ${d} dage`;
    }

    // ---------------------------------------------------------------------------
    // Expand / collapse
    // ---------------------------------------------------------------------------

    let expandedIds = new Set<number>();

    function toggleExpand(id: number) {
      if (expandedIds.has(id)) {
        expandedIds.delete(id);
      } else {
        expandedIds.add(id);
        const bev = revurderinger.find((r: any) => r.bevilling_id === id);
        if (bev) {
          if (!aktiviteterByCpr[bev.cpr_elev]) loadAktiviteter(bev.cpr_elev);
          if (!bevillingerByCpr[bev.cpr_elev]) loadBevillinger(bev.cpr_elev);
        }
      }
      expandedIds = new Set(expandedIds);
    }

    function expandAll() {
      expandedIds = new Set(filteredRevurderinger.map((b: any) => b.bevilling_id));
      filteredRevurderinger.forEach((bev: any) => {
        if (!aktiviteterByCpr[bev.cpr_elev]) loadAktiviteter(bev.cpr_elev);
        if (!bevillingerByCpr[bev.cpr_elev]) loadBevillinger(bev.cpr_elev);
      });
    }

    function collapseAll() {
      expandedIds = new Set();
    }

    $: allExpanded = filteredRevurderinger.length > 0 && filteredRevurderinger.every((b: any) => expandedIds.has(b.bevilling_id));

    // ---------------------------------------------------------------------------
    // Bevilling save / koerselsraekke handlers (used by BevillingTable)
    // ---------------------------------------------------------------------------

    function emptyToNull(value: any) { return value === "" ? null : value; }
    function numberOrNull(value: any) { return value === "" ? null : Number(value); }

    async function handleSaveBevilling(bevillingId: number, updates: any): Promise<boolean> {
      const { hjaelpemiddel_ids, ...bevillingUpdates } = updates;
      const res = await backendFetch(`/bevilling/${bevillingId}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(bevillingUpdates),
      });
      if (!res.ok) { alert("Kunne ikke gemme bevilling"); return false; }
      await backendFetch(`/bevilling/${bevillingId}/hjaelpemidler`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ hjaelpemiddel_ids: hjaelpemiddel_ids ?? [] }),
      });
      await invalidateAll();
      return true;
    }

    async function handleSaveKoerselsraekke(koerselId: number, updates: any): Promise<boolean> {
      const { tillaeg_ids, dag_ids, ...rest } = updates;
      const r1 = await backendFetch(`/bevilling/koerselsraekke/${koerselId}`, {
        method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify(rest),
      });
      if (!r1.ok) return false;
      const r2 = await backendFetch(`/bevilling/koerselsraekke/${koerselId}/tillaeg`, {
        method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ tillaeg_ids: tillaeg_ids ?? [] }),
      });
      if (!r2.ok) return false;
      const r3 = await backendFetch(`/bevilling/koerselsraekke/${koerselId}/dage`, {
        method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ dag_ids: dag_ids ?? [] }),
      });
      if (!r3.ok) return false;
      await invalidateAll();
      return true;
    }

    async function handleCreateKoerselsraekke(bevillingId: number, updates: any): Promise<boolean> {
      const res = await backendFetch(`/bevilling/create_koerselsraekke/${bevillingId}`, {
        method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(updates),
      });
      if (!res.ok) return false;
      await invalidateAll();
      return true;
    }

    async function handleFinalizeKoerselsraekke(koerselId: number): Promise<boolean> {
      const res = await backendFetch(`/bevilling/koerselsraekke/${koerselId}`, {
        method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ final: true }),
      });
      if (!res.ok) return false;
      await invalidateAll();
      return true;
    }

    // ---------------------------------------------------------------------------
    // PPR toggle
    // ---------------------------------------------------------------------------

    async function togglePpr(bevillingId: number, cpr: string, current: boolean | null) {
      const res = await backendFetch(`/bevilling/${bevillingId}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ revurderet_af_ppr: !current }),
      });
      if (!res.ok) { console.error("Failed to update revurderet_af_ppr:", res.status); return; }
      await loadAktiviteter(cpr);
      await invalidateAll();
    }

    // ---------------------------------------------------------------------------
    // BR / PPR confirm popups
    // ---------------------------------------------------------------------------

    let brConfirmFor: { bevillingId: number; cpr: string; current: boolean | null } | null = null;
    let pprConfirmFor: { bevillingId: number; cpr: string; current: boolean | null } | null = null;

    function openBrConfirm(bevillingId: number, cpr: string, current: boolean | null) {
      if (current) { toggleBr(bevillingId, cpr, current); return; }
      brConfirmFor = { bevillingId, cpr, current };
    }

    function openPprConfirm(bevillingId: number, cpr: string, current: boolean | null) {
      if (current) { togglePpr(bevillingId, cpr, current); return; }
      pprConfirmFor = { bevillingId, cpr, current };
    }

    async function toggleBr(bevillingId: number, cpr: string, current: boolean | null) {
      const res = await backendFetch(`/bevilling/${bevillingId}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ revurderet_af_br: !current }),
      });
      if (!res.ok) { console.error("Failed to update revurderet_af_br:", res.status); return; }
      await loadAktiviteter(cpr);
      await invalidateAll();
    }

    // ---------------------------------------------------------------------------
    // Aktiviteter — lazy-loaded per CPR
    // ---------------------------------------------------------------------------

    let aktiviteterByCpr: Record<string, any[]> = {};
    let loadingAktiviteterCpr = new Set<string>();

    async function loadAktiviteter(cpr: string) {
      loadingAktiviteterCpr.add(cpr);
      loadingAktiviteterCpr = new Set(loadingAktiviteterCpr);
      try {
        const res = await backendFetch(`/aktivitet/${cpr}`);
        if (res.ok) {
          aktiviteterByCpr[cpr] = await res.json();
          aktiviteterByCpr = { ...aktiviteterByCpr };
        }
      } finally {
        loadingAktiviteterCpr.delete(cpr);
        loadingAktiviteterCpr = new Set(loadingAktiviteterCpr);
      }
    }

    // Comments fold-down state per bevilling_id
    let expandedCommentsBevIds = new Set<number>();

    function toggleComments(bevillingId: number) {
      if (expandedCommentsBevIds.has(bevillingId)) {
        expandedCommentsBevIds.delete(bevillingId);
      } else {
        expandedCommentsBevIds.add(bevillingId);
      }
      expandedCommentsBevIds = new Set(expandedCommentsBevIds);
    }

    // ---------------------------------------------------------------------------
    // Comment modal
    // ---------------------------------------------------------------------------

    let showCommentModal = false;
    let commentModalCpr = "";
    let commentModalBevillingId: number | null = null;
    let newComment = "";
    let savingComment = false;

    let inlineComments: Record<number, string> = {};
    let savingInlineCommentIds = new Set<number>();

    async function saveInlineComment(cpr: string, bevillingId: number) {
      const kommentar = (inlineComments[bevillingId] ?? "").trim();
      if (!kommentar) return;
      savingInlineCommentIds.add(bevillingId);
      savingInlineCommentIds = new Set(savingInlineCommentIds);
      try {
        const res = await backendFetch(`/aktivitet/${cpr}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ aktivitetstype: "Kommentar", kommentar, udfoert_af: null, relateret_bevilling_id: bevillingId }),
        });
        if (res.ok) {
          inlineComments = { ...inlineComments, [bevillingId]: "" };
          await loadAktiviteter(cpr);
        }
      } finally {
        savingInlineCommentIds.delete(bevillingId);
        savingInlineCommentIds = new Set(savingInlineCommentIds);
      }
    }

    function openCommentModal(cpr: string, bevillingId: number) {
      commentModalCpr = cpr;
      commentModalBevillingId = bevillingId;
      newComment = "";
      showCommentModal = true;
    }

    async function saveComment() {
      const kommentar = newComment.trim();
      if (!kommentar) return;
      savingComment = true;
      try {
        const res = await backendFetch(`/aktivitet/${commentModalCpr}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            aktivitetstype: "Kommentar",
            kommentar,
            udfoert_af: null,
            relateret_bevilling_id: commentModalBevillingId,
          }),
        });
        if (res.ok) {
          newComment = "";
          showCommentModal = false;
          await loadAktiviteter(commentModalCpr);
          await invalidateAll();
        }
      } finally {
        savingComment = false;
      }
    }

    // ---------------------------------------------------------------------------
    // Bevillinger — lazy-loaded per CPR
    // ---------------------------------------------------------------------------

    let bevillingerByCpr: Record<string, any[]> = {};
    let loadingBevillingerCpr = new Set<string>();

    async function loadBevillinger(cpr: string) {
      loadingBevillingerCpr.add(cpr);
      loadingBevillingerCpr = new Set(loadingBevillingerCpr);
      try {
        const res = await backendFetch(`/bevilling/get_student_bevillinger/${cpr}`);
        if (!res.ok) return;
        const bevillinger = await res.json();
        const withKoersels = await Promise.all(
          bevillinger.map(async (b: any) => {
            const kr = await backendFetch(`/bevilling/get_bevilling_koerselsraekker/${b.bevilling_id}`);
            return { ...b, koerselsraekker: kr.ok ? await kr.json() : [] };
          })
        );
        bevillingerByCpr[cpr] = withKoersels;
        bevillingerByCpr = { ...bevillingerByCpr };
      } finally {
        loadingBevillingerCpr.delete(cpr);
        loadingBevillingerCpr = new Set(loadingBevillingerCpr);
      }
    }

    // ---------------------------------------------------------------------------
    // Create bevilling modal
    // ---------------------------------------------------------------------------

    let showCreateBevillingModal = false;
    let bevillingModalCpr = "";
    let createBevillingStep: 1 | 2 = 1;
    let createBevillingModalMode: 'kopi' | 'tom' | null = null;

    // Step 2 — Kørselsrække fields
    let modalKoersel: any = {};
    let modalKoerselTillaegIds: number[] = [];
    let modalKoerselDagIds: number[] = [];
    let modalKoerselTillaegSelectValue = "";
    let modalKoerselDagSelectValue = "";
    let isCreatingKoerselInModal = false;
    let isCalculatingModalKoerselDistance = false;
    let modalKoerselDistanceError: string | null = null;

    let skoleType: 'folkeskole' | 'ungdomsuddannelse' | null = null;
    let newBevilling: any = {};
    let selectedBegrundelser: string[] = [];
    let begrundelseSelectValue = "";
    const begrundelseOptions = ["Sygdom", "Afstand", "Farlig skolevej"];

    function getEmptyBevilling() {
      return {
        adresse_id: null as string | null,
        adresse_tekst: "",
        matrikel_id: "",
        ungdomsuddannelse_id: "",
        hjemmel_id: "",
        afgoerelsesbrev_id: "",
        revurderingsdato: "",
        befordringsudvalg: "",
        esdh_noegle: "",
        sagsbehandler_id: "",
        ppr_sagsbehandler_id: "",
        ansoegningsdato: "",
        sagsbehandlingsdato: "",
        relation_til_barnet: "",
        foerste_koersel_dato: "",
        ansoegningstype: "",
        afstandskriterie_dato: "",
        afstandskriterie_klassetrin: "",
        begrundelse_fra_formular: "",
        hjaelpemiddel_ids: [],
      };
    }

    function resetCreateBevillingForm() {
      newBevilling = getEmptyBevilling();
      skoleType = null;
      selectedBegrundelser = [];
      begrundelseSelectValue = "";
    }

    function resetModalKoersel(mode: 'kopi' | 'tom', cpr: string) {
      if (mode === 'kopi') {
        const bevs = bevillingerByCpr[cpr] ?? [];
        const activeBev = bevs.find((b: any) => b.status_tekst === 'Aktiv') ?? bevs[0];
        const src = activeBev?.koerselsraekker?.[0] ?? null;
        if (src) {
          modalKoersel = {
            tidspunkt_id: src.tidspunkt_id ?? "",
            befordringstype_id: src.befordringstype_id ?? "",
            bevilget_koereafstand_pr_vej: src.bevilget_koereafstand_pr_vej != null ? String(src.bevilget_koereafstand_pr_vej) : "",
            gyldig_fra: "",
            gyldig_til: "",
            taxa_id: src.taxa_id ?? "",
            kommentar: src.kommentar ?? "",
          };
          const rawTillaeg = src.tillaeg_ids ?? "";
          modalKoerselTillaegIds = rawTillaeg ? String(rawTillaeg).split(",").map(Number).filter(n => !isNaN(n)) : [];
          const rawDage = src.dag_ids ?? "";
          modalKoerselDagIds = rawDage ? String(rawDage).split(",").map(Number).filter(n => !isNaN(n)) : [];
        } else {
          resetModalKoerselEmpty();
        }
      } else {
        resetModalKoerselEmpty();
      }
      modalKoerselTillaegSelectValue = "";
      modalKoerselDagSelectValue = "";
      modalKoerselDistanceError = null;
    }

    function resetModalKoerselEmpty() {
      modalKoersel = { tidspunkt_id: "", befordringstype_id: "", bevilget_koereafstand_pr_vej: "", gyldig_fra: "", gyldig_til: "", taxa_id: "", kommentar: "" };
      modalKoerselTillaegIds = [];
      modalKoerselDagIds = [];
    }

    function isModalKoerselEgenbefordring(typeId: any): boolean {
      if (!typeId) return false;
      const type = koerselstyper.find((t: any) => Number(t.id) === Number(typeId));
      return type?.label?.toLowerCase() === 'egenbefordring';
    }

    async function calculateModalKoerselDistance(typeId: any) {
      if (!isModalKoerselEgenbefordring(typeId)) {
        modalKoersel = { ...modalKoersel, bevilget_koereafstand_pr_vej: "" };
        return;
      }
      if (!newBevilling.adresse_tekst) {
        modalKoerselDistanceError = "Ingen adresse på bevillingen — kan ikke beregne afstand";
        return;
      }
      if (!newBevilling.matrikel_id) {
        modalKoerselDistanceError = "Ingen skole valgt på bevillingen — kan ikke beregne afstand";
        return;
      }
      isCalculatingModalKoerselDistance = true;
      modalKoerselDistanceError = null;
      try {
        const geoRes = await backendFetch(`/bevilling/geocode_address?address=${encodeURIComponent(newBevilling.adresse_tekst)}`);
        if (!geoRes.ok) throw new Error("Kunne ikke geokode adressen");
        const geo = await geoRes.json();
        const schoolRes = await backendFetch(`/lookup/skolematrikel/${newBevilling.matrikel_id}/coordinates`);
        if (!schoolRes.ok) throw new Error("Kunne ikke hente skolens koordinater");
        const school = await schoolRes.json();
        const params = new URLSearchParams({ lat1: String(geo.latitude), lon1: String(geo.longitude), lat2: String(school.latitude), lon2: String(school.longitude) });
        const distRes = await backendFetch(`/bevilling/calculate_driving_distance?${params}`);
        if (!distRes.ok) throw new Error("Kunne ikke beregne køreafstand");
        const dist = await distRes.json();
        const km = dist.distance_km ?? dist.distance ?? dist.driving_distance_km;
        if (km == null) throw new Error("Ugyldigt svar fra afstandsberegning");
        if (Number(modalKoersel.befordringstype_id) !== Number(typeId)) return;
        modalKoersel = { ...modalKoersel, bevilget_koereafstand_pr_vej: String(km) };
      } catch (err: any) {
        modalKoerselDistanceError = err?.message ?? "Fejl ved beregning af afstand";
      } finally {
        isCalculatingModalKoerselDistance = false;
      }
    }

    function handleGoToStep2() {
      createBevillingStep = 2;
    }

    function prefillFromBevilling(source: any) {
      skoleType = (source.ungdomsuddannelse_id && !source.matrikel_id) ? 'ungdomsuddannelse' : 'folkeskole';
      const rawBegrundelse = source.begrundelse_fra_formular ?? "";
      selectedBegrundelser = rawBegrundelse.split(", ").filter((b: string) => begrundelseOptions.includes(b));
      begrundelseSelectValue = "";
      newBevilling = {
        adresse_id:                  source.adresse_id ?? null,
        adresse_tekst:               source.adresse_for_bevilling ?? "",
        matrikel_id:                 source.matrikel_id != null ? String(source.matrikel_id) : "",
        ungdomsuddannelse_id:        source.ungdomsuddannelse_id != null ? String(source.ungdomsuddannelse_id) : "",
        hjemmel_id:                  source.hjemmel_id != null ? String(source.hjemmel_id) : "",
        afgoerelsesbrev_id:          source.afgoerelsesbrev_id != null ? String(source.afgoerelsesbrev_id) : "",
        sagsbehandler_id:            source.sagsbehandler_id != null ? String(source.sagsbehandler_id) : "",
        ppr_sagsbehandler_id:        source.ppr_sagsbehandler_id != null ? String(source.ppr_sagsbehandler_id) : "",
        relation_til_barnet:         source.relation_til_barnet ?? "",
        ansoegningstype:             source.ansoegningstype ?? "",
        afstandskriterie_dato:       source.afstandskriterie_dato ? String(source.afstandskriterie_dato).slice(0, 10) : "",
        afstandskriterie_klassetrin: source.afstandskriterie_klassetrin != null ? String(source.afstandskriterie_klassetrin) : "",
        revurderingsdato:            source.revurderingsdato ? String(source.revurderingsdato).slice(0, 10) : "",
        befordringsudvalg:           source.befordringsudvalg ? String(source.befordringsudvalg).slice(0, 10) : "",
        begrundelse_fra_formular:    rawBegrundelse,
        esdh_noegle:                 "",
        ansoegningsdato:             "",
        sagsbehandlingsdato:         "",
        foerste_koersel_dato:        "",
        hjaelpemiddel_ids:           [],
      };
    }

    function openCreateBevillingModal(cpr: string, mode: 'kopi' | 'tom') {
      bevillingModalCpr = cpr;
      createBevillingModalMode = mode;
      createBevillingStep = 1;
      resetCreateBevillingForm();
      resetModalKoersel(mode, cpr);
      if (mode === 'kopi') {
        const bevs = bevillingerByCpr[cpr] ?? [];
        const activeBev = bevs.find((b: any) => b.status_tekst === 'Aktiv') ?? bevs[0];
        if (activeBev) prefillFromBevilling(activeBev);
      }
      showCreateBevillingModal = true;
    }

    function addBegrundelse() {
      if (begrundelseSelectValue === "") return;
      if (!selectedBegrundelser.includes(begrundelseSelectValue)) {
        selectedBegrundelser = [...selectedBegrundelser, begrundelseSelectValue];
      }
      newBevilling.begrundelse_fra_formular = selectedBegrundelser.join(", ");
      begrundelseSelectValue = "";
    }

    function removeBegrundelse(value: string) {
      selectedBegrundelser = selectedBegrundelser.filter((v) => v !== value);
      newBevilling.begrundelse_fra_formular = selectedBegrundelser.join(", ");
    }

    async function handleCreateBevilling() {
      const isMidlertidig = newBevilling.ansoegningstype === "Midlertidig kørsel";
      const payload = {
        adresse_id:                  newBevilling.adresse_id,
        matrikel_id:                 (isMidlertidig && skoleType === 'ungdomsuddannelse') ? null : numberOrNull(newBevilling.matrikel_id),
        ungdomsuddannelse_id:        (isMidlertidig && skoleType === 'ungdomsuddannelse') ? numberOrNull(newBevilling.ungdomsuddannelse_id) : null,
        hjemmel_id:                  numberOrNull(newBevilling.hjemmel_id),
        afgoerelsesbrev_id:          numberOrNull(newBevilling.afgoerelsesbrev_id),
        revurderingsdato:            emptyToNull(newBevilling.revurderingsdato),
        befordringsudvalg:           emptyToNull(newBevilling.befordringsudvalg),
        esdh_noegle:                 emptyToNull(newBevilling.esdh_noegle),
        sagsbehandler_id:            numberOrNull(newBevilling.sagsbehandler_id),
        ppr_sagsbehandler_id:        numberOrNull(newBevilling.ppr_sagsbehandler_id),
        ansoegningsdato:             emptyToNull(newBevilling.ansoegningsdato),
        sagsbehandlingsdato:         emptyToNull(newBevilling.sagsbehandlingsdato),
        relation_til_barnet:         emptyToNull(newBevilling.relation_til_barnet),
        foerste_koersel_dato:        emptyToNull(newBevilling.foerste_koersel_dato),
        ansoegningstype:             emptyToNull(newBevilling.ansoegningstype),
        afstandskriterie_dato:       emptyToNull(newBevilling.afstandskriterie_dato),
        afstandskriterie_klassetrin: numberOrNull(newBevilling.afstandskriterie_klassetrin),
        begrundelse_fra_formular:    emptyToNull(newBevilling.begrundelse_fra_formular),
        hjaelpemiddel_ids:           newBevilling.hjaelpemiddel_ids ?? [],
      };

      const res = await backendFetch(
        `/bevilling/create_bevilling/${bevillingModalCpr}?status_text=${encodeURIComponent("Kommende")}`,
        { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) }
      );

      if (!res.ok) {
        let message = "Kunne ikke oprette bevilling";
        try {
          const err = await res.json();
          message = err?.detail?.message ?? (Array.isArray(err?.detail) ? err.detail.map((e: any) => e.msg ?? JSON.stringify(e)).join("\n") : err?.detail) ?? message;
        } catch { /* keep fallback */ }
        alert(`Fejl ${res.status}: ${message}`);
        return;
      }

      showCreateBevillingModal = false;
      resetCreateBevillingForm();
      createBevillingStep = 1;
      await loadBevillinger(bevillingModalCpr);
      await invalidateAll();
    }

    async function handleCreateBevillingAndKoersel() {
      if (!newBevilling.adresse_id) { alert("Adresse mangler"); return; }
      isCreatingKoerselInModal = true;
      const isMidlertidig = newBevilling.ansoegningstype === "Midlertidig kørsel";
      const payload = {
        adresse_id:                  newBevilling.adresse_id,
        matrikel_id:                 (isMidlertidig && skoleType === 'ungdomsuddannelse') ? null : numberOrNull(newBevilling.matrikel_id),
        ungdomsuddannelse_id:        (isMidlertidig && skoleType === 'ungdomsuddannelse') ? numberOrNull(newBevilling.ungdomsuddannelse_id) : null,
        hjemmel_id:                  numberOrNull(newBevilling.hjemmel_id),
        afgoerelsesbrev_id:          numberOrNull(newBevilling.afgoerelsesbrev_id),
        revurderingsdato:            emptyToNull(newBevilling.revurderingsdato),
        befordringsudvalg:           emptyToNull(newBevilling.befordringsudvalg),
        esdh_noegle:                 emptyToNull(newBevilling.esdh_noegle),
        sagsbehandler_id:            numberOrNull(newBevilling.sagsbehandler_id),
        ppr_sagsbehandler_id:        numberOrNull(newBevilling.ppr_sagsbehandler_id),
        ansoegningsdato:             emptyToNull(newBevilling.ansoegningsdato),
        sagsbehandlingsdato:         emptyToNull(newBevilling.sagsbehandlingsdato),
        relation_til_barnet:         emptyToNull(newBevilling.relation_til_barnet),
        foerste_koersel_dato:        emptyToNull(newBevilling.foerste_koersel_dato),
        ansoegningstype:             emptyToNull(newBevilling.ansoegningstype),
        afstandskriterie_dato:       emptyToNull(newBevilling.afstandskriterie_dato),
        afstandskriterie_klassetrin: numberOrNull(newBevilling.afstandskriterie_klassetrin),
        begrundelse_fra_formular:    emptyToNull(newBevilling.begrundelse_fra_formular),
        hjaelpemiddel_ids:           newBevilling.hjaelpemiddel_ids ?? [],
      };

      try {
        const bevRes = await backendFetch(
          `/bevilling/create_bevilling/${bevillingModalCpr}?status_text=${encodeURIComponent("Kommende")}`,
          { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) }
        );
        if (!bevRes.ok) {
          let message = "Kunne ikke oprette bevilling";
          try { const err = await bevRes.json(); message = err?.detail?.message ?? err?.detail ?? message; } catch { /* keep fallback */ }
          alert(`Fejl ${bevRes.status}: ${message}`);
          return;
        }
        const { bevilling_id: newBevillingId } = await bevRes.json();

        const krPayload = {
          tidspunkt_id:                  numberOrNull(modalKoersel.tidspunkt_id),
          befordringstype_id:            numberOrNull(modalKoersel.befordringstype_id),
          bevilget_koereafstand_pr_vej:  Number(modalKoersel.bevilget_koereafstand_pr_vej) || 0,
          gyldig_fra:                    modalKoersel.gyldig_fra || null,
          gyldig_til:                    modalKoersel.gyldig_til || null,
          taxa_id:                       modalKoersel.taxa_id || null,
          kommentar:                     modalKoersel.kommentar || "",
          final:                         false,
          tillaeg_ids:                   modalKoerselTillaegIds,
          dag_ids:                       modalKoerselDagIds,
        };
        const krRes = await backendFetch(
          `/bevilling/create_koerselsraekke/${newBevillingId}`,
          { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(krPayload) }
        );
        if (!krRes.ok) {
          alert("Bevilling oprettet, men kørselsrækken fejlede — tjek sagen");
        }

        showCreateBevillingModal = false;
        resetCreateBevillingForm();
        createBevillingStep = 1;
        await loadBevillinger(bevillingModalCpr);
        await invalidateAll();
      } finally {
        isCreatingKoerselInModal = false;
      }
    }

    // ---------------------------------------------------------------------------
    // Create letter modal
    // ---------------------------------------------------------------------------

    let showCreateLetterModal = false;
    let letterModalCpr = "";
    let letterType = "";
    let befordringsudvalgResultat = "";
    let selectedLetterBevillingId = "";
    let ophoersdato = "";
    let creatingLetter = false;

    $: selectedLetterBevilling = selectedLetterBevillingId
      ? (bevillingerByCpr[letterModalCpr] ?? []).find((b: any) => String(b.bevilling_id) === selectedLetterBevillingId)
      : null;
    $: selectedLetterBevillingHasBefordringsudvalg = !!(selectedLetterBevilling?.befordringsudvalg);
    $: selectedLetterBevillingIsOphoert = selectedLetterBevilling?.status_tekst === "Ophørt";

    function openCreateLetterModal(cpr: string) {
      letterModalCpr = cpr;
      letterType = "";
      befordringsudvalgResultat = "";
      selectedLetterBevillingId = "";
      ophoersdato = "";
      showCreateLetterModal = true;
    }

    async function handleCreateLetter() {
      if (!selectedLetterBevillingId) { alert("Vælg en bevilling"); return; }
      if (!letterType) { alert("Vælg hvad brevet er i forbindelse med"); return; }
      if (selectedLetterBevillingHasBefordringsudvalg && !befordringsudvalgResultat) { alert("Vælg resultat af befordringsudvalgsmøde"); return; }
      if (selectedLetterBevillingIsOphoert && !ophoersdato) { alert("Vælg ophørsdato"); return; }

      creatingLetter = true;
      try {
        const payload = {
          brev_i_forbindelse_med: letterType,
          befordringsudvalg_resultat: selectedLetterBevillingHasBefordringsudvalg ? befordringsudvalgResultat : null,
          ophoersdato: selectedLetterBevillingIsOphoert ? ophoersdato : null,
        };
        const res = await backendFetch(
          `/bevilling/create_letter/${letterModalCpr}/${selectedLetterBevillingId}`,
          { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) }
        );
        if (!res.ok) {
          let message = "Kunne ikke oprette brev";
          try { const err = await res.json(); message = err?.detail?.message ?? err?.detail ?? message; } catch { /* keep fallback */ }
          alert(message);
          return;
        }
        const result = await res.json();
      alert(`Brev er sat i kø. Reference: ${result.reference}`);
      await backendFetch(`/aktivitet/${letterModalCpr}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          aktivitetstype: "Brev oprettet",
          kommentar: `Bevilling ID: ${selectedLetterBevillingId}`,
          relateret_bevilling_id: Number(selectedLetterBevillingId),
          udfoert_af: null,
        }),
      });
      showCreateLetterModal = false;
      await loadAktiviteter(letterModalCpr);
      await invalidateAll();
    } finally {
      creatingLetter = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Bevilling field editing (quick edits in the expanded details grid)
  // ---------------------------------------------------------------------------

  let editingBevillingFields: number | null = null;
  let editFields = {
    hjemmel_id: null as number | null,
    afgoerelsesbrev_id: null as number | null,
    afstandskriterie_dato: "",
    revurderingsdato: "",
  };

  function startEditFields(bev: any) {
    editingBevillingFields = bev.bevilling_id;
    editFields = {
      hjemmel_id: bev.hjemmel_id ?? null,
      afgoerelsesbrev_id: bev.afgoerelsesbrev_id ?? null,
      afstandskriterie_dato: bev.afstandskriterie_dato ? bev.afstandskriterie_dato.slice(0, 10) : "",
      revurderingsdato: bev.revurderingsdato ? bev.revurderingsdato.slice(0, 10) : "",
    };
  }

  function cancelEditFields() { editingBevillingFields = null; }

  async function saveEditFields(bevillingId: number) {
    const res = await backendFetch(`/bevilling/${bevillingId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        hjemmel_id: editFields.hjemmel_id,
        afgoerelsesbrev_id: editFields.afgoerelsesbrev_id,
        afstandskriterie_dato: editFields.afstandskriterie_dato || null,
        revurderingsdato: editFields.revurderingsdato || null,
      }),
    });
    if (!res.ok) { console.error("Failed to update bevilling fields:", res.status); return; }
    cancelEditFields();
    await invalidateAll();
  }
</script>


<svelte:window on:keydown={(e) => {
  if (e.key !== 'Escape') return;
  if (showCreateBevillingModal) { showCreateBevillingModal = false; resetCreateBevillingForm(); createBevillingStep = 1; }
  if (showCreateLetterModal) { showCreateLetterModal = false; }
  if (showCommentModal) { showCommentModal = false; }
}} />

<svelte:head>
  <title>Befordring – Revurdering</title>
</svelte:head>


<!-- =========================================================
     PPR vurderet — confirm popup
     ========================================================= -->
{#if pprConfirmFor}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    role="dialog"
    aria-modal="true"
    tabindex="-1"
    on:click|self={() => (pprConfirmFor = null)}
    on:keydown={(e) => { if (e.key === 'Escape') pprConfirmFor = null; }}
  >
    <div class="bg-white rounded-xl shadow-2xl w-full max-w-md overflow-hidden">
      <div class="flex items-center justify-between px-5 py-4" style="background:#032A42;">
        <h3 class="text-sm font-semibold text-white">PPR vurderet</h3>
        <button type="button" aria-label="Luk" class="text-white/70 hover:text-white" on:click={() => (pprConfirmFor = null)}>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="px-5 py-5 text-sm text-gray-700 space-y-3">
        <p>Sørg for at du er helt færdig med vurderingen før du godkender.</p>
        <p class="font-semibold text-gray-900">Sagen er vurderet</p>
      </div>
      <div class="flex justify-end gap-2 px-5 py-4 border-t border-gray-100">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-lg"
          on:click={() => (pprConfirmFor = null)}
        >Annullér</button>
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium text-white bg-green-600 hover:bg-green-700 rounded-lg"
          on:click={async () => { if (pprConfirmFor) { await togglePpr(pprConfirmFor.bevillingId, pprConfirmFor.cpr, pprConfirmFor.current); pprConfirmFor = null; } }}
        >Godkend</button>
      </div>
    </div>
  </div>
{/if}


<!-- =========================================================
     BR vurderet — confirm popup
     ========================================================= -->
{#if brConfirmFor}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    role="dialog"
    aria-modal="true"
    tabindex="-1"
    on:click|self={() => (brConfirmFor = null)}
    on:keydown={(e) => { if (e.key === 'Escape') brConfirmFor = null; }}
  >
    <div class="bg-white rounded-xl shadow-2xl w-full max-w-md overflow-hidden">
      <div class="flex items-center justify-between px-5 py-4" style="background:#032A42;">
        <h3 class="text-sm font-semibold text-white">BR vurderet</h3>
        <button type="button" aria-label="Luk" class="text-white/70 hover:text-white" on:click={() => (brConfirmFor = null)}>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="px-5 py-5 text-sm text-gray-700 space-y-3">
        <p>Sagen forsvinder fra denne side når du godkender vurderingen. Sørg derfor for at du er helt færdig med vurderingen og har oprettet brev.</p>
        <p class="font-semibold text-gray-900">Sagen er vurderet</p>
      </div>
      <div class="flex justify-end gap-2 px-5 py-4 border-t border-gray-100">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-lg"
          on:click={() => (brConfirmFor = null)}
        >Annullér</button>
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium text-white bg-green-600 hover:bg-green-700 rounded-lg"
          on:click={async () => { if (brConfirmFor) { await toggleBr(brConfirmFor.bevillingId, brConfirmFor.cpr, brConfirmFor.current); brConfirmFor = null; } }}
        >Godkend</button>
      </div>
    </div>
  </div>
{/if}


<!-- =========================================================
     Create bevilling modal
     ========================================================= -->
{#if showCreateBevillingModal}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    on:click|self={() => { showCreateBevillingModal = false; resetCreateBevillingForm(); createBevillingStep = 1; }}
    role="presentation"
  >
    <div class="w-[750px] max-h-[90vh] overflow-y-auto bg-white rounded-lg shadow-2xl" role="dialog" aria-modal="true" tabindex="-1">

      <div class="sticky top-0 z-10 px-8 py-5 border-b border-gray-200" style="background-color: #032A42;">
        <h2 class="text-lg font-bold text-white">Opret ny bevilling</h2>
        <p class="mt-0.5 text-sm" style="color: rgba(255,255,255,0.7);">
          {createBevillingStep === 1 ? 'Trin 1 af 2 — Bevillingsoplysninger' : 'Trin 2 af 2 — Kørselsrække'}
        </p>
      </div>

      {#if createBevillingStep === 1}
      <div class="p-8">
        <div class="grid grid-cols-2 gap-5">

          <label class="text-sm font-medium text-gray-700 col-span-2">
            Ansøgningstype *
            <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.ansoegningstype}>
              <option value="">Vælg ansøgningstype</option>
              <option value="Kørsel">Kørsel</option>
              <option value="Midlertidig kørsel">Midlertidig kørsel</option>
              <option value="Skolebus">Skolebus</option>
            </select>
          </label>

          {#if newBevilling.ansoegningstype === "Midlertidig kørsel"}
            <div class="col-span-2">
              <p class="text-sm font-medium text-gray-700 mb-2">Skole type *</p>
              <div class="flex gap-2">
                <button type="button"
                  class="flex-1 py-2 text-sm font-medium rounded border transition-colors"
                  style={skoleType === 'folkeskole' ? 'background-color:#032A42;color:#fff;border-color:#032A42;' : 'background-color:#fff;color:#374151;border-color:#d1d5db;'}
                  on:click={() => skoleType = 'folkeskole'}>Folkeskole</button>
                <button type="button"
                  class="flex-1 py-2 text-sm font-medium rounded border transition-colors"
                  style={skoleType === 'ungdomsuddannelse' ? 'background-color:#032A42;color:#fff;border-color:#032A42;' : 'background-color:#fff;color:#374151;border-color:#d1d5db;'}
                  on:click={() => skoleType = 'ungdomsuddannelse'}>Ungdomsuddannelse</button>
              </div>
            </div>
            {#if skoleType === 'folkeskole'}
              <label class="text-sm font-medium text-gray-700 col-span-2">
                Folkeskole (matrikel)
                <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.matrikel_id}>
                  <option value="">Vælg</option>
                  {#each lookupOptions.skolematrikler ?? [] as option}
                    <option value={String(option.id)}>{option.label}</option>
                  {/each}
                </select>
              </label>
            {:else if skoleType === 'ungdomsuddannelse'}
              <label class="text-sm font-medium text-gray-700 col-span-2">
                Ungdomsuddannelse
                <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.ungdomsuddannelse_id}>
                  <option value="">Vælg</option>
                  {#each lookupOptions.ungdomsuddannelser ?? [] as option}
                    <option value={String(option.id)}>{option.label}</option>
                  {/each}
                </select>
              </label>
            {/if}
          {:else if newBevilling.ansoegningstype}
            <label class="text-sm font-medium text-gray-700 col-span-2">
              Folkeskole (matrikel)
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.matrikel_id}>
                <option value="">Vælg</option>
                {#each lookupOptions.skolematrikler ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>
          {/if}

          {#if (newBevilling.ansoegningstype && newBevilling.ansoegningstype !== "Midlertidig kørsel") || (newBevilling.ansoegningstype === "Midlertidig kørsel" && skoleType !== null)}

            <label class="text-sm font-medium text-gray-700 col-span-2">
              Adresse for bevilling
              <div class="mt-1.5">
                <AddresseSearch
                  adresseId={newBevilling.adresse_id}
                  adresseTekst={newBevilling.adresse_tekst}
                  onSelect={(result) => {
                    newBevilling = { ...newBevilling, adresse_id: result?.adresse_id ?? null, adresse_tekst: result?.adresse_tekst ?? "" };
                  }}
                />
              </div>
            </label>

            <label class="text-sm font-medium text-gray-700">
              Hjemmel
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.hjemmel_id}>
                <option value="">Vælg</option>
                {#each lookupOptions.hjemler ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm font-medium text-gray-700">
              Afgørelsesbrev
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.afgoerelsesbrev_id}>
                <option value="">Vælg</option>
                {#each lookupOptions.afgoerelsesbreve ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm font-medium text-gray-700">
              Revurdering
              <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.revurderingsdato} />
            </label>

            <label class="text-sm font-medium text-gray-700">
              Befordringsudvalg
              <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.befordringsudvalg} />
            </label>

            <label class="text-sm font-medium text-gray-700">
              ESDH-nøgle
              <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.esdh_noegle} />
            </label>

            <label class="text-sm font-medium text-gray-700">
              Sagsbehandler
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.sagsbehandler_id}>
                <option value="">Vælg</option>
                {#each lookupOptions.sagsbehandlere ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm font-medium text-gray-700">
              PPR ansvarlig
              <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.ppr_sagsbehandler_id}>
                <option value="">Vælg</option>
                {#each lookupOptions.pprSagsbehandlere ?? [] as option}
                  <option value={String(option.id)}>{option.label}</option>
                {/each}
              </select>
            </label>

            <label class="text-sm font-medium text-gray-700">
              Sagsbehandlingsdato
              <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.sagsbehandlingsdato} />
            </label>

            <label class="text-sm font-medium text-gray-700">
              Ansøger relation
              <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.relation_til_barnet} />
            </label>

            <label class="text-sm font-medium text-gray-700">
              Dato for første kørsel
              <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.foerste_koersel_dato} />
            </label>

            <label class="text-sm font-medium text-gray-700">
              Afstandskriterie dato
              <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.afstandskriterie_dato} />
            </label>

            <label class="text-sm font-medium text-gray-700">
              Afstandskriterie klassetrin
              <input type="number" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={newBevilling.afstandskriterie_klassetrin} />
            </label>

            <label class="text-sm font-medium text-gray-700 col-span-2">
              Begrundelse
              <div class="mt-1.5 border border-gray-300 rounded p-3">
                <div class="mb-2 flex flex-wrap gap-1.5">
                  {#each selectedBegrundelser as begrundelse}
                    <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                      {begrundelse}
                      <button type="button" class="ml-1 text-red-500 hover:text-red-700 font-bold" on:click={() => removeBegrundelse(begrundelse)}>×</button>
                    </span>
                  {/each}
                </div>
                <select class="w-full border border-gray-300 rounded px-2 py-1.5 text-sm" bind:value={begrundelseSelectValue} on:change={addBegrundelse}>
                  <option value="">Tilføj begrundelse</option>
                  {#each begrundelseOptions.filter((opt) => !selectedBegrundelser.includes(opt)) as opt}
                    <option value={opt}>{opt}</option>
                  {/each}
                </select>
              </div>
            </label>

          {/if}

        </div>
      </div>

      {:else}

      <!-- Step 2: Kørselsrække -->
      <div class="p-8">
        <div class="grid grid-cols-2 gap-5">

          <label class="text-sm font-medium text-gray-700">
            Tidspunkt *
            <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.tidspunkt_id}>
              <option value="">Vælg</option>
              {#each tidspunkter as opt}
                <option value={opt.id}>{opt.label}</option>
              {/each}
            </select>
          </label>

          <label class="text-sm font-medium text-gray-700">
            Kørselstype *
            <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm"
              bind:value={modalKoersel.befordringstype_id}
              on:change={(e) => { modalKoersel = { ...modalKoersel, befordringstype_id: e.currentTarget.value }; calculateModalKoerselDistance(e.currentTarget.value); }}
            >
              <option value="">Vælg</option>
              {#each koerselstyper as opt}
                <option value={opt.id}>{opt.label}</option>
              {/each}
            </select>
          </label>

          <label class="text-sm font-medium text-gray-700">
            Bevilget km pr. vej *
            {#if isCalculatingModalKoerselDistance}
              <span class="ml-1 text-blue-500 text-xs font-normal">beregner...</span>
            {/if}
            <input type="number" step="0.1"
              class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm {isCalculatingModalKoerselDistance ? 'opacity-50' : ''}"
              disabled={isCalculatingModalKoerselDistance}
              bind:value={modalKoersel.bevilget_koereafstand_pr_vej} />
          </label>

          <label class="text-sm font-medium text-gray-700">
            Gyldig fra *
            <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.gyldig_fra} />
          </label>

          <label class="text-sm font-medium text-gray-700">
            Gyldig til *
            <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.gyldig_til} />
          </label>

          <label class="text-sm font-medium text-gray-700">
            Taxa-ID
            <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.taxa_id} />
          </label>

          <label class="text-sm font-medium text-gray-700 col-span-2">
            Kørselstype tillæg
            <div class="mt-1.5 border border-gray-300 rounded p-3">
              <div class="mb-2 flex flex-wrap gap-1.5">
                {#each modalKoerselTillaegIds as id}
                  {@const opt = koerselstypeTillaeg.find((t: any) => Number(t.id) === id)}
                  <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                    {opt?.label ?? id}
                    <button type="button" class="ml-1 text-red-500 hover:text-red-700 font-bold"
                      on:click={() => { modalKoerselTillaegIds = modalKoerselTillaegIds.filter(x => x !== id); }}>×</button>
                  </span>
                {/each}
              </div>
              <select class="w-full border border-gray-300 rounded px-2 py-1.5 text-sm"
                bind:value={modalKoerselTillaegSelectValue}
                on:change={(e) => {
                  const val = Number(e.currentTarget.value);
                  if (val && !modalKoerselTillaegIds.includes(val)) modalKoerselTillaegIds = [...modalKoerselTillaegIds, val];
                  modalKoerselTillaegSelectValue = "";
                }}>
                <option value="">Tilføj tillæg</option>
                {#each koerselstypeTillaeg.filter((t: any) => !modalKoerselTillaegIds.includes(Number(t.id))) as opt}
                  <option value={String(opt.id)}>{opt.label}</option>
                {/each}
              </select>
            </div>
          </label>

          <label class="text-sm font-medium text-gray-700 col-span-2">
            Dage
            <div class="mt-1.5 border border-gray-300 rounded p-3">
              <div class="mb-2 flex flex-wrap gap-1.5">
                {#each modalKoerselDagIds as id}
                  {@const opt = dage.find((d: any) => Number(d.id) === id)}
                  <span class="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-1 text-xs">
                    {opt?.label ?? id}
                    <button type="button" class="ml-1 text-red-500 hover:text-red-700 font-bold"
                      on:click={() => { modalKoerselDagIds = modalKoerselDagIds.filter(x => x !== id); }}>×</button>
                  </span>
                {/each}
              </div>
              <select class="w-full border border-gray-300 rounded px-2 py-1.5 text-sm"
                bind:value={modalKoerselDagSelectValue}
                on:change={(e) => {
                  const val = Number(e.currentTarget.value);
                  if (val && !modalKoerselDagIds.includes(val)) modalKoerselDagIds = [...modalKoerselDagIds, val];
                  modalKoerselDagSelectValue = "";
                }}>
                <option value="">Tilføj dag</option>
                {#each dage.filter((d: any) => !modalKoerselDagIds.includes(Number(d.id))) as opt}
                  <option value={String(opt.id)}>{opt.label}</option>
                {/each}
              </select>
            </div>
          </label>

          <label class="text-sm font-medium text-gray-700 col-span-2">
            Kommentar
            <input class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={modalKoersel.kommentar} />
          </label>

          {#if modalKoerselDistanceError}
            <div class="col-span-2 px-3 py-2 text-xs text-red-700 bg-red-50 border border-red-200 rounded">
              {modalKoerselDistanceError}
            </div>
          {/if}

        </div>
      </div>

      {/if}

      <!-- Footer: different buttons per step -->
      {#if createBevillingStep === 1}
      <div class="flex justify-end gap-3 border-t border-gray-200 px-8 py-5">
        <button type="button"
          class="px-5 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
          on:click={() => { showCreateBevillingModal = false; resetCreateBevillingForm(); createBevillingStep = 1; }}>
          Annullér
        </button>
        <button type="button"
          disabled={!newBevilling.adresse_id}
          class="px-5 py-2 text-sm font-medium text-white rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          style="background-color: #032A42;"
          on:click={handleCreateBevilling}>
          Opret bevilling
        </button>
        <button type="button"
          disabled={!newBevilling.adresse_id}
          class="px-5 py-2 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          on:click={handleGoToStep2}>
          Tilføj Kørselsrækker →
        </button>
      </div>
      {:else}
      <div class="flex items-center justify-between border-t border-gray-200 px-8 py-5">
        <button type="button"
          class="px-4 py-2 text-sm font-medium text-gray-600 hover:text-gray-900 flex items-center gap-1 transition-colors"
          on:click={() => createBevillingStep = 1}>
          ← Tilbage
        </button>
        <div class="flex gap-3">
          <button type="button"
            class="px-5 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
            on:click={() => { showCreateBevillingModal = false; resetCreateBevillingForm(); createBevillingStep = 1; }}>
            Annullér
          </button>
          <button type="button"
            disabled={isCreatingKoerselInModal || !newBevilling.adresse_id}
            class="px-5 py-2 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            on:click={handleCreateBevillingAndKoersel}>
            {isCreatingKoerselInModal ? 'Opretter...' : 'Opret bevilling + kørsel'}
          </button>
        </div>
      </div>
      {/if}

    </div>
  </div>
{/if}


<!-- =========================================================
     Create letter modal
     ========================================================= -->
{#if showCreateLetterModal}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    on:click|self={() => { showCreateLetterModal = false; }}
    role="presentation"
  >
    <div class="w-[560px] bg-white rounded-lg shadow-2xl" role="dialog" aria-modal="true" tabindex="-1">

      <div class="px-8 py-5 border-b border-gray-200 rounded-t-lg" style="background-color: #6d28d9;">
        <h2 class="text-lg font-bold text-white">Opret brev</h2>
        <p class="mt-0.5 text-sm" style="color: rgba(255,255,255,0.7);">Vælg bevilling og brevtype</p>
      </div>

      <div class="p-8 space-y-5">
        <label class="block text-sm font-medium text-gray-700">
          Vælg bevilling
          <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={selectedLetterBevillingId}>
            <option value="">Vælg bevilling</option>
            {#each bevillingerByCpr[letterModalCpr] ?? [] as bevilling}
              <option value={String(bevilling.bevilling_id)}>
                {bevilling.status_tekst ?? "Ukendt status"} – {bevilling.adresse_for_bevilling ?? bevilling.adresse_tekst ?? "Ingen adresse"}
              </option>
            {/each}
          </select>
        </label>

        <label class="block text-sm font-medium text-gray-700">
          Brevet er i forbindelse med en:
          <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={letterType}>
            <option value="">Vælg</option>
            <option value="ansøgning">Ansøgning</option>
            <option value="revurdering">Revurdering</option>
            <option value="midlertidig kørsel">Midlertidig kørsel</option>
          </select>
        </label>

        {#if selectedLetterBevillingHasBefordringsudvalg}
          <label class="block text-sm font-medium text-gray-700">
            Resultat af befordringsudvalgsmøde
            <select class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={befordringsudvalgResultat}>
              <option value="">Vælg</option>
              <option value="Befordringsudvalg: Afslag / fastholdelse">Befordringsudvalg: Afslag / fastholdelse</option>
              <option value="Befordringsudvalg: Ændring i bevilling">Befordringsudvalg: Ændring i bevilling</option>
            </select>
          </label>
        {/if}

        {#if selectedLetterBevillingIsOphoert}
          <label class="block text-sm font-medium text-gray-700">
            Ophørsdato
            <input type="date" class="mt-1.5 w-full border border-gray-300 rounded px-3 py-2 text-sm" bind:value={ophoersdato} />
          </label>
        {/if}
      </div>

      <div class="flex justify-end gap-3 border-t border-gray-200 px-8 py-5 bg-gray-50 rounded-b-lg">
        <button type="button"
          class="px-5 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
          on:click={() => { showCreateLetterModal = false; }}>
          Annullér
        </button>
        <button type="button"
          disabled={creatingLetter}
          class="px-5 py-2 text-sm font-medium bg-purple-600 hover:bg-purple-700 text-white rounded transition-colors disabled:opacity-50"
          on:click={handleCreateLetter}>
          {creatingLetter ? "Opretter..." : "Opret brev"}
        </button>
      </div>

    </div>
  </div>
{/if}


<!-- =========================================================
     Add comment modal
     ========================================================= -->
{#if showCommentModal}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    on:click|self={() => { showCommentModal = false; }}
    role="presentation"
  >
    <div class="w-full max-w-md bg-white rounded-lg shadow-2xl" role="dialog" aria-modal="true" tabindex="-1">
      <div class="px-6 py-4 border-b border-gray-200" style="background-color: #032A42;">
        <h2 class="text-base font-bold text-white">Tilføj kommentar</h2>
      </div>
      <div class="p-6">
        <textarea
          rows="4"
          class="w-full border border-gray-300 rounded px-3 py-2 text-sm resize-none focus:border-blue-400 focus:ring-0"
          placeholder="Skriv kommentar..."
          bind:value={newComment}
        ></textarea>
      </div>
      <div class="flex justify-end gap-3 border-t border-gray-200 px-6 py-4 bg-gray-50 rounded-b-lg">
        <button type="button"
          class="px-4 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
          on:click={() => { showCommentModal = false; }}>
          Annullér
        </button>
        <button type="button"
          disabled={savingComment || !newComment.trim()}
          class="px-4 py-2 text-sm font-medium text-white rounded transition-colors disabled:opacity-50"
          style="background-color: #032A42;"
          on:click={saveComment}>
          {savingComment ? "Gemmer..." : "Gem kommentar"}
        </button>
      </div>
    </div>
  </div>
{/if}


<!-- =========================================================
     Page
     ========================================================= -->
<section>

  <!-- Page header -->
  <div class="flex items-center justify-between mb-5 flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Revurdering</h1>
      <p class="text-sm text-gray-500 mt-0.5">Bevillinger der afventer revurdering</p>
    </div>

    <div class="flex items-center gap-4 flex-wrap">

      <UpdateTemplateButton class="px-3 py-1.5 text-xs" />

      {#if uniqueSkoler.length > 0}
        <select
          class="min-w-[180px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white"
          bind:value={selectedSkole}
        >
          <option value="">Alle skoler ({revurderinger.length})</option>
          {#each uniqueSkoler as skole}
            {@const count = revurderinger.filter((b: any) => b.skole_navn === skole).length}
            <option value={skole}>{skole} ({count})</option>
          {/each}
        </select>
      {/if}

      {#if uniqueSagsbehandlere.length > 0}
        <select
          class="min-w-[160px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white"
          bind:value={selectedSagsbehandler}
        >
          <option value="">Alle sagsbehandlere</option>
          {#each uniqueSagsbehandlere as sb}
            {@const count = revurderinger.filter((b: any) => b.sagsbehandler_tekst === sb).length}
            <option value={sb}>{sb} ({count})</option>
          {/each}
        </select>
      {/if}

      {#if uniquePprSagsbehandlere.length > 0}
        <select
          class="min-w-[160px] border border-gray-300 rounded pl-2 pr-6 py-1 text-xs text-gray-700 focus:border-blue-400 focus:ring-0 bg-white"
          bind:value={selectedPprSagsbehandler}
        >
          <option value="">Alle PPR sagsbehandlere</option>
          {#each uniquePprSagsbehandlere as ppr}
            {@const count = revurderinger.filter((b: any) => b.ppr_sagsbehandler_tekst === ppr).length}
            <option value={ppr}>{ppr} ({count})</option>
          {/each}
        </select>
      {/if}

      {#if anyFilterActive}
        <button
          type="button"
          class="text-xs font-medium text-gray-500 hover:text-red-600 flex items-center gap-1 transition-colors whitespace-nowrap"
          on:click={() => { selectedSkole = ""; selectedSagsbehandler = ""; selectedPprSagsbehandler = ""; }}
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
          Nulstil filtre
        </button>
      {/if}

      {#if filteredRevurderinger.length > 0}
        <button
          type="button"
          class="text-xs font-medium text-sky-700 hover:underline whitespace-nowrap"
          on:click={() => allExpanded ? collapseAll() : expandAll()}
        >
          {allExpanded ? 'Fold alle' : 'Udvid alle'}
        </button>
      {/if}

      <span class="text-sm font-bold text-gray-500">
        {filteredRevurderinger.length}{anyFilterActive ? ` / ${revurderinger.length}` : ''} sager
      </span>

    </div>
  </div>


  <!-- Summary card -->
  <div class="bg-white border border-gray-300 rounded-lg shadow px-6 py-5 mb-5 flex items-center gap-8">
    <div>
      <p class="text-4xl font-bold text-gray-900">{revurderinger.length}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Sager</p>
    </div>
    <div class="h-10 w-px bg-gray-200"></div>
    <div>
      <p class="text-2xl font-bold" style={overskredet > 0 ? 'color:#dc2626;' : 'color:#9ca3af;'}>{overskredet}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Overskredet</p>
    </div>
    <div class="h-10 w-px bg-gray-200"></div>
    <div>
      <p class="text-2xl font-bold" style={indenFor30Dage > 0 ? 'color:#ca8a04;' : 'color:#9ca3af;'}>{indenFor30Dage}</p>
      <p class="text-xs uppercase tracking-widest text-gray-400 mt-1.5">Inden for 30 dage</p>
    </div>
  </div>


  {#if filteredRevurderinger.length === 0}

    <div class="bg-white border border-gray-300 rounded-lg shadow px-6 py-16 text-center">
      <div class="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center mx-auto mb-4">
        <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
        </svg>
      </div>
      {#if selectedSkole}
        <p class="text-gray-700 font-semibold">Ingen sager for denne skole</p>
        <p class="text-sm text-gray-400 mt-1">{selectedSkole}</p>
      {:else}
        <p class="text-gray-700 font-semibold">Ingen sager til revurdering</p>
        <p class="text-sm text-gray-400 mt-1">Alle bevillinger er opdaterede.</p>
      {/if}
    </div>

  {:else}

    <div>

      {#each filteredRevurderinger as bev, i}

        {@const color = urgencyColor(bev.revurderingsdato)}
        {@const label = urgencyLabel(bev.revurderingsdato)}
        {@const isExpanded = expandedIds.has(bev.bevilling_id)}
        {@const activeKoerselstyper = [...new Set((bev.koerselsraekker ?? []).filter((k: any) => !k.final).map((k: any) => k.befordringstype_tekst).filter(Boolean))]}

        <div class="overflow-hidden transition-colors {isExpanded ? 'border border-gray-300 bg-gray-100 rounded-lg shadow-md my-2' : 'border border-gray-200 bg-white' + (i > 0 ? ' -mt-px' : '')}">

          <!-- Collapsed row -->
          <div
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-gray-50 transition-colors select-none"
            style="border-left: 3px solid {color};"
            on:click={() => toggleExpand(bev.bevilling_id)}
            role="button"
            tabindex="0"
            on:keydown={(e) => e.key === 'Enter' && toggleExpand(bev.bevilling_id)}
          >

            <svg
              class="w-4 h-4 text-gray-400 shrink-0 transition-transform duration-150 {isExpanded ? 'rotate-90' : ''}"
              fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
            </svg>

            <div class="min-w-0 w-52 shrink-0 flex flex-col justify-center">
              <div class="flex items-center gap-2">
                <a
                  href="/sag/{bev.cpr_elev}"
                  class="font-semibold text-sky-700 hover:underline text-sm whitespace-nowrap"
                  on:click|stopPropagation
                >
                  {bev.adresseringsnavn ?? "—"}
                </a>
              </div>
              <div class="flex items-center gap-1.5 mt-0.5">
                <span class="text-gray-400 text-xs whitespace-nowrap">{formatCpr(bev.cpr_elev)}</span>
                {#if bev.skole_navn}
                  <span class="text-gray-300 text-xs">·</span>
                  <span class="text-gray-500 text-xs whitespace-nowrap truncate">{bev.skole_navn}</span>
                {/if}
              </div>
              {#if activeKoerselstyper.length > 0}
                <div class="flex items-center gap-1 mt-1 flex-wrap">
                  {#each activeKoerselstyper as type}
                    <span class="px-1.5 rounded text-[10px] font-medium bg-teal-50 text-teal-700 border border-teal-100 leading-5">{type}</span>
                  {/each}
                </div>
              {/if}
            </div>

            <div class="hidden lg:flex flex-1 items-center min-w-0 overflow-hidden px-2">
              <div class="flex flex-col min-w-0 min-w-[90px] w-[110px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Revurderingsdato</span>
                <span class="text-xs text-gray-600 truncate">{formatDanishDate(bev.revurderingsdato) ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[80px] w-[130px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Klasseart</span>
                <span class="text-xs text-gray-600 truncate">{bev.klasseart ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[60px] w-[80px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Klassetrin</span>
                <span class="text-xs text-gray-600 truncate">{bev.klassebetegnelse ?? (bev.elevklassetrin ? `Trin ${bev.elevklassetrin}` : '—')}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[80px] w-[110px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Sagsbehandler</span>
                <span class="text-xs text-gray-600 truncate">{bev.sagsbehandler_tekst ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[80px] w-[130px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">PPR sagsbehandler</span>
                <span class="text-xs text-gray-600 truncate">{bev.ppr_sagsbehandler_tekst ?? "—"}</span>
              </div>
              <div class="flex flex-col min-w-0 min-w-[60px] w-[80px]">
                <span class="text-[9px] font-bold uppercase tracking-wider text-gray-400 leading-none mb-0.5">Gåafstand</span>
                <span class="text-xs text-gray-600 truncate">
                  {bev.gaaafstand_km != null ? Number(bev.gaaafstand_km).toFixed(1) + ' km' : '—'}
                </span>
              </div>
              {#if bev.statusbemaerkning}
                <div class="flex flex-col min-w-0 flex-1 pl-2 border-l border-amber-200 ml-2">
                  <span class="text-[9px] font-bold uppercase tracking-wider text-amber-500 leading-none mb-0.5">Årsag</span>
                  <span class="text-xs text-amber-700 truncate" title={bev.statusbemaerkning}>{bev.statusbemaerkning}</span>
                </div>
              {/if}
            </div>

            <div class="flex items-center gap-2 shrink-0">
              <span
                class="text-[11px] font-semibold px-2 py-0.5 rounded-full whitespace-nowrap"
                style="background:{color}18; color:{color};"
              >
                {label}
              </span>
            </div>

            <!-- PPR / BR checkboxes -->
            <div class="shrink-0 flex items-center gap-1.5">

              <!-- PPR vurderet -->
              <button
                type="button"
                title="PPR vurderet"
                class="flex items-center gap-1.5 border-2 rounded px-3 py-1.5 text-xs font-medium transition-all whitespace-nowrap
                  {bev.revurderet_af_ppr
                    ? 'bg-green-600 border-green-600 text-white shadow-sm'
                    : 'bg-white border-gray-300 text-gray-500 hover:border-green-400 hover:text-green-600'}"
                on:click|stopPropagation={() => openPprConfirm(bev.bevilling_id, bev.cpr_elev, bev.revurderet_af_ppr)}
              >
                <div class="w-3.5 h-3.5 rounded border flex items-center justify-center shrink-0
                  {bev.revurderet_af_ppr ? 'bg-white/20 border-white/60' : 'border-gray-300'}">
                  {#if bev.revurderet_af_ppr}
                    <svg class="w-2.5 h-2.5 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                  {/if}
                </div>
                PPR vurderet
              </button>

              <!-- BR vurderet -->
              <button
                type="button"
                title="BR vurderet"
                class="flex items-center gap-1.5 border-2 rounded px-3 py-1.5 text-xs font-medium transition-all whitespace-nowrap
                  {bev.revurderet_af_br
                    ? 'bg-green-600 border-green-600 text-white shadow-sm'
                    : 'bg-white border-gray-300 text-gray-500 hover:border-green-400 hover:text-green-600'}"
                on:click|stopPropagation={() => openBrConfirm(bev.bevilling_id, bev.cpr_elev, bev.revurderet_af_br)}
              >
                <div class="w-3.5 h-3.5 rounded border flex items-center justify-center shrink-0
                  {bev.revurderet_af_br ? 'bg-white/20 border-white/60' : 'border-gray-300'}">
                  {#if bev.revurderet_af_br}
                    <svg class="w-2.5 h-2.5 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                  {/if}
                </div>
                BR vurderet
              </button>

            </div>

          </div>


          <!-- Expanded panel -->
          {#if isExpanded}
            {@const isEditingFields = editingBevillingFields === bev.bevilling_id}
            {@const commentsOpen = expandedCommentsBevIds.has(bev.bevilling_id)}
            <div class="border-t border-gray-100" style="border-left: 3px solid {color};">

              <!-- Statusbemærkning callout -->
              {#if bev.statusbemaerkning}
                <div class="px-6 py-3 bg-amber-50 border-b border-amber-200 flex items-start gap-2.5">
                  <svg class="w-4 h-4 text-amber-500 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
                  </svg>
                  <div>
                    <p class="text-[10px] font-bold uppercase tracking-wider text-amber-600 mb-0.5">Årsag til revurdering</p>
                    <p class="text-sm text-amber-900">{bev.statusbemaerkning}</p>
                  </div>
                </div>
              {/if}

              <!-- Elevdata section -->
              <div class="bg-gray-100">
                <!-- Grey header outside white card -->
                <div class="px-6 py-2.5 flex items-center justify-between gap-3">
                  <div class="flex items-center gap-2">
                    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500">Elevdata</p>
                    <span class="text-gray-300 text-[10px]">|</span>
                    <a href="/sag/{bev.cpr_elev}" class="flex items-center gap-0.5 text-xs font-medium text-sky-600 hover:text-sky-800 transition-colors">
                      Gå til sag
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
                      </svg>
                    </a>
                  </div>
                </div>
                <div class="px-4 pb-3">
                <div class="bg-white border border-gray-300 rounded-lg shadow overflow-hidden">

                  <!-- Card header with Redigér inside white card -->
                  <div class="flex items-center justify-end px-6 py-3 border-b border-gray-100">
                    {#if isEditingFields}
                      <div class="flex items-center gap-3">
                        <button type="button"
                          class="px-3 py-1.5 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded transition-colors"
                          on:click={() => saveEditFields(bev.bevilling_id)}>
                          Gem ændringer
                        </button>
                        <button type="button"
                          class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                          on:click={cancelEditFields}>
                          Annullér
                        </button>
                      </div>
                    {:else}
                      <button type="button"
                        class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                        on:click={() => startEditFields(bev)}>
                        Redigér
                      </button>
                    {/if}
                  </div>

                  <!-- Details grid -->
                  <div class="px-6 py-4 grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-x-6 gap-y-3">

                    <div>
                      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Klasseart</p>
                      <p class="text-xs text-gray-700">{bev.klasseart ?? "—"}</p>
                    </div>

                    <div>
                      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Klasse / trin</p>
                      <p class="text-xs text-gray-700">
                        {bev.klassebetegnelse ?? "—"}{#if bev.elevklassetrin}&nbsp;· trin {bev.elevklassetrin}{/if}
                      </p>
                    </div>

                    <div class="col-span-2 sm:col-span-1">
                      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Adresse</p>
                      <p class="text-xs text-gray-700 truncate" title={bev.folkeregister_adresse}>{bev.folkeregister_adresse ?? "—"}</p>
                    </div>

                    <div>
                      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Gåafstand</p>
                      <p class="text-xs text-gray-700">
                        {bev.gaaafstand_km != null ? Number(bev.gaaafstand_km).toFixed(1) + ' km' : '—'}
                      </p>
                    </div>

                    <div>
                      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Hjemmel</p>
                      {#if isEditingFields}
                        <select
                          class="w-full border border-gray-300 rounded pl-1.5 pr-6 py-0.5 text-xs focus:border-blue-400 focus:ring-0 bg-white"
                          value={editFields.hjemmel_id ?? ""}
                          on:change={(e) => editFields = { ...editFields, hjemmel_id: e.currentTarget.value ? Number(e.currentTarget.value) : null }}
                        >
                          <option value="">—</option>
                          {#each hjemler as opt}
                            <option value={opt.id}>{opt.label}</option>
                          {/each}
                        </select>
                      {:else}
                        <p class="text-xs text-gray-700">{bev.hjemmel_tekst ?? "—"}</p>
                      {/if}
                    </div>

                    <div>
                      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Afgørelsesbrev</p>
                      {#if isEditingFields}
                        <select
                          class="w-full border border-gray-300 rounded pl-1.5 pr-6 py-0.5 text-xs focus:border-blue-400 focus:ring-0 bg-white"
                          value={editFields.afgoerelsesbrev_id ?? ""}
                          on:change={(e) => editFields = { ...editFields, afgoerelsesbrev_id: e.currentTarget.value ? Number(e.currentTarget.value) : null }}
                        >
                          <option value="">—</option>
                          {#each afgoerelsesbreve as opt}
                            <option value={opt.id}>{opt.label}</option>
                          {/each}
                        </select>
                      {:else}
                        <p class="text-xs text-gray-700">{bev.afgoerelsesbrev_tekst ?? "—"}</p>
                      {/if}
                    </div>

                    <div>
                      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Afstandskriterie dato</p>
                      {#if isEditingFields}
                        <input type="date" class="border border-gray-300 rounded px-1.5 py-0.5 text-xs focus:border-blue-400 focus:ring-0" bind:value={editFields.afstandskriterie_dato} />
                      {:else}
                        <p class="text-xs text-gray-700">{formatDanishDate(bev.afstandskriterie_dato) ?? "—"}</p>
                      {/if}
                    </div>

                    <div>
                      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">PPR Sagsbehandler</p>
                      <p class="text-xs text-gray-700">{bev.ppr_sagsbehandler_tekst ?? "—"}</p>
                    </div>

                    <div>
                      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Sagsbehandler</p>
                      <p class="text-xs text-gray-700">{bev.sagsbehandler_tekst ?? "—"}</p>
                    </div>

                    <div>
                      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">Revurderingsdato</p>
                      {#if isEditingFields}
                        <input type="date" class="w-full border border-gray-300 rounded px-1.5 py-0.5 text-xs focus:border-blue-400 focus:ring-0" bind:value={editFields.revurderingsdato} />
                      {:else}
                        <p class="text-xs text-gray-700">{formatDanishDate(bev.revurderingsdato) ?? "—"}</p>
                      {/if}
                    </div>

                  </div>
                </div>
                </div>
              </div>

              <!-- Comment section -->
              <div class="border-t border-gray-200 bg-blue-50">
                <!-- Clickable header row -->
                <div
                  class="px-6 py-2.5 flex items-center gap-3 cursor-pointer select-none transition-colors hover:bg-blue-100 {commentsOpen ? 'border-b border-blue-200' : ''}"
                  role="button"
                  tabindex="0"
                  on:click={() => toggleComments(bev.bevilling_id)}
                  on:keydown={(e) => e.key === 'Enter' && toggleComments(bev.bevilling_id)}
                >
                  <svg class="w-4 h-4 text-blue-400 shrink-0 transition-transform duration-150 {commentsOpen ? 'rotate-180' : ''}" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
                  </svg>
                  <div class="flex items-center gap-2">
                    <p class="text-[10px] font-bold uppercase tracking-wider text-blue-700">Kommentarer</p>
                    <svg class="w-3.5 h-3.5 text-blue-400 shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                    </svg>
                    <span class="text-blue-300 text-[10px]">|</span>
                    <a
                      href="/sag/{bev.cpr_elev}#sagsforloeb"
                      class="flex items-center gap-0.5 text-xs font-medium text-sky-600 hover:text-sky-800 transition-colors"
                      on:click|stopPropagation
                    >
                      Sagsforløb
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
                      </svg>
                    </a>
                  </div>
                </div>

                {#if commentsOpen}
                  <div class="px-6 py-3">
                    {#if loadingAktiviteterCpr.has(bev.cpr_elev)}
                      <p class="text-xs text-gray-400 italic">Henter kommentarer...</p>
                    {:else}
                      {@const comments = (aktiviteterByCpr[bev.cpr_elev] ?? []).filter((a: any) => a.aktivitetstype === 'Kommentar').slice(0, 3)}
                      {#if comments.length > 0}
                        <div class="space-y-2 mb-3">
                          {#each comments as akt}
                            <div class="border-l-4 border-l-blue-400 bg-white rounded-r px-2.5 py-2 shadow-sm">
                              <div class="flex items-center justify-between gap-2 mb-0.5">
                                <span class="text-[11px] font-medium text-gray-700">{akt.udfoert_af ?? "System"}</span>
                                <span class="text-[10px] text-gray-400 whitespace-nowrap">{new Date(akt.oprettet_tidspunkt).toLocaleString("da-DK")}</span>
                              </div>
                              {#if akt.kommentar}
                                <p class="text-xs text-gray-600 whitespace-pre-wrap line-clamp-3">{akt.kommentar}</p>
                              {/if}
                            </div>
                          {/each}
                        </div>
                      {/if}
                      <div class="mt-1 flex items-end gap-2">
                        <textarea
                          class="flex-1 border border-gray-300 rounded px-3 py-2 text-sm resize-none focus:border-blue-400 focus:ring-0 bg-white"
                          rows="2"
                          placeholder="Skriv kommentar..."
                          bind:value={inlineComments[bev.bevilling_id]}
                        ></textarea>
                        <button
                          type="button"
                          class="px-3 text-xs font-medium bg-blue-600 hover:bg-blue-700 text-white rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed shrink-0 self-stretch"
                          disabled={savingInlineCommentIds.has(bev.bevilling_id) || !(inlineComments[bev.bevilling_id]?.trim())}
                          on:click={() => saveInlineComment(bev.cpr_elev, bev.bevilling_id)}
                        >
                          {savingInlineCommentIds.has(bev.bevilling_id) ? "Gemmer..." : "Gem kommentar"}
                        </button>
                      </div>
                    {/if}
                  </div>
                {/if}
              </div>

              <!-- Bevillinger section -->
              <div class="border-t-2 border-gray-300 bg-gray-100">
                <div class="px-6 py-2.5 border-b border-gray-300 flex items-center justify-between gap-3 flex-wrap">
                  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500">Bevillinger</p>
                  <div class="flex items-center gap-2">
                    <button
                      type="button"
                      disabled={!(bevillingerByCpr[bev.cpr_elev]?.length > 0)}
                      class="px-3 py-1.5 text-xs font-medium text-white rounded transition-colors whitespace-nowrap disabled:opacity-40 disabled:cursor-not-allowed"
                      style="background-color: #032A42;"
                      on:click={() => openCreateBevillingModal(bev.cpr_elev, 'kopi')}
                    >
                      + Ny bevilling fra kopi
                    </button>
                    <button
                      type="button"
                      class="px-3 py-1.5 text-xs font-medium text-white rounded transition-colors whitespace-nowrap"
                      style="background-color: #032A42;"
                      on:click={() => openCreateBevillingModal(bev.cpr_elev, 'tom')}
                    >
                      + Ny bevilling fra tom
                    </button>
                    <button type="button"
                      class="px-3 py-1.5 text-xs font-medium bg-purple-600 hover:bg-purple-700 text-white rounded transition-colors flex items-center gap-1 whitespace-nowrap"
                      on:click={() => openCreateLetterModal(bev.cpr_elev)}>
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                      </svg>
                      + Opret brev
                    </button>
                  </div>
                </div>

                <div class="px-6 py-4">
                  {#if loadingBevillingerCpr.has(bev.cpr_elev)}
                    <p class="text-xs text-gray-400 italic">Henter bevillinger...</p>
                  {:else if bevillingerByCpr[bev.cpr_elev]}
                    <BevillingTable
                      bevillinger={bevillingerByCpr[bev.cpr_elev]}
                      lookupOptions={lookupOptions}
                      readonlyKoerselsraekker={true}
                      onSaveBevilling={async (id, updates) => {
                        const ok = await handleSaveBevilling(id, updates);
                        if (ok) await loadBevillinger(bev.cpr_elev);
                        return ok;
                      }}
                      onCreateKoerselsraekke={async (id, updates) => {
                        const ok = await handleCreateKoerselsraekke(id, updates);
                        if (ok) await loadBevillinger(bev.cpr_elev);
                        return ok;
                      }}
                      onSaveKoerselsraekke={async (id, updates) => {
                        const ok = await handleSaveKoerselsraekke(id, updates);
                        if (ok) await loadBevillinger(bev.cpr_elev);
                        return ok;
                      }}
                      onFinalizeKoerselsraekke={async (id) => {
                        const ok = await handleFinalizeKoerselsraekke(id);
                        if (ok) await loadBevillinger(bev.cpr_elev);
                        return ok;
                      }}
                    />
                  {:else}
                    <p class="text-xs text-gray-400 italic">Ingen bevillinger fundet.</p>
                  {/if}
                </div>
              </div>

            </div>
          {/if}

        </div>

      {/each}

    </div>

  {/if}

</section>
