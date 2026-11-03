import { useCallback } from "react"
import { ContextPanel } from "@/components/ContextPanel"
import { DialogLayer } from "@/components/DialogLayer"
import { TabletSurface } from "@/components/TabletSurface"
import { ToastStack } from "@/components/ToastStack"
import { useAdminNui } from "@/hooks/useAdminNui"

export default function App() {
  const { state, dispatch, handlers } = useAdminNui()
  const removeToast = useCallback((id: number) => {
    dispatch({ type: "toastRemove", id })
  }, [dispatch])

  return (
    <div id="app" className={`app app--${state.theme.position}`}>
      <ContextPanel
        state={state}
        onClose={handlers.onClose}
        onBack={handlers.onBack}
        onSearch={handlers.onSearch}
        onSelect={handlers.onSelect}
        onPlayerSelect={handlers.onPlayerSelect}
        onMore={handlers.onMore}
        onFilter={handlers.onFilter}
        onMovementToggle={handlers.onMovementToggle}
      />

      <DialogLayer
        dialog={state.dialog}
        onCancel={handlers.onDialogCancel}
        onInputSubmit={handlers.onInputSubmit}
        onAlertConfirm={handlers.onAlertConfirm}
      />

      <ToastStack toasts={state.toasts} onRemove={removeToast} />

      <TabletSurface
        state={state}
        onTab={handlers.onTab}
        onCategory={handlers.onCategory}
        onBack={handlers.onBack}
        onSearch={handlers.onTabletSearch}
        onFilter={handlers.onTabletFilter}
        onContextSelect={handlers.onContextSelect}
        onRowPrimary={handlers.onRowPrimary}
        onRowButton={handlers.onRowButton}
        onModalTab={handlers.onModalTab}
        onModalRowPrimary={handlers.onModalRowPrimary}
        onModalRowButton={handlers.onModalRowButton}
        onModalClose={handlers.onModalClose}
        onShowTooltip={handlers.onShowTooltip}
        onHideTooltip={handlers.onHideTooltip}
        onInputFocus={handlers.onInputFocus}
      />
    </div>
  )
}
