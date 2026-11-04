MZAdminLogs = MZAdminLogs or {}

local MENU_ID = 'mz_admin:logs'
local EVENT = 'mz_admin:client:logsAction'
local PAGE_SIZE = 25
local CurrentParentId = 'mz_admin:root'

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function displayDate(value)
  value = trim(value)
  if value == '' then return (type(locale) == 'function' and locale('bans.s_c1b4b0a9abcf') or 'Data indisponivel') end
  return value:gsub('T', ' '):gsub('Z$', '')
end

local function bind(option, action, args)
  args = type(args) == 'table' and args or {}
  args.action = action
  option.event = EVENT
  option.args = args
  return option
end

local function cloneFilters(filters)
  local result = {}
  for key, value in pairs(type(filters) == 'table' and filters or {}) do
    if type(value) == 'string' or type(value) == 'boolean' then result[key] = value end
  end
  return result
end

local function hasFilters(filters)
  for _, key in ipairs({
    'search', 'category', 'severity', 'action', 'actor', 'auditId', 'dateFrom', 'dateTo'
  }) do
    if trim(filters[key]) ~= '' then return true end
  end
  return filters.auditOnly == true
end

local function requestFilters(current)
  current = type(current) == 'table' and current or {}
  local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('logs.s_22b5d3073dca') or 'Filtrar logs administrativos'), {
    {
      type = 'input',
      label = (type(locale) == 'function' and locale('logs.s_7d609a7328a3') or 'Busca livre'),
      default = current.search or '',
      description = (type(locale) == 'function' and locale('logs.s_b3bed04b1265') or 'Procura em acao, autor, alvo e payload sanitizado.')
    },
    { type = 'input', label = (type(locale) == 'function' and locale('logs.s_41d311ec3da3') or 'Categoria exata'), default = current.category or '' },
    { type = 'input', label = (type(locale) == 'function' and locale('logs.s_181b177708be') or 'Severidade exata'), default = current.severity or '' },
    { type = 'input', label = (type(locale) == 'function' and locale('logs.s_885b7ac23dbf') or 'Acao exata'), default = current.action or '' },
    { type = 'input', label = (type(locale) == 'function' and locale('logs.s_fc09c7700df8') or 'Autor estrutural exato'), default = current.actor or '' },
    { type = 'input', label = (type(locale) == 'function' and locale('logs.s_2c38c11abd51') or 'Data inicial'), default = current.dateFrom or '', placeholder = '2026-07-27 00:00:00' },
    { type = 'input', label = (type(locale) == 'function' and locale('logs.s_a293c7ef42d7') or 'Data final'), default = current.dateTo or '', placeholder = '2026-07-27 23:59:59' },
    { type = 'input', label = (type(locale) == 'function' and locale('logs.s_31f747353da6') or 'Audit ID exato'), default = current.auditId or '' },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('logs.s_ae1d8fc0fe96') or 'Somente eventos com Audit ID'), checked = current.auditOnly == true }
  }, {
    allowCancel = true,
    labels = { confirm = (type(locale) == 'function' and locale('bans.s_4ac3b3110330') or 'Aplicar'), cancel = (type(locale) == 'function' and locale('garage.s_c111e0ab9ddb') or 'Cancelar') }
  })
  if type(values) ~= 'table' then return nil end
  return {
    search = trim(values[1]),
    category = trim(values[2]),
    severity = trim(values[3]),
    action = trim(values[4]),
    actor = trim(values[5]),
    dateFrom = trim(values[6]),
    dateTo = trim(values[7]),
    auditId = trim(values[8]),
    auditOnly = values[9] == true
  }
end

local function itemMetadata(item)
  local metadata = {
    { label = 'ID', value = item.id or '-' },
    { label = (type(locale) == 'function' and locale('logs.s_5966b0ce8b7e') or 'Categoria'), value = item.category or '-' },
    { label = (type(locale) == 'function' and locale('logs.s_62737be6bfeb') or 'Severidade'), value = item.severity or 'info' },
    { label = (type(locale) == 'function' and locale('logs.s_58a82deb057d') or 'Alvo'), value = item.targetName or item.targetCitizenId or '-' },
    { label = 'Audit ID', value = item.auditId or '-' }
  }
  if item.reason then metadata[#metadata + 1] = { label = (type(locale) == 'function' and locale('menu.s_cbeec536b2f8') or 'Motivo'), value = item.reason } end
  if item.message then metadata[#metadata + 1] = { label = (type(locale) == 'function' and locale('logs.s_eaffb6306dc5') or 'Mensagem'), value = item.message } end
  return metadata
end

function MZAdminLogs.Open(filters, offset, parentId)
  parentId = trim(parentId)
  if parentId ~= '' then CurrentParentId = parentId end
  filters = cloneFilters(filters)
  offset = math.max(0, math.floor(tonumber(offset) or 0))
  local request = cloneFilters(filters)
  request.offset = offset

  local data = MZAdminClient.ListAdminLogs(request)
  if not data then return false end

  local options = {
    bind({
      title = (type(locale) == 'function' and locale('logs.s_ef722a671a09') or 'Aplicar filtros'),
      description = hasFilters(filters) and (type(locale) == 'function' and locale('logs.s_5a624bce6468') or 'Filtros ativos.') or (type(locale) == 'function' and locale('logs.s_80ca57006c11') or 'Busca, categoria, acao, autor, periodo e Audit ID.'),
      icon = 'filter'
    }, 'filter', { filters = filters })
  }
  if hasFilters(filters) then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('logs.s_d22f68306a54') or 'Limpar filtros'),
      description = (type(locale) == 'function' and locale('logs.s_e722ab8a5d54') or 'Volta para os eventos globais mais recentes.'),
      icon = 'filter-circle-xmark'
    }, 'clear')
  end

  for _, item in ipairs(data.items or {}) do
    options[#options + 1] = {
      title = tostring(item.action or (type(locale) == 'function' and locale('logs.s_9383be4ba104') or 'Evento')),
      description = ('%s | %s'):format(
        displayDate(item.createdAt),
        tostring(item.actorName or item.actorCitizenId or 'system')
      ),
      icon = item.auditId and 'shield' or 'clipboard-list',
      metadata = itemMetadata(item),
      readOnly = true
    }
  end

  if #(data.items or {}) == 0 then
    options[#options + 1] = {
      title = (type(locale) == 'function' and locale('logs.s_b517935a28d0') or 'Nenhum log encontrado'),
      description = (type(locale) == 'function' and locale('logs.s_ec20d635964c') or 'A consulta global nao retornou eventos para estes filtros.'),
      icon = 'magnifying-glass',
      readOnly = true
    }
  end

  local pagination = data.pagination or {}
  if offset > 0 then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('bans.s_4647a651b2cc') or 'Pagina anterior'),
      icon = 'arrow-left'
    }, 'page', { filters = filters, offset = math.max(0, offset - PAGE_SIZE) })
  end
  if tonumber(pagination.returned) == PAGE_SIZE then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('bans.s_d09ccdb8c4ad') or 'Proxima pagina'),
      icon = 'arrow-right'
    }, 'page', { filters = filters, offset = offset + PAGE_SIZE })
  end

  MZAdminUI.RegisterContext({
    id = MENU_ID,
    menu = CurrentParentId,
    title = (type(locale) == 'function' and locale('menu.s_490f79b27c84') or 'Logs administrativos'),
    subtitle = ((type(locale) == 'function' and locale('logs.s_092425de8ab1') or 'Escopo global | pagina %d')):format(math.floor(offset / PAGE_SIZE) + 1),
    options = options
  })
  return MZAdminUI.ShowContext(MENU_ID)
end

AddEventHandler(EVENT, function(payload)
  local action = type(payload) == 'table' and tostring(payload.action or '') or ''
  if action == 'filter' then
    local filters = requestFilters(payload.filters)
    if filters then MZAdminLogs.Open(filters, 0) end
  elseif action == 'clear' then
    MZAdminLogs.Open({}, 0)
  elseif action == 'page' then
    MZAdminLogs.Open(payload.filters, payload.offset)
  end
end)
