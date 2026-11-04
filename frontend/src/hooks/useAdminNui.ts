import { useEffect, useReducer, useRef } from "react"
import { post, postLocked } from "@/lib/nui"
import { initialState, reducer } from "@/lib/state"
import type {
  AlertDialogPayload,
  InputDialogPayload,
  MenuOption,
  NuiMessage,
  PlayerSelectorPayload,
  PlayerSelectorResult,
  TabletRow,
  TabletView,
  TooltipState,
} from "@/lib/types"
import { visibleActionEntries } from "@/components/ContextPanel"

type PanelAction =
  | { kind: "option"; entry: { option: MenuOption; originalIndex: number } }
  | { kind: "player"; key: string }
  | { kind: "more" }

export function useAdminNui() {
  const [state, dispatch] = useReducer(reducer, initialState)
  const stateRef = useRef(state)
  stateRef.current = state

  const selectorTimer = useRef<number | null>(null)
  const tabletTimer = useRef<number | null>(null)

  function suspendTablet() {
    dispatch({ type: "tabletSuspend" })
  }

  function resumeTablet() {
    dispatch({ type: "tabletResume" })
  }

  function closeAll(send = true) {
    dispatch({ type: "close" })
    if (send) post("close")
  }

  function openPlayerSelector(selector: PlayerSelectorPayload) {
    dispatch({ type: "openPlayerSelector", payload: selector })
  }

  function closeTabletModal(send = true) {
    dispatch({ type: "tabletModalClose" })
    if (send) post("tabletModalClose", {})
  }

  function closeTablet(send = true) {
    dispatch({ type: "tabletClose" })
    if (send) post("tabletClose", { reason: "ui" })
  }

  function cancelPlayerSelector(restorePrevious = true) {
    const selector = stateRef.current.panel.selector
    if (!selector) return false
    post("playerSelectorCancel", {
      requestId: selector.requestId,
      restorePrevious,
    })
    return true
  }

  function requestPlayerSelectorPage(page = 1, append = false) {
    const selector = stateRef.current.panel.selector
    if (!selector) return
    dispatch({ type: "selectorSearching" })
    post("playerSelectorSearch", {
      requestId: selector.requestId,
      query: stateRef.current.panel.search,
      filter: selector.filter,
      page,
      append,
    })
  }

  function panelActions(): PanelAction[] {
    const panel = stateRef.current.panel
    if (panel.mode === "selector" && panel.selector) {
      return [
        ...panel.selector.items.map((item) => ({ kind: "player" as const, key: item.key })),
        ...(panel.selector.hasMore ? [{ kind: "more" as const }] : []),
      ]
    }
    return visibleActionEntries(panel.menu, panel.search).map((entry) => ({
      kind: "option" as const,
      entry,
    }))
  }

  function submitPanelSelection() {
    const panel = stateRef.current.panel
    const actions = panelActions()
    const action = actions[panel.focused]
    if (!action) return

    if (action.kind === "option") {
      post("select", {
        id: panel.menu?.id,
        index: action.entry.option.index || action.entry.originalIndex + 1,
      })
      return
    }

    if (action.kind === "player" && panel.selector) {
      post("playerSelectorSelect", {
        requestId: panel.selector.requestId,
        key: action.key,
      })
      return
    }

    if (action.kind === "more") {
      requestPlayerSelectorPage((panel.selector?.page || 1) + 1, true)
    }
  }

  function cancelDialog() {
    const dialog = stateRef.current.dialog
    if (!dialog) return
    if (dialog.kind === "input") {
      post("inputCancel", { requestId: dialog.payload.requestId })
    } else {
      post("alertSubmit", {
        requestId: dialog.payload.requestId,
        result: "cancel",
        cancelled: true,
      })
    }
    dispatch({ type: "dialogClose" })
  }

  function showTooltip(button: HTMLButtonElement) {
    const text = String(button.dataset.label || button.getAttribute("aria-label") || "").trim()
    if (!text) return

    const probe = document.createElement("div")
    probe.className = "mz-tablet__tooltip"
    probe.textContent = text
    probe.style.position = "fixed"
    probe.style.left = "-9999px"
    probe.style.top = "0"
    probe.style.visibility = "hidden"
    document.body.appendChild(probe)
    const tip = probe.getBoundingClientRect()
    probe.remove()

    const anchor = button.getBoundingClientRect()
    const left = Math.min(window.innerWidth - tip.width - 8, anchor.right + 8)
    const top = Math.max(8, Math.min(window.innerHeight - tip.height - 8, anchor.top + (anchor.height - tip.height) / 2))

    const tooltip: TooltipState = {
      text,
      left: Math.max(8, left),
      top,
      anchor: { right: anchor.right, top: anchor.top, height: anchor.height },
    }
    dispatch({ type: "tabletTooltip", tooltip })
  }

  function hideTooltip() {
    dispatch({ type: "tabletTooltip", tooltip: null })
  }

  function handlePanelSearch(query: string) {
    dispatch({ type: "panelSearch", query })
    if (stateRef.current.panel.mode === "selector" && stateRef.current.panel.selector) {
      if (selectorTimer.current) window.clearTimeout(selectorTimer.current)
      selectorTimer.current = window.setTimeout(() => requestPlayerSelectorPage(1, false), 250)
    }
  }

  function handlePanelSelect(option: MenuOption, index: number, _element: HTMLButtonElement) {
    const menu = stateRef.current.panel.menu
    if (!menu) return
    post("select", {
      id: menu.id,
      index: option.index || index + 1,
    })
  }

  function handlePlayerSelect(key: string, _element: HTMLButtonElement) {
    const selector = stateRef.current.panel.selector
    if (!selector) return
    post("playerSelectorSelect", {
      requestId: selector.requestId,
      key,
    })
  }

  function handleMore() {
    const selector = stateRef.current.panel.selector
    if (!selector) return
    requestPlayerSelectorPage(selector.page + 1, true)
  }

  function handleFilter(filter: string) {
    dispatch({ type: "selectorFilter", filter })
    const selector = stateRef.current.panel.selector
    if (!selector) return
    post("playerSelectorSearch", {
      requestId: selector.requestId,
      query: stateRef.current.panel.search,
      filter,
      page: 1,
      append: false,
    })
  }

  function handlePanelBack() {
    const panel = stateRef.current.panel
    if (cancelPlayerSelector(true)) return
    if (panel.menu?.menu) post("back", { id: panel.menu.id })
  }

  function handlePanelClose() {
    if (!cancelPlayerSelector(false)) closeAll(true)
  }

  function handleMovementToggle() {
    const current = stateRef.current
    if (current.movement.toggleEnabled && current.panel.open && !current.dialog) {
      post("toggleMovement")
    }
  }

  function handleTab(tab: string) {
    const currentTab = stateRef.current.tablet.tab
    dispatch({ type: "tabletTab", tab })
    if (tab === currentTab) {
      post("tabletNavigate", { tab: "" })
    } else {
      post("tabletNavigate", { tab })
    }
  }

  function handleCategory(category: string) {
    dispatch({ type: "tabletCategory", category })
    post("tabletNavigate", { category })
  }

  function handleTabletSearch(query: string) {
    dispatch({ type: "tabletSearch", query })
    if (stateRef.current.tablet.context) return
    if (tabletTimer.current) window.clearTimeout(tabletTimer.current)
    tabletTimer.current = window.setTimeout(() => {
      const tablet = stateRef.current.tablet
      post("tabletSearch", {
        category: tablet.category,
        tab: tablet.tab,
        query: stateRef.current.tablet.search,
      })
    }, 250)
  }

  function handleTabletFilter(filter: string) {
    post("tabletFilter", {
      category: stateRef.current.tablet.view?.category,
      filter,
    })
  }

  function handleContextSelect(option: MenuOption, index: number, element: HTMLButtonElement) {
    const context = stateRef.current.tablet.context
    if (!context) return
    postLocked(element, "tabletContextSelect", {
      id: context.id,
      index: option.index || index + 1,
    })
  }

  function handleRowPrimary(row: TabletRow, view: TabletView | null, element: HTMLElement) {
    const action = row.primary?.action
    if (!action) return

    if (view?.tab === "main") {
      postLocked(element, "tabletAction", {
        action,
        args: row.primary?.args,
      })
      return
    }

    if (row.key) {
      postLocked(element, "tabletRowAction", {
        category: view?.category,
        key: row.key,
        action,
        args: row.primary?.args,
      })
      return
    }

    postLocked(element, "tabletAction", {
      action,
      args: row.primary?.args,
    })
  }

  function handleRowButton(row: TabletRow, action: string, args: unknown, element: HTMLElement) {
    postLocked(element, "tabletRowAction", {
      category: stateRef.current.tablet.view?.category,
      key: row.key || "",
      action,
      args,
    })
  }

  function handleModalTab(tab: string) {
    dispatch({ type: "tabletModalTab", tab })
  }

  function handleModalRowPrimary(row: TabletRow, element: HTMLElement) {
    const action = row.primary?.action
    if (!action) return
    postLocked(element, "tabletModalAction", {
      action,
      args: row.primary?.args || {},
    })
  }

  function handleModalRowButton(action: string, args: unknown, element: HTMLElement) {
    postLocked(element, "tabletModalAction", {
      action,
      args: args || {},
    })
  }

  function handleModalClose() {
    closeTabletModal(true)
  }

  function handleTabletClose() {
    closeTablet(true)
  }

  function handleInputSubmit(values: Array<string | number | boolean | null>) {
    const dialog = stateRef.current.dialog
    if (!dialog || dialog.kind !== "input") return
    post("inputSubmit", {
      requestId: dialog.payload.requestId,
      values,
    })
    dispatch({ type: "dialogClose" })
  }

  function handleAlertConfirm() {
    const dialog = stateRef.current.dialog
    if (!dialog || dialog.kind !== "alert") return
    post("alertSubmit", {
      requestId: dialog.payload.requestId,
      result: "confirm",
    })
    dispatch({ type: "dialogClose" })
  }

  function handleInputFocus(focused: boolean) {
    post("tabletInputFocus", { focused })
  }

  // --- Server -> NUI contract ------------------------------------------------
  useEffect(() => {
    function onMessage(event: MessageEvent) {
      const data = event.data as NuiMessage
      if (!data || typeof data !== "object") return
      if (typeof data.locale === "string") dispatch({ type: "locale", locale: data.locale })

      switch (data.action) {
        case "theme":
          dispatch({ type: "theme", theme: data.theme, brand: data.brand })
          break

        case "openContext":
          if (data.menu) {
            if (stateRef.current.tablet.visible) {
              dispatch({ type: "tabletContext", menu: data.menu })
            } else {
              dispatch({ type: "tabletClose" })
              dispatch({ type: "openContext", menu: data.menu })
            }
          }
          break

        case "openTablet":
          if (data.model) dispatch({ type: "openTablet", model: { ...data.model, locale: data.locale ?? data.model.locale } })
          break

        case "tabletView":
          if (data.view) dispatch({ type: "tabletView", view: data.view })
          break

        case "tabletContext":
          if (data.menu) dispatch({ type: "tabletContext", menu: data.menu })
          break

        case "tabletModal":
          dispatch({ type: "tabletModal", modal: data.modal || {} })
          break

        case "tabletModalClose":
          closeTabletModal(false)
          break

        case "tabletClose":
          closeTablet(false)
          break

        case "tabletResume":
          resumeTablet()
          break

        case "openPlayerSelector":
          if (data.selector) {
            suspendTablet()
            openPlayerSelector(data.selector)
          }
          break

        case "playerSelectorResults":
          if (data.requestId && data.result) {
            dispatch({
              type: "playerSelectorResults",
              requestId: data.requestId,
              result: data.result,
              append: data.append === true,
            })
          }
          break

        case "close":
          closeAll(false)
          break

        case "notify":
          if (data.data) dispatch({ type: "notify", data: data.data })
          break

        case "inputDialog":
          dispatch({
            type: "inputDialog",
            payload: {
              requestId: String(data.requestId || ""),
              title: data.title,
              rows: data.rows,
              options: data.options,
            } satisfies InputDialogPayload,
          })
          break

        case "alertDialog":
          dispatch({
            type: "alertDialog",
            payload: {
              requestId: String(data.requestId || ""),
              data: data.data,
            } satisfies AlertDialogPayload,
          })
          break

        case "movementMode":
          dispatch({
            type: "movementMode",
            enabled: data.movementEnabled,
            key: data.key,
            toggleEnabled: data.toggleEnabled,
          })
          break

        default:
          break
      }
    }

    window.addEventListener("message", onMessage)
    return () => window.removeEventListener("message", onMessage)
    // The listener uses refs for current state and stable dispatch.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    post("ready")
  }, [])

  useEffect(() => {
    const root = document.documentElement
    root.style.setProperty("--mz-primary", state.theme.accent)
    root.style.setProperty("--mz-primary-hover", state.theme.accent)
    root.style.setProperty("--mz-accent", state.theme.accent2)
    root.style.setProperty("--mz-panel-width", `${state.theme.width}px`)
    root.style.setProperty("--primary", state.theme.accent)
    root.style.setProperty("--ring", state.theme.accent)
  }, [state.theme])

  useEffect(() => {
    if (state.tablet.model) {
      document.documentElement.lang = String(state.tablet.model.locale || "pt-BR")
    }
  }, [state.tablet.model])

  useEffect(() => {
    function hide() {
      dispatch({ type: "tabletTooltip", tooltip: null })
    }
    window.addEventListener("resize", hide)
    window.addEventListener("scroll", hide, true)
    return () => {
      window.removeEventListener("resize", hide)
      window.removeEventListener("scroll", hide, true)
    }
  }, [])

  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      const current = stateRef.current
      const { panel, tablet, dialog, movement } = current
      const modalOpen = tablet.modal !== null

      // O modal de jogador é a camada superior: ESC fecha o modal e preserva a página.
      if (modalOpen && !dialog) {
        if (event.key === "Escape") {
          event.preventDefault()
          closeTabletModal(true)
          return
        }
        return
      }

      if (tablet.visible && !dialog) {
        if (event.repeat) return
        if (event.key === "Escape") {
          event.preventDefault()
          closeTablet(true)
          return
        }
        if (event.key === "Tab" && tablet.hasTabs) {
          event.preventDefault()
          post("tabletBlockedToggle")
          return
        }
        if (String(event.key || "").toUpperCase() === movement.key) {
          event.preventDefault()
          post("tabletFreeToggle")
          return
        }
      }

      if ((event.ctrlKey || event.metaKey)
        && String(event.key || "").toLowerCase() === "k"
        && panel.open
        && !dialog) {
        const search = document.getElementById("menuSearch") as HTMLInputElement | null
        if (search && !search.closest(".hidden")) {
          event.preventDefault()
          search.focus()
          search.select()
          return
        }
      }

      if (movement.toggleEnabled
        && panel.open
        && !dialog
        && String(event.key || "").toUpperCase() === movement.key) {
        event.preventDefault()
        post("toggleMovement")
        return
      }

      if (panel.open && !dialog) {
        const actions = panelActions()
        const length = actions.length
        if (event.key === "ArrowDown") {
          event.preventDefault()
          dispatch({ type: "panelFocus", index: length ? (panel.focused + 1) % length : 0 })
          return
        }
        if (event.key === "ArrowUp") {
          event.preventDefault()
          dispatch({ type: "panelFocus", index: length ? (panel.focused - 1 + length) % length : 0 })
          return
        }
        if (event.key === "Enter") {
          event.preventDefault()
          submitPanelSelection()
          return
        }
      }

      if (event.key === "Escape") {
        if (dialog) {
          cancelDialog()
          return
        }
        if (cancelPlayerSelector(false)) return
        if (panel.open) closeAll(true)
      }

      if (event.key === "Backspace"
        && panel.open
        && !dialog) {
        const search = document.getElementById("menuSearch") as HTMLInputElement | null
        if (document.activeElement !== search || !search?.value) {
          event.preventDefault()
          if (cancelPlayerSelector(true)) return
          if (panel.menu?.menu) post("back", { id: panel.menu.id })
        }
      }
    }

    document.addEventListener("keydown", onKeyDown)
    return () => document.removeEventListener("keydown", onKeyDown)
    // Reattaching on state changes keeps the keyboard owner identical to the
    // legacy implementation, where handlers always read the current DOM state.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state])

  useEffect(() => {
    return () => {
      if (selectorTimer.current) window.clearTimeout(selectorTimer.current)
      if (tabletTimer.current) window.clearTimeout(tabletTimer.current)
    }
  }, [])

  return {
    state,
    dispatch,
    handlers: {
      onClose: handlePanelClose,
      onBack: handlePanelBack,
      onSearch: handlePanelSearch,
      onSelect: handlePanelSelect,
      onPlayerSelect: handlePlayerSelect,
      onMore: handleMore,
      onFilter: handleFilter,
      onMovementToggle: handleMovementToggle,
      onTab: handleTab,
      onCategory: handleCategory,
      onTabletSearch: handleTabletSearch,
      onTabletFilter: handleTabletFilter,
      onContextSelect: handleContextSelect,
      onRowPrimary: handleRowPrimary,
      onRowButton: handleRowButton,
      onModalTab: handleModalTab,
      onModalRowPrimary: handleModalRowPrimary,
      onModalRowButton: handleModalRowButton,
      onModalClose: handleModalClose,
      onTabletClose: handleTabletClose,
      onShowTooltip: showTooltip,
      onHideTooltip: hideTooltip,
      onDialogCancel: cancelDialog,
      onInputSubmit: handleInputSubmit,
      onAlertConfirm: handleAlertConfirm,
      onInputFocus: handleInputFocus,
      onTabletResume: resumeTablet,
      onTabletSuspend: suspendTablet,
    },
  }
}

export type { PlayerSelectorResult }
