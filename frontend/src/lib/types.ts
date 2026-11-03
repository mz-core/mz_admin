export type Variant = "neutral" | "info" | "success" | "warning" | "danger"

export type Theme = {
  accent: string
  accent2: string
  position: "left" | "right" | "center"
  width: number
}

export type MovementState = {
  enabled: boolean
  key: string
  toggleEnabled: boolean
}

export type MetadataValue =
  | string
  | number
  | null
  | undefined
  | { label?: string; value?: string | number }

export type MenuOption = {
  index?: number
  type?: "action" | "section" | string
  label?: string
  title?: string
  description?: string
  icon?: string
  iconColor?: string
  disabled?: boolean
  readOnly?: boolean
  metadata?: MetadataValue[] | Record<string, string | number>
  progress?: number
  arrow?: boolean
  menu?: string
  checked?: boolean
  badge?: string
  badgeVariant?: Variant
  status?: string
  statusVariant?: Variant
  shortcut?: string
  destructive?: boolean
  tone?: string
}

export type ContextUser = {
  name?: string
  subtitle?: string
  role?: string
  variant?: Variant
}

export type ContextStat = {
  label?: string
  value?: string | number
  variant?: Variant
}

export type ContextMenu = {
  id: string
  title?: string
  subtitle?: string
  brand?: string
  headerIcon?: string
  badge?: string
  layout?: "context" | "dashboard" | string
  searchable?: boolean
  searchPlaceholder?: string
  user?: ContextUser
  stats?: ContextStat[]
  menu?: string
  canClose?: boolean
  options?: MenuOption[]
}

export type PlayerSelectorItem = {
  key: string
  source?: number
  name?: string
  characterName?: string
  online?: boolean
  self?: boolean
}

export type PlayerSelectorResult = {
  items?: PlayerSelectorItem[]
  page?: number
  total?: number
  hasMore?: boolean
  hint?: string
}

export type PlayerSelectorPayload = {
  requestId: string
  title?: string
  subtitle?: string
  brand?: string
  filters?: string[]
  defaultFilter?: string
  searchPlaceholder?: string
}

export type PlayerSelectorView = PlayerSelectorPayload & {
  filter: string
  filters: string[]
  items: PlayerSelectorItem[]
  page: number
  total: number
  hasMore: boolean
  hint: string
  summary: string
  loading: boolean
}

export type TabletTab = {
  id: string
  label?: string
  icon?: string
}

export type TabletModel = {
  title?: string
  brand?: string
  locale?: string
  user?: {
    name?: string
    role?: string
    owner?: boolean
  }
  categories?: TabletTab[]
  tabs?: TabletTab[]
}

export type TabletRowStatus = {
  label?: string
  variant?: Variant
}

export type TabletRowPrimary = {
  action?: string
  args?: unknown
}

export type TabletRowButton = {
  action?: string
  label?: string
  icon?: string
  tone?: string
  args?: unknown
}

export type TabletRow = {
  key?: string
  icon?: string
  title?: string
  subtitle?: string
  status?: TabletRowStatus
  selected?: boolean
  tone?: string
  primary?: TabletRowPrimary
  buttons?: TabletRowButton[]
}

export type TabletFilter = {
  id: string
  label?: string
}

export type TabletView = {
  tab?: string
  category?: string
  title?: string
  subtitle?: string
  searchable?: boolean
  query?: string
  workspace?: boolean
  layout?: string
  filters?: TabletFilter[]
  activeFilter?: string
  rows?: TabletRow[]
  empty?: string
  loading?: boolean
  error?: string
}

export type TabletModal = {
  title?: string
  subtitle?: string
  tabs?: TabletTab[]
  content?: Record<string, { rows?: TabletRow[]; empty?: string }>
}

export type InputRow = {
  type?: string
  label?: string
  name?: string
  placeholder?: string
  required?: boolean
  default?: string | number | boolean
  value?: string | number
  checked?: boolean
  description?: string
  options?: Array<string | { value: string | number; label?: string }>
}

export type InputDialogPayload = {
  requestId: string
  title?: string
  rows?: InputRow[]
  options?: {
    labels?: { confirm?: string; cancel?: string }
    confirmLabel?: string
    cancelLabel?: string
  }
}

export type AlertDialogData = {
  type?: string
  severity?: string
  confirmColor?: string
  color?: string
  header?: string
  title?: string
  content?: string
  description?: string
  cancel?: boolean
  destructive?: boolean
  labels?: { confirm?: string; cancel?: string }
  confirmLabel?: string
  cancelLabel?: string
  confirm?: string
  confirmText?: string
  cancelText?: string
}

export type AlertDialogPayload = {
  requestId: string
  data?: AlertDialogData
}

export type NotifyPayload = {
  type?: string
  title?: string
  description?: string
  message?: string
  duration?: number
}

export type Toast = {
  id: number
  type: string
  title: string
  description: string
  duration: number
}

export type TooltipState = {
  text: string
  left: number
  top: number
  anchor: { right: number; top: number; height: number }
}

export type PanelState = {
  open: boolean
  mode: "context" | "selector"
  menu: ContextMenu | null
  selector: PlayerSelectorView | null
  focused: number
  search: string
}

export type TabletState = {
  visible: boolean
  model: TabletModel | null
  hasTabs: boolean
  tab: string | null
  category: string | null
  expanded: boolean
  workspace: boolean
  isHome: boolean
  view: TabletView | null
  context: ContextMenu | null
  modal: TabletModal | null
  modalTab: string | null
  search: string
  searchScope: string | null
  tooltip: TooltipState | null
}

export type DialogState =
  | { kind: "input"; payload: InputDialogPayload }
  | { kind: "alert"; payload: AlertDialogPayload }

export type AppState = {
  theme: Theme
  brand: string
  movement: MovementState
  panel: PanelState
  tablet: TabletState
  dialog: DialogState | null
  toasts: Toast[]
}

export type NuiMessage = {
  action?: string
  theme?: Partial<Theme>
  brand?: string
  menu?: ContextMenu
  model?: TabletModel
  view?: TabletView
  modal?: TabletModal
  selector?: PlayerSelectorPayload
  result?: PlayerSelectorResult
  requestId?: string
  append?: boolean
  movementEnabled?: boolean
  key?: string
  toggleEnabled?: boolean
  data?: NotifyPayload & AlertDialogData
  rows?: InputRow[]
  options?: InputDialogPayload["options"]
  title?: string
}
