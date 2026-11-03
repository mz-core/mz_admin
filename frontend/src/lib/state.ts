import type {
  AlertDialogPayload,
  AppState,
  ContextMenu,
  DialogState,
  InputDialogPayload,
  NotifyPayload,
  PlayerSelectorPayload,
  PlayerSelectorResult,
  TabletModel,
  TabletModal,
  TabletState,
  TabletView,
  Theme,
  TooltipState,
} from "@/lib/types"

let toastId = 0

export const emptyTablet: TabletState = {
  visible: false,
  model: null,
  hasTabs: false,
  tab: null,
  category: null,
  expanded: false,
  workspace: false,
  isHome: false,
  view: null,
  context: null,
  modal: null,
  modalTab: null,
  search: "",
  searchScope: null,
  tooltip: null,
}

export const initialState: AppState = {
  theme: {
    accent: "#009fe3",
    accent2: "#67c9f1",
    position: "left",
    width: 380,
  },
  brand: "MZ Admin",
  movement: { enabled: false, key: "F6", toggleEnabled: true },
  panel: {
    open: false,
    mode: "context",
    menu: null,
    selector: null,
    focused: 0,
    search: "",
  },
  tablet: { ...emptyTablet },
  dialog: null,
  toasts: [],
}

export type Action =
  | { type: "theme"; theme?: Partial<Theme>; brand?: string }
  | { type: "movementMode"; enabled?: boolean; key?: string; toggleEnabled?: boolean }
  | { type: "openContext"; menu: ContextMenu }
  | { type: "close" }
  | { type: "notify"; data: NotifyPayload }
  | { type: "inputDialog"; payload: InputDialogPayload }
  | { type: "alertDialog"; payload: AlertDialogPayload }
  | { type: "dialogClose" }
  | { type: "toastRemove"; id: number }
  | { type: "openTablet"; model: TabletModel }
  | { type: "tabletView"; view: TabletView }
  | { type: "tabletContext"; menu: ContextMenu }
  | { type: "tabletModal"; modal: TabletModal }
  | { type: "tabletModalClose" }
  | { type: "tabletClose" }
  | { type: "tabletResume" }
  | { type: "tabletSuspend" }
  | { type: "tabletTab"; tab: string }
  | { type: "tabletCategory"; category: string }
  | { type: "tabletSearch"; query: string }
  | { type: "tabletModalTab"; tab: string }
  | { type: "tabletTooltip"; tooltip: TooltipState | null }
  | { type: "openPlayerSelector"; payload: PlayerSelectorPayload }
  | {
      type: "playerSelectorResults"
      requestId: string
      result: PlayerSelectorResult
      append: boolean
    }
  | { type: "panelSearch"; query: string }
  | { type: "panelFocus"; index: number }
  | { type: "selectorFilter"; filter: string }
  | { type: "selectorSearching" }

function isHex(value: unknown) {
  return typeof value === "string" && /^#[0-9a-f]{6}$/i.test(value)
}

function sanitizeTheme(theme: Partial<Theme> | undefined, current: Theme): Theme {
  const requestedWidth = Number(theme?.width)
  const safeWidth = Number.isFinite(requestedWidth)
    ? Math.min(640, Math.max(320, requestedWidth))
    : current.width
  const position = ["left", "right", "center"].includes(String(theme?.position))
    ? (theme?.position as Theme["position"])
    : current.position

  return {
    accent: isHex(theme?.accent) ? String(theme?.accent) : current.accent,
    accent2: isHex(theme?.accent2) ? String(theme?.accent2) : current.accent2,
    position,
    width: safeWidth,
  }
}

function validFunctionKey(value: unknown) {
  const key = String(value || "").toUpperCase()
  return /^F([1-9]|1[0-2])$/.test(key) ? key : null
}

function applySearchScope(tablet: TabletState, scope: string, query = "") {
  const nextScope = String(scope || "")
  if (nextScope === tablet.searchScope) return tablet
  return { ...tablet, searchScope: nextScope, search: String(query || "") }
}

function openContextInTablet(state: AppState, menu: ContextMenu): AppState {
  const tablet = state.tablet
  if (tablet.hasTabs && !tablet.tab) return state

  let nextTablet: TabletState = {
    ...tablet,
    visible: true,
    context: menu,
    view: null,
    expanded: true,
    workspace: true,
    isHome: false,
  }

  if (menu.searchable === true) {
    nextTablet = applySearchScope(nextTablet, `context:${menu.id}`)
  }

  return { ...state, panel: { ...state.panel, open: false }, tablet: nextTablet }
}

function clearTabletWorkspace(tablet: TabletState): TabletState {
  return {
    ...tablet,
    view: null,
    context: null,
    isHome: false,
    search: "",
    searchScope: null,
  }
}

function setTabletViewState(state: AppState, view: TabletView): AppState {
  let tablet = state.tablet
  if (tablet.hasTabs && !tablet.tab) return state

  tablet = {
    ...tablet,
    view: view || {},
    context: null,
    expanded: true,
    isHome: view.tab === "main",
    workspace: view.workspace === true,
  }

  if (view.tab && view.tab !== tablet.tab) {
    tablet = { ...tablet, tab: view.tab }
  }

  if (view.category && !tablet.hasTabs) {
    tablet = { ...tablet, category: view.category }
  }

  if (view.searchable === true) {
    tablet = applySearchScope(tablet, view.tab || view.category || "", view.query)
  }

  return { ...state, tablet }
}

function playerSelectorState(payload: PlayerSelectorPayload) {
  const filters = Array.isArray(payload.filters) && payload.filters.length
    ? payload.filters
    : ["all", "online", "offline"]
  const filter = filters.includes(String(payload.defaultFilter))
    ? String(payload.defaultFilter)
    : filters[0]

  return {
    requestId: payload.requestId,
    title: payload.title,
    subtitle: payload.subtitle,
    brand: payload.brand,
    filters,
    filter,
    searchPlaceholder: payload.searchPlaceholder,
    items: [],
    page: 1,
    total: 0,
    hasMore: false,
    hint: "",
    summary: "Buscando jogadores online…",
    loading: true,
  }
}

function notifyState(data: NotifyPayload) {
  const type = data.type === "inform" ? "info" : data.type || "info"
  return {
    id: ++toastId,
    type,
    title: data.title || "MZ Admin",
    description: data.description || data.message || "",
    duration: Number(data.duration || 5000),
  }
}

export function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    case "theme": {
      return {
        ...state,
        theme: sanitizeTheme(action.theme, state.theme),
        brand: action.brand || state.brand,
      }
    }

    case "movementMode": {
      const nextKey = action.key === undefined
        ? state.movement.key
        : validFunctionKey(action.key) || "F6"
      return {
        ...state,
        movement: {
          enabled: action.enabled === true,
          key: nextKey,
          toggleEnabled: action.toggleEnabled === undefined
            ? state.movement.toggleEnabled
            : action.toggleEnabled !== false,
        },
      }
    }

    case "openContext": {
      if (state.tablet.visible) return openContextInTablet(state, action.menu)
      return {
        ...state,
        panel: {
          open: true,
          mode: "context",
          menu: action.menu,
          selector: null,
          focused: 0,
          search: "",
        },
        tablet: { ...emptyTablet },
      }
    }

    case "close": {
      return {
        ...state,
        panel: {
          open: false,
          mode: "context",
          menu: null,
          selector: null,
          focused: 0,
          search: "",
        },
        dialog: null,
        movement: { ...state.movement, enabled: false },
      }
    }

    case "notify": {
      return { ...state, toasts: [...state.toasts, notifyState(action.data)] }
    }

    case "toastRemove": {
      return { ...state, toasts: state.toasts.filter((toast) => toast.id !== action.id) }
    }

    case "inputDialog": {
      return { ...state, dialog: { kind: "input", payload: action.payload } }
    }

    case "alertDialog": {
      return { ...state, dialog: { kind: "alert", payload: action.payload } }
    }

    case "dialogClose": {
      return { ...state, dialog: null }
    }

    case "openTablet": {
      const model = action.model || {}
      const tabs = Array.isArray(model.tabs) ? model.tabs : []
      return {
        ...state,
        panel: {
          open: false,
          mode: "context",
          menu: null,
          selector: null,
          focused: 0,
          search: "",
        },
        tablet: {
          ...emptyTablet,
          visible: true,
          model,
          hasTabs: tabs.length > 0,
        },
      }
    }

    case "tabletView": {
      return setTabletViewState(state, action.view)
    }

    case "tabletContext": {
      return openContextInTablet(state, action.menu)
    }

    case "tabletModal": {
      return {
        ...state,
        tablet: {
          ...state.tablet,
          modal: action.modal || {},
          modalTab: null,
        },
      }
    }

    case "tabletModalClose": {
      return {
        ...state,
        tablet: { ...state.tablet, modal: null, modalTab: null },
      }
    }

    case "tabletClose": {
      return { ...state, tablet: { ...emptyTablet } }
    }

    case "tabletResume": {
      if (!state.tablet.model) return state
      return { ...state, tablet: { ...state.tablet, visible: true } }
    }

    case "tabletSuspend": {
      return { ...state, tablet: { ...state.tablet, visible: false } }
    }

    case "tabletTab": {
      const nextTab = action.tab
      let tablet = clearTabletWorkspace({
        ...state.tablet,
        modal: null,
        modalTab: null,
      })

      if (nextTab === state.tablet.tab) {
        tablet = { ...tablet, tab: null, expanded: false }
      } else {
        tablet = { ...tablet, tab: nextTab, expanded: true }
      }

      return { ...state, tablet }
    }

    case "tabletCategory": {
      return {
        ...state,
        tablet: { ...state.tablet, category: action.category },
      }
    }

    case "tabletSearch": {
      return {
        ...state,
        tablet: { ...state.tablet, search: action.query },
      }
    }

    case "tabletModalTab": {
      return {
        ...state,
        tablet: { ...state.tablet, modalTab: action.tab },
      }
    }

    case "tabletTooltip": {
      return {
        ...state,
        tablet: { ...state.tablet, tooltip: action.tooltip },
      }
    }

    case "openPlayerSelector": {
      return {
        ...state,
        panel: {
          open: true,
          mode: "selector",
          menu: null,
          selector: playerSelectorState(action.payload),
          focused: 0,
          search: "",
        },
        tablet: { ...state.tablet, visible: false },
      }
    }

    case "playerSelectorResults": {
      const selector = state.panel.selector
      if (!selector || selector.requestId !== action.requestId) return state
      const incoming = Array.isArray(action.result.items) ? action.result.items : []
      const items = action.append
        ? [...selector.items, ...incoming.filter((item) => !selector.items.some((known) => known.key === item.key))]
        : incoming
      const total = Math.max(items.length, Number(action.result.total) || 0)
      const hint = String(action.result.hint || "").trim()

      return {
        ...state,
        panel: {
          ...state.panel,
          focused: 0,
          selector: {
            ...selector,
            items,
            page: Math.max(1, Number(action.result.page) || 1),
            hasMore: action.result.hasMore === true,
            total,
            hint,
            summary: hint || `${items.length} de ${total} resultado(s)`,
            loading: false,
          },
        },
      }
    }

    case "panelSearch": {
      return {
        ...state,
        panel: {
          ...state.panel,
          search: action.query,
          focused: state.panel.mode === "context" ? 0 : state.panel.focused,
        },
      }
    }

    case "panelFocus": {
      return { ...state, panel: { ...state.panel, focused: action.index } }
    }

    case "selectorFilter": {
      const selector = state.panel.selector
      if (!selector) return state
      return {
        ...state,
        panel: {
          ...state.panel,
          focused: 0,
          selector: {
            ...selector,
            filter: action.filter,
            summary: "Buscando…",
            loading: true,
          },
        },
      }
    }

    case "selectorSearching": {
      const selector = state.panel.selector
      if (!selector) return state
      return {
        ...state,
        panel: {
          ...state.panel,
          selector: { ...selector, summary: "Buscando…", loading: true },
        },
      }
    }

    default:
      return state
  }
}

export function dialogRequestId(dialog: DialogState | null) {
  return dialog?.payload.requestId
}
