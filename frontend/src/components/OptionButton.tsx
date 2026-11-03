import { Icon } from "@/components/Icon"
import { metadataValues, safeVariant, searchableText } from "@/lib/format"
import type { MenuOption, PlayerSelectorItem, Variant } from "@/lib/types"

export function Pill({
  text,
  variant = "neutral",
  className = "option__pill",
}: {
  text?: string | number | null
  variant?: Variant | string
  className?: string
}) {
  if (text === undefined || text === null || String(text).trim() === "") return null
  return <span className={`${className} is-${safeVariant(variant)}`}>{String(text)}</span>
}

export function EmptyState({ title, detail }: { title: string; detail?: string }) {
  return (
    <div className="option-empty">
      <span>{title}</span>
      {detail ? <small>{detail}</small> : null}
    </div>
  )
}

export function OptionButton({
  option,
  originalIndex,
  focused,
  filtered,
  onSelect,
}: {
  option: MenuOption
  originalIndex: number
  focused?: boolean
  filtered?: boolean
  onSelect?: (element: HTMLButtonElement) => void
}) {
  if (String(option.type || "").toLowerCase() === "section") {
    return (
      <div className="option-section">
        <span>{option.label || option.title || ""}</span>
      </div>
    )
  }

  const disabled = option.disabled === true || option.readOnly === true
  const progress = typeof option.progress === "number"
    ? Math.max(0, Math.min(100, option.progress))
    : null
  const arrow = (option.menu || option.arrow === true) && option.arrow !== false
  const toggle = typeof option.checked === "boolean"
  const tone = option.destructive === true || String(option.tone || "").toLowerCase() === "danger"
  const metadata = metadataValues(option.metadata).slice(0, 4)

  return (
    <button
      className={[
        "option",
        disabled ? "is-disabled" : "",
        tone ? "is-danger" : "",
        focused ? "is-focused" : "",
        filtered ? "is-filtered" : "",
      ].filter(Boolean).join(" ")}
      data-index={originalIndex}
      data-search={searchableText(option)}
      type="button"
      onClick={(event) => {
        if (disabled) return
        onSelect?.(event.currentTarget)
      }}
    >
      <span
        className="option__icon"
        style={option.iconColor ? { color: option.iconColor } : undefined}
      >
        <Icon name={option.icon} />
      </span>
      <span className="option__body">
        <span className="option__titleRow">
          <span className="option__title">{option.title || "Opção"}</span>
          <Pill text={option.badge} variant={option.badgeVariant || "neutral"} />
        </span>
        {option.description ? <span className="option__desc">{option.description}</span> : null}
        {metadata.length ? (
          <span className="option__meta">
            {metadata.map((value, index) => (
              <span className="chip" key={`${value}-${index}`}>{value}</span>
            ))}
          </span>
        ) : null}
      </span>
      <span className="option__right">
        <Pill text={option.status} variant={option.statusVariant || "info"} className="option__status" />
        {option.shortcut ? <kbd className="option__shortcut">{option.shortcut}</kbd> : null}
        {progress !== null ? (
          <span className="progress" title={`${Math.round(progress)}%`}>
            <span style={{ width: `${progress}%` }} />
          </span>
        ) : null}
        {toggle ? (
          <span className={`option__toggle${option.checked ? " is-on" : ""}`} aria-hidden="true">
            <span />
          </span>
        ) : null}
        {arrow ? <Icon name="chevron" /> : null}
      </span>
    </button>
  )
}

export function PlayerOption({
  item,
  focused,
  onSelect,
}: {
  item: PlayerSelectorItem
  focused?: boolean
  onSelect?: (element: HTMLButtonElement) => void
}) {
  const online = item.online === true && Number(item.source) > 0
  const characterName = String(item.characterName || "").trim()
  const sessionName = String(item.name || "").trim()
  const title = characterName || sessionName || "Character sem nome"
  const details: string[] = []
  if (sessionName && sessionName.toLowerCase() !== title.toLowerCase()) details.push(sessionName)
  details.push(online ? `Source ${Number(item.source)}` : "Offline")
  if (item.self === true) details.push("voce")

  return (
    <button
      className={`option player-option${focused ? " is-focused" : ""}`}
      data-player-key={item.key}
      type="button"
      onClick={(event) => onSelect?.(event.currentTarget)}
    >
      <span
        className={`option__icon player-option__state ${online ? "is-online" : "is-offline"}`}
        aria-hidden="true"
      >
        <span />
      </span>
      <span className="option__body">
        <span className="option__titleRow">
          <span className="option__title">{title}</span>
        </span>
        <span className="option__desc">{details.join(" · ")}</span>
      </span>
      <span className="option__right">
        <Pill
          text={online ? "Online" : "Offline"}
          variant={online ? "success" : "neutral"}
          className="option__status"
        />
        <Icon name="chevron" />
      </span>
    </button>
  )
}
