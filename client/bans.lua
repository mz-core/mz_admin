MZAdminBans = MZAdminBans or {}

local ROOT_ID = 'mz_admin:root'
local LIST_ID = 'mz_admin:bans'
local ACTION_EVENT = 'mz_admin:client:banMenuAction'
local PAGE_SIZE = 25
local CurrentActions = {}
local BanGuardReady = false
local CurrentParentId = ROOT_ID

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
    banguard_unavailable = 'MZ BanGuard nao esta iniciado.',
    banguard_call_failed = 'O BanGuard nao respondeu corretamente.',
    database_unavailable = 'Banco do BanGuard indisponivel.',
    schema_not_ready = 'Schema do BanGuard ainda nao foi instalado.',
    core_unavailable = 'MZ Core indisponivel.',
    invalid_actor = 'Contexto Staff invalido.',
    invalid_target = 'Player invalido ou desconectado.',
    expected_identity_required = 'Selecione novamente o jogador antes de banir.',
    stale_target = 'A sessao selecionada mudou de Character. Selecione novamente.',
    self_target = 'Voce nao pode banir a si mesmo.',
    target_owner = 'O Staff Supremo esta protegido.',
    target_higher_or_equal = 'Voce nao pode banir Staff de nivel igual ou superior.',
    invalid_reason = 'Informe um motivo com pelo menos 3 caracteres.',
    invalid_duration = 'Duracao invalida. Use perm, 30m, 12h ou 7d.',
    duration_too_long = 'Duracao acima do limite seguro.',
    missing_required_identifier = 'O player nao possui o identifier obrigatorio.',
    already_banned = 'Este player ja possui banimento ativo.',
    invalid_public_id = 'Public ID invalido.',
    not_found = 'Public ID nao encontrado no banco local.',
    already_revoked = 'Este banimento ja foi revogado.',
    expired = 'Este banimento temporario ja expirou.',
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
  return ('%02d/%02d/%04d %02d:%02d'):format(day, month, year, hour, minute)
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
  return {
    active = filters.active == true and true or (filters.active == false and false or nil),
    search = trim(filters.search)
  }
end

local function requestCreate(targetSource, expectedCitizenid)
  if not BanGuardReady or CurrentActions.ban ~= true then
    notify('Banimento indisponivel para seu contexto.', 'error')
    return false
  end

  if not targetSource then
    local selected = MZAdminPlayerSelector.Select({
      title = 'Selecionar jogador para banir',
      allowOffline = false
    })
    targetSource = selected and tonumber(selected.source)
    expectedCitizenid = selected and selected.citizenid
    if not targetSource then return false end
  end
  local rows = {
    {
    type = 'input',
    label = 'Duracao',
    default = 'perm',
    description = 'Use perm, 30m, 12h ou 7d.',
    required = true,
    min = 1,
    max = 16
    },
    {
    type = 'textarea',
    label = 'Motivo',
    required = true,
    min = 3,
    max = 256
    }
  }

  local values = MZAdminUI.InputDialog('Banir player', rows, {
    allowCancel = true,
    labels = { confirm = 'Banir', cancel = 'Cancelar' }
  })
  if type(values) ~= 'table' then return false end

  local duration = trim(values[1])
  local reason = trim(values[2])
  if duration == '' or #reason < 3 then
    notify('Preencha duracao e motivo.', 'error')
    return false
  end

  local data, err = MZAdminClient.StaffRequest(
    'createBan',
    math.floor(targetSource),
    duration,
    reason,
    expectedCitizenid
  )
  if not data then
    notify(errorMessage(err), 'error')
    return false
  end

  local ban = data.ban or {}
  notify(('Ban criado: %s'):format(tostring(ban.publicId or 'sem codigo')), 'success')
  return true
end

local function requestRevoke(publicId)
  if not BanGuardReady or CurrentActions.banRevoke ~= true then
    notify('Voce nao possui permissao para revogar banimentos.', 'error')
    return false
  end

  local values = MZAdminUI.InputDialog('Revogar banimento', {
    { type = 'input', label = 'Public ID', default = publicId or '', required = true, min = 10, max = 10 },
    { type = 'textarea', label = 'Motivo da revogacao', required = true, min = 3, max = 256 }
  }, {
    allowCancel = true,
    labels = { confirm = 'Revogar', cancel = 'Cancelar' }
  })
  if type(values) ~= 'table' then return false end

  publicId = trim(values[1]):upper()
  local reason = trim(values[2])
  local data, err = MZAdminClient.StaffRequest('revokeBan', publicId, reason)
  if not data then
    notify(errorMessage(err), 'error')
    return false
  end

  notify(('Ban revogado: %s'):format(tostring(data.ban and data.ban.publicId or publicId)), 'success')
  return true
end

local function openDetails(publicId, filters, page)
  local data, err = MZAdminClient.StaffRequest('getBan', publicId)
  if not data or type(data.ban) ~= 'table' then
    notify(errorMessage(err), 'error')
    return false
  end

  local ban = data.ban
  local options = {
    { title = 'Player', description = tostring(ban.playerName or 'Nao informado'), icon = 'user', readOnly = true },
    {
      title = 'CitizenID',
      description = tostring(ban.citizenId or 'Indisponivel'),
      icon = 'id-card',
      readOnly = true
    },
    { title = 'Motivo', description = tostring(ban.reason or 'Nao informado'), icon = 'message', readOnly = true },
    { title = 'Criado por', description = tostring(ban.bannedBy or 'Nao informado'), icon = 'user-shield', readOnly = true },
    { title = 'Criado em', description = formatUnixUtc(ban.createdAt), icon = 'calendar', readOnly = true },
    {
      title = 'Expiracao',
      description = ban.expiresAt and formatUnixUtc(ban.expiresAt) or 'Permanente',
      icon = 'clock',
      readOnly = true
    }
  }
  if ban.active == true and CurrentActions.banRevoke == true then
    options[#options + 1] = bind({
      title = 'Revogar banimento',
      description = 'Exige motivo e gera auditoria no BanGuard.',
      icon = 'unlock',
      iconColor = '#22C55E'
    }, 'revoke', { publicId = ban.publicId, filters = filters, page = page })
  elseif ban.active ~= true then
    options[#options + 1] = {
      title = 'Banimento revogado',
      description = ('%s | %s'):format(
        tostring(ban.revokedBy or 'Nao informado'),
        tostring(ban.revokeReason or 'Sem motivo')
      ),
      icon = 'unlock',
      readOnly = true
    }
  end

  local detailId = LIST_ID .. ':detail:' .. tostring(ban.publicId)
  MZAdminUI.RegisterContext({
    id = detailId,
    menu = LIST_ID,
    title = tostring(ban.publicId),
    subtitle = ban.active == true and 'Banimento ativo' or 'Banimento revogado',
    options = options
  })
  return MZAdminUI.ShowContext(detailId)
end

function MZAdminBans.Configure(actions, ready, parentId)
  CurrentActions = type(actions) == 'table' and actions or {}
  BanGuardReady = ready == true
  parentId = trim(parentId)
  CurrentParentId = parentId ~= '' and parentId or ROOT_ID
end

function MZAdminBans.PromptCreate(targetSource, expectedCitizenid)
  return requestCreate(tonumber(targetSource), expectedCitizenid)
end

function MZAdminBans.PromptRevoke(publicId)
  return requestRevoke(publicId)
end

function MZAdminBans.Open(filters, page)
  if not BanGuardReady or CurrentActions.banView ~= true then
    notify('Consulta de banimentos indisponivel.', 'error')
    return false
  end

  filters = cloneFilters(filters)
  page = math.max(1, math.floor(tonumber(page) or 1))
  local data, err = MZAdminClient.StaffRequest('listBans', {
    active = filters.active,
    search = filters.search,
    page = page
  })
  if not data then
    notify(errorMessage(err), 'error')
    return false
  end

  local statusText = filters.active == true and 'ativos'
    or (filters.active == false and 'revogados' or 'todos')
  local options = {
    bind({
      title = 'Filtrar banimentos',
      description = ('Status: %s%s'):format(
        statusText,
        filters.search ~= '' and (' | busca: ' .. filters.search) or ''
      ),
      icon = 'filter'
    }, 'filters', { filters = filters })
  }

  if CurrentActions.ban == true then
    options[#options + 1] = bind({
      title = 'Banir player online',
      description = 'Hierarquia, identifiers e persistencia sao revalidados no servidor.',
      icon = 'user-lock'
    }, 'create')
  end

  for _, ban in ipairs(data.items or {}) do
    options[#options + 1] = bind({
      title = ('%s | %s'):format(tostring(ban.publicId or '-'), tostring(ban.playerName or 'Sem nome')),
      description = ('%s | %s'):format(
        ban.active == true and 'Ativo' or 'Revogado',
        formatUnixUtc(ban.createdAt)
      ),
      icon = ban.active == true and 'ban' or 'unlock',
      metadata = {
        { label = 'Motivo', value = tostring(ban.reason or '-') },
        { label = 'CitizenID', value = tostring(ban.citizenId or 'Indisponivel') },
        { label = 'Staff', value = tostring(ban.bannedBy or '-') },
        { label = 'Expira', value = ban.expiresAt and formatUnixUtc(ban.expiresAt) or 'Permanente' }
      }
    }, 'details', { publicId = ban.publicId, filters = filters, page = page })
  end

  if #(data.items or {}) == 0 then
    options[#options + 1] = {
      title = 'Nenhum banimento encontrado',
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
    menu = CurrentParentId,
    title = 'Banimentos',
    subtitle = ('%d registro(s) | pagina %d'):format(tonumber(data.total) or 0, page),
    options = options
  })
  return MZAdminUI.ShowContext(LIST_ID)
end

AddEventHandler(ACTION_EVENT, function(payload)
  payload = type(payload) == 'table' and payload or {}
  if payload.action == 'create' then
    requestCreate()
  elseif payload.action == 'details' then
    openDetails(payload.publicId, payload.filters, payload.page)
  elseif payload.action == 'revoke' then
    if requestRevoke(payload.publicId) then
      MZAdminBans.Open(payload.filters, payload.page)
    end
  elseif payload.action == 'page' then
    MZAdminBans.Open(payload.filters, payload.page)
  elseif payload.action == 'filters' then
    local current = cloneFilters(payload.filters)
    local values = MZAdminUI.InputDialog('Filtrar banimentos', {
      {
        type = 'select',
        label = 'Status',
        default = current.active == true and 'active' or (current.active == false and 'revoked' or 'all'),
        options = {
          { value = 'all', label = 'Todos' },
          { value = 'active', label = 'Ativos' },
          { value = 'revoked', label = 'Revogados' }
        }
      },
      { type = 'input', label = 'Public ID, nome ou CitizenID', default = current.search or '', max = 80 }
    }, {
      allowCancel = true,
      labels = { confirm = 'Aplicar', cancel = 'Cancelar' }
    })
    if type(values) == 'table' then
      MZAdminBans.Open({
        active = values[1] == 'active' and true or (values[1] == 'revoked' and false or nil),
        search = trim(values[2])
      }, 1)
    end
  end
end)

RegisterNetEvent('mz_admin:client:banResult', function(action, resultData)
  if type(resultData) ~= 'table' or resultData.ok ~= true then
    notify(errorMessage(resultData and resultData.error), 'error')
    return
  end
  local publicId = resultData.data and resultData.data.ban and resultData.data.ban.publicId or '-'
  notify(action == 'revoke'
    and ('Ban revogado: ' .. tostring(publicId))
    or ('Ban criado: ' .. tostring(publicId)), 'success')
end)
