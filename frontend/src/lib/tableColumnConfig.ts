export const statusBadgeClasses: Record<string, string> = {
  ny: "bg-blue-100 text-blue-700",
  aktiv: "bg-green-100 text-green-800",
  afslag: "bg-red-100 text-red-700",
  ophørt: "bg-red-100 text-red-700",
  revurdering: "bg-yellow-100 text-yellow-700",
  kommende: "bg-blue-100 text-blue-700",
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
  "inline-flex min-h-8 items-center justify-center rounded px-2.5 py-1 text-sm hover:bg-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-300";

export const tablePrimaryActionButtonClass =
  `${tableActionButtonClass} text-sky-600`;

export const tableSaveActionButtonClass =
  `${tableActionButtonClass} text-green-700`;

export const tableCancelActionButtonClass =
  `${tableActionButtonClass} text-red-600`;

export const tableIconButtonClass =
  "inline-flex h-8 w-8 items-center justify-center rounded hover:bg-yellow-50 focus:outline-none focus:ring-2 focus:ring-yellow-300";