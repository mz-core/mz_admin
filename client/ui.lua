local MZAdminUI = {}

MZAdminUIConfig = MZAdminUIConfig or {
  BrandName = 'MZ Admin',
  DefaultPosition = 'top-left',
  DefaultDuration = 5000,
  Backend = 'nui',
  UseOxFallback = false,
  EnableMovementWhileOpen = true,
  MovementToggleKey = 'F6',
  MovementEnabledByDefault = false,
  EnableFocusToggle = true,
  FocusToggleKey = 'F6',
  Theme = { accent = '#1aa9e8', accent2 = '#65d9ff', position = 'left', width = 420 },
  EnableTestCommand = false,
  ChatPrefix = 'mz_admin'
}

local ContextStore = {}
local PendingRequests = {}
local RequestCounter = 0
local NuiReady = false
local CurrentContextId = nil
local NuiFocused = false
local NuiDialogOpen = false
local TextInputFocused = false
local LastFocusToggleAt = 0
local MovementEnabled = false
local LastMovementToggleAt = 0
local ActivePlayerSelector = nil
local TabletActive = false
local TabletSuspended = false
local TabletCallbacks = nil
local TabletAdminTreeMode = false
local shouldUseOx

local THEME_MIN_WIDTH = 320
local THEME_MAX_WIDTH = 640
local THEME_POSITIONS = {
  left = true,
  right = true,
  center = true
}

local MENU_LAYOUTS = {
  context = true,
  dashboard = true
}

local function sanitizeLayout(value)
  value = tostring(value or 'context'):lower()
  return MENU_LAYOUTS[value] and value or 'context'
end

local function cfg()
  return MZAdminUIConfig or {}
end

local function validFunctionKey(value)
  value = tostring(value or ''):upper()
  local number = tonumber(value:match('^F(%d+)$'))
  if number and number >= 1 and number <= 12 then return value end
  return nil
end

local function movementToggleKey()
  local config = cfg()
  return validFunctionKey(config.MovementToggleKey)
    or validFunctionKey(config.FocusToggleKey)
    or 'F6'
end

local function movementToggleEnabled()
  local config = cfg()
  if config.EnableMovementWhileOpen ~= nil then
    return config.EnableMovementWhileOpen ~= false
  end
  return config.EnableFocusToggle ~= false
end

local function defaultMovementEnabled()
  if not movementToggleEnabled() then return false end
  local configured = (cfg()).MovementEnabledByDefault
  if configured == nil then return false end
  return configured == true
end

local function actualMovementEnabled()
  return NuiFocused
    and (CurrentContextId ~= nil or TabletActive)
    and MovementEnabled
    and not NuiDialogOpen
end

local function applyMovementInput()
  local enabled = actualMovementEnabled()
  if type(SetNuiFocusKeepInput) == 'function' then
    SetNuiFocusKeepInput(enabled and not TextInputFocused)
  end
  SendNUIMessage({
    action = 'movementMode',
    movementEnabled = enabled,
    contextOpen = CurrentContextId ~= nil,
    key = movementToggleKey(),
    toggleEnabled = movementToggleEnabled()
  })
  return enabled
end

local function setFocus(enabled)
  enabled = enabled == true
  NuiFocused = enabled
  SetNuiFocus(enabled, enabled)
  applyMovementInput()
end

function MZAdminUI.SetMovementEnabled(enabled)
  if not movementToggleEnabled() then return false, 'movement_toggle_disabled' end
  if shouldUseOx('context') then return false, 'unsupported_backend' end
  if not CurrentContextId and not TabletActive then return false, 'context_not_open' end
  if NuiDialogOpen then return false, 'dialog_open' end

  MovementEnabled = enabled == true
  if not NuiFocused then
    setFocus(true)
  else
    applyMovementInput()
  end
  return true, MovementEnabled
end

function MZAdminUI.ToggleMovement()
  local now = GetGameTimer()
  if now - LastMovementToggleAt < 150 then return false, 'toggle_debounced' end
  LastMovementToggleAt = now
  return MZAdminUI.SetMovementEnabled(not MovementEnabled)
end

function MZAdminUI.IsMovementEnabled()
  return actualMovementEnabled()
end

local function restoreMovementAfterDialog(previousMovement)
  NuiDialogOpen = false
  MovementEnabled = previousMovement == true
  if CurrentContextId or TabletActive then
    setFocus(true)
  else
    setFocus(false)
  end
end

local function beginNuiDialog()
  local previousMovement = MovementEnabled
  NuiDialogOpen = true
  MovementEnabled = false
  setFocus(true)
  return previousMovement
end

local COMBAT_CONTROLS = {
  24, 25, 37, 44, 45,
  68, 69, 70, 91, 92,
  140, 141, 142, 143,
  257, 263, 264
}

CreateThread(function()
  while true do
    if actualMovementEnabled() then
      for _, control in ipairs(COMBAT_CONTROLS) do
        DisableControlAction(0, control, true)
      end
      Wait(0)
    else
      Wait(250)
    end
  end
end)

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function debugPrint(...)
  if (cfg()).Debug == true then
    print('[mz_admin_ui][debug]', ...)
  end
end

local function oxReady()
  return type(lib) == 'table'
end

local function contextReady()
  return oxReady()
    and type(lib.registerContext) == 'function'
    and type(lib.showContext) == 'function'
end

local function inputReady()
  return oxReady() and type(lib.inputDialog) == 'function'
end

local function alertReady()
  return oxReady() and type(lib.alertDialog) == 'function'
end

local function notifyReady()
  return oxReady() and type(lib.notify) == 'function'
end

local function nuiReady()
  return true -- ui_page é local; SendNUIMessage é seguro mesmo antes do callback ready.
end

shouldUseOx = function(kind)
  local backend = tostring((cfg()).Backend or 'nui')

  if backend == 'ox_lib' then
    if kind == 'context' then return contextReady() end
    if kind == 'input' then return inputReady() end
    if kind == 'alert' then return alertReady() end
    if kind == 'notify' then return notifyReady() end
    return oxReady()
  end

  if backend == 'auto' then
    return false -- NUI própria é prioridade. ox_lib só será usado se uma chamada NUI for desativada no futuro.
  end

  return false
end

local function chat(message, color)
  TriggerEvent('chat:addMessage', {
    color = color or { 120, 190, 255 },
    args = { tostring((cfg()).ChatPrefix or 'mz_admin_ui'), tostring(message or '') }
  })
end

function MZAdminUI.SetContextFocus(enabled)
  if (cfg()).EnableFocusToggle == false then return false, 'focus_toggle_disabled' end
  if shouldUseOx('context') then return false, 'unsupported_backend' end
  if not CurrentContextId then return false, 'context_not_open' end
  if NuiDialogOpen then return false, 'dialog_open' end

  enabled = enabled == true
  if NuiFocused == enabled then return true, enabled end
  setFocus(enabled)
  return true, enabled
end

function MZAdminUI.ToggleContextFocus()
  local now = GetGameTimer()
  if now - LastFocusToggleAt < 150 then return false, 'toggle_debounced' end
  LastFocusToggleAt = now
  return MZAdminUI.SetContextFocus(not NuiFocused)
end

function MZAdminUI.IsContextFocused()
  return CurrentContextId ~= nil and NuiFocused == true
end

local function nextRequestId(prefix)
  RequestCounter = RequestCounter + 1
  return ('%s_%s_%s'):format(prefix or 'req', GetGameTimer(), RequestCounter)
end

local function awaitNui(requestId)
  local p = promise.new()
  PendingRequests[requestId] = p
  return Citizen.Await(p)
end

local function resolveRequest(requestId, result)
  requestId = trim(requestId)
  local p = PendingRequests[requestId]
  if not p then
    return false
  end

  PendingRequests[requestId] = nil
  p:resolve(result)
  return true
end

local function sanitizeSelectorText(value, maximum)
  value = tostring(value or ''):gsub('%c', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  return value:sub(1, maximum or 128)
end

local function sanitizeSelectorItem(item, index)
  if type(item) ~= 'table' then return nil end
  local source = tonumber(item.source)
  if source then source = math.floor(source) end
  local citizenid = sanitizeSelectorText(item.citizenid, 64)
  local accountId = tonumber(item.accountId or item.account_id)
  local characterId = tonumber(item.characterId or item.character_id)
  local key = sanitizeSelectorText(item.key, 128)
  if key == '' then
    key = source and ('source:%d:%s'):format(source, citizenid)
      or (citizenid ~= '' and ('character:%s'):format(citizenid) or ('item:%d'):format(index))
  end

  return {
    key = key,
    source = source,
    citizenid = citizenid ~= '' and citizenid or nil,
    accountId = accountId and math.floor(accountId) or nil,
    characterId = characterId and math.floor(characterId) or nil,
    name = sanitizeSelectorText(item.name, 96),
    characterName = sanitizeSelectorText(item.characterName or item.character_name, 128),
    online = item.online == true and source ~= nil,
    self = item.self == true,
    ping = math.max(0, math.floor(tonumber(item.ping) or 0))
  }
end

local function sanitizeSelectorResult(result, page, pageSize)
  result = type(result) == 'table' and result or {}
  local items = {}
  for index, item in ipairs(type(result.items) == 'table' and result.items or {}) do
    local sanitized = sanitizeSelectorItem(item, index)
    if sanitized then items[#items + 1] = sanitized end
  end
  return {
    items = items,
    page = math.max(1, math.floor(tonumber(result.page) or page or 1)),
    pageSize = math.max(1, math.min(50, math.floor(tonumber(result.pageSize) or pageSize or 25))),
    total = math.max(0, math.floor(tonumber(result.total) or #items)),
    hasMore = result.hasMore == true,
    hint = sanitizeSelectorText(result.hint, 160)
  }
end

local function selectorDisplayResult(result)
  local items = {}
  for _, item in ipairs(result.items) do
    items[#items + 1] = {
      key = item.key,
      source = item.online and item.source or nil,
      name = item.name,
      characterName = item.characterName,
      online = item.online,
      self = item.self,
      ping = item.ping
    }
  end
  return {
    items = items,
    page = result.page,
    pageSize = result.pageSize,
    total = result.total,
    hasMore = result.hasMore,
    hint = result.hint
  }
end

local function loadPlayerSelectorPage(query, filter, page, append)
  local selector = ActivePlayerSelector
  if not selector then return end
  selector.generation = selector.generation + 1
  local generation = selector.generation

  CreateThread(function()
    local ok, result = pcall(selector.fetch, query, filter, page, selector.pageSize)
    if ActivePlayerSelector ~= selector or selector.generation ~= generation then return end
    if not ok then
      debugPrint('player selector fetch falhou:', result)
      result = { items = {}, page = page, pageSize = selector.pageSize, hint = (type(locale) == 'function' and locale('ui_text.s_125047d4c27c') or 'Falha ao buscar jogadores.') }
    end

    local normalized = sanitizeSelectorResult(result, page, selector.pageSize)
    if append ~= true then selector.items = {} end
    for _, item in ipairs(normalized.items) do selector.items[item.key] = item end
    SendNUIMessage({
      action = 'playerSelectorResults',
      requestId = selector.requestId,
      result = selectorDisplayResult(normalized),
      append = append == true
    })
  end)
end

local function resumeTablet()
  if not TabletActive or not TabletSuspended then return false end
  TabletSuspended = false
  TextInputFocused = false
  SendNUIMessage({ action = 'tabletResume' })
  setFocus(true)
  return true
end

local function finishPlayerSelector(selected, restorePrevious)
  local selector = ActivePlayerSelector
  if not selector then return false, false end
  ActivePlayerSelector = nil
  NuiDialogOpen = selector.previousDialog == true
  MovementEnabled = selector.previousMovement == true
  SendNUIMessage({ action = 'close' })
  setFocus(false)

  -- O seletor usa a superficie legada (contextPanel). Se ele foi aberto a
  -- partir do tablet, o tablet foi apenas suspenso no NUI; retoma-lo aqui
  -- evita ficar com TabletActive=true e DOM oculto (foco fantasma).
  local resumedTablet = false
  if selector.previousTablet == true and TabletActive then
    resumedTablet = resumeTablet()
  end

  selector.promise:resolve(selected)
  if not resumedTablet and restorePrevious == true and selector.previousContextId then
    SetTimeout(0, function()
      if not ActivePlayerSelector and CurrentContextId == selector.previousContextId then
        MZAdminUI.ShowContext(selector.previousContextId)
      end
    end)
  end
  return true, resumedTablet
end

local function notifyPayload(messageOrData, kind, duration, extra)
  local data

  if type(messageOrData) == 'table' then
    data = messageOrData
  else
    data = type(extra) == 'table' and extra or {}
    data.description = data.description or tostring(messageOrData or '')
    data.type = data.type or kind or 'inform'
    data.duration = data.duration or duration or (cfg()).DefaultDuration or 5000
  end

  if data.type == 'info' then
    data.type = 'inform'
  end

  data.title = data.title or (cfg()).BrandName or 'MZ Admin'
  data.position = data.position or (cfg()).DefaultPosition or 'top-right'
  data.duration = tonumber(data.duration) or (cfg()).DefaultDuration or 5000

  return data
end

local function validHexColor(value)
  return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

local function sanitizeThemePatch(theme)
  if type(theme) ~= 'table' then return nil end

  local sanitized = {}
  if validHexColor(theme.accent) then sanitized.accent = theme.accent end
  if validHexColor(theme.accent2) then sanitized.accent2 = theme.accent2 end

  local position = type(theme.position) == 'string' and theme.position:lower() or nil
  if position and THEME_POSITIONS[position] then sanitized.position = position end

  local width = tonumber(theme.width)
  if width then
    sanitized.width = math.floor(math.max(THEME_MIN_WIDTH, math.min(THEME_MAX_WIDTH, width)))
  end

  return next(sanitized) and sanitized or nil
end

local function mergeTheme(base, patch)
  local merged = {}
  for key, value in pairs(type(base) == 'table' and base or {}) do merged[key] = value end
  for key, value in pairs(type(patch) == 'table' and patch or {}) do merged[key] = value end
  return merged
end

local function globalTheme()
  return mergeTheme({
    accent = '#009FE3',
    accent2 = '#67C9F1',
    position = 'left',
    width = 380
  }, sanitizeThemePatch((cfg()).Theme))
end

local function resolveContextVisual(id)
  local chain, seen = {}, {}
  local currentId = trim(id)

  while currentId ~= '' and not seen[currentId] and #chain < 32 do
    seen[currentId] = true
    local context = ContextStore[currentId]
    if not context then break end
    table.insert(chain, 1, context)
    currentId = trim(context.menu)
  end

  local theme = globalTheme()
  local brand = (cfg()).BrandName or 'MZ Admin'
  local headerIcon, badge
  for _, context in ipairs(chain) do
    theme = mergeTheme(theme, context.theme)
    if trim(context.brand) ~= '' then brand = tostring(context.brand) end
    if trim(context.headerIcon) ~= '' then headerIcon = tostring(context.headerIcon) end
    if trim(context.badge) ~= '' then badge = tostring(context.badge) end
  end

  return theme, brand, headerIcon, badge
end

local function sendTheme(theme, brand)
  SendNUIMessage({
    action = 'theme',
    locale = Config.Locale or 'pt-br',
    theme = theme or globalTheme(),
    brand = brand or (cfg()).BrandName or 'MZ Admin'
  })
end

local function sendCurrentTheme()
  if CurrentContextId then
    local theme, brand = resolveContextVisual(CurrentContextId)
    sendTheme(theme, brand)
    return
  end
  sendTheme()
end

function MZAdminUI.Notify(messageOrData, kind, duration, extra)
  local data = notifyPayload(messageOrData, kind, duration, extra)

  if shouldUseOx('notify') then
    lib.notify(data)
    return true, 'ox_lib'
  end

  if nuiReady() then
    sendCurrentTheme()
    SendNUIMessage({ action = 'notify', locale = Config.Locale or 'pt-br', data = data })
    return true, 'nui'
  end

  chat(data.description or data.title or 'Notificacao', data.type == 'error' and { 255, 100, 100 } or nil)
  return false, 'chat_fallback'
end

local function executeOption(option)
  option = type(option) == 'table' and option or {}
  local args = option.args

  if option.disabled == true or option.readOnly == true then
    return
  end

  if type(option.onSelect) == 'function' then
    option.onSelect(args, option)
    return
  end

  if trim(option.menu) ~= '' then
    if TabletAdminTreeMode then
      MZAdminUI.ShowTabletContext(option.menu)
    else
      MZAdminUI.ShowContext(option.menu)
    end
    return
  end

  if trim(option.event) ~= '' then
    TriggerEvent(option.event, args, option)
    return
  end

  if trim(option.serverEvent) ~= '' then
    TriggerServerEvent(option.serverEvent, args, option)
    return
  end

  if trim(option.command) ~= '' then
    ExecuteCommand(option.command)
    return
  end

  if type(option.params) == 'table' then
    local params = option.params
    if trim(params.event) ~= '' then
      if params.isServer == true or params.type == 'server' then
        TriggerServerEvent(params.event, params.args, option)
      elseif params.type == 'command' then
        ExecuteCommand(params.event)
      else
        TriggerEvent(params.event, params.args, option)
      end
      return
    end
  end
end

local function executeLifecycle(context, callbackName)
  context = type(context) == 'table' and context or {}
  local callback = context[callbackName]
  if type(callback) == 'function' then
    callback()
    return true
  end

  local eventName = trim(context[callbackName .. 'Event'])
  if eventName ~= '' then
    TriggerEvent(eventName, context[callbackName .. 'Args'], context)
    return true
  end

  return false
end

local function uiOption(option, index)
  option = type(option) == 'table' and option or {}
  local optionType = tostring(option.type or 'action'):lower()
  if optionType ~= 'section' then optionType = 'action' end

  return {
    index = index,
    type = optionType,
    label = option.label,
    title = tostring(option.title or option.label or (type(locale) == 'function' and locale('ui_text.s_b4c5aec54c6b') or 'Opcao')),
    description = option.description,
    icon = option.icon,
    iconColor = option.iconColor,
    image = option.image,
    disabled = option.disabled == true,
    readOnly = option.readOnly == true or optionType == 'section',
    metadata = option.metadata,
    progress = option.progress,
    colorScheme = option.colorScheme,
    arrow = option.arrow,
    menu = option.menu,
    values = option.values,
    checked = option.checked,
    close = option.close,
    iconAnimation = option.iconAnimation,
    badge = option.badge,
    badgeVariant = option.badgeVariant,
    status = option.status,
    statusVariant = option.statusVariant,
    shortcut = option.shortcut,
    destructive = option.destructive == true,
    tone = option.tone
  }
end

local function oxOption(option)
  option = type(option) == 'table' and option or {}

  local normalized = {}
  local passthrough = {
    'title', 'description', 'icon', 'iconColor', 'image', 'disabled', 'readOnly',
    'metadata', 'progress', 'colorScheme', 'arrow', 'menu', 'event', 'serverEvent',
    'args', 'values', 'checked', 'close', 'iconAnimation'
  }

  for _, key in ipairs(passthrough) do
    if option[key] ~= nil then
      normalized[key] = option[key]
    end
  end

  normalized.title = tostring(normalized.title or (type(locale) == 'function' and locale('ui_text.s_b4c5aec54c6b') or 'Opcao'))

  if type(option.onSelect) == 'function'
    or trim(option.event) ~= ''
    or trim(option.serverEvent) ~= ''
    or trim(option.command) ~= ''
    or type(option.params) == 'table'
    or trim(option.menu) ~= ''
  then
    normalized.onSelect = function()
      executeOption(option)
    end
  elseif type(option.onSelect) ~= 'nil' then
    debugPrint('onSelect ignorado: tipo invalido em', normalized.title)
  end

  return normalized
end

local function normalizeMenu(menu)
  menu = type(menu) == 'table' and menu or {}

  local id = trim(menu.id)
  if id == '' then
    id = ('mz_admin_ui_%s'):format(GetGameTimer())
  end

  local stored = {
    id = id,
    title = tostring(menu.title or menu.header or 'Menu'),
    subtitle = menu.subtitle or menu.description or menu.brand,
    brand = menu.brand,
    headerIcon = menu.headerIcon,
    badge = menu.badge,
    layout = sanitizeLayout(menu.layout),
    searchable = menu.searchable == true,
    searchPlaceholder = menu.searchPlaceholder,
    user = type(menu.user) == 'table' and menu.user or nil,
    stats = type(menu.stats) == 'table' and menu.stats or nil,
    theme = sanitizeThemePatch(menu.theme),
    menu = menu.menu,
    canClose = menu.canClose,
    onExit = menu.onExit,
    onBack = menu.onBack,
    onExitEvent = menu.onExitEvent,
    onExitArgs = menu.onExitArgs,
    onBackEvent = menu.onBackEvent,
    onBackArgs = menu.onBackArgs,
    options = {}
  }

  local ui = {
    id = stored.id,
    title = stored.title,
    subtitle = stored.subtitle,
    brand = stored.brand,
    headerIcon = stored.headerIcon,
    badge = stored.badge,
    layout = stored.layout,
    searchable = stored.searchable,
    searchPlaceholder = stored.searchPlaceholder,
    user = stored.user,
    stats = stored.stats,
    menu = stored.menu,
    canClose = stored.canClose ~= false,
    options = {}
  }

  local ox = {
    id = stored.id,
    title = stored.title,
    subtitle = stored.subtitle,
    menu = stored.menu,
    canClose = stored.canClose,
    onExit = (type(stored.onExit) == 'function' or trim(stored.onExitEvent) ~= '') and function()
      executeLifecycle(stored, 'onExit')
    end or nil,
    onBack = (type(stored.onBack) == 'function' or trim(stored.onBackEvent) ~= '') and function()
      executeLifecycle(stored, 'onBack')
    end or nil,
    options = {}
  }

  if type(menu.options) == 'table' then
    for index, option in ipairs(menu.options) do
      stored.options[index] = option
      ui.options[#ui.options + 1] = uiOption(option, index)
      ox.options[#ox.options + 1] = oxOption(option)
    end
  end

  return stored, ui, ox
end

function MZAdminUI.RegisterContext(menu)
  local stored, ui, ox = normalizeMenu(menu)
  ContextStore[stored.id] = stored

  if shouldUseOx('context') then
    lib.registerContext(ox)
    return true, stored.id, 'ox_lib'
  end

  return true, stored.id, 'nui'
end

function MZAdminUI.ShowContext(id)
  id = trim(id)
  if id == '' then
    return false, 'invalid_context_id'
  end

  -- Enquanto o tablet esta ativo, TODO contexto administrativo e renderizado
  -- dentro dele. Fechar o tablet aqui abria a superficie legada (contextPanel)
  -- por cima/Depois da NUI nova e deixava o MZAdminRouter com estado divergente.
  if TabletActive then
    return MZAdminUI.ShowTabletContext(id)
  end

  local stored = ContextStore[id]
  if not stored then
    return false, 'context_not_registered'
  end

  if shouldUseOx('context') then
    if not contextReady() then
      MZAdminUI.Notify((type(locale) == 'function' and locale('ui_text.s_e9afffca9025') or 'ox_lib context indisponivel. Use os comandos como fallback.'), 'error')
      return false, 'ox_lib_context_unavailable'
    end

    CurrentContextId = id
    lib.showContext(id)
    return true, 'ox_lib'
  end

  local _, ui = normalizeMenu(stored)
  local contextAlreadyOpen = CurrentContextId ~= nil
  CurrentContextId = id
  if not contextAlreadyOpen then
    MovementEnabled = defaultMovementEnabled()
  end
  local theme, brand, inheritedHeaderIcon, inheritedBadge = resolveContextVisual(id)
  ui.brand = ui.brand or brand
  ui.headerIcon = ui.headerIcon or inheritedHeaderIcon
  ui.badge = ui.badge or inheritedBadge
  sendTheme(theme, brand)
  SendNUIMessage({ action = 'openContext', locale = Config.Locale or 'pt-br', menu = ui })
  setFocus(true)
  return true, 'nui'
end

function MZAdminUI.OpenContext(menu)
  local ok, idOrErr = MZAdminUI.RegisterContext(menu)
  if not ok then
    return false, idOrErr
  end

  return MZAdminUI.ShowContext(idOrErr)
end

function MZAdminUI.OpenMenu(menu)
  return MZAdminUI.OpenContext(menu)
end

function MZAdminUI.RegisterSimpleMenu(id, title, options, parent)
  return MZAdminUI.RegisterContext({
    id = id,
    title = title,
    menu = parent,
    options = options or {}
  })
end

function MZAdminUI.CloseContext()
  if ActivePlayerSelector then finishPlayerSelector(nil, false) end

  -- Em modo de arvore administrativa inline (aba ADMIN), fechar o contexto
  -- nao derruba o tablet: apenas libera o contexto atual e o foco NUI para
  -- interacao com o mundo (posicionamento de garagem) ou menu delegado.
  -- A reabertura (ShowContext/ShowTabletContext) restaura o foco.
  if TabletActive then
    CurrentContextId = nil
    if TabletAdminTreeMode then
      setFocus(false)
    end
    return true
  end

  if shouldUseOx('context') and oxReady() and type(lib.hideContext) == 'function' then
    lib.hideContext(true)
  end

  CurrentContextId = nil
  MovementEnabled = false
  SendNUIMessage({ action = 'close' })
  sendTheme()
  setFocus(false)
  return true
end

local function nuiInputDialog(title, rows, options)
  local requestId = nextRequestId('input')
  local previousMovement = beginNuiDialog()
  sendCurrentTheme()
  SendNUIMessage({
    action = 'inputDialog',
    locale = Config.Locale or 'pt-br',
    requestId = requestId,
    title = tostring(title or (type(locale) == 'function' and locale('ui_text.s_b568d47f2e24') or 'Entrada')),
    rows = type(rows) == 'table' and rows or {},
    options = type(options) == 'table' and options or {}
  })
  local response = awaitNui(requestId)
  restoreMovementAfterDialog(previousMovement)

  if not response or response.cancelled then
    return nil
  end

  return response.values
end

function MZAdminUI.InputDialog(title, rows, options)
  if shouldUseOx('input') then
    title = tostring(title or (type(locale) == 'function' and locale('ui_text.s_b568d47f2e24') or 'Entrada'))
    rows = type(rows) == 'table' and rows or {}
    options = type(options) == 'table' and options or {}

    local ok, result = pcall(function()
      return lib.inputDialog(title, rows, options)
    end)

    if not ok then
      MZAdminUI.Notify(((type(locale) == 'function' and locale('ui_text.s_50d3661439d5') or 'Falha no inputDialog: %s')):format(tostring(result)), 'error')
      return nil, tostring(result)
    end

    return result
  end

  return nuiInputDialog(title, rows, options)
end

local function normalizeAlert(dataOrTitle, content, options)
  local data
  if type(dataOrTitle) == 'table' then
    data = dataOrTitle
  else
    data = type(options) == 'table' and options or {}
    data.header = data.header or tostring(dataOrTitle or 'Alerta')
    data.content = data.content or tostring(content or '')
  end

  if data.centered == nil then
    data.centered = true
  end

  return data
end

local function nuiAlertDialog(data)
  local requestId = nextRequestId('alert')
  local previousMovement = beginNuiDialog()
  sendCurrentTheme()
  SendNUIMessage({
    action = 'alertDialog',
    locale = Config.Locale or 'pt-br',
    requestId = requestId,
    data = data
  })
  local response = awaitNui(requestId)
  restoreMovementAfterDialog(previousMovement)

  if not response or response.cancelled then
    return 'cancel'
  end

  return response.result or 'confirm'
end

function MZAdminUI.AlertDialog(dataOrTitle, content, options)
  local data = normalizeAlert(dataOrTitle, content, options)

  if shouldUseOx('alert') then
    local ok, result = pcall(function()
      return lib.alertDialog(data)
    end)

    if not ok then
      MZAdminUI.Notify(((type(locale) == 'function' and locale('ui_text.s_9f18f1c5d504') or 'Falha no alertDialog: %s')):format(tostring(result)), 'error')
      return nil, tostring(result)
    end

    return result
  end

  return nuiAlertDialog(data)
end

function MZAdminUI.Confirm(title, content, options)
  options = type(options) == 'table' and options or {}
  options.header = options.header or tostring(title or 'Confirmar')
  options.content = options.content or tostring(content or (type(locale) == 'function' and locale('ui_text.s_ea94920ee209') or 'Confirmar acao?'))
  options.centered = options.centered ~= false
  options.cancel = options.cancel ~= false

  local result = MZAdminUI.AlertDialog(options)
  return result == 'confirm'
end

function MZAdminUI.PlayerSelector(options)
  options = type(options) == 'table' and options or {}
  if not nuiReady() then return nil, 'nui_unavailable' end
  if ActivePlayerSelector then return nil, 'selector_busy' end

  local fetch = options.fetch
  local providerExport = sanitizeSelectorText(options.provider, 64)
  if providerExport ~= '' then
    local invokingResource = type(GetInvokingResource) == 'function' and GetInvokingResource() or nil
    if type(invokingResource) ~= 'string' or invokingResource == ''
      or not providerExport:match('^[%w:_-]+$') then
      return nil, 'invalid_provider'
    end

    fetch = function(query, filter, page, pageSize)
      if GetResourceState(invokingResource) ~= 'started' then
        error('player_selector_provider_unavailable')
      end
      local provider = exports[invokingResource]
      return provider[providerExport](provider, query, filter, page, pageSize)
    end
  end
  if type(fetch) ~= 'function' then return nil, 'fetch_required' end

  local requestId = nextRequestId('player_selector')
  local pending = promise.new()
  local filters = type(options.filters) == 'table' and options.filters or { 'all', 'online', 'offline' }
  local allowedFilters = {}
  local allowedFilterSet = {}
  for _, value in ipairs(filters) do
    value = tostring(value or ''):lower()
    if (value == 'all' or value == 'online' or value == 'offline') and not allowedFilterSet[value] then
      allowedFilters[#allowedFilters + 1] = value
      allowedFilterSet[value] = true
    end
  end
  if #allowedFilters == 0 then
    allowedFilters = { 'all', 'online', 'offline' }
    allowedFilterSet = { all = true, online = true, offline = true }
  end
  local defaultFilter = tostring(options.defaultFilter or allowedFilters[1]):lower()
  if not allowedFilterSet[defaultFilter] then defaultFilter = allowedFilters[1] end

  ActivePlayerSelector = {
    requestId = requestId,
    promise = pending,
    fetch = fetch,
    pageSize = math.max(1, math.min(50, math.floor(tonumber(options.pageSize) or 25))),
    allowedFilters = allowedFilterSet,
    defaultFilter = defaultFilter,
    previousContextId = CurrentContextId,
    previousTablet = TabletActive == true,
    previousMovement = MovementEnabled == true,
    previousDialog = NuiDialogOpen == true,
    generation = 0,
    items = {}
  }
  TextInputFocused = false
  NuiDialogOpen = true
  MovementEnabled = false
  TabletSuspended = TabletActive == true

  if shouldUseOx('context') and oxReady() and type(lib.hideContext) == 'function' then
    lib.hideContext(false)
  end

  sendCurrentTheme()
  SendNUIMessage({
    action = 'openPlayerSelector',
    locale = Config.Locale or 'pt-br',
    selector = {
      requestId = requestId,
      title = sanitizeSelectorText(options.title or (type(locale) == 'function' and locale('ui.select_player') or 'Selecionar jogador'), 96),
      subtitle = sanitizeSelectorText(options.subtitle or (type(locale) == 'function' and locale('ui_text.s_fc5f059b6e2d') or 'Online agora; pesquise para localizar Characters offline.'), 160),
      brand = sanitizeSelectorText(options.brand or (cfg()).BrandName or 'MZ Admin', 64),
      filters = allowedFilters,
      defaultFilter = defaultFilter,
      searchPlaceholder = sanitizeSelectorText(options.searchPlaceholder or (type(locale) == 'function' and locale('ui_text.s_0c7f3df22cc8') or 'Nome, Character, citizenid ou source...'), 128),
      minimumOfflineSearch = math.max(1, math.min(8, math.floor(tonumber(options.minimumOfflineSearch) or 2)))
    }
  })
  setFocus(true)
  loadPlayerSelectorPage('', defaultFilter, 1, false)

  return Citizen.Await(pending)
end

function MZAdminUI.IsReady()
  if tostring((cfg()).Backend or 'nui') == 'ox_lib' then
    return contextReady() and inputReady() and alertReady()
  end

  return nuiReady()
end

function MZAdminUI.GetBackend()
  local backend = tostring((cfg()).Backend or 'nui')
  if backend == 'ox_lib' and contextReady() and inputReady() and alertReady() then
    return 'ox_lib'
  end
  if backend == 'ox_lib' then
    return 'fallback'
  end
  return 'nui'
end

-- ---------------------------------------------------------------------------
-- Tablet administrativo: apresentacao generica de painel (sidebar + dados).
-- O conteudo e a autoridade vivem no consumidor (mz_admin); aqui so existe a
-- camada de renderizacao e o despacho de callbacks tipados.
-- ---------------------------------------------------------------------------

local function sanitizeTabletText(value, maximum)
  value = tostring(value or ''):gsub('%c', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  return value:sub(1, maximum or 96)
end

local function sanitizeTabletModel(model)
  model = type(model) == 'table' and model or {}
  local categories = {}
  local seen = {}
  for _, category in ipairs(type(model.categories) == 'table' and model.categories or {}) do
    if type(category) == 'table' then
      local id = sanitizeTabletText(category.id, 32)
      if id ~= '' and not seen[id] then
        seen[id] = true
        categories[#categories + 1] = {
          id = id,
          label = sanitizeTabletText(category.label, 48),
          icon = sanitizeTabletText(category.icon, 48)
        }
      end
    end
  end

  local tabs = {}
  local seenTabs = {}
  for _, tab in ipairs(type(model.tabs) == 'table' and model.tabs or {}) do
    if type(tab) == 'table' then
      local id = sanitizeTabletText(tab.id, 32)
      if id ~= '' and not seenTabs[id] then
        seenTabs[id] = true
        tabs[#tabs + 1] = {
          id = id,
          label = sanitizeTabletText(tab.label, 48),
          icon = sanitizeTabletText(tab.icon, 48)
        }
      end
    end
  end

  local user = type(model.user) == 'table' and model.user or {}
  return {
    title = sanitizeTabletText(model.title, 48),
    brand = sanitizeTabletText(model.brand, 48),
    locale = sanitizeTabletText(model.locale, 16),
    user = {
      name = sanitizeTabletText(user.name, 96),
      role = sanitizeTabletText(user.role, 48),
      owner = user.owner == true
    },
    categories = categories,
    tabs = tabs
  }
end

local function sanitizeTabletRow(raw)
  if type(raw) ~= 'table' then return nil end
  local buttons = {}
  for _, rawBtn in ipairs(type(raw.buttons) == 'table' and raw.buttons or {}) do
    if type(rawBtn) == 'table' then
      buttons[#buttons + 1] = {
        action = sanitizeTabletText(rawBtn.action, 48),
        label = sanitizeTabletText(rawBtn.label, 48),
        icon = sanitizeTabletText(rawBtn.icon, 48),
        tone = sanitizeTabletText(rawBtn.tone, 16),
        args = rawBtn.args and type(rawBtn.args) == 'table' and rawBtn.args or nil
      }
    end
  end

  local status = type(raw.status) == 'table' and raw.status or nil
  local primary = type(raw.primary) == 'table' and raw.primary or nil
  local primaryAction = primary and sanitizeTabletText(primary.action, 48) or nil

  return {
    key = sanitizeTabletText(raw.key, 128),
    icon = sanitizeTabletText(raw.icon, 48),
    title = sanitizeTabletText(raw.title, 96),
    subtitle = sanitizeTabletText(raw.subtitle, 160),
    status = status and {
      label = sanitizeTabletText(status.label, 32),
      variant = sanitizeTabletText(status.variant, 16)
    } or nil,
    selected = raw.selected == true,
    tone = sanitizeTabletText(raw.tone, 16),
    primary = (primaryAction and primaryAction ~= '') and {
      action = primaryAction,
      args = primary and type(primary.args) == 'table' and primary.args or nil
    } or nil,
    buttons = buttons
  }
end

local function sanitizeTabletRows(rawRows)
  local rows = {}
  for _, raw in ipairs(type(rawRows) == 'table' and rawRows or {}) do
    local sanitized = sanitizeTabletRow(raw)
    if sanitized then rows[#rows + 1] = sanitized end
  end
  return rows
end

local function sanitizeTabletView(view)
  view = type(view) == 'table' and view or {}
  local filters = {}
  local seenFilters = {}
  for _, filter in ipairs(type(view.filters) == 'table' and view.filters or {}) do
    if type(filter) == 'table' then
      local id = sanitizeTabletText(filter.id, 32)
      if id ~= '' and not seenFilters[id] then
        seenFilters[id] = true
        filters[#filters + 1] = {
          id = id,
          label = sanitizeTabletText(filter.label, 32)
        }
      end
    end
  end

  return {
    tab = sanitizeTabletText(view.tab, 32),
    category = sanitizeTabletText(view.category, 32),
    title = sanitizeTabletText(view.title, 64),
    subtitle = sanitizeTabletText(view.subtitle, 160),
    searchable = view.searchable == true,
    query = sanitizeTabletText(view.query, 64),
    workspace = view.workspace == true,
    layout = sanitizeTabletText(view.layout, 16),
    filters = filters,
    activeFilter = sanitizeTabletText(view.activeFilter, 32),
    rows = sanitizeTabletRows(view.rows),
    empty = sanitizeTabletText(view.empty, 160),
    loading = view.loading == true,
    error = sanitizeTabletText(view.error, 160)
  }
end

local function sanitizeTabletModal(modal)
  modal = type(modal) == 'table' and modal or {}
  local tabs = {}
  local seenTabs = {}
  for _, tab in ipairs(type(modal.tabs) == 'table' and modal.tabs or {}) do
    if type(tab) == 'table' then
      local id = sanitizeTabletText(tab.id, 32)
      if id ~= '' and not seenTabs[id] then
        seenTabs[id] = true
        tabs[#tabs + 1] = { id = id, label = sanitizeTabletText(tab.label, 32), icon = sanitizeTabletText(tab.icon, 32) }
      end
    end
  end

  local content = {}
  local rawContent = type(modal.content) == 'table' and modal.content or {}
  for tabId, tabContent in pairs(rawContent) do
    if type(tabContent) == 'table' then
      content[tostring(tabId):gsub('%c', ''):sub(1, 32)] = {
        rows = sanitizeTabletRows(tabContent.rows),
        empty = sanitizeTabletText(tabContent.empty, 160)
      }
    end
  end

  return {
    title = sanitizeTabletText(modal.title, 96),
    subtitle = sanitizeTabletText(modal.subtitle, 160),
    tabs = tabs,
    content = content
  }
end

function MZAdminUI.SetTabletCallbacks(callbacks)
  if type(callbacks) ~= 'table' then
    TabletCallbacks = nil
    return false
  end
  TabletCallbacks = callbacks
  return true
end

function MZAdminUI.OpenTablet(model, movementEnabled)
  if shouldUseOx('context') and contextReady() then return false, 'unsupported_backend' end

  if ActivePlayerSelector then finishPlayerSelector(nil, false) end
  if CurrentContextId then
    MZAdminUI.CloseContext()
  end

  TabletAdminTreeMode = false
  TabletActive = true
  TabletSuspended = false
  TextInputFocused = false
  MovementEnabled = movementToggleEnabled() and movementEnabled == true
  NuiFocused = false
  SendNUIMessage({ action = 'openTablet', locale = Config.Locale or 'pt-br', model = sanitizeTabletModel(model) })
  setFocus(true)
  return true
end

function MZAdminUI.SetTabletView(view)
  if not TabletActive then return false, 'tablet_not_open' end
  SendNUIMessage({ action = 'tabletView', view = sanitizeTabletView(view) })
  return true
end

-- Habilita/desabilita o modo de arvore de contexto administrativa inline
-- (aba ADMIN). Enquanto ativo, ShowContext/executeOption renderizam dentro
-- do tablet em vez de abrir o painel de contexto separado.
function MZAdminUI.SetTabletAdminTreeMode(enabled)
  if not TabletActive then return false, 'tablet_not_open' end
  TabletAdminTreeMode = enabled == true
  return true
end

function MZAdminUI.ShowTabletContext(id)
  id = trim(id)
  if id == '' then return false, 'invalid_context_id' end
  local stored = ContextStore[id]
  if not stored then return false, 'context_not_registered' end
  local _, ui = normalizeMenu(stored)
  CurrentContextId = id
  local theme, brand, inheritedHeaderIcon, inheritedBadge = resolveContextVisual(id)
  ui.brand = ui.brand or brand
  ui.headerIcon = ui.headerIcon or inheritedHeaderIcon
  ui.badge = ui.badge or inheritedBadge
  SendNUIMessage({ action = 'tabletContext', locale = Config.Locale or 'pt-br', menu = ui })
  if TabletActive then setFocus(true) end
  return true, 'nui'
end

function MZAdminUI.SetTabletContext(id)
  return MZAdminUI.ShowTabletContext(id)
end

function MZAdminUI.SetTabletModal(modal)
  if not TabletActive then return false, 'tablet_not_open' end
  SendNUIMessage({ action = 'tabletModal', locale = Config.Locale or 'pt-br', modal = sanitizeTabletModal(modal) })
  return true
end

function MZAdminUI.CloseTabletModal()
  if not TabletActive then return false, 'tablet_not_open' end
  SendNUIMessage({ action = 'tabletModalClose' })
  return true
end

function MZAdminUI.CloseTablet(sendToNui)
  if not TabletActive then return false, 'tablet_not_open' end
  TabletActive = false
  TabletSuspended = false
  TabletAdminTreeMode = false
  CurrentContextId = nil
  TextInputFocused = false
  MovementEnabled = false
  TabletCallbacks = nil
  if ActivePlayerSelector then
    -- Encerra o seletor antes de destruir o tablet para nao deixar promessa
    -- pendente nem foco orfao se a permissao for revogada no meio da selecao.
    finishPlayerSelector(nil, false)
  end
  if sendToNui ~= false then
    SendNUIMessage({ action = 'tabletClose' })
  end
  setFocus(false)
  return true
end

function MZAdminUI.IsTabletOpen()
  return TabletActive == true
end

exports('Notify', MZAdminUI.Notify)
exports('OpenContext', MZAdminUI.OpenContext)
exports('OpenMenu', MZAdminUI.OpenMenu)
exports('RegisterContext', MZAdminUI.RegisterContext)
exports('RegisterSimpleMenu', MZAdminUI.RegisterSimpleMenu)
exports('ShowContext', MZAdminUI.ShowContext)
exports('CloseContext', MZAdminUI.CloseContext)
exports('CloseMenu', MZAdminUI.CloseContext)
exports('HideContext', MZAdminUI.CloseContext)
exports('InputDialog', MZAdminUI.InputDialog)
exports('AlertDialog', MZAdminUI.AlertDialog)
exports('Confirm', MZAdminUI.Confirm)
exports('PlayerSelector', MZAdminUI.PlayerSelector)
exports('IsReady', MZAdminUI.IsReady)
exports('GetBackend', MZAdminUI.GetBackend)
exports('SetContextFocus', MZAdminUI.SetContextFocus)
exports('ToggleContextFocus', MZAdminUI.ToggleContextFocus)
exports('IsContextFocused', MZAdminUI.IsContextFocused)
exports('SetMovementEnabled', MZAdminUI.SetMovementEnabled)
exports('ToggleMovement', MZAdminUI.ToggleMovement)
exports('IsMovementEnabled', MZAdminUI.IsMovementEnabled)
exports('OpenTablet', MZAdminUI.OpenTablet)
exports('SetTabletView', MZAdminUI.SetTabletView)
exports('SetTabletAdminTreeMode', MZAdminUI.SetTabletAdminTreeMode)
exports('ShowTabletContext', MZAdminUI.ShowTabletContext)
exports('SetTabletContext', MZAdminUI.SetTabletContext)
exports('SetTabletModal', MZAdminUI.SetTabletModal)
exports('CloseTabletModal', MZAdminUI.CloseTabletModal)
exports('CloseTablet', MZAdminUI.CloseTablet)
exports('IsTabletOpen', MZAdminUI.IsTabletOpen)
exports('SetTabletCallbacks', MZAdminUI.SetTabletCallbacks)

RegisterNetEvent('mz_admin_ui:client:notify', function(messageOrData, kind, duration, extra)
  MZAdminUI.Notify(messageOrData, kind, duration, extra)
end)

RegisterNetEvent('mz_admin_ui:client:openContext', function(menu)
  MZAdminUI.OpenContext(menu)
end)

RegisterNetEvent('mz_admin_ui:client:alert', function(dataOrTitle, content, options)
  MZAdminUI.AlertDialog(dataOrTitle, content, options)
end)

RegisterNetEvent('mz_admin_ui:client:close', function()
  MZAdminUI.CloseContext()
end)

RegisterNUICallback('ready', function(_, cb)
  NuiReady = true
  sendTheme()
  cb({ ok = true })
end)

RegisterNUICallback('toggleFocus', function(_, cb)
  local ok, stateOrError = MZAdminUI.ToggleContextFocus()
  cb({
    ok = ok == true,
    focused = ok == true and stateOrError or NuiFocused,
    error = ok == true and nil or stateOrError
  })
end)

RegisterNUICallback('toggleMovement', function(_, cb)
  local ok, stateOrError = MZAdminUI.ToggleMovement()
  cb({
    ok = ok == true,
    movementEnabled = ok == true and stateOrError or actualMovementEnabled(),
    error = ok == true and nil or stateOrError
  })
end)

RegisterNUICallback('select', function(data, cb)
  cb({ ok = true })

  local id = trim(data and data.id)
  local index = tonumber(data and data.index)
  local context = ContextStore[id]
  if not context or not index or not context.options[index] then
    return
  end

  executeOption(context.options[index])
end)

RegisterNUICallback('playerSelectorSearch', function(data, cb)
  local selector = ActivePlayerSelector
  if not selector or tostring(data and data.requestId or '') ~= selector.requestId then
    cb({ ok = false, error = 'selector_not_active' })
    return
  end
  local query = sanitizeSelectorText(data and data.query, 64)
  local filter = tostring(data and data.filter or 'all'):lower()
  if not selector.allowedFilters[filter] then filter = selector.defaultFilter end
  local page = math.max(1, math.floor(tonumber(data and data.page) or 1))
  cb({ ok = true })
  loadPlayerSelectorPage(query, filter, page, data and data.append == true)
end)

RegisterNUICallback('playerSelectorSelect', function(data, cb)
  local selector = ActivePlayerSelector
  if not selector or tostring(data and data.requestId or '') ~= selector.requestId then
    cb({ ok = false, error = 'selector_not_active' })
    return
  end
  local key = sanitizeSelectorText(data and data.key, 128)
  local selected = selector.items[key]
  if not selected then
    cb({ ok = false, error = 'invalid_selection' })
    return
  end
  cb({ ok = true })
  finishPlayerSelector(selected, false)
end)

RegisterNUICallback('playerSelectorCancel', function(data, cb)
  local selector = ActivePlayerSelector
  if not selector or tostring(data and data.requestId or '') ~= selector.requestId then
    cb({ ok = false, error = 'selector_not_active' })
    return
  end
  cb({ ok = true })
  local restorePrevious = data and data.restorePrevious ~= false
  local _, resumedTablet = finishPlayerSelector(nil, restorePrevious)
  if not restorePrevious and not resumedTablet then
    CurrentContextId = nil
    MovementEnabled = false
    sendTheme()
  end
end)

RegisterNUICallback('back', function(data, cb)
  cb({ ok = true })

  local id = trim(data and data.id)
  local context = ContextStore[id]

  if context and executeLifecycle(context, 'onBack') then
    return
  end

  if context and trim(context.menu) ~= '' then
    MZAdminUI.ShowContext(context.menu)
    return
  end
end)

RegisterNUICallback('close', function(_, cb)
  cb({ ok = true })

  if ActivePlayerSelector then
    finishPlayerSelector(nil, true)
    return
  end

  local context = CurrentContextId and ContextStore[CurrentContextId]
  CurrentContextId = nil
  MovementEnabled = false
  setFocus(false)
  sendTheme()

  if context then executeLifecycle(context, 'onExit') end
end)

RegisterNUICallback('inputSubmit', function(data, cb)
  cb({ ok = true })
  resolveRequest(data and data.requestId, { values = data and data.values or {}, keepFocus = CurrentContextId ~= nil })
end)

RegisterNUICallback('inputCancel', function(data, cb)
  cb({ ok = true })
  resolveRequest(data and data.requestId, { cancelled = true, keepFocus = CurrentContextId ~= nil })
end)

RegisterNUICallback('alertSubmit', function(data, cb)
  cb({ ok = true })
  resolveRequest(data and data.requestId, { result = data and data.result or 'confirm', keepFocus = CurrentContextId ~= nil })
end)

RegisterNUICallback('tabletNavigate', function(data, cb)
  cb({ ok = true })
  local callbacks = TabletCallbacks
  if callbacks and callbacks.onNavigate then
    callbacks.onNavigate(data and (data.tab or data.category))
  end
end)

RegisterNUICallback('tabletAction', function(data, cb)
  cb({ ok = true })
  local callbacks = TabletCallbacks
  if callbacks and callbacks.onAction then
    callbacks.onAction(data and data.action, data and data.args)
  end
end)

RegisterNUICallback('tabletRowAction', function(data, cb)
  cb({ ok = true })
  local callbacks = TabletCallbacks
  if callbacks and callbacks.onRowAction then
    callbacks.onRowAction(
      data and (data.tab or data.category),
      data and data.key,
      data and data.action,
      data and data.args
    )
  end
end)

RegisterNUICallback('tabletSearch', function(data, cb)
  cb({ ok = true })
  local callbacks = TabletCallbacks
  if callbacks and callbacks.onSearch then
    callbacks.onSearch(data and (data.tab or data.category), data and data.query)
  end
end)

RegisterNUICallback('tabletFilter', function(data, cb)
  cb({ ok = true })
  local callbacks = TabletCallbacks
  if callbacks and callbacks.onFilter then
    callbacks.onFilter(data and (data.tab or data.category), data and data.filter)
  end
end)

RegisterNUICallback('tabletContextSelect', function(data, cb)
  cb({ ok = true })
  local id = trim(data and data.id)
  local index = tonumber(data and data.index)
  local context = ContextStore[id]
  if not context or not index or not context.options[index] then return end
  executeOption(context.options[index])
end)

RegisterNUICallback('tabletContextBack', function(data, cb)
  cb({ ok = true })
  local id = trim(data and data.id)
  local context = ContextStore[id]
  if not context then return end
  if executeLifecycle(context, 'onBack') then return end
  if trim(context.menu) ~= '' then
    MZAdminUI.ShowTabletContext(context.menu)
  end
end)

RegisterNUICallback('tabletModalAction', function(data, cb)
  cb({ ok = true })
  local callbacks = TabletCallbacks
  if callbacks and callbacks.onModalAction then
    callbacks.onModalAction(data and data.action, data and data.args)
  end
end)

RegisterNUICallback('tabletModalClose', function(data, cb)
  cb({ ok = true })
  local callbacks = TabletCallbacks
  if callbacks and callbacks.onModalClose then
    callbacks.onModalClose()
  end
end)

RegisterNUICallback('tabletInputFocus', function(data, cb)
  TextInputFocused = data and data.focused == true or false
  applyMovementInput()
  cb({ ok = true })
end)

RegisterNUICallback('tabletFreeToggle', function(_, cb)
  local ok = MZAdminRouter and type(MZAdminRouter.Toggle) == 'function'
    and MZAdminRouter.Toggle('free') == true
  cb({ ok = ok })
end)

RegisterNUICallback('tabletBlockedToggle', function(_, cb)
  local ok = MZAdminRouter and type(MZAdminRouter.Toggle) == 'function'
    and MZAdminRouter.Toggle('blocked') == true
  cb({ ok = ok })
end)

RegisterNUICallback('tabletClose', function(data, cb)
  cb({ ok = true })
  local callbacks = TabletCallbacks
  if callbacks and callbacks.onClose then
    callbacks.onClose(data and data.reason)
  end
  TabletActive = false
  TabletSuspended = false
  TabletAdminTreeMode = false
  CurrentContextId = nil
  TextInputFocused = false
  MovementEnabled = false
  TabletCallbacks = nil
  setFocus(false)
end)

RegisterCommand('mz_admin_ui_focus_toggle', function()
  MZAdminUI.ToggleMovement()
end, false)

RegisterCommand('mz_admin_ui_movement_toggle', function()
  -- Enquanto o tablet esta aberto e focado, F6 e tratado EXCLUSIVAMENTE pelo
  -- keydown da NUI (tabletFreeToggle). Sem foco (ex.: posicionamento no mundo),
  -- o atalho recupera o foco em vez de ficar inerte.
  if TabletActive then
    if NuiFocused then return end
    MZAdminUI.SetMovementEnabled(true)
    return
  end
  if CurrentContextId == nil then
    if MZAdminRouter and type(MZAdminRouter.Toggle) == 'function' then
      MZAdminRouter.Toggle('free')
    end
    return
  end
  if NuiFocused then return end
  MZAdminUI.ToggleMovement()
end, false)

RegisterKeyMapping(
  'mz_admin_ui_movement_toggle',
  (type(locale) == 'function' and locale('ui_text.s_aa2fe1051430') or 'Abrir/fechar o painel administrativo com movimento livre'),
  'keyboard',
  movementToggleKey()
)

CreateThread(function()
  Wait(750)
  sendTheme()
  debugPrint(('backend=%s ready=%s nuiReady=%s'):format(MZAdminUI.GetBackend(), tostring(MZAdminUI.IsReady()), tostring(NuiReady)))
end)

_G.MZAdminUI = MZAdminUI

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  TabletActive = false
  TabletSuspended = false
  if ActivePlayerSelector then finishPlayerSelector(nil, false) end
  CurrentContextId = nil
  NuiDialogOpen = false
  TextInputFocused = false
  MovementEnabled = false
  TabletCallbacks = nil
  setFocus(false)
end)


