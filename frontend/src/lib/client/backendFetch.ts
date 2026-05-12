function normalizePath(path: string) {
  if (path.startsWith("/")) {
    return path;
  }

  return `/${path}`;
}


export function backendFetch(path: string, options: RequestInit = {}) {
  return fetch(`/api/backend${normalizePath(path)}`, options);
}