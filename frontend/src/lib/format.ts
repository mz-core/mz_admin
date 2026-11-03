import type { MetadataValue, Variant } from "@/lib/types"

export function escapeHtml(value: unknown) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;")
}

export function safeVariant(value: unknown, fallback: Variant = "neutral"): Variant {
  const normalized = String(value || "").toLowerCase()
  return ["neutral", "info", "success", "warning", "danger"].includes(normalized)
    ? (normalized as Variant)
    : fallback
}

export function selectorFilterLabel(filter: string) {
  if (filter === "online") return "Online"
  if (filter === "offline") return "Offline"
  return "Todos"
}

export function metadataValues(metadata: unknown): string[] {
  if (!metadata) return []
  if (Array.isArray(metadata)) {
    return (metadata as MetadataValue[]).map((item) => {
      if (typeof item === "object" && item !== null) {
        const label = item.label || ""
        return item.value !== undefined ? `${label}: ${item.value}` : label
      }
      return String(item)
    })
  }
  if (typeof metadata === "object") {
    return Object.entries(metadata as Record<string, unknown>).map(([key, value]) => `${key}: ${value}`)
  }
  return []
}

export function searchableText(option: {
  title?: string
  description?: string
  badge?: string
  status?: string
}) {
  return [option.title, option.description, option.badge, option.status]
    .filter(Boolean)
    .join(" ")
    .toLowerCase()
}
