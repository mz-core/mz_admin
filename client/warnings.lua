MZAdminWarnings = MZAdminWarnings or {}

local ROOT_ID = 'mz_admin:root'
local HOME_ID = 'mz_admin:warnings:home'
local LIST_ID = 'mz_admin:warnings:list'
local ACTION_EVENT = 'mz_admin:client:warningMenuAction'
local PAGE_SIZE = 25
local CurrentActions = {}
local WarningsReady = false

local function trim(value)
  return tostring(value or ''):gsub('%c', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
end

local function notify(message, kind)
  MZAdminUI.Notify(tostring(message or ''), kind or 'inform')
end

local function errorMessage(err)
  local messages = {
    permission_denied = 'Sem permissao para esta acao.',
    rate_limited = 'Aguarde um instante antes de repetir esta acao.',
    warnings_unavailable = 'MZ Warns nao esta iniciado.',
    warnings_call_failed = 'O modulo de advertencias nao respondeu corretamente.',
    not_initialized = 'O modulo de advertencias ainda nao foi inicializado.',
    initializing = 'O modulo de advertencias ainda esta inicializando.',
    core_unavailable = 'MZ Core indisponivel.',
    authorization_unavailable = 'Nao foi possivel validar a permissao.',
    invalid_actor = 'Contexto Staff invalido.',
    invalid_target = 'Player invalido ou desconectado.',
    stale_target = 'A sessao selecionada mudou de Character. Selecione novamente.',
    self_target = 'Voce nao pode advertir a si mesmo.',
    target_owner = 'O Staff Supremo esta protegido.',
    target_higher_or_equal = 'Voce nao pode advertir Staff de nivel igual ou superior.',
    hierarchy_unavailable = 'A hierarquia Staff esta indisponivel.',
    invalid_reason = 'Informe um motivo com pelo menos 3 caracteres.',
    invalid_status = 'Filtro de status invalido.',
    invalid_public_id = 'Public ID de advertencia invalido.',
    not_found = 'Advertencia nao encontrada.',
    already_revoked = 'Esta advertencia ja foi revogada.',
    revision_conflict = 'A advertencia foi alterada por outro Staff. Atualize a lista.',
    persistence_failed = 'Falha ao persistir. Nenhuma acao foi concluida.'
  }
  return messages[tostring(err or '')] or ('Acao negada: ' .. tostring(err or 'erro desconhecido'))
end

local function formatUnixUtc(timestamp)
  timestamp = tonumber(timestamp)
  if not timestamp or timestamp <= 0 then return 'Data indisponivel' end
  if timestamp >= 100000000000 then timestamp = timestamp / 1000 end
  timestamp = math.floor(timestamp)
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
  local dayOfYear = dayOfEra - ((365 * yearOfEra) + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100))
  local monthPosition = math.floor(((5 * dayOfYear) + 2) / 153)
  local day = dayOfYear - math.floor(((153 * monthPosition) + 2) / 5) + 1
  local month = monthPosition + (monthPosition < 10 and 3 or -9)
  year = year + (month <= 2 and 1 or 0)
  return ('%02d/%02d/%04d %02d:%02d UTC'):format(day, month, year, hour, minute)
end

local function bind(option, action, args)
  args = type(args) == 'table' and args or {}
  args.action = action
  option.event = ACTION_EVENT
  option.args = args
  return option
end

local function cloneFilters(filters)
  filters = type(filters) == 'table' and filters or {}
  local status = tostring(filters.status or '')
  if status ~= 'active' and status ~= 'revoked' then status = nil end
  return {
    status = status,
    targetSource = tonumber(filters.targetSource),
    targetName = trim(filters.targetName),
    search = trim(filters.search)
  }
end

local function requestIssue(targetSource, expectedCitizenid)
  if not WarningsReady or CurrentActions.warningsIssue ~= true then
    notify('Aplicacao de advertencias indisponivel para seu contexto.', 'error')
    return false
  end

  if not targetSource then
    local selected = MZAdminPlayerSelector.Select({
      title = 'Selecionar jogador para advertir',
      allowOffline = false
    })
    targetSource = selected and tonumber(selected.source)
    expectedCitizenid = selected and selected.citizenid
    if not targetSource then return false end
  end
  local rows = {
    {
    type = 'textarea',
    label = 'Motivo da advertencia',
    description = 'A advertencia sera persistida e auditada. Nao aplica ban ou kick.',
    required = true,
    min = 3,
    max = 256
    }
  }

  local values = MZAdminUI.InputDialog('Advertir player', rows, {
    allowCancel = true,
    labels = { confirm = 'Advertir', cancel = 'Cancelar' }
  })
  if type(values) ~= 'table' then return false end

  local reason = trim(values[1])
  if #reason < 3 then
    notify('Preencha um motivo valido.', 'error')
    return false
  end

  local data, err = MZAdminClient.StaffRequest(
    'issueWarning',
    math.floor(targetSource),
    reason,
    expectedCitizenid
  )
  if not data then
    notify(errorMessage(err), 'error')
    return false
  end
  notify(('Advertencia registrada: %s'):format(
    tostring(data.warning and data.warning.publicId or '-')
  ), 'success')
  return true
end

local function requestRevoke(publicId)
  if not WarningsReady or CurrentActions.warningsRevoke ~= true then
    notify('Voce nao possui permissao para revogar advertencias.', 'error')
    return false
  end
  local values = MZAdminUI.InputDialog('Revogar advertencia', {
    {
      type = 'textarea',
      label = 'Motivo da revogacao',
      required = true,
      min = 3,
      max = 256
    }
  }, {
    allowCancel = true,
    labels = { confirm = 'Revogar', cancel = 'Cancelar' }
  })
  if type(values) ~= 'table' then return false end

  local data, err = MZAdminClient.StaffRequest('revokeWarning', publicId, trim(values[1]))
  if not data then
    notify(errorMessage(err), 'error')
    return false
  end
  notify(('Advertencia revogada: %s'):format(
    tostring(data.warning and data.warning.publicId or publicId)
  ), 'success')
  return true
end

local function openDetails(warning, filters, page)
  if type(warning) ~= 'table' then return false end
  local options = {
    {
      title = 'Player',
      description = tostring(warning.targetName or 'Nao informado'),
      icon = 'user',
      readOnly = true
    },
    {
      title = 'Conta / personagem',
      description = ('Conta #%s | Personagem #%s'):format(
        tostring(warning.accountId or 'Indisponivel'),
        tostring(warning.characterId or 'Indisponivel')
      ),
      icon = 'id-card',
      readOnly = true
    },
    {
      title = 'Motivo',
      description = tostring(warning.reason or 'Nao informado'),
      icon = 'message',
      readOnly = true
    },
    {
      title = 'Aplicada por',
      description = tostring(warning.issuedByName or 'Nao informado'),
      icon = 'user-shield',
      readOnly = true
    },
    {
      title = 'Aplicada em',
      description = formatUnixUtc(warning.issuedAt),
      icon = 'calendar',
      readOnly = true
    }
  }

  if warning.status == 'active' and CurrentActions.warningsRevoke == true then
    options[#options + 1] = bind({
      title = 'Revogar advertencia',
      description = 'Mantem o registro e acrescenta uma revisao de auditoria.',
      icon = 'rotate-left',
      iconColor = '#22C55E'
    }, 'revoke', {
      publicId = warning.publicId,
      filters = filters,
      page = page
    })
  elseif warning.status == 'revoked' then
    options[#options + 1] = {
      title = 'Advertencia revogada',
      description = ('%s em %s | %s'):format(
        tostring(warning.revokedByName or 'Nao informado'),
        formatUnixUtc(warning.revokedAt),
        tostring(warning.revokeReason or 'Sem motivo')
      ),
      icon = 'rotate-left',
      readOnly = true
    }
  end

  local detailId = LIST_ID .. ':detail:' .. tostring(warning.publicId)
  MZAdminUI.RegisterContext({
    id = detailId,
    menu = LIST_ID,
    title = tostring(warning.publicId or 'Advertencia'),
    subtitle = warning.status == 'active' and 'Advertencia ativa' or 'Advertencia revogada',
    options = options
  })
  return MZAdminUI.ShowContext(detailId)
end

function MZAdminWarnings.Configure(actions, ready)
  CurrentActions = type(actions) == 'table' and actions or {}
  WarningsReady = ready == true
end

function MZAdminWarnings.GetMenuId()
  return HOME_ID
end

function MZAdminWarnings.Register(parentId, actions, ready)
  MZAdminWarnings.Configure(actions, ready)
  local options = {}
  if CurrentActions.warningsIssue == true then
    options[#options + 1] = bind({
      title = 'Advertir player online',
      description = 'Exige motivo e respeita a hierarquia Staff.',
      icon = 'triangle-exclamation'
    }, 'issue')
  end
  if CurrentActions.warningsView == true then
    options[#options + 1] = bind({
      title = 'Advertencias ativas',
      description = 'Consulta paginada de registros ativos.',
      icon = 'list-check'
    }, 'open', { filters = { status = 'active' }, page = 1 })
    options[#options + 1] = bind({
      title = 'Historico completo',
      description = 'Inclui advertencias ativas e revogadas.',
      icon = 'clock-rotate-left'
    }, 'open', { filters = {}, page = 1 })
  end
  MZAdminUI.RegisterContext({
    id = HOME_ID,
    menu = parentId or ROOT_ID,
    title = 'Advertências',
    subtitle = 'Registros administrativos sem punicao automatica',
    options = options
  })
end

function MZAdminWarnings.PromptIssue(targetSource, expectedCitizenid)
  return requestIssue(tonumber(targetSource), expectedCitizenid)
end

function MZAdminWarnings.OpenForPlayer(targetSource, targetName)
  targetSource = tonumber(targetSource)
  if not targetSource then return false end
  return MZAdminWarnings.Open({
    targetSource = targetSource,
    targetName = targetName
  }, 1)
end

function MZAdminWarnings.OpenForIdentity(identity)
  identity = type(identity) == 'table' and identity or {}
  local accountId = tonumber(identity.accountId)
  if accountId then
    return MZAdminWarnings.Open({
      search = tostring(accountId),
      targetName = identity.characterName or identity.name
    }, 1)
  end
  local targetSource = tonumber(identity.source or identity.target)
  if identity.online == true and targetSource then
    return MZAdminWarnings.OpenForPlayer(targetSource, identity.characterName or identity.name)
  end
  local search = tostring(identity.citizenid or '')
  if search == '' then return false end
  return MZAdminWarnings.Open({
    search = search,
    targetName = identity.characterName or identity.name
  }, 1)
end

function MZAdminWarnings.Open(filters, page)
  if not WarningsReady or CurrentActions.warningsView ~= true then
    notify('Consulta de advertencias indisponivel.', 'error')
    return false
  end
  filters = cloneFilters(filters)
  page = math.max(1, math.floor(tonumber(page) or 1))
  local data, err = MZAdminClient.StaffRequest('listWarnings', {
    status = filters.status,
    targetSource = filters.targetSource,
    search = filters.search,
    page = page
  })
  if not data then
    notify(errorMessage(err), 'error')
    return false
  end

  local statusText = filters.status == 'active' and 'ativas'
    or (filters.status == 'revoked' and 'revogadas' or 'todas')
  local scopeText = filters.targetSource
    and (' | player: ' .. (filters.targetName ~= '' and filters.targetName or ('ID ' .. filters.targetSource)))
    or ''
  local options = {
    bind({
      title = 'Filtrar advertencias',
      description = ('Status: %s%s%s'):format(
        statusText,
        scopeText,
        filters.search ~= '' and (' | busca: ' .. filters.search) or ''
      ),
      icon = 'filter'
    }, 'filters', { filters = filters })
  }

  for _, warning in ipairs(data.items or {}) do
    options[#options + 1] = bind({
      title = ('%s | %s'):format(
        tostring(warning.publicId or '-'),
        tostring(warning.targetName or 'Sem nome')
      ),
      description = ('%s | %s'):format(
        warning.status == 'active' and 'Ativa' or 'Revogada',
        formatUnixUtc(warning.issuedAt)
      ),
      icon = warning.status == 'active' and 'triangle-exclamation' or 'rotate-left',
      metadata = {
        { label = 'Motivo', value = tostring(warning.reason or '-') },
        { label = 'Conta', value = tostring(warning.accountId or 'Indisponivel') },
        { label = 'Personagem', value = tostring(warning.characterId or 'Indisponivel') },
        { label = 'Staff', value = tostring(warning.issuedByName or '-') }
      }
    }, 'details', { warning = warning, filters = filters, page = page })
  end

  if #(data.items or {}) == 0 then
    options[#options + 1] = {
      title = 'Nenhuma advertencia encontrada',
      icon = 'magnifying-glass',
      readOnly = true
    }
  end
  if page > 1 then
    options[#options + 1] = bind({
      title = 'Pagina anterior',
      icon = 'arrow-left'
    }, 'page', { filters = filters, page = page - 1 })
  end
  if page * PAGE_SIZE < (tonumber(data.total) or 0) then
    options[#options + 1] = bind({
      title = 'Proxima pagina',
      icon = 'arrow-right'
    }, 'page', { filters = filters, page = page + 1 })
  end

  MZAdminUI.RegisterContext({
    id = LIST_ID,
    menu = HOME_ID,
    title = 'Advertencias',
    subtitle = ('%d registro(s) | pagina %d'):format(tonumber(data.total) or 0, page),
    options = options
  })
  return MZAdminUI.ShowContext(LIST_ID)
end

AddEventHandler(ACTION_EVENT, function(payload)
  payload = type(payload) == 'table' and payload or {}
  if payload.action == 'issue' then
    requestIssue()
  elseif payload.action == 'open' or payload.action == 'page' then
    MZAdminWarnings.Open(payload.filters, payload.page)
  elseif payload.action == 'details' then
    openDetails(payload.warning, payload.filters, payload.page)
  elseif payload.action == 'revoke' then
    if requestRevoke(payload.publicId) then
      MZAdminWarnings.Open(payload.filters, payload.page)
    end
  elseif payload.action == 'filters' then
    local current = cloneFilters(payload.filters)
    local values = MZAdminUI.InputDialog('Filtrar advertencias', {
      {
        type = 'select',
        label = 'Status',
        default = current.status or 'all',
        options = {
          { value = 'all', label = 'Todas' },
          { value = 'active', label = 'Ativas' },
          { value = 'revoked', label = 'Revogadas' }
        }
      },
      {
        type = 'input',
        label = 'Public ID, nome ou CitizenID',
        default = current.search or '',
        max = 80
      }
    }, {
      allowCancel = true,
      labels = { confirm = 'Aplicar', cancel = 'Cancelar' }
    })
    if type(values) == 'table' then
      MZAdminWarnings.Open({
        status = values[1] ~= 'all' and values[1] or nil,
        targetSource = current.targetSource,
        targetName = current.targetName,
        search = trim(values[2])
      }, 1)
    end
  end
end)
