import { useEffect, useState } from "react"
import type { Toast } from "@/lib/types"

function ToastItem({ toast, onRemove }: { toast: Toast; onRemove: (id: number) => void }) {
  const [leaving, setLeaving] = useState(false)

  useEffect(() => {
    const leave = window.setTimeout(() => setLeaving(true), toast.duration)
    const remove = window.setTimeout(() => onRemove(toast.id), toast.duration + 180)
    return () => {
      window.clearTimeout(leave)
      window.clearTimeout(remove)
    }
  }, [toast.duration, toast.id, onRemove])

  return (
    <div
      className={`toast ${toast.type}`}
      style={leaving ? { opacity: 0, transform: "translateX(16px)" } : undefined}
    >
      <div className="toast__title">{toast.title}</div>
      <div className="toast__desc">{toast.description}</div>
    </div>
  )
}

export function ToastStack({ toasts, onRemove }: { toasts: Toast[]; onRemove: (id: number) => void }) {
  return (
    <div id="toasts" className="mz-toasts" aria-live="polite">
      {toasts.map((toast) => (
        <ToastItem key={toast.id} toast={toast} onRemove={onRemove} />
      ))}
    </div>
  )
}
