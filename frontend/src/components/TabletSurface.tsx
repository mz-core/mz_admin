import { Icon } from "@/components/Icon"
import { Pill } from "@/components/OptionButton"
import { Input } from "@/components/ui/input"
import type {
  AppState,
  ContextMenu,
  MenuOption,
  TabletModal,
  TabletRow,
  TabletTab,
  TabletView,
} from "@/lib/types"
import { OptionButton } from "@/components/OptionButton"

type TabletSurfaceProps = {
  state: AppState
  onTab: (tab: string) => void
  onCategory: (category: string) => void
  onBack: () => void
  onSearch: (query: string) => void
  onFilter: (filter: string) => void
  onContextSelect: (option: MenuOption, index: number, element: HTMLButtonElement) => void
  onRowPrimary: (row: TabletRow, view: TabletView | null, element: HTMLElement) => void
  onRowButton: (row: TabletRow, action: string, args: unknown, element: HTMLElement) => void
  onModalTab: (tab: string) => void
  onModalRowPrimary: (row: TabletRow, element: HTMLElement) => void
  onModalRowButton: (action: string, args: unknown, element: HTMLElement) => void
  onModalClose: () => void
  onShowTooltip: (button: HTMLButtonElement) => void
  onHideTooltip: () => void
  onInputFocus: (focused: boolean) => void
}

function isTextEntry(element: EventTarget | null) {
  const tag = (element as HTMLElement | null)?.tagName
  return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT"
}

function TabletEmpty({ text }: { text?: string }) {
  return (
    <div className="mz-tablet__empty">
      <span>{text || "Nenhum item."}</span>
    </div>
  )
}

function TabletRowView({
  row,
  onPrimary,
  onButton,
}: {
  row: TabletRow
  onPrimary: (row: TabletRow, element: HTMLElement) => void
  onButton: (row: TabletRow, action: string, args: unknown, element: HTMLElement) => void
}) {
  const status = row.status
    ? <Pill text={row.status.label} variant={row.status.variant || "neutral"} className="mz-tablet__pill" />
    : null
  const tone = row.tone === "danger" ? " is-danger" : ""
  const selected = row.selected === true ? " is-selected" : ""
  const hasPrimary = Boolean(row.primary?.action)
  const content = (
    <>
      {row.icon ? (
        <span className="mz-tablet__rowIcon"><Icon name={row.icon} /></span>
      ) : null}
      <span className="mz-tablet__rowBody">
        <span className="mz-tablet__rowTitle">{row.title || ""}</span>
        {row.subtitle ? <span className="mz-tablet__rowSubtitle">{row.subtitle}</span> : null}
      </span>
      {status}
    </>
  )

  return (
    <div
      className={`mz-tablet__row${tone}${selected}`}
      data-key={row.key || ""}
      data-primary={hasPrimary ? "1" : undefined}
    >
      {hasPrimary ? (
        <button className="mz-tablet__rowPrimary" type="button" onClick={(event) => onPrimary(row, event.currentTarget)}>
          {content}
        </button>
      ) : content}
      {Array.isArray(row.buttons) && row.buttons.length ? (
        <span className="mz-tablet__rowActions">
          {row.buttons.map((button, index) => {
            const buttonTone = button.tone === "danger"
              ? " is-danger"
              : button.tone === "warning"
                ? " is-warning"
                : ""
            return (
              <button
                className={`mz-tablet__action${buttonTone}`}
                data-index={index}
                type="button"
                title={button.label || ""}
                key={index}
                onClick={(event) => {
                  event.stopPropagation()
                  if (button.action) onButton(row, button.action, button.args, event.currentTarget)
                }}
              >
                {button.icon ? <Icon name={button.icon} /> : null}
                <span>{button.label || ""}</span>
              </button>
            )
          })}
        </span>
      ) : null}
    </div>
  )
}

function PlayerCard({ row, onPrimary }: { row: TabletRow; onPrimary: (row: TabletRow, element: HTMLElement) => void }) {
  const online = row.status?.variant === "success"
  return (
    <button className="mz-tablet__card" data-key={row.key || ""} type="button" onClick={(event) => onPrimary(row, event.currentTarget)}>
      <div className="mz-tablet__cardHead">
        <span className={`mz-tablet__cardState${online ? " is-online" : ""}`} aria-hidden="true" />
        <span className="mz-tablet__cardName">{row.title || ""}</span>
      </div>
      <div className="mz-tablet__cardMeta">
        <span className="mz-tablet__cardId">{row.subtitle || ""}</span>
        {row.status ? <Pill text={row.status.label} variant={row.status.variant || "neutral"} className="mz-tablet__pill" /> : null}
      </div>
    </button>
  )
}

function FlightHome({
  view,
  rows,
  model,
  onAction,
}: {
  view: TabletView
  rows: TabletRow[]
  model: AppState["tablet"]["model"]
  onAction: (row: TabletRow, element: HTMLElement) => void
}) {
  const user = model?.user || {}
  const userName = user.name || "Staff"
  const userRole = user.role || "Staff"

  return (
    <>
      <section className="mz-flightCard">
        <header className="mz-flightCard__header">
          <strong>Sessão administrativa</strong>
          <span className="mz-flightCard__headerIcon"><Icon name="info" /></span>
        </header>
        <div className="mz-flightStats">
          <span>Staff: <b>{userName}</b></span>
          <span>Cargo: <b>{userRole}</b></span>
          <span>Ações: <b>{rows.length}</b></span>
        </div>
      </section>
      <section className="mz-flightCard">
        <header className="mz-flightCard__header">
          <strong>Ações rápidas</strong>
          <span className="mz-flightCard__headerIcon"><Icon name="bolt" /></span>
        </header>
        {view.subtitle ? <p className="mz-flightCard__subtitle">{view.subtitle}</p> : null}
        <div className="mz-flightActions">
          {rows.length ? rows.map((row, index) => (
            <button
              className={`mz-flightAction${row.tone === "danger" ? " is-danger" : ""}`}
              data-flight-action={index}
              type="button"
              title={row.subtitle || row.title || ""}
              key={row.key || index}
              onClick={(event) => onAction(row, event.currentTarget)}
            >
              {row.icon ? <span className="mz-flightAction__icon"><Icon name={row.icon} /></span> : null}
              <span>{row.title || ""}</span>
            </button>
          )) : <TabletEmpty text={view.empty || "Nenhuma ação autorizada."} />}
        </div>
      </section>
    </>
  )
}

function renderTabletModalTabs(
  modal: TabletModal,
  activeTab: string | null,
  onSelect: (tab: string) => void
) {
  const tabs = Array.isArray(modal.tabs) ? modal.tabs : []
  return tabs.map((tab) => (
    <button
      className={`mz-tablet__modalTab${tab.id === activeTab ? " is-active" : ""}`}
      data-tab={tab.id}
      type="button"
      key={tab.id}
      onClick={() => onSelect(tab.id)}
    >
      {tab.icon ? <span className="mz-tablet__modalTabIcon"><Icon name={tab.icon} /></span> : null}
      <span>{tab.label || tab.id}</span>
    </button>
  ))
}

function TabletTabs({
  tabs,
  active,
  onSelect,
  onShow,
  onHide,
}: {
  tabs: TabletTab[]
  active: string | null
  onSelect: (tab: string) => void
  onShow: (button: HTMLButtonElement) => void
  onHide: () => void
}) {
  return (
    <nav id="tabletTabs" className="mz-tablet__tabs" aria-label="Seções administrativas">
      {tabs.map((tab) => (
        <button
          className={`mz-tablet__tab${tab.id === active ? " is-active" : ""}`}
          data-tab={tab.id}
          data-label={tab.label || tab.id}
          type="button"
          aria-label={tab.label || tab.id}
          aria-describedby="tabletTooltip"
          aria-expanded={tab.id === active}
          key={tab.id}
          onMouseEnter={(event) => onShow(event.currentTarget)}
          onMouseLeave={onHide}
          onFocus={(event) => onShow(event.currentTarget)}
          onBlur={onHide}
          onClick={() => onSelect(tab.id)}
        >
          {tab.icon ? <span className="mz-tablet__tabIcon"><Icon name={tab.icon} /></span> : null}
          <span>{tab.label || tab.id}</span>
        </button>
      ))}
    </nav>
  )
}

export function TabletSurface({
  state,
  onTab,
  onCategory,
  onBack,
  onSearch,
  onFilter,
  onContextSelect,
  onRowPrimary,
  onRowButton,
  onModalTab,
  onModalRowPrimary,
  onModalRowButton,
  onModalClose,
  onShowTooltip,
  onHideTooltip,
  onInputFocus,
}: TabletSurfaceProps) {
  const tablet = state.tablet
  const model = tablet.model
  const view = tablet.view
  const context: ContextMenu | null = tablet.context
  const modal = tablet.modal
  const tabs = Array.isArray(model?.tabs) ? model.tabs : []
  const categories = Array.isArray(model?.categories) ? model.categories : []
  const user = model?.user || {}
  const userName = user.name || "Staff"
  const userRole = user.role || "Staff"
  const rows = Array.isArray(view?.rows) ? view.rows : []
  const isGrid = String(view?.layout || "").toLowerCase() === "grid" && view?.tab !== "main"
  const searchable = view?.searchable === true || context?.searchable === true
  const filters = Array.isArray(view?.filters) ? view.filters : []
  const contextOptions = Array.isArray(context?.options) ? context.options : []
  const term = String(tablet.search || "").trim().toLowerCase()
  const backVisible = Boolean(context?.menu)
  const title = context ? context.title || "Menu" : view?.title || ""
  const subtitle = context ? context.subtitle || "" : view?.subtitle || ""
  const modalTabs = Array.isArray(modal?.tabs) ? modal.tabs : []
  const activeModalTab = tablet.modalTab && modalTabs.some((tab) => tab.id === tablet.modalTab)
    ? tablet.modalTab
    : modalTabs[0]?.id || null
  const modalContent = modal?.content?.[activeModalTab || ""] || {}
  const modalRows = Array.isArray(modalContent.rows) ? modalContent.rows : []

  return (
    <section
      id="tablet"
      className={[
        "mz-tablet",
        tablet.visible ? "" : "hidden",
        tablet.expanded ? "" : "is-collapsed",
        tablet.workspace ? "" : "is-compact",
        tablet.isHome ? "is-home" : "",
      ].filter(Boolean).join(" ")}
      aria-live="polite"
      onFocusCapture={(event) => {
        if (isTextEntry(event.target)) onInputFocus(true)
      }}
      onBlurCapture={(event) => {
        if (isTextEntry(event.target) && !isTextEntry(event.relatedTarget)) onInputFocus(false)
      }}
    >
      <div className="mz-tablet__frame">
        <div className="mz-tablet__accent" aria-hidden="true" />
        <header className="mz-tablet__header">
          <div className="mz-tablet__brand">
            <img
              className="mz-tablet__logo"
              src="logo_s.svg"
              width="56"
              height="56"
              alt="MZ Admin"
              fetchPriority="high"
              translate="no"
            />
            <h1 id="tabletTitle" className="mz-tablet__title" translate="no">{model?.title || ""}</h1>
          </div>
          <div className="mz-tablet__divider" aria-hidden="true" />
          <div className="mz-tablet__user">
            <span id="tabletUserInitial" className="mz-tablet__avatar" aria-hidden="true">
              {String(userName).trim().charAt(0).toUpperCase() || "S"}
            </span>
            <div className="mz-tablet__userText">
              <div className="mz-tablet__userNameRow">
                <strong id="tabletUserName" className="mz-tablet__userName">{userName}</strong>
                <span
                  id="tabletCrown"
                  className={`mz-tablet__crown${user.owner === true ? "" : " hidden"}`}
                  title="Owner"
                  aria-label="Owner"
                >
                  {user.owner === true ? <Icon name="crown" /> : null}
                </span>
              </div>
              <small id="tabletUserRole" className="mz-tablet__userRole">{userRole}</small>
            </div>
          </div>
        </header>

        <div className="mz-tablet__body">
          {tablet.hasTabs ? (
            <TabletTabs
              tabs={tabs}
              active={tablet.tab}
              onSelect={onTab}
              onShow={onShowTooltip}
              onHide={onHideTooltip}
            />
          ) : null}
          <aside
            id="tabletSidebar"
            className={`mz-tablet__sidebar${tablet.hasTabs ? " hidden" : ""}`}
          >
            <nav id="tabletNav" className="mz-tablet__nav scrollbar-thin">
              {categories.map((category) => (
                <button
                  className={`mz-tablet__navItem${category.id === tablet.category ? " is-active" : ""}`}
                  data-category={category.id}
                  type="button"
                  key={category.id}
                  onClick={() => onCategory(category.id)}
                >
                  <span className="mz-tablet__navIcon"><Icon name={category.icon} /></span>
                  <span className="mz-tablet__navLabel">{category.label || category.id}</span>
                </button>
              ))}
            </nav>
          </aside>

          <main
            id="tabletContent"
            className="mz-tablet__content"
            aria-hidden={tablet.expanded ? "false" : "true"}
            inert={!tablet.expanded}
          >
            <div className="mz-tablet__contentHeader">
              <button
                id="tabletBackBtn"
                className={`mz-icon-btn${backVisible ? "" : " hidden"}`}
                type="button"
                title="Voltar"
                aria-label="Voltar"
                onClick={onBack}
              >
                <Icon name="arrow-left" />
              </button>
              <div className="mz-tablet__contentTitleWrap">
                <h2 id="tabletViewTitle" className="mz-tablet__viewTitle">{title}</h2>
                <p id="tabletViewSubtitle" className={`mz-tablet__viewSubtitle${subtitle ? "" : " hidden"}`}>{subtitle}</p>
              </div>
              <div id="tabletSearchWrap" className={`mz-tablet__search${searchable ? "" : " hidden"}`}>
                <span className="mz-tablet__searchIcon" aria-hidden="true"><Icon name="search" /></span>
                <Input
                  id="tabletSearch"
                  type="text"
                  autoComplete="off"
                  spellCheck={false}
                  aria-label="Buscar na seção"
                  placeholder="Buscar…"
                  value={tablet.search}
                  onChange={(event) => onSearch(event.target.value)}
                />
              </div>
            </div>

            <div
              id="tabletFilters"
              className={`mz-tablet__filters${filters.length ? "" : " hidden"}`}
              role="group"
              aria-label="Filtrar"
            >
              {filters.map((filter) => (
                <button
                  className={`mz-tablet__filter${filter.id === view?.activeFilter ? " is-active" : ""}`}
                  data-filter={filter.id}
                  type="button"
                  key={filter.id}
                  onClick={() => onFilter(filter.id)}
                >
                  {filter.label || filter.id}
                </button>
              ))}
            </div>

            <div
              id="tabletRows"
              className={`mz-tablet__rows scrollbar-thin${isGrid ? " is-grid" : ""}`}
            >
              {view?.loading === true ? (
                <TabletEmpty text="Carregando…" />
              ) : view?.tab === "main" ? (
                <FlightHome
                  view={view}
                  rows={rows}
                  model={model}
                  onAction={(row, element) => onRowPrimary(row, view, element)}
                />
              ) : context ? (
                contextOptions.length ? (
                  contextOptions.map((option, index) => {
                    const type = String(option.type || "").toLowerCase()
                    const searchText = [option.title, option.description, option.badge, option.status]
                      .filter(Boolean).join(" ").toLowerCase()
                    const filtered = Boolean(term) && type !== "section" && !searchText.includes(term)
                    return (
                      <OptionButton
                        key={index}
                        option={option}
                        originalIndex={index}
                        filtered={filtered}
                        onSelect={(element) => onContextSelect(option, index, element)}
                      />
                    )
                  })
                ) : (
                  <TabletEmpty text="Nenhuma opção disponível" />
                )
              ) : isGrid ? (
                rows.length
                  ? rows.map((row, index) => (
                      <PlayerCard
                        key={row.key || index}
                        row={row}
                        onPrimary={(target, element) => onRowPrimary(target, view, element)}
                      />
                    ))
                  : <TabletEmpty text={view?.empty || "Nenhum item."} />
              ) : rows.length ? (
                rows.map((row, index) => (
                  <TabletRowView
                    key={row.key || index}
                    row={row}
                    onPrimary={(target, element) => onRowPrimary(target, view, element)}
                    onButton={(target, action, args, element) => onRowButton(target, action, args, element)}
                  />
                ))
              ) : (
                <TabletEmpty text={view?.empty || "Nenhum item."} />
              )}
            </div>
          </main>
        </div>

        <section
          id="tabletModal"
          className={`mz-tablet__modal${modal ? "" : " hidden"}`}
          role="dialog"
          aria-modal="true"
          aria-labelledby="tabletModalTitle"
          aria-live="polite"
        >
          <div className="mz-tablet__modalFrame">
            <header className="mz-tablet__modalHeader">
              <div className="mz-tablet__modalTitleWrap">
                <h2 id="tabletModalTitle" className="mz-tablet__modalTitle">{modal?.title || "Jogador"}</h2>
                <p id="tabletModalSubtitle" className={`mz-tablet__modalSubtitle${modal?.subtitle ? "" : " hidden"}`}>
                  {modal?.subtitle || ""}
                </p>
              </div>
              <button
                id="tabletModalCloseBtn"
                className="mz-icon-btn"
                type="button"
                title="Fechar"
                aria-label="Fechar"
                onClick={onModalClose}
              >
                <Icon name="x" />
              </button>
            </header>
            <div className="mz-tablet__modalContent">
              <nav id="tabletModalTabs" className="mz-tablet__modalTabs scrollbar-thin" aria-label="Seções">
                {modal ? renderTabletModalTabs(modal, activeModalTab, onModalTab) : null}
              </nav>
              <div id="tabletModalBody" className="mz-tablet__modalBody scrollbar-thin">
                {modal
                  ? modalRows.length
                    ? modalRows.map((row, index) => (
                        <TabletRowView
                          key={row.key || index}
                          row={row}
                          onPrimary={(target, element) => onModalRowPrimary(target, element)}
                          onButton={(_target, action, args, element) => onModalRowButton(action, args, element)}
                        />
                      ))
                    : <TabletEmpty text={modalContent.empty || "Nenhum dado disponível."} />
                  : null}
              </div>
            </div>
          </div>
        </section>
      </div>
      <div
        id="tabletTooltip"
        className={`mz-tablet__tooltip${tablet.tooltip ? "" : " hidden"}`}
        role="tooltip"
        style={tablet.tooltip ? { left: tablet.tooltip.left, top: tablet.tooltip.top } : undefined}
      >
        {tablet.tooltip?.text || ""}
      </div>
    </section>
  )
}
