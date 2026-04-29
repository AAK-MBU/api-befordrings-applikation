export const statusBadgeClasses: Record<string, string> = {
  aktiv: "bg-green-100 text-green-800",
  inaktiv: "bg-red-100 text-red-700",
  revurdering: "bg-yellow-100 text-yellow-700",
  ny: "bg-blue-100 text-blue-700",
  default: "bg-slate-100 text-slate-700"
};


export function getStatusBadgeClass(status: string | null | undefined) {
  const key = String(status ?? "").toLowerCase();

  return statusBadgeClasses[key] ?? statusBadgeClasses.default;
}