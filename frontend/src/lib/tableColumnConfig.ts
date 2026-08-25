export function formatDanishDate(dateStr: string | null | undefined): string {
  if (!dateStr) return "—";
  const parts = dateStr.split("-");
  if (parts.length !== 3) return dateStr;
  const [year, month, day] = parts;
  return `${day}-${month}-${year}`;
}


export function formatCpr(cpr: string | null | undefined): string {
  if (!cpr) return "—";
  const digits = String(cpr).replace(/\D/g, "");
  return digits.length === 10 ? `${digits.slice(0, 6)}-${digits.slice(6)}` : String(cpr);
}


export const statusBadgeClasses: Record<string, string> = {
  ny: "bg-blue-100 text-blue-700",
  aktiv: "bg-green-100 text-green-800",
  afslag: "bg-red-100 text-red-700",
  ophørt: "bg-slate-100 text-slate-700",
  revurdering: "bg-yellow-100 text-yellow-700",
  påbegyndt: "bg-blue-100 text-blue-700",
  kommende: "bg-violet-100 text-violet-700",
  udløbet: "bg-slate-100 text-slate-700",
  fejlet: "bg-red-100 text-red-700",
  default: "bg-slate-100 text-slate-700"
};


export function getStatusBadgeClass(status: string | null | undefined) {
  const key = String(status ?? "").toLowerCase();
  return statusBadgeClasses[key] ?? statusBadgeClasses.default;
}


const befordringstypeBadgeClasses: Record<string, string> = {
  "egen befordring":  "bg-violet-100 text-violet-700 border border-violet-200",
  "rutekørsel":       "bg-amber-100 text-amber-700 border border-amber-200",
  "skånekørsel":      "bg-amber-100 text-amber-700 border border-amber-200",
  "solokørsel":       "bg-amber-100 text-amber-700 border border-amber-200",
  "variabel kørsel":  "bg-amber-100 text-amber-700 border border-amber-200",
  "skolerejsekort":   "bg-sky-100 text-sky-700 border border-sky-200",
  "skolebus":         "bg-teal-100 text-teal-700 border border-teal-200",
  "cykelbus":         "bg-green-100 text-green-700 border border-green-200",
  "gåbus":            "bg-green-100 text-green-700 border border-green-200",
};

export function getBefordringstypeBadgeClass(label: string): string {
  return befordringstypeBadgeClasses[label.toLowerCase()] ?? "bg-gray-100 text-gray-600 border border-gray-200";
}


// Yellow "Revurdering" pill shown NEXT TO the real status when a bevilling row
// carries the revurdering flag. Returns an HTML string for {@html} render
// contexts (DataTable columns); Svelte components inline the equivalent markup.
export function revurderingPillHtml(row: any): string {
  if (!row?.revurdering) return "";
  const reason = row.statusbemaerkning
    ? ` title="${String(row.statusbemaerkning).replace(/"/g, "&quot;")}"`
    : "";
  return `<span class="ml-1.5 inline-block px-2 py-0.5 rounded text-xs font-medium ${statusBadgeClasses.revurdering}"${reason}>Revurdering</span>`;
}


// -----------------------------
// Table action buttons
// -----------------------------

export const tableActionButtonClass =
  "inline-flex min-h-8 items-center justify-center rounded px-3 py-2 text-sm font-medium transition-all focus:outline-none focus:ring-2 focus:ring-offset-2";

export const tablePrimaryActionButtonClass =
  `${tableActionButtonClass} text-blue-600 hover:bg-blue-50 focus:ring-blue-300`;

export const tableSaveActionButtonClass =
  `${tableActionButtonClass} text-green-700 hover:bg-green-50 focus:ring-green-300`;

export const tableCancelActionButtonClass =
  `${tableActionButtonClass} text-red-600 hover:bg-red-50 focus:ring-red-300`;

export const tableIconButtonClass =
  "inline-flex h-8 w-8 items-center justify-center rounded hover:bg-blue-50 focus:outline-none focus:ring-2 focus:ring-blue-300 transition-colors";
