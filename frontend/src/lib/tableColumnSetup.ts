// src/lib/tableColumnSetup.ts
// Her samler vi alt det "tunge" DataTable-setup ét sted,
// så dine Svelte-sider bliver mere læselige og vi kan genbruge logik flere steder.
// Nu UDEN hårdkodede kolonne-numre. I stedet finder vi kolonner dynamisk
// ud fra header-teksten, baseret på vores globale tableColumnConfig.

import type { DataTableOptions } from "@flowbite-svelte-plugins/datatable";
import {
  employees,
  type ColumnKey,
  normalizeHeaderLabel,
  columnHeaderConfig,
  statusBadgeClasses,
  tableTheme,
} from "$lib/tableColumnConfig";

/* ===========================================
   HJÆLPEFUNKTION: TEKSTUDTRÆK FRA NODE
   =========================================== */

/**
 * extractText:
 * Givet en node (fra DataTables' interne repræsentation),
 * prøver vi at finde første tekststreng inde i den.
 */
export function extractText(node: any): string | null {
  if (!node) return null;

  if (typeof node.data === "string") return node.data.trim();

  if (Array.isArray(node.childNodes)) {
    let texts: string[] = [];

    for (const child of node.childNodes) {
      const txt = extractText(child);
      if (txt) texts.push(txt);
    }

    return texts.length ? texts.join("") : null;
  }

  return null;
}

/* ===========================================
   HJÆLPEFUNKTION: BYG KOLONNE-INDEX FRA HEADER
   ============================================
   - Læser TH-teksterne i header-rækken
   - Normaliserer teksten (lowercase, fjerner spaces, fixer &amp;)
   - Matcher mod columnHeaderConfig (global config)
   - Returnerer fx:
     { id: 0, name: 1, status: 3, ... }
   =========================================== */

function buildColumnIndex(
  headerCells: any[]
): Partial<Record<ColumnKey, number>> {
  const indices: Partial<Record<ColumnKey, number>> = {};

  headerCells.forEach((th, index) => {
    const raw = extractText(th) || "";
    const normalized = normalizeHeaderLabel(raw);

    // Loop over alle kolonner i config og find match
    (Object.entries(columnHeaderConfig) as [ColumnKey, string[]][]).forEach(
      ([key, labels]) => {
        if (labels.includes(normalized)) {
          indices[key] = index;
        }
      }
    );
  });

  return indices;
}

/* ===========================================
   TABLE OPTIONS TIL OVERBLIK-VIEW
   =========================================== */

export const overblikTableOptions: DataTableOptions = {
  /**
   * tableRender:
   * Hook der giver os "det der skal blive til HTML"
   * før DataTable/Flowbite viser det i browseren.
   * Her:
   *  - tilføjer vi filter-rækken under header
   *  - laver navn til link
   *  - laver status badges
   *  - tilføjer input-felter, selects, tooltips osv.
   */
  tableRender: (_data, table, type) => {
    // Ved print vil vi ikke pille ved UI, så vi returnerer uændret.
    if (type === "print") return table;

    /* ---------- THEAD (kolonneoverskrifter) ---------- */

    const tHead = table.childNodes.find((n: any) => n.nodeName === "THEAD");
    if (!tHead) return table;

    const headerRow = tHead.childNodes.find((n: any) => n.nodeName === "TR");
    if (!headerRow) return table;

    const headerCells = headerRow.childNodes;

    // 💡 BUILD DYNAMIC COLUMN INDEX HER
    const columnIndex = buildColumnIndex(headerCells);
    console.log("columnIndex:", columnIndex);

    /* ---------- FILTER ROW (søgefelter under overskrifterne) ---------- */

    const filterRow = {
      nodeName: "TR",
      attributes: { class: tableTheme.filterRowClass },
      childNodes: headerCells.map((th: any, index: number) => {
        const columnName = extractText(th) || `Kolonne ${index + 1}`;
        return {
          nodeName: "TH",
          childNodes: [
            {
              nodeName: "INPUT",
              attributes: {
                class: tableTheme.filterInputClass,
                type: "search",
                placeholder: `Søg ${columnName}`,
                "data-columns": `[${index}]`,
              },
            },
          ],
        };
      }),
    };

    tHead.childNodes.push(filterRow);

    /* ============================
       BODY EDIT FIELDS
       ============================ */

    const tBody = table.childNodes.find((n: any) => n.nodeName === "TBODY");
    if (!tBody) return table;

    tBody.childNodes.forEach((row: any) => {
      if (row.nodeName !== "TR") return;

      const cells = row.childNodes;

      /* ---------------------------------------------------
         NAVN-KOLONNE SOM LINK (Id + Navn)
         - Finder id- og navn-kolonner dynamisk
         --------------------------------------------------- */

      const cprIdx = columnIndex.cpr;
      const nameIdx = columnIndex.name;

      if (cprIdx !== undefined && nameIdx !== undefined) {

        const cprCell = cells[cprIdx];
        const nameCell = cells[nameIdx];

        if (cprCell && nameCell) {

          const cprText = extractText(cprCell);
          const nameText = extractText(nameCell);

          if (cprText && nameText) {

            nameCell.childNodes = [
              {
                nodeName: "A",
                attributes: {
                  href: `/sag/${cprText}`,
                  class: tableTheme.linkClass,
                },
                childNodes: [{ nodeName: "#text", data: nameText }],
              },
            ];

          }
        }
      }

      /* ---------------------------------------------------
         STATUS BADGE
         --------------------------------------------------- */

      const statusIdx = columnIndex.status;

      if (statusIdx !== undefined) {
        const statusCell = cells[statusIdx];
        if (statusCell) {
          const value = extractText(statusCell) || "";
          const lower = value.toLowerCase();

          const colorClass =
            statusBadgeClasses[lower] ?? statusBadgeClasses.default;

          const badgeClass = `${tableTheme.badgeBaseClass} ${colorClass}`;

          statusCell.childNodes = [
            {
              nodeName: "SPAN",
              attributes: { class: badgeClass },
              childNodes: [{ nodeName: "#text", data: value }],
            },
          ];
        }
      }

      /* ---------------------------------------------------
         DATE PICKER
         --------------------------------------------------- */

      const dateIdx = columnIndex.date;

      if (dateIdx !== undefined) {
        const dateCell = cells[dateIdx];

        if (dateCell) {
          dateCell.childNodes = [
            {
              nodeName: "INPUT",
              attributes: {
                type: "date",
                class: tableTheme.dateInputClass,
              },
            },
          ];
        }
      }

      /* ---------------------------------------------------
         EMPLOYEE SELECT
         --------------------------------------------------- */

      const empIdx = columnIndex.employee;

      if (empIdx !== undefined) {
        const empCell = cells[empIdx];

        if (empCell) {
          empCell.childNodes = [
            {
              nodeName: "SELECT",
              attributes: { class: tableTheme.selectClass },
              childNodes: [
                {
                  nodeName: "OPTION",
                  attributes: { value: "" },
                  childNodes: [{ nodeName: "#text", data: "Vælg" }],
                },
                ...employees.map((e) => ({
                  nodeName: "OPTION",
                  attributes: { value: e },
                  childNodes: [{ nodeName: "#text", data: e }],
                })),
              ],
            },
          ];
        }
      }

      /* ---------------------------------------------------
         PPR KOMMENTAR INPUT FRITEKST
         --------------------------------------------------- */

      const pprIdx = columnIndex.pprComment;

      if (pprIdx !== undefined) {
        const PPRcommentCell = cells[pprIdx];

        if (PPRcommentCell) {
          PPRcommentCell.childNodes = [
            {
              nodeName: "INPUT",
              attributes: {
                type: "text",
                class: tableTheme.textInputClass,
                // tilføj evt. w-full i class for at få bredden til at følge table
                placeholder: "PPR kommentar...",
              },
            },
          ];
        }
      }

      /* ---------------------------------------------------
         NOTE INPUT FRITEKST
         --------------------------------------------------- */

      const noteIdx = columnIndex.note;

      if (noteIdx !== undefined) {
        const noteCell = cells[noteIdx];

        if (noteCell) {
          noteCell.childNodes = [
            {
              nodeName: "INPUT",
              attributes: {
                type: "text",
                class: tableTheme.textInputClass,
                placeholder: "Skriv note...",
              },
            },
          ];
        }
      }

      /* ---------------------------------------------------
         REASON TOOLTIP
         --------------------------------------------------- */

      const reasonIdx = columnIndex.reason;

      if (reasonIdx !== undefined) {
        const reasonCell = cells[reasonIdx];

        if (reasonCell) {
          const txt = extractText(reasonCell);

          if (txt) {
            reasonCell.childNodes = [
              {
                nodeName: "SPAN",
                attributes: {
                  title: txt,
                  class: "text-blue-600 cursor-help",
                },
                childNodes: [{ nodeName: "#text", data: "Se begrundelse" }],
              },
            ];
          }
        }
      }

      // De øvrige kolonner (Kategori, Skole, Pris, osv.)
      // vises bare som normale celler uden special-UI.
    });

    return table;
  },
};