import { useTranslation } from "@/lib/locale"
import { useEffect, useRef } from "react"
import { Icon } from "@/components/Icon"
import { EmptyState, OptionButton, PlayerOption, Pill } from "@/components/OptionButton"
import { Input } from "@/components/ui/input"
import { safeVariant, searchableText, selectorFilterLabel } from "@/lib/format"
import type { AppState, ContextMenu, MenuOption } from "@/lib/types"

type ContextPanelProps = {
  state: AppState
  onClose: () => void
  onBack: () => void
  onSearch: (query: string) => void
  onSelect: (option: MenuOption, index: number, element: HTMLButtonElement) => void
  onPlayerSelect: (key: string, element: HTMLButtonElement) => void
  onMore: (element: HTMLButtonElement) => void
  onFilter: (filter: string) => void
  onMovementToggle: () => void
}

export function visibleActionEntries(menu: ContextMenu | null, search: string) {
  const term = String(search || "").trim().toLowerCase()
  const entries: Array<{ option: MenuOption; originalIndex: number }> = []
  const options = Array.isArray(menu?.options) ? menu.options : []

  options.forEach((option, index) => {
    const type = String(option.type || "").toLowerCase()
    if (type === "section" || option.disabled === true || option.readOnly === true) return
    if (term && !searchableText(option).includes(term)) return
    entries.push({ option, originalIndex: index })
  })

  return entries
}

export function ContextPanel({
  state,
  onClose,
  onBack,
  onSearch,
  onSelect,
  onPlayerSelect,
  onMore,
  onFilter,
  onMovementToggle,
}: ContextPanelProps) {
  const t = useTranslation()
  const panel = state.panel
  const menu = panel.menu
  const selector = panel.mode === "selector" ? panel.selector : null
  const optionsRef = useRef<HTMLDivElement>(null)
  const isDashboard = String(menu?.layout || "context").toLowerCase() === "dashboard"
  const isSelector = selector !== null
  const term = String(panel.search || "").trim().toLowerCase()
  const visible = visibleActionEntries(menu, panel.search)
  const focused = panel.focused

  useEffect(() => {
    if (!panel.open) return
    const current = optionsRef.current?.querySelector(".option.is-focused")
    current?.scrollIntoView({ block: "nearest" })
  }, [panel.open, focused, panel.search, isSelector, selector?.items.length])

  const placeholder = selector
    ? selector.searchPlaceholder || t("search_player")
    : menu?.searchPlaceholder || t("search_tool")
  const searchable = isSelector || menu?.searchable === true
  const brand = selector ? selector.brand || state.brand : menu?.brand || state.brand
  const title = selector ? selector.title || t("select_player") : menu?.title || "Menu"
  const subtitle = selector ? selector.subtitle || "" : menu?.subtitle || ""
  const backVisible = isSelector ? true : Boolean(menu?.menu)
  const user = menu?.user
  const stats = Array.isArray(menu?.stats) ? menu.stats.slice(0, 4) : []
  const dashboardVisible = !isSelector && (Boolean(user) || stats.length > 0)

  return (
    <section
      id="contextPanel"
      className={[
        "mz-panel",
        panel.open ? "" : "hidden",
        isDashboard && !isSelector ? "is-dashboard" : "",
        state.movement.enabled ? "is-movement" : "",
      ].filter(Boolean).join(" ")}
      aria-live="polite"
    >
      <div className="mz-panel__accent" aria-hidden="true" />

      <header className="mz-panel__header">
        <button
          id="backBtn"
          className={`mz-icon-btn${backVisible ? "" : " hidden"}`}
          type="button"
          title={t("back")}
          aria-label={t("back")}
          onClick={onBack}
        >
          <Icon name="arrow-left" />
        </button>
        <span
          id="headerIcon"
          className={`mz-panel__headerIcon${isSelector || menu?.headerIcon ? "" : " hidden"}`}
          aria-hidden="true"
        >
          {isSelector ? <Icon name="user-search" /> : menu?.headerIcon ? <Icon name={menu.headerIcon} /> : null}
        </span>
        <div className="mz-panel__titleWrap">
          <div className="mz-panel__eyebrowRow">
            <span id="brand" className="mz-panel__brand">{brand}</span>
            <span
              id="menuBadge"
              className={`mz-panel__badge${!isSelector && menu?.badge ? "" : " hidden"}`}
            >
              {!isSelector ? menu?.badge || "" : ""}
            </span>
          </div>
          <h1 id="menuTitle" className="mz-panel__title">{title}</h1>
          <p className="mz-panel__subtitle">
            <span id="subtitleSeparator" className="hidden" aria-hidden="true" />
            <span id="menuSubtitle" className={subtitle ? "" : "hidden"}>{subtitle}</span>
          </p>
        </div>
        <button id="closeBtn" className="mz-icon-btn" type="button" title={t("close")} aria-label={t("close")} onClick={onClose}>
          <Icon name="x" />
        </button>
      </header>

      <section
        id="dashboardMeta"
        className={`mz-dashboardMeta${dashboardVisible ? "" : " hidden"}`}
      >
        <div id="userCard" className={`mz-userCard${user ? "" : " hidden"}`}>
          {user ? (
            <>
              <span className="mz-userCard__avatar">
                {String(user.name || "S").trim().charAt(0).toUpperCase() || "S"}
              </span>
              <span className="mz-userCard__body">
                <strong>{user.name || "Staff"}</strong>
                <small>{user.subtitle || t("session")}</small>
              </span>
              <Pill text={user.role || "STAFF"} variant={user.variant || "info"} className="mz-userCard__role" />
            </>
          ) : null}
        </div>
        <div id="statsGrid" className={`mz-stats${stats.length ? "" : " hidden"}`}>
          {stats.map((stat, index) => (
            <div className={`mz-stat is-${safeVariant(stat.variant || "neutral")}`} key={index}>
              <span>{stat.label || ""}</span>
              <strong>{stat.value ?? "—"}</strong>
            </div>
          ))}
        </div>
      </section>

      <div id="searchWrap" className={`mz-search${searchable ? "" : " hidden"}`}>
        <span className="mz-search__icon" aria-hidden="true"><Icon name="search" /></span>
        <Input
          id="menuSearch"
          type="text"
          autoComplete="off"
          spellCheck={false}
          aria-label={t("search_menu")}
          placeholder={placeholder}
          value={panel.search}
          onChange={(event) => onSearch(event.target.value)}
        />
        <span id="searchHint" className="mz-search__hint">CTRL K</span>
      </div>

      <div
        id="selectorFilters"
        className={`mz-selectorFilters${selector ? "" : " hidden"}`}
        role="group"
        aria-label={t("filter_players")}
      >
        {selector
          ? selector.filters.map((filter) => (
              <button
                className={`mz-selectorFilter${filter === selector.filter ? " is-active" : ""}`}
                data-filter={filter}
                type="button"
                key={filter}
                onClick={() => onFilter(filter)}
              >
                {filter === "all" ? t("all") : selectorFilterLabel(filter)}
              </button>
            ))
          : null}
      </div>
      <p
        id="selectorSummary"
        className={`mz-selectorSummary${selector ? "" : " hidden"}`}
        aria-live="polite"
      >
        {selector ? (selector.loading ? t("searching") : selector.summary || t("result_count").replace("{shown}", String(selector.items.length)).replace("{total}", String(selector.total))) : ""}
      </p>

      <div id="options" className="mz-options scrollbar-thin" ref={optionsRef}>
        {selector ? (
          selector.loading && selector.items.length === 0 ? (
            <EmptyState title={t("searching")} />
          ) : selector.items.length ? (
            <>
              {selector.items.map((item, index) => (
                <PlayerOption
                  key={item.key}
                  item={item}
                  focused={index === focused}
                  onSelect={(element) => onPlayerSelect(item.key, element)}
                />
              ))}
              {selector.hasMore ? (
                <button className="option selector-more" type="button" onClick={(event) => onMore(event.currentTarget)}>
                  <span className="option__icon">+</span>
                  <span className="option__body">
                    <span className="option__title">{t("load_more")}</span>
                    <span className="option__desc">{t("next_players")}</span>
                  </span>
                  <span className="option__right" />
                </button>
              ) : null}
            </>
          ) : (
            <EmptyState
              title={selector.hint || t("no_player")}
              detail={t("try_other")}
            />
          )
        ) : menu && (menu.options?.length ?? 0) > 0 ? (
          (menu.options || []).map((option, index) => {
            const visibleIndex = visible.findIndex((entry) => entry.originalIndex === index)
            const filtered = visibleIndex === -1 && String(option.type || "").toLowerCase() !== "section"
            return (
              <OptionButton
                key={index}
                option={option}
                originalIndex={index}
                focused={visibleIndex !== -1 && visibleIndex === focused}
                filtered={filtered && Boolean(term)}
                onSelect={(element) => onSelect(option, index, element)}
              />
            )
          })
        ) : (
          <EmptyState
            title={t("no_options")}
            detail={t("permissions_hint")}
          />
        )}
      </div>

      <footer className="mz-panel__footer">
        <span><b>↑ ↓</b> {t("navigate")}</span>
        <span><b>Enter</b> {t("select")}</span>
        <span><b>Esc</b> {t("back_hint")}</span>
        <button
          id="focusToggleBtn"
          className={`mz-panel__focusToggle${state.movement.toggleEnabled ? "" : " hidden"}`}
          type="button"
          aria-label={state.movement.enabled ? t("lock_movement") : t("unlock_movement")}
          onClick={onMovementToggle}
        >
          <b id="focusToggleKey">{state.movement.key}</b>
          <span id="focusToggleLabel">
            {state.movement.enabled ? t("lock_movement") : t("unlock_movement")}
          </span>
        </button>
      </footer>
    </section>
  )
}
