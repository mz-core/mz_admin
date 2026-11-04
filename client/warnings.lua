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
    permission_denied = (type(locale) == 'function' and locale('errors.permission_denied') or 'Sem permissao para esta acao.'),
    rate_limited = (type(locale) == 'function' and locale('errors.rate_limited') or 'Aguarde um instante antes de repetir esta acao.'),
    warnings_unavailable = (type(locale) == 'function' and locale('warnings.s_10613995614c') or 'MZ Warns nao esta iniciado.'),
    warnings_call_failed = (type(locale) == 'function' and locale('warnings.s_038c137b791a') or 'O modulo de advertencias nao respondeu corretamente.'),
    not_initialized = (type(locale) == 'function' and locale('warnings.s_691b411f83a3') or 'O modulo de advertencias ainda nao foi inicializado.'),
    initializing = (type(locale) == 'function' and locale('warnings.s_f16634968c58') or 'O modulo de advertencias ainda esta inicializando.'),
    core_unavailable = (type(locale) == 'function' and locale('bans.s_43d0d4855d2c') or 'MZ Core indisponivel.'),
    authorization_unavailable = (type(locale) == 'function' and locale('warnings.s_9838134777be') or 'Nao foi possivel validar a permissao.'),
    invalid_actor = (type(locale) == 'function' and locale('bans.s_d256c2cb51a0') or 'Contexto Staff invalido.'),
    invalid_target = (type(locale) == 'function' and locale('errors.invalid_target') or 'Player invalido ou desconectado.'),
    stale_target = (type(locale) == 'function' and locale('bans.s_dbf0f245a941') or 'A sessao selecionada mudou de Character. Selecione novamente.'),
    self_target = (type(locale) == 'function' and locale('warnings.s_a0528affa152') or 'Voce nao pode advertir a si mesmo.'),
    target_owner = (type(locale) == 'function' and locale('errors.target_owner') or 'O Staff Supremo esta protegido.'),
    target_higher_or_equal = (type(locale) == 'function' and locale('warnings.s_d2a1b67ef34d') or 'Voce nao pode advertir Staff de nivel igual ou superior.'),
    hierarchy_unavailable = (type(locale) == 'function' and locale('warnings.s_b2bc40753a5d') or 'A hierarquia Staff esta indisponivel.'),
    invalid_reason = (type(locale) == 'function' and locale('errors.invalid_reason') or 'Informe um motivo com pelo menos 3 caracteres.'),
    invalid_status = (type(locale) == 'function' and locale('warnings.s_279e27c9adab') or 'Filtro de status invalido.'),
    invalid_public_id = (type(locale) == 'function' and locale('warnings.s_290c9174c1c3') or 'Public ID de advertencia invalido.'),
    not_found = (type(locale) == 'function' and locale('warnings.s_1dc442448a42') or 'Advertencia nao encontrada.'),
    already_revoked = (type(locale) == 'function' and locale('warnings.s_c6e79c57dbc9') or 'Esta advertencia ja foi revogada.'),
    revision_conflict = (type(locale) == 'function' and locale('warnings.s_21694a3c396f') or 'A advertencia foi alterada por outro Staff. Atualize a lista.'),
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
    notify((type(locale) == 'function' and locale('warnings.s_84a5605a9771') or 'Aplicacao de advertencias indisponivel para seu contexto.'), 'error')
    return false
  end

  if not targetSource then
    local selected = MZAdminPlayerSelector.Select({
      title = (type(locale) == 'function' and locale('warnings.s_a3b5e1191887') or 'Selecionar jogador para advertir'),
      allowOffline = false
    })
    targetSource = selected and tonumber(selected.source)
    expectedCitizenid = selected and selected.citizenid
    if not targetSource then return false end
  end
  local rows = {
    {
    type = 'textarea',
    label = (type(locale) == 'function' and locale('warnings.s_3731b122ee8e') or 'Motivo da advertencia'),
    description = (type(locale) == 'function' and locale('warnings.s_d174a6b107e2') or 'A advertencia sera persistida e auditada. Nao aplica ban ou kick.'),
    required = true,
    min = 3,
    max = 256
    }
  }

  local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('warnings.s_ac6704689ae3') or 'Advertir player'), rows, {
    allowCancel = true,
    labels = { confirm = (type(locale) == 'function' and locale('warnings.s_62e98c590dd8') or 'Advertir'), cancel = (type(locale) == 'function' and locale('garage.s_c111e0ab9ddb') or 'Cancelar') }
  })
  if type(values) ~= 'table' then return false end

  local reason = trim(values[1])
  if #reason < 3 then
    notify((type(locale) == 'function' and locale('warnings.s_06d67950700d') or 'Preencha um motivo valido.'), 'error')
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
  notify(((type(locale) == 'function' and locale('warnings.s_1e0fdbbcc672') or 'Advertencia registrada: %s')):format(
    tostring(data.warning and data.warning.publicId or '-')
  ), 'success')
  return true
end

local function requestRevoke(publicId)
  if not WarningsReady or CurrentActions.warningsRevoke ~= true then
    notify((type(locale) == 'function' and locale('warnings.s_8cdb6cc69876') or 'Voce nao possui permissao para revogar advertencias.'), 'error')
    return false
  end
  local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('warnings.s_ef9361a15dbb') or 'Revogar advertencia'), {
    {
      type = 'textarea',
      label = (type(locale) == 'function' and locale('bans.s_b6fd5c7d4594') or 'Motivo da revogacao'),
      required = true,
      min = 3,
      max = 256
    }
  }, {
    allowCancel = true,
    labels = { confirm = (type(locale) == 'function' and locale('router.s_d4ec79be0fea') or 'Revogar'), cancel = (type(locale) == 'function' and locale('garage.s_c111e0ab9ddb') or 'Cancelar') }
  })
  if type(values) ~= 'table' then return false end

  local data, err = MZAdminClient.StaffRequest('revokeWarning', publicId, trim(values[1]))
  if not data then
    notify(errorMessage(err), 'error')
    return false
  end
  notify(((type(locale) == 'function' and locale('warnings.s_4af3be6a2a4b') or 'Advertencia revogada: %s')):format(
    tostring(data.warning and data.warning.publicId or publicId)
  ), 'success')
  return true
end

local function openDetails(warning, filters, page)
  if type(warning) ~= 'table' then return false end
  local options = {
    {
      title = (type(locale) == 'function' and locale('bans.s_e53407cfe1a5') or 'Player'),
      description = tostring(warning.targetName or (type(locale) == 'function' and locale('bans.s_e1e22bb79941') or 'Nao informado')),
      icon = 'user',
      readOnly = true
    },
    {
      title = (type(locale) == 'function' and locale('warnings.s_f3493431438c') or 'Conta / personagem'),
      description = ((type(locale) == 'function' and locale('warnings.s_172f7760ff66') or 'Conta #%s | Personagem #%s')):format(
        tostring(warning.accountId or (type(locale) == 'function' and locale('bans.s_fb32e2e272bd') or 'Indisponivel')),
        tostring(warning.characterId or (type(locale) == 'function' and locale('bans.s_fb32e2e272bd') or 'Indisponivel'))
      ),
      icon = 'id-card',
      readOnly = true
    },
    {
      title = (type(locale) == 'function' and locale('menu.s_cbeec536b2f8') or 'Motivo'),
      description = tostring(warning.reason or (type(locale) == 'function' and locale('bans.s_e1e22bb79941') or 'Nao informado')),
      icon = 'message',
      readOnly = true
    },
    {
      title = (type(locale) == 'function' and locale('warnings.s_e5d1a046647d') or 'Aplicada por'),
      description = tostring(warning.issuedByName or (type(locale) == 'function' and locale('bans.s_e1e22bb79941') or 'Nao informado')),
      icon = 'user-shield',
      readOnly = true
    },
    {
      title = (type(locale) == 'function' and locale('warnings.s_9a4aa2fdab76') or 'Aplicada em'),
      description = formatUnixUtc(warning.issuedAt),
      icon = 'calendar',
      readOnly = true
    }
  }

  if warning.status == 'active' and CurrentActions.warningsRevoke == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('warnings.s_ef9361a15dbb') or 'Revogar advertencia'),
      description = (type(locale) == 'function' and locale('warnings.s_9d2bce86ea99') or 'Mantem o registro e acrescenta uma revisao de auditoria.'),
      icon = 'rotate-left',
      iconColor = '#22C55E'
    }, 'revoke', {
      publicId = warning.publicId,
      filters = filters,
      page = page
    })
  elseif warning.status == 'revoked' then
    options[#options + 1] = {
      title = (type(locale) == 'function' and locale('warnings.s_c827aa49d4a1') or 'Advertencia revogada'),
      description = ((type(locale) == 'function' and locale('warnings.s_733dcffa32c6') or '%s em %s | %s')):format(
        tostring(warning.revokedByName or (type(locale) == 'function' and locale('bans.s_e1e22bb79941') or 'Nao informado')),
        formatUnixUtc(warning.revokedAt),
        tostring(warning.revokeReason or (type(locale) == 'function' and locale('bans.s_a3d2022d79d0') or 'Sem motivo'))
      ),
      icon = 'rotate-left',
      readOnly = true
    }
  end

  local detailId = LIST_ID .. ':detail:' .. tostring(warning.publicId)
  MZAdminUI.RegisterContext({
    id = detailId,
    menu = LIST_ID,
    title = tostring(warning.publicId or (type(locale) == 'function' and locale('warnings.s_c29238499b09') or 'Advertencia')),
    subtitle = warning.status == 'active' and (type(locale) == 'function' and locale('warnings.s_aa149a38055b') or 'Advertencia ativa') or (type(locale) == 'function' and locale('warnings.s_c827aa49d4a1') or 'Advertencia revogada'),
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
      title = (type(locale) == 'function' and locale('warnings.s_4fb33591dfe6') or 'Advertir player online'),
      description = (type(locale) == 'function' and locale('warnings.s_a163321c9cfb') or 'Exige motivo e respeita a hierarquia Staff.'),
      icon = 'triangle-exclamation'
    }, 'issue')
  end
  if CurrentActions.warningsView == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('warnings.s_1ce9db2f4c79') or 'Advertencias ativas'),
      description = (type(locale) == 'function' and locale('warnings.s_2a148185ed3a') or 'Consulta paginada de registros ativos.'),
      icon = 'list-check'
    }, 'open', { filters = { status = 'active' }, page = 1 })
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('warnings.s_a2d5a99ded73') or 'Historico completo'),
      description = (type(locale) == 'function' and locale('warnings.s_91e9b8293ee3') or 'Inclui advertencias ativas e revogadas.'),
      icon = 'clock-rotate-left'
    }, 'open', { filters = {}, page = 1 })
  end
  MZAdminUI.RegisterContext({
    id = HOME_ID,
    menu = parentId or ROOT_ID,
    title = (type(locale) == 'function' and locale('warnings.s_06db09168487') or 'Advertências'),
    subtitle = (type(locale) == 'function' and locale('warnings.s_b4f86e799ee0') or 'Registros administrativos sem punicao automatica'),
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
    notify((type(locale) == 'function' and locale('warnings.s_178e73fbec23') or 'Consulta de advertencias indisponivel.'), 'error')
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

  local statusText = filters.status == 'active' and (type(locale) == 'function' and locale('warnings.s_f05bbc36f555') or 'ativas')
    or (filters.status == 'revoked' and (type(locale) == 'function' and locale('warnings.s_8d48d05994c2') or 'revogadas') or (type(locale) == 'function' and locale('warnings.s_c92a9bc341d7') or 'todas'))
  local scopeText = filters.targetSource
    and ((type(locale) == 'function' and locale('warnings.s_b815972083c2') or ' | player: ') .. (filters.targetName ~= '' and filters.targetName or ('ID ' .. filters.targetSource)))
    or ''
  local options = {
    bind({
      title = (type(locale) == 'function' and locale('warnings.s_6bcb81f49fee') or 'Filtrar advertencias'),
      description = ((type(locale) == 'function' and locale('warnings.s_e97b18154b13') or 'Status: %s%s%s')):format(
        statusText,
        scopeText,
        filters.search ~= '' and ((type(locale) == 'function' and locale('bans.s_8e2827fd0476') or ' | busca: ') .. filters.search) or ''
      ),
      icon = 'filter'
    }, 'filters', { filters = filters })
  }

  for _, warning in ipairs(data.items or {}) do
    options[#options + 1] = bind({
      title = ('%s | %s'):format(
        tostring(warning.publicId or '-'),
        tostring(warning.targetName or (type(locale) == 'function' and locale('bans.s_54e5aafbabec') or 'Sem nome'))
      ),
      description = ('%s | %s'):format(
        warning.status == 'active' and (type(locale) == 'function' and locale('garage.s_f21c4ff2bbb3') or 'Ativa') or (type(locale) == 'function' and locale('warnings.s_2501fb480f37') or 'Revogada'),
        formatUnixUtc(warning.issuedAt)
      ),
      icon = warning.status == 'active' and 'triangle-exclamation' or 'rotate-left',
      metadata = {
        { label = (type(locale) == 'function' and locale('menu.s_cbeec536b2f8') or 'Motivo'), value = tostring(warning.reason or '-') },
        { label = (type(locale) == 'function' and locale('router.s_4d07517575be') or 'Conta'), value = tostring(warning.accountId or (type(locale) == 'function' and locale('bans.s_fb32e2e272bd') or 'Indisponivel')) },
        { label = (type(locale) == 'function' and locale('router.s_e5a2a32e47eb') or 'Personagem'), value = tostring(warning.characterId or (type(locale) == 'function' and locale('bans.s_fb32e2e272bd') or 'Indisponivel')) },
        { label = 'Staff', value = tostring(warning.issuedByName or '-') }
      }
    }, 'details', { warning = warning, filters = filters, page = page })
  end

  if #(data.items or {}) == 0 then
    options[#options + 1] = {
      title = (type(locale) == 'function' and locale('warnings.s_6e3e40cb1a38') or 'Nenhuma advertencia encontrada'),
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
    menu = HOME_ID,
    title = (type(locale) == 'function' and locale('menu.s_598c7e028360') or 'Advertencias'),
    subtitle = ((type(locale) == 'function' and locale('bans.s_6725f46b5abb') or '%d registro(s) | pagina %d')):format(tonumber(data.total) or 0, page),
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
    local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('warnings.s_6bcb81f49fee') or 'Filtrar advertencias'), {
      {
        type = 'select',
        label = 'Status',
        default = current.status or 'all',
        options = {
          { value = 'all', label = (type(locale) == 'function' and locale('warnings.s_8a3c3440366a') or 'Todas') },
          { value = 'active', label = (type(locale) == 'function' and locale('warnings.s_5aa11a9c2490') or 'Ativas') },
          { value = 'revoked', label = (type(locale) == 'function' and locale('warnings.s_f14083e7c8e7') or 'Revogadas') }
        }
      },
      {
        type = 'input',
        label = (type(locale) == 'function' and locale('bans.s_dc2b71640fe6') or 'Public ID, nome ou CitizenID'),
        default = current.search or '',
        max = 80
      }
    }, {
      allowCancel = true,
      labels = { confirm = (type(locale) == 'function' and locale('bans.s_4ac3b3110330') or 'Aplicar'), cancel = (type(locale) == 'function' and locale('garage.s_c111e0ab9ddb') or 'Cancelar') }
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
