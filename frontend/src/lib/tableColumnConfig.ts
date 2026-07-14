export function formatDanishDate(dateStr: string | null | undefined): string {
  if (!dateStr) return "—";
  const parts = dateStr.split("-");
  if (parts.length !== 3) return dateStr;
  const [year, month, day] = parts;
  return `${day}-${month}-${year}`;
}


export const statusBadgeClasses: Record<string, string> = {
  ny: "bg-blue-100 text-blue-700",
  aktiv: "bg-green-100 text-green-800",
  afslag: "bg-red-100 text-red-700",
  ophørt: "bg-red-100 text-red-700",
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