MZAdminWhitelist = MZAdminWhitelist or {}

local ROOT_ID = 'mz_admin:whitelist'
local ACTION_EVENT = 'mz_admin:client:whitelistAction'
local canManage = false

local STATUS_LABELS = {
  pending = 'Pendentes',
  approved = 'Aprovadas',
  rejected = 'Recusadas',
  revoked = 'Revogadas'
}

local function notify(message, kind)
  MZAdminUI.Notify({
    title = 'Whitelist',
    description = tostring(message or ''),
    type = kind or 'inform'
  })
end

local function request(callbackName, ...)
  local ok, result = pcall(lib.callback.await, callbackName, false, ...)
  if not ok or type(result) ~= 'table' then return nil, 'callback_failed' end
  if result.ok ~= true then return nil, result.error or 'request_failed' end
  return result.data
end

local function binding(action, payload)
  local args = { action = action }
  for key, value in pairs(type(payload) == 'table' and payload or {}) do
    args[key] = value
  end
  return {
    event = ACTION_EVENT,
    args = args
  }
end

local function withBinding(option, action, payload)
  local event = binding(action, payload)
  option.event = event.event
  option.args = event.args
  return option
end

local function formatUnixUtc(value)
  local timestamp = tonumber(value)
  if not timestamp or timestamp <= 0 then return 'Nao disponibilizado' end
  timestamp = math.floor(timestamp >= 100000000000 and timestamp / 1000 or timestamp)
  local days = math.floor(timestamp / 86400)
  local secondsOfDay = timestamp - (days * 86400)
  local hour = math.floor(secondsOfDay / 3600)
  local minute = math.floor((secondsOfDay % 3600) / 60)
  local z = days + 719468
  local era = math.floor((z >= 0 and z or z - 146096) / 146097)
  local dayOfEra = z - (era * 146097)
  local yearOfEra = math.floor((dayOfEra - math.floor(dayOfEra / 1460)
    + math.floor(dayOfEra / 36524) - math.floor(dayOfEra / 146096)) / 365)
  local year = yearOfEra + (era * 400)
  local dayOfYear = dayOfEra - ((365 * yearOfEra) + math.floor(yearOfEra / 4)
    - math.floor(yearOfEra / 100))
  local monthPosition = math.floor(((5 * dayOfYear) + 2) / 153)
  local day = dayOfYear - math.floor(((153 * monthPosition) + 2) / 5) + 1
  local month = monthPosition + (monthPosition < 10 and 3 or -9)
  year = year + (month <= 2 and 1 or 0)
  return ('%02d/%02d/%04d %02d:%02d'):format(day, month, year, hour, minute)
end

local function decide(entry, action, listState)
  if not canManage then
    notify('Voce nao possui permissao para alterar a whitelist.', 'error')
    return
  end
  local labels = {
    approve = 'Aprovar whitelist',
    reject = 'Recusar whitelist',
    revoke = 'Revogar whitelist'
  }
  local values = MZAdminUI.InputDialog(labels[action] or 'Alterar whitelist', {
    {
      type = 'textarea',
      label = 'Motivo',
      required = true,
      min = 3,
      max = 256
    }
  }, {
    allowCancel = true,
    labels = { confirm = 'Confirmar', cancel = 'Cancelar' }
  })
  local reason = type(values) == 'table' and tostring(values[1] or '') or ''
  reason = reason:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if #reason < 3 then return end

  local data, err = request(
    'mz_admin:server:decideWhitelist',
    entry.publicId,
    action,
    reason
  )
  if not data then
    notify('Acao negada: ' .. tostring(err), 'error')
    return
  end
  notify('Whitelist atualizada: ' .. tostring(data.entry and data.entry.status or action), 'success')
  TriggerEvent(ACTION_EVENT, {
    action = 'openStatus',
    status = listState.status,
    page = listState.page,
    search = listState.search
  })
end

local function registerEntryMenu(entry, listState)
  local menuId = ('mz_admin:whitelist:%s'):format(tostring(entry.publicId))
  local options = {
    {
      title = 'Codigo publico',
      description = tostring(entry.publicId),
      icon = 'id-card',
      readOnly = true
    },
    {
      title = 'Status',
      description = tostring(entry.status),
      icon = 'circle-info',
      readOnly = true
    },
    {
      title = 'Solicitada em',
      description = formatUnixUtc(entry.requestedAt),
      icon = 'calendar',
      readOnly = true
    },
    {
      title = 'Ultima tentativa',
      description = formatUnixUtc(entry.lastAttemptAt),
      icon = 'clock',
      readOnly = true
    }
  }

  if entry.decidedAt then
    options[#options + 1] = {
      title = 'Ultima decisao',
      description = ('%s por %s'):format(
        formatUnixUtc(entry.decidedAt),
        tostring(entry.decidedBy or 'Staff')
      ),
      icon = 'user-shield',
      readOnly = true
    }
  end

  if canManage and entry.status ~= 'approved' then
    options[#options + 1] = withBinding({
      title = 'Aprovar',
      description = 'Libera a entrada quando o modo enforce estiver ativo.',
      icon = 'user-check'
    }, 'decide', {
      decision = 'approve',
      publicId = entry.publicId,
      playerName = entry.playerName,
      status = entry.status,
      listStatus = listState.status,
      listPage = listState.page,
      listSearch = listState.search
    })
  end
  if canManage and entry.status == 'pending' then
    options[#options + 1] = withBinding({
      title = 'Recusar',
      description = 'Registra a decisao sem excluir a solicitacao.',
      icon = 'user-xmark'
    }, 'decide', {
      decision = 'reject',
      publicId = entry.publicId,
      playerName = entry.playerName,
      status = entry.status,
      listStatus = listState.status,
      listPage = listState.page,
      listSearch = listState.search
    })
  end
  if canManage and entry.status == 'approved' then
    options[#options + 1] = withBinding({
      title = 'Revogar',
      description = 'Bloqueia a proxima conexao no modo enforce.',
      icon = 'user-lock'
    }, 'decide', {
      decision = 'revoke',
      publicId = entry.publicId,
      playerName = entry.playerName,
      status = entry.status,
      listStatus = listState.status,
      listPage = listState.page,
      listSearch = listState.search
    })
  end

  MZAdminUI.RegisterContext({
    id = menuId,
    menu = ('mz_admin:whitelist:list:%s'):format(listState.status),
    title = tostring(entry.playerName or entry.publicId),
    subtitle = tostring(entry.publicId),
    options = options
  })
  return menuId
end

local function openStatus(status, page, search)
  if not STATUS_LABELS[status] then return end
  page = math.max(1, math.floor(tonumber(page) or 1))
  search = tostring(search or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if #search > 80 then search = search:sub(1, 80) end

  local data, err = request('mz_admin:server:listWhitelist', {
    status = status,
    search = search,
    page = page,
    pageSize = 25
  })
  if not data then
    notify('Falha ao consultar: ' .. tostring(err), 'error')
    return
  end

  local menuId = ('mz_admin:whitelist:list:%s'):format(status)
  local listState = {
    status = status,
    page = tonumber(data.page) or page,
    search = search
  }
  local options = {
    withBinding({
      title = 'Buscar',
      description = search ~= '' and ('Filtro atual: ' .. search) or 'Public ID ou nome do player.',
      icon = 'magnifying-glass'
    }, 'filterStatus', listState)
  }

  for _, entry in ipairs(type(data.items) == 'table' and data.items or {}) do
    local entryMenuId = registerEntryMenu(entry, listState)
    options[#options + 1] = {
      title = tostring(entry.playerName or entry.publicId),
      description = ('%s | %s'):format(
        tostring(entry.publicId),
        formatUnixUtc(entry.requestedAt)
      ),
      icon = status == 'approved' and 'user-check'
        or (status == 'pending' and 'user-clock' or 'user-lock'),
      menu = entryMenuId,
      arrow = true
    }
  end
  if #options == 1 then
    options[#options + 1] = {
      title = 'Nenhum registro',
      description = 'Nao existem entradas com este status.',
      icon = 'inbox',
      readOnly = true
    }
  end
  if listState.page > 1 then
    options[#options + 1] = withBinding({
      title = 'Pagina anterior',
      icon = 'arrow-left'
    }, 'openStatus', {
      status = status,
      page = listState.page - 1,
      search = search
    })
  end
  if listState.page * (tonumber(data.pageSize) or 25) < (tonumber(data.total) or 0) then
    options[#options + 1] = withBinding({
      title = 'Proxima pagina',
      icon = 'arrow-right'
    }, 'openStatus', {
      status = status,
      page = listState.page + 1,
      search = search
    })
  end

  MZAdminUI.RegisterContext({
    id = menuId,
    menu = ROOT_ID,
    title = STATUS_LABELS[status],
    subtitle = ('%d registro(s) | pagina %d | modo %s'):format(
      tonumber(data.total) or 0,
      listState.page,
      tostring(data.mode or 'unknown')
    ),
    options = options
  })
  MZAdminUI.ShowContext(menuId)
end

function MZAdminWhitelist.Register(rootId, actions)
  actions = type(actions) == 'table' and actions or {}
  canManage = actions.whitelistManage == true
  local options = {}
  for _, status in ipairs({ 'pending', 'approved', 'rejected', 'revoked' }) do
    options[#options + 1] = withBinding({
      title = STATUS_LABELS[status],
      description = 'Consultar solicitacoes por estado.',
      icon = status == 'pending' and 'user-clock'
        or (status == 'approved' and 'user-check' or 'user-lock')
    }, 'openStatus', { status = status })
  end
  MZAdminUI.RegisterContext({
    id = ROOT_ID,
    menu = rootId,
    title = 'Whitelist',
    subtitle = canManage and 'Consulta e decisoes auditadas' or 'Somente leitura',
    options = options
  })
end

function MZAdminWhitelist.GetMenuId()
  return ROOT_ID
end

RegisterNetEvent(ACTION_EVENT, function(payload)
  payload = type(payload) == 'table' and payload or {}
  if payload.action == 'openStatus' then
    openStatus(
      tostring(payload.status or ''),
      tonumber(payload.page),
      tostring(payload.search or '')
    )
    return
  end
  if payload.action == 'filterStatus' then
    local values = MZAdminUI.InputDialog('Buscar whitelist', {
      {
        type = 'input',
        label = 'Public ID ou nome',
        default = tostring(payload.search or ''),
        max = 80
      }
    }, {
      allowCancel = true,
      labels = { confirm = 'Buscar', cancel = 'Cancelar' }
    })
    if type(values) == 'table' then
      openStatus(tostring(payload.status or ''), 1, tostring(values[1] or ''))
    end
    return
  end
  if payload.action == 'decide' then
    decide({
      publicId = tostring(payload.publicId or ''),
      playerName = tostring(payload.playerName or ''),
      status = tostring(payload.status or '')
    }, tostring(payload.decision or ''), {
      status = tostring(payload.listStatus or 'pending'),
      page = math.max(1, math.floor(tonumber(payload.listPage) or 1)),
      search = tostring(payload.listSearch or '')
    })
  end
end)
