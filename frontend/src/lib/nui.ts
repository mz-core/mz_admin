export function resourceName() {
  const parent = (window as Window & { GetParentResourceName?: () => string }).GetParentResourceName
  return typeof parent === "function" ? parent() : "mz_admin"
}

export function post(name: string, data: Record<string, unknown> = {}) {
  return fetch(`https://${resourceName()}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  }).catch(() => null)
}

export function postLocked(element: HTMLElement | null, name: string, data: Record<string, unknown> = {}) {
  if (!element || element.dataset.busy === "1") return
  element.dataset.busy = "1"
  element.setAttribute("aria-busy", "true")
  post(name, data).finally(() => {
    window.setTimeout(() => {
      element.dataset.busy = "0"
      element.removeAttribute("aria-busy")
    }, 250)
  })
}
