// src/lib/tableColumnConfig.ts

export type ColumnKey =
  | "id"
  | "cpr"
  | "name"
  | "kategori"
  | "status"
  | "ansøgersrelation"
  | "barnetsadresse"
  | "skole"
  | "skolensadresse"
  | "gåafstandkm"
  | "begrundelsekort"
  | "reason"
  | "employee"
  | "pprComment"
  | "brmedarbejder"
  | "note"
  | "pris"
  | "oprettelsesdato"
  | "date"
  | "senestændret";

/* ===========================================
   MEDARBEJDERE / PPR-SAGSB.
   =========================================== */
export const employees = ["Annie", "Lena", "Mik", "Susanne", "Julie"];

/* ===========================================
   HEADER NORMALISERING
   =========================================== */

export function normalizeHeaderLabel(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .replace(/&amp;amp;/g, "&")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, "");
}

/* ===========================================
   MAP HEADER → LOGISK KOLONNEKEY
   =========================================== */

export const columnHeaderConfig: Record<ColumnKey, string[]> = {
  id: ["id"],
  cpr: ["cpr"],
  name: ["navn"],
  kategori: ["kategori"],
  status: ["status"],
  ansøgersrelation: ["ansøgersrelation"],
  barnetsadresse: ["barnetsadresse"],
  skole: ["skole"],
  skolensadresse: ["skolensadresse"],
  gåafstandkm: ["gåafstandkm"],
  begrundelsekort: ["begrundelsekort"],
  reason: ["begrundelse"],
  employee: ["pprsagsbehandler"],
  pprComment: ["pprkommentar"],
  brmedarbejder: ["brmedarbejder"],
  note: ["note"],
  pris: ["pris"],
  oprettelsesdato: ["oprettelsesdato"],
  date: ["revurderingsdato"],
  senestændret: ["senestændret"],
};

/* ===========================================
   STATUS BADGE FARBVER (kan udvides)
   =========================================== */

export const statusBadgeClasses: Record<string, string> = {
  aktiv: "bg-green-100 text-green-800",
  inaktiv: "bg-red-100 text-red-700",
  revurdering: "bg-yellow-100 text-yellow-700",
  default: "bg-slate-100 text-slate-700",
};

/* ===========================================
   TABEL UI TEMA
   =========================================== */

export const tableTheme = {
  filterRowClass: "search-filtering-row",
  filterInputClass: "datatable-input",
  linkClass: "text-blue-600 hover:underline",
  badgeBaseClass:
    "inline-flex items-center rounded-full px-3 py-1 text-xs font-medium",
  textInputClass: "border rounded px-2 py-1 text-gray-500 italic",
  dateInputClass: "border rounded px-2 py-1 w-full",
  selectClass: "border rounded px-2 py-1 w-full",
};



// ===========================================
// KOLONNER TIL SAG-DETALJE-VIEW AKA STAMDATA AKA SAG/ID
// ===========================================

export type ColumnDef = {
  key: ColumnKey;
  label: string; // hvad brugeren ser som overskrift
};

// rækkefølgen her bliver rækkefølgen i tabellen på sag/[id]
export const sagColumns: ColumnDef[] = [
  { key: "id", label: "Sags-ID" },
  { key: "cpr", label: "CPR-nummer" },
  { key: "name", label: "Navn" },
  { key: "kategori", label: "Kategori" },
  { key: "status", label: "Status" },
  { key: "ansøgersrelation", label: "Ansøgers relation" },
  { key: "barnetsadresse", label: "Barnets adresse" },
  { key: "skole", label: "Skole" },
  { key: "skolensadresse", label: "Skolens adresse" },
  { key: "gåafstandkm", label: "Gåafstand (km)" },
  { key: "begrundelsekort", label: "Begrundelse (kort)" },
  { key: "reason", label: "Begrundelse" },
  { key: "employee", label: "PPR-sagsbehandler" },
  { key: "pprComment", label: "PPR-kommentar" },
  { key: "brmedarbejder", label: "BR-medarbejder" },
  { key: "note", label: "Note" },
  { key: "pris", label: "Pris" },
  { key: "oprettelsesdato", label: "Oprettelsesdato" },
  { key: "date", label: "Revurderingsdato" },
  { key: "senestændret", label: "Senest ændret" },
];