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
    permission_denied = (type(locale) == 'function' and locale('errors.permission_denied') or 'Sem permissao para esta acao.'),
    rate_limited = (type(locale) == 'function' and locale('errors.rate_limited') or 'Aguarde um instante antes de repetir esta acao.'),
    banguard_unavailable = (type(locale) == 'function' and locale('errors.banguard_unavailable') or 'MZ BanGuard nao esta iniciado.'),
    banguard_call_failed = (type(locale) == 'function' and locale('bans.s_7a5e899c3ffa') or 'O BanGuard nao respondeu corretamente.'),
    database_unavailable = (type(locale) == 'function' and locale('bans.s_ca59e84be52a') or 'Banco do BanGuard indisponivel.'),
    schema_not_ready = (type(locale) == 'function' and locale('bans.s_4df696b07663') or 'Schema do BanGuard ainda nao foi instalado.'),
    core_unavailable = (type(locale) == 'function' and locale('bans.s_43d0d4855d2c') or 'MZ Core indisponivel.'),
    invalid_actor = (type(locale) == 'function' and locale('bans.s_d256c2cb51a0') or 'Contexto Staff invalido.'),
    invalid_target = (type(locale) == 'function' and locale('errors.invalid_target') or 'Player invalido ou desconectado.'),
    expected_identity_required = (type(locale) == 'function' and locale('bans.s_d72b4d3a6523') or 'Selecione novamente o jogador antes de banir.'),
    stale_target = (type(locale) == 'function' and locale('bans.s_dbf0f245a941') or 'A sessao selecionada mudou de Character. Selecione novamente.'),
    self_target = (type(locale) == 'function' and locale('bans.s_1e66ea475202') or 'Voce nao pode banir a si mesmo.'),
    target_owner = (type(locale) == 'function' and locale('errors.target_owner') or 'O Staff Supremo esta protegido.'),
    target_higher_or_equal = (type(locale) == 'function' and locale('bans.s_ba223e199bde') or 'Voce nao pode banir Staff de nivel igual ou superior.'),
    invalid_reason = (type(locale) == 'function' and locale('errors.invalid_reason') or 'Informe um motivo com pelo menos 3 caracteres.'),
    invalid_duration = (type(locale) == 'function' and locale('errors.invalid_duration') or 'Duracao invalida. Use perm, 30m, 12h ou 7d.'),
    duration_too_long = (type(locale) == 'function' and locale('bans.s_fe7211a8d066') or 'Duracao acima do limite seguro.'),
    missing_required_identifier = (type(locale) == 'function' and locale('bans.s_efa1a915b06b') or 'O player nao possui o identifier obrigatorio.'),
    already_banned = (type(locale) == 'function' and locale('bans.s_d1b5a7b95c88') or 'Este player ja possui banimento ativo.'),
    invalid_public_id = (type(locale) == 'function' and locale('bans.s_8bf6c8d4fef6') or 'Public ID invalido.'),
    not_found = (type(locale) == 'function' and locale('bans.s_ea70bae423db') or 'Public ID nao encontrado no banco local.'),
    already_revoked = (type(locale) == 'function' and locale('bans.s_1aecb7132660') or 'Este banimento ja foi revogado.'),
    expired = (type(locale) == 'function' and locale('bans.s_c31b45ed1eb0') or 'Este banimento temporario ja expirou.'),
    persistence_failed = (type(locale) == 'function' and locale('bans.s_080d2f2c4c24') or 'Falha ao persistir. Nenhuma acao foi concluida.')
  }
  return messages[tostring(err or '')] or ((type(locale) == 'function' and locale('router.s_d9c4ffa0dedc') or 'Acao negada: ') .. tostring(err or (type(locale) == 'function' and locale('garage.s_d7cff8e730ea') or 'erro desconhecido')))
end

local function formatUnixUtc(timestamp)
  timestamp = tonumber(timestamp)
  if not timestamp or timestamp <= 0 then return (type(locale) == 'function' and locale('bans.s_c1b4b0a9abcf') or 'Data indisponivel') end
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
    notify((type(locale) == 'function' and locale('bans.s_f68ccf018c13') or 'Banimento indisponivel para seu contexto.'), 'error')
    return false
  end

  if not targetSource then
    local selected = MZAdminPlayerSelector.Select({
      title = (type(locale) == 'function' and locale('bans.s_8080440363b4') or 'Selecionar jogador para banir'),
      allowOffline = false
    })
    targetSource = selected and tonumber(selected.source)
    expectedCitizenid = selected and selected.citizenid
    if not targetSource then return false end
  end
  local rows = {
    {
    type = 'input',
    label = (type(locale) == 'function' and locale('menu.s_9bd8554a89a4') or 'Duracao'),
    default = 'perm',
    description = (type(locale) == 'function' and locale('menu.s_9f5bb500ed8c') or 'Use perm, 30m, 12h ou 7d.'),
    required = true,
    min = 1,
    max = 16
    },
    {
    type = 'textarea',
    label = (type(locale) == 'function' and locale('menu.s_cbeec536b2f8') or 'Motivo'),
    required = true,
    min = 3,
    max = 256
    }
  }

  local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('bans.s_b95ca64e1d84') or 'Banir player'), rows, {
    allowCancel = true,
    labels = { confirm = (type(locale) == 'function' and locale('bans.s_0a8b777fd70a') or 'Banir'), cancel = (type(locale) == 'function' and locale('garage.s_c111e0ab9ddb') or 'Cancelar') }
  })
  if type(values) ~= 'table' then return false end

  local duration = trim(values[1])
  local reason = trim(values[2])
  if duration == '' or #reason < 3 then
    notify((type(locale) == 'function' and locale('router.s_e844a2af1255') or 'Preencha duracao e motivo.'), 'error')
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
  notify(((type(locale) == 'function' and locale('router.s_47b6fffe1309') or 'Ban criado: %s')):format(tostring(ban.publicId or (type(locale) == 'function' and locale('bans.s_512f1189db13') or 'sem codigo'))), 'success')
  return true
end

local function requestRevoke(publicId)
  if not BanGuardReady or CurrentActions.banRevoke ~= true then
    notify((type(locale) == 'function' and locale('bans.s_b1e2676894e5') or 'Voce nao possui permissao para revogar banimentos.'), 'error')
    return false
  end

  local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('router.s_3081c2977f16') or 'Revogar banimento'), {
    { type = 'input', label = (type(locale) == 'function' and locale('bans.s_cd07ee2b7943') or 'Public ID'), default = publicId or '', required = true, min = 10, max = 10 },
    { type = 'textarea', label = (type(locale) == 'function' and locale('bans.s_b6fd5c7d4594') or 'Motivo da revogacao'), required = true, min = 3, max = 256 }
  }, {
    allowCancel = true,
    labels = { confirm = (type(locale) == 'function' and locale('router.s_d4ec79be0fea') or 'Revogar'), cancel = (type(locale) == 'function' and locale('garage.s_c111e0ab9ddb') or 'Cancelar') }
  })
  if type(values) ~= 'table' then return false end

  publicId = trim(values[1]):upper()
  local reason = trim(values[2])
  local data, err = MZAdminClient.StaffRequest('revokeBan', publicId, reason)
  if not data then
    notify(errorMessage(err), 'error')
    return false
  end

  notify(((type(locale) == 'function' and locale('router.s_92a63c204352') or 'Ban revogado: %s')):format(tostring(data.ban and data.ban.publicId or publicId)), 'success')
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
    { title = (type(locale) == 'function' and locale('bans.s_e53407cfe1a5') or 'Player'), description = tostring(ban.playerName or (type(locale) == 'function' and locale('bans.s_e1e22bb79941') or 'Nao informado')), icon = 'user', readOnly = true },
    {
      title = 'CitizenID',
      description = tostring(ban.citizenId or (type(locale) == 'function' and locale('bans.s_fb32e2e272bd') or 'Indisponivel')),
      icon = 'id-card',
      readOnly = true
    },
    { title = (type(locale) == 'function' and locale('menu.s_cbeec536b2f8') or 'Motivo'), description = tostring(ban.reason or (type(locale) == 'function' and locale('bans.s_e1e22bb79941') or 'Nao informado')), icon = 'message', readOnly = true },
    { title = (type(locale) == 'function' and locale('bans.s_762618c07174') or 'Criado por'), description = tostring(ban.bannedBy or (type(locale) == 'function' and locale('bans.s_e1e22bb79941') or 'Nao informado')), icon = 'user-shield', readOnly = true },
    { title = (type(locale) == 'function' and locale('bans.s_16379961e450') or 'Criado em'), description = formatUnixUtc(ban.createdAt), icon = 'calendar', readOnly = true },
    {
      title = (type(locale) == 'function' and locale('bans.s_c38134c5d9e5') or 'Expiracao'),
      description = ban.expiresAt and formatUnixUtc(ban.expiresAt) or (type(locale) == 'function' and locale('bans.s_f6e42f89e024') or 'Permanente'),
      icon = 'clock',
      readOnly = true
    }
  }
  if ban.active == true and CurrentActions.banRevoke == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('router.s_3081c2977f16') or 'Revogar banimento'),
      description = (type(locale) == 'function' and locale('bans.s_9a2eff0d3afd') or 'Exige motivo e gera auditoria no BanGuard.'),
      icon = 'unlock',
      iconColor = '#22C55E'
    }, 'revoke', { publicId = ban.publicId, filters = filters, page = page })
  elseif ban.active ~= true then
    options[#options + 1] = {
      title = (type(locale) == 'function' and locale('bans.s_64225fbd7d4f') or 'Banimento revogado'),
      description = ('%s | %s'):format(
        tostring(ban.revokedBy or (type(locale) == 'function' and locale('bans.s_e1e22bb79941') or 'Nao informado')),
        tostring(ban.revokeReason or (type(locale) == 'function' and locale('bans.s_a3d2022d79d0') or 'Sem motivo'))
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
    subtitle = ban.active == true and (type(locale) == 'function' and locale('bans.s_8d9f0d12b7f7') or 'Banimento ativo') or (type(locale) == 'function' and locale('bans.s_64225fbd7d4f') or 'Banimento revogado'),
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
    notify((type(locale) == 'function' and locale('bans.s_d0f61e87ee84') or 'Consulta de banimentos indisponivel.'), 'error')
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

  local statusText = filters.active == true and (type(locale) == 'function' and locale('bans.s_7ee5802a307f') or 'ativos')
    or (filters.active == false and (type(locale) == 'function' and locale('bans.s_437b2fe2cc55') or 'revogados') or (type(locale) == 'function' and locale('bans.s_a90108078540') or 'todos'))
  local options = {
    bind({
      title = (type(locale) == 'function' and locale('bans.s_20c23f8f93de') or 'Filtrar banimentos'),
      description = ((type(locale) == 'function' and locale('bans.s_42fb396b3a6d') or 'Status: %s%s')):format(
        statusText,
        filters.search ~= '' and ((type(locale) == 'function' and locale('bans.s_8e2827fd0476') or ' | busca: ') .. filters.search) or ''
      ),
      icon = 'filter'
    }, 'filters', { filters = filters })
  }

  if CurrentActions.ban == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('bans.s_43fdca6efdc2') or 'Banir player online'),
      description = (type(locale) == 'function' and locale('bans.s_b304ef033adb') or 'Hierarquia, identifiers e persistencia sao revalidados no servidor.'),
      icon = 'user-lock'
    }, 'create')
  end

  for _, ban in ipairs(data.items or {}) do
    options[#options + 1] = bind({
      title = ('%s | %s'):format(tostring(ban.publicId or '-'), tostring(ban.playerName or (type(locale) == 'function' and locale('bans.s_54e5aafbabec') or 'Sem nome'))),
      description = ('%s | %s'):format(
        ban.active == true and (type(locale) == 'function' and locale('router.s_8263fde6ccc4') or 'Ativo') or (type(locale) == 'function' and locale('router.s_4391b7de4835') or 'Revogado'),
        formatUnixUtc(ban.createdAt)
      ),
      icon = ban.active == true and 'ban' or 'unlock',
      metadata = {
        { label = (type(locale) == 'function' and locale('menu.s_cbeec536b2f8') or 'Motivo'), value = tostring(ban.reason or '-') },
        { label = 'CitizenID', value = tostring(ban.citizenId or (type(locale) == 'function' and locale('bans.s_fb32e2e272bd') or 'Indisponivel')) },
        { label = 'Staff', value = tostring(ban.bannedBy or '-') },
        { label = (type(locale) == 'function' and locale('bans.s_0c2de023873e') or 'Expira'), value = ban.expiresAt and formatUnixUtc(ban.expiresAt) or (type(locale) == 'function' and locale('bans.s_f6e42f89e024') or 'Permanente') }
      }
    }, 'details', { publicId = ban.publicId, filters = filters, page = page })
  end

  if #(data.items or {}) == 0 then
    options[#options + 1] = {
      title = (type(locale) == 'function' and locale('bans.s_20ed6b16dbf4') or 'Nenhum banimento encontrado'),
      icon = 'magnifying-glass',
      readOnly = true
    }
  end

  if page > 1 then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('bans.s_4647a651b2cc') or 'Pagina anterior'),
      icon = 'arrow-left'
    }, 'page', { filters = filters, page = page - 1 })
  end
  if page * PAGE_SIZE < (tonumber(data.total) or 0) then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('bans.s_d09ccdb8c4ad') or 'Proxima pagina'),
      icon = 'arrow-right'
    }, 'page', { filters = filters, page = page + 1 })
  end

  MZAdminUI.RegisterContext({
    id = LIST_ID,
    menu = CurrentParentId,
    title = (type(locale) == 'function' and locale('menu.s_b0f7c118af48') or 'Banimentos'),
    subtitle = ((type(locale) == 'function' and locale('bans.s_6725f46b5abb') or '%d registro(s) | pagina %d')):format(tonumber(data.total) or 0, page),
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
    local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('bans.s_20c23f8f93de') or 'Filtrar banimentos'), {
      {
        type = 'select',
        label = 'Status',
        default = current.active == true and 'active' or (current.active == false and 'revoked' or 'all'),
        options = {
          { value = 'all', label = (type(locale) == 'function' and locale('menu.s_a4114a83f4c6') or 'Todos') },
          { value = 'active', label = (type(locale) == 'function' and locale('bans.s_52420a2157c4') or 'Ativos') },
          { value = 'revoked', label = (type(locale) == 'function' and locale('bans.s_b5ac5ba32c55') or 'Revogados') }
        }
      },
      { type = 'input', label = (type(locale) == 'function' and locale('bans.s_dc2b71640fe6') or 'Public ID, nome ou CitizenID'), default = current.search or '', max = 80 }
    }, {
      allowCancel = true,
      labels = { confirm = (type(locale) == 'function' and locale('bans.s_4ac3b3110330') or 'Aplicar'), cancel = (type(locale) == 'function' and locale('garage.s_c111e0ab9ddb') or 'Cancelar') }
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
    and ((type(locale) == 'function' and locale('bans.s_7b1f0c2dfbcc') or 'Ban revogado: ') .. tostring(publicId))
    or ((type(locale) == 'function' and locale('bans.s_4d55d8dc2bc8') or 'Ban criado: ') .. tostring(publicId)), 'success')
end)
