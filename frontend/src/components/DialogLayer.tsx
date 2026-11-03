import { useEffect, useRef } from "react"
import { Icon } from "@/components/Icon"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import type { AlertDialogData, DialogState, InputRow, Variant } from "@/lib/types"

type DialogLayerProps = {
  dialog: DialogState | null
  onCancel: () => void
  onInputSubmit: (values: Array<string | number | boolean | null>) => void
  onAlertConfirm: () => void
}

function getAlertVariant(data: AlertDialogData): Variant {
  const rawType = String(data.type || data.severity || "").toLowerCase()
  const rawColor = String(data.confirmColor || data.color || "").toLowerCase()
  const title = String(data.header || data.title || "").toLowerCase()
  const content = String(data.content || data.description || "").toLowerCase()
  const text = `${title} ${content}`

  const isDanger = data.destructive === true
    || rawType === "error"
    || rawType === "danger"
    || rawColor === "red"
    || rawColor === "danger"
    || text.includes("arquivar")
    || text.includes("excluir")
    || text.includes("deletar")
    || text.includes("remover")

  if (isDanger) return "danger"
  if (rawType === "warning" || rawType === "warn" || rawColor === "yellow" || rawColor === "orange") return "warning"
  if (rawType === "success" || rawColor === "green") return "success"
  return "info"
}

function renderInputRow(row: InputRow, index: number, first: boolean) {
  const type = row.type || "input"
  const label = row.label || row.name || `Campo ${index + 1}`
  const name = `field_${index}`
  const placeholder = row.placeholder || ""
  const value = row.default ?? row.value ?? ""
  const description = row.description

  if (type === "checkbox") {
    const checked = row.checked === true || row.default === true
    return (
      <div className="field" key={index}>
        <div className="field--checkbox">
          <input id={name} name={name} type="checkbox" defaultChecked={checked} autoFocus={first} />
          <label htmlFor={name}>{label}</label>
        </div>
        {description ? <span className="field__description">{description}</span> : null}
      </div>
    )
  }

  if (type === "textarea") {
    return (
      <div className="field" key={index}>
        <label htmlFor={name}>{label}</label>
        <textarea
          id={name}
          name={name}
          placeholder={placeholder}
          required={row.required === true}
          defaultValue={String(value)}
          autoFocus={first}
        />
        {description ? <span className="field__description">{description}</span> : null}
      </div>
    )
  }

  if (type === "select") {
    const options = Array.isArray(row.options) ? row.options : []
    return (
      <div className="field" key={index}>
        <label htmlFor={name}>{label}</label>
        <select id={name} name={name} required={row.required === true} defaultValue={String(value)} autoFocus={first}>
          {options.map((option, optionIndex) => {
            const optionValue = typeof option === "object" ? option.value : option
            const optionLabel = typeof option === "object" ? option.label || option.value : option
            return (
              <option value={String(optionValue)} key={optionIndex}>
                {optionLabel}
              </option>
            )
          })}
        </select>
        {description ? <span className="field__description">{description}</span> : null}
      </div>
    )
  }

  const htmlType = type === "number"
    ? "number"
    : type === "color"
      ? "color"
      : type === "date"
        ? "date"
        : type === "time"
          ? "time"
          : "text"

  return (
    <div className="field" key={index}>
      <label htmlFor={name}>{label}</label>
      <Input
        id={name}
        name={name}
        type={htmlType}
        defaultValue={String(value)}
        placeholder={placeholder}
        required={row.required === true}
        autoFocus={first}
      />
      {description ? <span className="field__description">{description}</span> : null}
    </div>
  )
}

export function DialogLayer({ dialog, onCancel, onInputSubmit, onAlertConfirm }: DialogLayerProps) {
  const dialogRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!dialog || dialog.kind !== "input") return
    const first = dialogRef.current?.querySelector("input, textarea, select") as HTMLElement | null
    first?.focus()
  }, [dialog])

  if (!dialog) {
    return (
      <section id="dialogOverlay" className="mz-dialogOverlay hidden">
        <div id="dialog" className="mz-dialog" role="dialog" aria-modal="true" />
      </section>
    )
  }

  if (dialog.kind === "input") {
    const payload = dialog.payload
    const rows = Array.isArray(payload.rows) ? payload.rows : []
    const options = payload.options || {}
    const labels = options.labels || {}
    const confirmLabel = labels.confirm || options.confirmLabel || "Confirmar"
    const cancelLabel = labels.cancel || options.cancelLabel || "Cancelar"

    return (
      <section id="dialogOverlay" className="mz-dialogOverlay">
        <div id="dialog" className="mz-dialog" role="dialog" aria-modal="true" ref={dialogRef}>
          <div className="dialog__header">
            <h2 className="dialog__title">{payload.title || "Input"}</h2>
            <button className="mz-icon-btn" type="button" title="Fechar" aria-label="Fechar" onClick={onCancel}>
              <Icon name="x" />
            </button>
          </div>
          <form
            id="inputForm"
            className="form"
            onSubmit={(event) => {
              event.preventDefault()
              const values = rows.map((row, index) => {
                const element = dialogRef.current?.querySelector<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>(
                  `[name="field_${index}"]`
                )
                if (!element) return null
                if ((row.type || "input") === "checkbox") return (element as HTMLInputElement).checked
                if ((row.type || "input") === "number") {
                  return element.value === "" ? null : Number(element.value)
                }
                return element.value
              })
              onInputSubmit(values)
            }}
          >
            <div className="dialog__body">
              {rows.map((row, index) => renderInputRow(row, index, index === 0))}
            </div>
            <div className="dialog__actions">
              <Button className="btn" type="button" variant="ghost" onClick={onCancel}>{cancelLabel}</Button>
              <Button className="btn btn--primary" type="submit" variant="ghost">{confirmLabel}</Button>
            </div>
          </form>
        </div>
      </section>
    )
  }

  const data = dialog.payload.data || {}
  const hasCancel = data.cancel !== false
  const variant = getAlertVariant(data)
  const confirmClass = variant === "danger" ? "btn btn--danger" : "btn btn--primary"
  const iconName = variant === "danger" || variant === "warning" ? "warning" : "info"
  const labels = data.labels || {}
  const confirmLabel = labels.confirm || data.confirmLabel || data.confirm || data.confirmText || "Confirmar"
  const cancelLabel = labels.cancel || data.cancelLabel || data.cancelText || "Cancelar"

  return (
    <section id="dialogOverlay" className="mz-dialogOverlay">
      <div id="dialog" className="mz-dialog" role="dialog" aria-modal="true" ref={dialogRef}>
        <div className="dialog__body dialog__confirmContent">
          <span className={`dialog__warnIcon is-${variant}`}><Icon name={iconName} /></span>
          <div>
            <h2 className="dialog__title">{data.header || data.title || "Alerta"}</h2>
            <p className="dialog__message">{data.content || data.description || ""}</p>
          </div>
        </div>
        <div className="dialog__actions">
          {hasCancel ? (
            <Button className="btn" type="button" variant="ghost" onClick={onCancel}>{cancelLabel}</Button>
          ) : null}
          <Button className={confirmClass} type="button" variant="ghost" onClick={onAlertConfirm}>{confirmLabel}</Button>
        </div>
      </div>
    </section>
  )
}
