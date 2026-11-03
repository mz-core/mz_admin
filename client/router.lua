-- mz_admin/client/router.lua
-- MZ Admin Unificado — unico roteador de navegacao administrativa.
--
-- TAB, /admin e /mztablet conduzem a ESTA interface (mesma NUI, mesma arvore
-- funcional, mesmo estado). A apresentacao pertence ao mz_admin; a autoridade
-- (validacao de capability/hierarquia/identidade) permanece 100% no servidor
-- via os callbacks tipados ja existentes. Nenhum payload do client e confiado.

MZAdminRouter = MZAdminRouter or {}

local Open = false
local CurrentTab = nil
local Actions = {}
local Context = nil
local PlayerList = {}
local PlayerQuery = ''
local PlayerFilter = 'online'
local PlayerPage = 1
local PlayerHasMore = false
local PlayerHint = nil
local SelectedPlayer = nil
local NavigationTabs = {}
local InputMode = 'blocked'

local TAB_MAIN = 'main'
local TAB_PLAYERS = 'players'
local RESOURCE_VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown'

local PAGE_SIZE = 25

-- Forward declarations (escopo lexico): refreshPlayers, definido adiante,
-- referencia playersView e pushView que so sao atribuidas mais abaixo.
-- Sem estas declaracoes antecipadas, elas seriam resolvidas como globais nil.
local playersView
local pushView

local function cfg()
  return type(Config.Tablet) == 'table' and Config.Tablet or {}
end

local function menuReady()
  return type(MZAdminUI) == 'table' and type(MZAdminUI.OpenTablet) == 'function'
end

local function notify(message, kind)
  if menuReady() then
    MZAdminUI.Notify(tostring(message or ''), kind or 'inform')
  elseif lib and lib.notify then
    lib.notify({ type = kind or 'inform', title = Config.NotifyTitle or 'Admin', description = tostring(message or '') })
  end
end

local ERROR_MESSAGES = {
  permission_denied = 'Sem permissao para esta acao.',
  rate_limited = 'Aguarde um instante antes de repetir esta acao.',
  invalid_target = 'Player invalido ou desconectado.',
  stale_target = 'A sessao selecionada mudou. Selecione novamente.',
  expected_identity_required = 'Selecione novamente o jogador.',
  self_target = 'Voce nao pode realizar esta acao em si mesmo.',
  target_owner = 'O Staff Supremo esta protegido.',
  target_higher_or_equal = 'Voce nao pode agir sobre Staff de nivel igual ou superior.',
  actor_without_staff_level = 'Seu contexto Staff nao possui nivel para este alvo.',
  hierarchy_denied = 'Acao negada pela hierarquia Staff.',
  hierarchy_unavailable = 'Hierarquia Staff indisponivel.',
  invalid_reason = 'Informe um motivo com pelo menos 3 caracteres.',
  invalid_duration = 'Duracao invalida. Use perm, 30m, 12h ou 7d.',
  banguard_unavailable = 'MZ BanGuard nao esta iniciado.',
  warnings_unavailable = 'Sistema de advertencias nao esta iniciado.',
  status_unavailable = 'Estado canonico indisponivel.',
  ped_unavailable = 'Ped indisponivel.',
  spectate_unavailable = 'Spectate indisponivel.',
  spectate_denied = 'Spectate negado.',
  callback_unavailable = 'Servidor nao respondeu ao callback.',
  callback_failed = 'Falha na comunicacao com o servidor.',
  admin_ui_unavailable = 'Interface MZ Admin indisponivel.'
}

local function errorMessage(err)
  err = tostring(err or 'unknown_error')
  return ERROR_MESSAGES[err] or ('Acao negada: ' .. err)
end

local function awaitCallback(name, ...)
  if not lib or not lib.callback or type(lib.callback.await) ~= 'function' then
    return nil, 'callback_unavailable'
  end
  local ok, response = pcall(lib.callback.await, name, false, ...)
  if not ok or type(response) ~= 'table' then
    return nil, 'callback_failed'
  end
  if response.ok ~= true then
    return nil, response.error or 'callback_failed'
  end
  return response.data or true, nil
end

local function runClientCommand(command, args)
  local line = tostring(command or '')
  if type(args) == 'table' and #args > 0 then
    line = line .. ' ' .. table.concat(args, ' ')
  end
  ExecuteCommand(line)
end

local function selfTarget()
  return GetPlayerServerId(PlayerId())
end

local function canOpenNow()
  if IsPauseMenuActive() then return false end

  if GetResourceState('mz_core') == 'started' then
    local session
    pcall(function()
      session = exports['mz_core']:GetPlayerSession()
    end)
    if not session then return false end
  end

  if GetResourceState('mz_inventory') == 'started' then
    local otherOpen = false
    pcall(function()
      otherOpen = exports['mz_inventory']:IsOpen() == true
    end)
    if otherOpen then return false end
  end

  return true
end

-- ---------------------------------------------------------------- rows

local function row(title, subtitle, icon, extra)
  extra = type(extra) == 'table' and extra or {}
  return {
    icon = icon,
    title = title,
    subtitle = subtitle,
    status = extra.status,
    selected = extra.selected,
    tone = extra.tone,
    primary = extra.primary,
    buttons = extra.buttons,
    key = extra.key
  }
end

local function btn(action, label, icon, tone, args)
  return { action = action, label = label, icon = icon, tone = tone, args = args }
end

-- ---------------------------------------------------------------- MAIN

local function mainView()
  local rows = {}
  if Actions.noclip then
    rows[#rows + 1] = row('NoClip', 'Alterna modo livre autorizado pelo servidor.', 'person-flying',
      { primary = { action = 'noclip' } })
  end
  if Actions.tpm then
    rows[#rows + 1] = row('Teleportar ao waypoint', 'Vai ate o ponto marcado no mapa.', 'map-location-dot',
      { primary = { action = 'tpm' } })
  end
  if Actions.tp then
    rows[#rows + 1] = row('Teleportar por coordenadas', ('Use /%s x y z [heading].'):format(Config.Commands.tp or 'tp'), 'location-dot',
      { primary = { action = 'tpHelp' } })
  end
  if Actions.loc then
    rows[#rows + 1] = row('Copiar coordenadas', 'Exibe coords de entidade e de solo.', 'crosshairs',
      { primary = { action = 'loc' } })
  end
  if Actions.heal then
    rows[#rows + 1] = row('Curar a si mesmo', 'Restaura vida, fome e sede.', 'heart-pulse',
      { primary = { action = 'selfHeal' } })
  end
  if Actions.revive then
    rows[#rows + 1] = row('Reviver a si mesmo', 'Conclui o ciclo canonico de respawn.', 'kit-medical',
      { primary = { action = 'selfRevive' } })
  end
  if Actions.armor then
    rows[#rows + 1] = row('Colete 100', 'Define o colete canonico em 100.', 'shield',
      { primary = { action = 'selfArmor' } })
  end
  if Actions.godMode then
    rows[#rows + 1] = row('Godmode', 'Alterna invencibilidade local autorizada.', 'shield-halved',
      { primary = { action = 'selfGodmode' } })
  end
  if Actions.wall then
    rows[#rows + 1] = row('Wall', 'Exibe players em tempo real com estado autorizado.', 'eye',
      { primary = { action = 'wall' } })
  end
  if Actions.spectate then
    rows[#rows + 1] = row('Encerrar spectate', 'Retorna a posicao e dimensao originais.', 'eye-slash',
      { primary = { action = 'spectateStop' } })
  end

  return {
    tab = TAB_MAIN,
    category = TAB_MAIN,
    title = 'Principal',
    subtitle = 'Acoes rapidas da sua sessao',
    rows = rows,
    empty = 'Nenhuma acao de sessao autorizada.'
  }
end

-- ---------------------------------------------------------------- JOGADORES

local function displayDate(value)
  value = tostring(value or '')
  return value:gsub('T', ' '):gsub('Z$', '')
end

local function refreshPlayers(silent)
  -- Busca unica e paginada no servidor: online primeiro e persistido por pesquisa
  -- (filtro online/offline/todos). accountId/characterId vem da identidade canonica
  -- quando a capability de leitura permitir; nunca do client.
  local data = MZAdminClient.SearchPlayers(PlayerQuery, PlayerFilter, PlayerPage, PAGE_SIZE)
  if type(data) ~= 'table' then
    if not silent then notify(errorMessage('callback_failed'), 'error') end
    return
  end

  PlayerList = data.items or {}
  PlayerHasMore = data.hasMore == true
  PlayerHint = data.hint

  if SelectedPlayer then
    local key = tostring(SelectedPlayer.key or SelectedPlayer.source or SelectedPlayer.citizenid or '')
    local still = false
    for _, p in ipairs(PlayerList) do
      if tostring(p.key or p.source or p.citizenid or '') == key then still = true break end
    end
    if not still then SelectedPlayer = nil end
  end

  if Open and CurrentTab == TAB_PLAYERS then
    pushView(playersView())
  end
end

local function playerButtons()
  local buttons = {}
  if Actions.gotoPlayer then buttons[#buttons + 1] = btn('goto', 'Ir até', 'arrow-right') end
  if Actions.bringPlayer then buttons[#buttons + 1] = btn('bring', 'Trazer', 'users') end
  if Actions.spectate then buttons[#buttons + 1] = btn('spectate', 'Esp.', 'eye') end
  if Actions.heal then buttons[#buttons + 1] = btn('heal', 'Curar', 'heart-pulse') end
  if Actions.revive then buttons[#buttons + 1] = btn('revive', 'Reviver', 'kit-medical') end
  if Context.warningsReady and Actions.warningsIssue then
    buttons[#buttons + 1] = btn('warn', 'Warn', 'warning', 'warning')
  end
  if Actions.kick then buttons[#buttons + 1] = btn('kick', 'Kick', 'x', 'danger') end
  if Context.banGuardReady and Actions.ban then buttons[#buttons + 1] = btn('ban', 'Ban', 'lock', 'danger') end
  return buttons
end

playersView = function()
  local query = PlayerQuery:gsub('^%s+', ''):gsub('%s+$', ''):lower()
  local rows = {}
  for _, p in ipairs(PlayerList) do
    local haystack = table.concat({
      tostring(p.source or ''), tostring(p.name or ''), tostring(p.characterName or ''), tostring(p.citizenid or '')
    }, ' '):lower()
    if query == '' or haystack:find(query, 1, true) then
      local online = p.online == true and tonumber(p.source) and tonumber(p.source) > 0
      local title = (p.characterName and p.characterName ~= '') and p.characterName
        or p.name or (online and ('ID ' .. tostring(p.source)) or 'Character offline')
      local subtitle = online and ('ID %s'):format(tostring(p.source))
        or ('Offline · %s'):format(tostring(p.citizenid or ''))
      if online and tonumber(p.ping) and tonumber(p.ping) > 0 then
        subtitle = subtitle .. (' · ping %s ms'):format(tostring(p.ping))
      end
      rows[#rows + 1] = row(title, subtitle, online and 'user' or 'user-clock', {
        key = tostring(p.key or p.source or p.citizenid or ''),
        status = online and { label = 'online', variant = 'success' } or { label = 'offline', variant = 'neutral' },
        selected = SelectedPlayer and SelectedPlayer.key == (p.key or p.source or p.citizenid),
        primary = { action = 'select', args = { key = tostring(p.key or p.source or p.citizenid or '') } }
      })
    end
  end

  return {
    tab = TAB_PLAYERS,
    category = TAB_PLAYERS,
    title = 'Jogadores',
    subtitle = PlayerHint and PlayerHint or ('Filtro: %s · %d resultado(s)'):format(PlayerFilter, #PlayerList),
    searchable = true,
    query = PlayerQuery,
    workspace = true,
    layout = 'grid',
    filters = {
      { id = 'online', label = 'Online' },
      { id = 'offline', label = 'Offline' },
      { id = 'all', label = 'Todos' }
    },
    activeFilter = PlayerFilter,
    rows = rows,
    empty = query == '' and 'Nenhum jogador encontrado.' or 'Nenhum jogador encontrado para a busca.'
  }
end

-- ---------------------------------------------------------------- player modal

local function promptReason(title, extraRow)
  local rows = type(extraRow) == 'table' and extraRow or {}
  rows[#rows + 1] = {
    type = 'textarea',
    label = 'Motivo',
    required = true,
    min = 3,
    max = 256,
    description = 'O motivo sera registrado em auditoria.'
  }
  local values = MZAdminUI.InputDialog(title, rows, {
    allowCancel = true,
    labels = { confirm = 'Confirmar', cancel = 'Cancelar' }
  })
  if type(values) ~= 'table' then return nil end
  return values
end

local function buildActionRows(p, online)
  local rows = {}
  local args = { source = online and tonumber(p.source) or nil, citizenid = p.citizenid }

  if online then
    if Actions.gotoPlayer then
      rows[#rows + 1] = row('Ir até o player', 'O servidor resolve a posicao do alvo.', 'person-walking-arrow-right',
        { primary = { action = 'goto', args = args } })
    end
    if Actions.bringPlayer then
      rows[#rows + 1] = row('Trazer o player', 'O servidor resolve a posicao do Staff.', 'people-arrows-left-right',
        { primary = { action = 'bring', args = args } })
    end
    if Actions.spectate then
      rows[#rows + 1] = row('Espectar o player', 'Protegido por hierarquia e retorno seguro.', 'binoculars',
        { primary = { action = 'spectate', args = args } })
    end
    if Actions.heal then
      rows[#rows + 1] = row('Curar o player', 'Aplica heal no alvo online.', 'heart-pulse',
        { primary = { action = 'heal', args = args } })
    end
    if Actions.revive then
      rows[#rows + 1] = row('Reviver o player', 'Aplica revive no alvo online.', 'kit-medical',
        { primary = { action = 'revive', args = args } })
    end
    if Context.warningsReady and Actions.warningsIssue then
      rows[#rows + 1] = row('Aplicar advertencia', 'Registra motivo e auditoria.', 'triangle-exclamation',
        { primary = { action = 'warn', args = args }, tone = 'warning' })
    end
    if Actions.kick then
      rows[#rows + 1] = row('Remover o player', 'Kick protegido por hierarquia e auditoria.', 'user-xmark',
        { primary = { action = 'kick', args = args }, tone = 'danger' })
    end
    if Context.banGuardReady and Actions.ban then
      rows[#rows + 1] = row('Banir o player', 'BanGuard persiste identifiers e auditoria.', 'user-lock',
        { primary = { action = 'ban', args = args }, tone = 'danger' })
    end
  end

  return rows
end

local function buildInfoRows(p, online)
  local rows = {
    row('Nome', tostring(p.characterName or p.name or '-'), 'user'),
    row('Citizen ID', tostring(p.citizenid or 'indisponivel'), 'address-card'),
    row('Status', online and 'Online' or 'Offline', online and 'circle-check' or 'user-clock',
      { status = { label = online and 'online' or 'offline', variant = online and 'success' or 'neutral' } })
  }
  if online then
    rows[#rows + 1] = row('Source', tostring(p.source), 'hashtag')
    if tonumber(p.ping) and tonumber(p.ping) > 0 then
      rows[#rows + 1] = row('Ping', ('%d ms'):format(tonumber(p.ping)), 'gauge')
    end
  end
  if p.accountId then
    rows[#rows + 1] = row('Conta', ('#%s'):format(tostring(p.accountId)), 'id-card')
  end
  if p.characterId then
    rows[#rows + 1] = row('Personagem', ('#%s'):format(tostring(p.characterId)), 'id-card')
  end
  return rows
end

local function buildCharactersRows(p)
  local accountId = tonumber(p.accountId)
  if not accountId then
    return { empty = 'Conta nao disponivel para este personagem.' }
  end
  local data, err = awaitCallback('mz_admin:server:getAccountCharacters', accountId)
  if not data then
    return { empty = errorMessage(err) }
  end
  local rows = {}
  for _, char in ipairs(data.characters or {}) do
    local name = (tostring(char.firstname or '') .. ' ' .. tostring(char.lastname or '')):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    rows[#rows + 1] = row(
      name ~= '' and name or ('Personagem #%s'):format(tostring(char.characterId or '-')),
      ('CID %s · %s'):format(tostring(char.citizenid or '-'), tostring(char.status or 'active')),
      char.citizenid == p.citizenid and 'circle-check' or 'user'
    )
  end
  return { rows = rows, empty = 'Nenhum personagem persistido para esta conta.' }
end

local function buildHistoryRows(p)
  local citizenid = tostring(p.citizenid or '')
  if citizenid == '' then
    return { empty = 'Identidade persistente indisponivel.' }
  end
  local rows = {}
  if Context.warningsReady and Actions.warningsView then
    local warnings, _ = awaitCallback('mz_admin:server:listWarnings', { search = citizenid, page = 1 })
    for _, warning in ipairs(type(warnings) == 'table' and warnings.items or {}) do
      rows[#rows + 1] = row(
        ('Warn %s | %s'):format(tostring(warning.publicId or '-'), tostring(warning.reason or '')),
        ('%s · %s'):format(tostring(warning.status or '-'), displayDate(warning.issuedAt)),
        warning.status == 'active' and 'triangle-exclamation' or 'rotate-left'
      )
    end
  end
  if Context.banGuardReady and Actions.banView then
    local bans, _ = awaitCallback('mz_admin:server:listBans', { search = citizenid, page = 1 })
    for _, ban in ipairs(type(bans) == 'table' and bans.items or {}) do
      rows[#rows + 1] = row(
        ('Ban %s | %s'):format(tostring(ban.publicId or '-'), tostring(ban.reason or '')),
        ('%s · %s'):format(ban.active == true and 'Ativo' or 'Revogado', displayDate(ban.createdAt)),
        ban.active == true and 'lock' or 'unlock'
      )
    end
  end
  return { rows = rows, empty = 'Nenhum historico de warns/bans para este personagem.' }
end

local function buildSecurityRows(p)
  local citizenid = tostring(p.citizenid or '')
  if citizenid == '' or not (Actions.securityAlertsView == true) then
    return { empty = 'Central de alertas indisponivel para seu contexto.' }
  end
  local data, err = awaitCallback('mz_admin:server:securityIncidentList', { player = citizenid })
  if not data then
    return { empty = errorMessage(err) }
  end
  local rows = {}
  for _, incident in ipairs(data.incidents or {}) do
    rows[#rows + 1] = row(
      ('[%s] %s'):format(tostring(incident.severity or 'info'):upper(), tostring(incident.playerName or incident.citizenid or '-')),
      ('%s · risco %d'):format(tostring(incident.human and incident.human.title or incident.code or 'incidente'), tonumber(incident.riskScore) or 0),
      incident.severity == 'critical' and 'triangle-exclamation' or 'shield'
    )
  end
  return { rows = rows, empty = 'Nenhum incidente de seguranca para este personagem.' }
end

local function buildPunishmentRows(p)
  local citizenid = tostring(p.citizenid or '')
  if citizenid == '' then
    return { empty = 'Identidade persistente indisponivel.' }
  end
  local rows = {}
  if Context.banGuardReady and Actions.banView then
    local bans, _ = awaitCallback('mz_admin:server:listBans', { search = citizenid, page = 1 })
    for _, ban in ipairs(type(bans) == 'table' and bans.items or {}) do
      local buttons = {}
      if ban.active == true and Actions.banRevoke then
        buttons[#buttons + 1] = btn('revokeBan', 'Revogar', 'unlock', 'danger', { publicId = ban.publicId })
      end
      rows[#rows + 1] = row(
        ('%s'):format(tostring(ban.publicId or '-')),
        ('%s · %s'):format(tostring(ban.reason or ''), displayDate(ban.createdAt)),
        ban.active == true and 'lock' or 'unlock',
        { buttons = buttons }
      )
    end
  end
  return { rows = rows, empty = 'Nenhuma punicao ativa para este personagem.' }
end

local function openPlayerModal(p)
  if not p then return end
  SelectedPlayer = p
  local online = p.online == true and tonumber(p.source) and tonumber(p.source) > 0
  local title = (p.characterName and p.characterName ~= '') and p.characterName or p.name or 'Jogador'

  MZAdminUI.SetTabletModal({
    title = title,
    subtitle = online and ('Online · ID %s'):format(tostring(p.source)) or 'Offline · consulta persistida',
    tabs = {
      { id = 'actions', label = 'Ações', icon = 'bolt' },
      { id = 'info', label = 'Informações', icon = 'info' },
      { id = 'characters', label = 'Personagens', icon = 'users' },
      { id = 'history', label = 'Histórico', icon = 'history' },
      { id = 'security', label = 'Segurança', icon = 'shield' },
      { id = 'punishments', label = 'Punições', icon = 'ban' }
    },
    content = {
      actions = { rows = buildActionRows(p, online), empty = 'Jogador offline: acoes em tempo real indisponiveis.' },
      info = { rows = buildInfoRows(p, online) },
      characters = buildCharactersRows(p),
      history = buildHistoryRows(p),
      security = buildSecurityRows(p),
      punishments = buildPunishmentRows(p)
    }
  })
end

-- ---------------------------------------------------------------- actions

local function findPlayerByKey(key)
  for _, p in ipairs(PlayerList) do
    if tostring(p.key or p.source or p.citizenid or '') == tostring(key) then return p end
  end
  return nil
end

local function targetArgs(args)
  args = type(args) == 'table' and args or {}
  return tonumber(args.source), tostring(args.citizenid or '')
end

local function kickPlayer(args)
  local source, citizenid = targetArgs(args)
  local values = promptReason(('Remover player (ID %s)'):format(tostring(source)))
  if not values then return end
  local reason = tostring(values[1] or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if #reason < 3 then notify('Motivo muito curto.', 'error') return end
  local data, err = awaitCallback('mz_admin:server:tabletKick', source, reason, citizenid)
  if not data then notify(errorMessage(err), 'error') else notify('Player removido.', 'success') end
end

local function banPlayer(args)
  local source, citizenid = targetArgs(args)
  local values = promptReason(('Banir player (ID %s)'):format(tostring(source)), {
    { type = 'input', label = 'Duracao', default = 'perm', required = true, min = 1, max = 16, description = 'Use perm, 30m, 12h ou 7d.' }
  })
  if not values then return end
  local duration = tostring(values[1] or ''):gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', '')
  local reason = tostring(values[2] or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if duration == '' or #reason < 3 then notify('Preencha duracao e motivo.', 'error') return end
  local data, err = awaitCallback('mz_admin:server:createBan', source, duration, reason, citizenid)
  if not data then notify(errorMessage(err), 'error') else notify(('Ban criado: %s'):format(tostring(data.ban and data.ban.publicId or '')), 'success') end
end

local function warnPlayer(args)
  local source, citizenid = targetArgs(args)
  local values = promptReason(('Advertir player (ID %s)'):format(tostring(source)))
  if not values then return end
  local reason = tostring(values[1] or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if #reason < 3 then notify('Motivo muito curto.', 'error') return end
  local data, err = awaitCallback('mz_admin:server:issueWarning', source, reason, citizenid)
  if not data then notify(errorMessage(err), 'error') else notify('Advertencia aplicada.', 'success') end
end

local function revokeBan(publicId)
  local values = promptReason('Revogar banimento')
  if not values then return end
  local reason = tostring(values[1] or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if #reason < 3 then notify('Motivo muito curto.', 'error') return end
  local data, err = awaitCallback('mz_admin:server:revokeBan', tostring(publicId):upper(), reason)
  if not data then notify(errorMessage(err), 'error') else notify(('Ban revogado: %s'):format(tostring(publicId)), 'success') end
end

local function handleModalAction(action, args)
  action = tostring(action or '')

  if action == 'goto' then
    local source, citizenid = targetArgs(args)
    local data, err = awaitCallback('mz_admin:server:tabletGoto', source, citizenid)
    if not data then notify(errorMessage(err), 'error') end
  elseif action == 'bring' then
    local source, citizenid = targetArgs(args)
    local data, err = awaitCallback('mz_admin:server:tabletBring', source, citizenid)
    if not data then notify(errorMessage(err), 'error') end
  elseif action == 'spectate' then
    local source, citizenid = targetArgs(args)
    local data, err = awaitCallback('mz_admin:server:tabletSpectateStart', source, citizenid)
    if not data then notify(errorMessage(err), 'error') end
  elseif action == 'heal' then
    local source, citizenid = targetArgs(args)
    local data, err = awaitCallback('mz_admin:server:tabletHeal', source, citizenid)
    if not data then notify(errorMessage(err), 'error') else notify('Player curado.', 'success') end
  elseif action == 'revive' then
    local source, citizenid = targetArgs(args)
    local data, err = awaitCallback('mz_admin:server:tabletRevive', source, citizenid)
    if not data then notify(errorMessage(err), 'error') else notify('Player revivido.', 'success') end
  elseif action == 'warn' then
    warnPlayer(args)
  elseif action == 'kick' then
    kickPlayer(args)
  elseif action == 'ban' then
    banPlayer(args)
  elseif action == 'revokeBan' then
    revokeBan(tostring((type(args) == 'table' and args or {}).publicId or ''))
  end
end

local function handleAction(action, args)
  action = tostring(action or '')

  if action == 'noclip' then
    runClientCommand(Config.NoClipCommand or 'noclip')
  elseif action == 'tpm' then
    runClientCommand(Config.Commands.tpm or 'tpm')
  elseif action == 'tpHelp' then
    notify(('Use /%s x y z [heading] para informar as coordenadas.'):format(Config.Commands.tp or 'tp'), 'inform')
  elseif action == 'loc' then
    runClientCommand(Config.Commands.loc or 'loc')
  elseif action == 'wall' then
    runClientCommand(Config.WallCommand or 'wall')
  elseif action == 'spectateStop' then
    local data, err = awaitCallback('mz_admin:server:tabletSpectateStop')
    if not data then notify(errorMessage(err), 'error') end
  elseif action == 'selfHeal' then
    local data, err = awaitCallback('mz_admin:server:tabletHeal', selfTarget(), nil)
    if not data then notify(errorMessage(err), 'error') else notify('Vida restaurada.', 'success') end
  elseif action == 'selfRevive' then
    local data, err = awaitCallback('mz_admin:server:tabletRevive', selfTarget(), nil)
    if not data then notify(errorMessage(err), 'error') else notify('Revive concluido.', 'success') end
  elseif action == 'selfArmor' then
    local data, err = awaitCallback('mz_admin:server:tabletArmor', 100)
    if not data then notify(errorMessage(err), 'error') else notify('Colete definido para 100.', 'success') end
  elseif action == 'selfGodmode' then
    runClientCommand(Config.Commands.godMode or 'godmode')
  end
end

-- ---------------------------------------------------------------- navigation

pushView = function(view)
  if not Open then return end
  if type(view) ~= 'table' then return end
  MZAdminUI.SetTabletAdminTreeMode(false)
  MZAdminUI.SetTabletView(view)
end

local function navigate(tab)
  if not Open then return end
  if tab == '' then
    CurrentTab = nil
    SelectedPlayer = nil
    MZAdminUI.SetTabletAdminTreeMode(false)
    return
  end
  CurrentTab = tab

  if tab == TAB_MAIN then
    pushView(mainView())
  elseif tab == TAB_PLAYERS then
    PlayerFilter = 'online'
    PlayerPage = 1
    PlayerQuery = ''
    SelectedPlayer = nil
    refreshPlayers(true)
  elseif NavigationTabs[tab] then
    MZAdminUI.SetTabletAdminTreeMode(true)
    MZAdminUI.ShowTabletContext(tab)
  end
end

local function buildNavigationTabs()
  local tabs = {
    { id = TAB_MAIN, label = 'INÍCIO', icon = 'home' },
    { id = TAB_PLAYERS, label = 'JOGADORES', icon = 'user-search' }
  }
  NavigationTabs = {}
  if type(MZAdminMenu.GetNavigationTabs) == 'function' then
    for _, tab in ipairs(MZAdminMenu.GetNavigationTabs()) do
      local id = tostring(tab.id or '')
      if id ~= '' and id ~= TAB_MAIN and id ~= TAB_PLAYERS and not NavigationTabs[id] then
        NavigationTabs[id] = true
        tabs[#tabs + 1] = { id = id, label = tab.label, icon = tab.icon }
      end
    end
  end
  return tabs
end

-- ---------------------------------------------------------------- open / close

function MZAdminRouter.IsOpen()
  return Open == true
end

function MZAdminRouter.Open(inputMode)
  inputMode = inputMode == 'free' and 'free' or 'blocked'
  if not (cfg()).Enabled then
    notify('Tablet administrativo desativado.', 'error')
    return false
  end
  if not menuReady() then
    notify(errorMessage('admin_ui_unavailable'), 'error')
    return false
  end
  if Open then
    InputMode = inputMode
    return MZAdminUI.SetMovementEnabled(InputMode == 'free')
  end
  if not canOpenNow() then return false end

  local context = MZAdminClient.GetMenuContext(true)
  if not context then return false end

  Actions = type(context.actions) == 'table' and context.actions or {}
  Context = context
  SelectedPlayer = nil
  PlayerQuery = ''
  PlayerFilter = 'online'
  PlayerPage = 1
  PlayerList = {}

  -- Registra a arvore de contextos administrativos (reuso integral do /admin).
  MZAdminMenu.RegisterModules(context)
  local navigationTabs = buildNavigationTabs()

  MZAdminUI.SetTabletCallbacks({
    onNavigate = function(tab) navigate(tostring(tab or '')) end,
    onAction = function(action, args) handleAction(tostring(action or ''), args) end,
    onRowAction = function(tab, key, action, args)
      if tostring(tab) == TAB_PLAYERS then
        if tostring(action) == 'select' then
          openPlayerModal(findPlayerByKey(key))
        end
      end
    end,
    onSearch = function(tab, query)
      if tostring(tab) == TAB_PLAYERS then
        PlayerQuery = tostring(query or ''):sub(1, 64)
        PlayerPage = 1
        refreshPlayers(true)
      end
    end,
    onFilter = function(tab, filter)
      if tostring(tab) == TAB_PLAYERS then
        PlayerFilter = (filter == 'offline' or filter == 'all' or filter == 'online') and filter or 'online'
        PlayerPage = 1
        refreshPlayers(true)
      end
    end,
    onModalAction = function(action, args) handleModalAction(tostring(action or ''), args) end,
    onModalClose = function() SelectedPlayer = nil end,
    onClose = function()
      Open = false
      InputMode = 'blocked'
      CurrentTab = nil
      SelectedPlayer = nil
      PlayerList = {}
    end
  })

  local user = { name = 'Staff', role = 'Staff', owner = false }
  if Context.self then
    user.name = tostring(Context.self.name or 'Staff')
    if type(Context.self.role) == 'table' then
      user.role = tostring(Context.self.role.name or 'Staff')
      -- Cargo real retornado pelo servidor; coroa exibida somente para OWNER.
      user.owner = tostring(Context.self.role.code or '') == 'owner'
    end
  end

  local ok = MZAdminUI.OpenTablet({
    title = RESOURCE_VERSION,
    brand = 'MZ Admin',
    locale = tostring(Config.Locale or 'pt-BR'),
    user = user,
    tabs = navigationTabs
  }, inputMode == 'free')
  if not ok then return false end

  Open = true
  InputMode = inputMode
  return true
end

function MZAdminRouter.Close()
  if not Open then return false end
  Open = false
  InputMode = 'blocked'
  CurrentTab = nil
  SelectedPlayer = nil
  PlayerList = {}
  if menuReady() then
    MZAdminUI.CloseTablet()
  end
  return true
end

function MZAdminRouter.Toggle(inputMode)
  inputMode = inputMode == 'free' and 'free' or 'blocked'
  if Open then
    if inputMode == 'free' then
      InputMode = InputMode == 'free' and 'blocked' or 'free'
      return MZAdminUI.SetMovementEnabled(InputMode == 'free')
    end
    if InputMode == 'blocked' then return MZAdminRouter.Close() end
    InputMode = inputMode
    return MZAdminUI.SetMovementEnabled(InputMode == 'free')
  end
  return MZAdminRouter.Open(inputMode)
end

-- ---------------------------------------------------------------- lifecycle

CreateThread(function()
  while true do
    if Open and CurrentTab == TAB_PLAYERS then
      local interval = math.max(1000, tonumber((cfg()).RefreshPlayersMs) or 5000)
      Wait(interval)
      if Open and CurrentTab == TAB_PLAYERS then
        refreshPlayers(true)
      end
    else
      Wait(1000)
    end
  end
end)

CreateThread(function()
  while true do
    if Open then
      Wait(3000)
      if Open then
        local context = MZAdminClient.GetMenuContext(true)
        if not context then
          MZAdminRouter.Close()
          notify('Sua permissao administrativa foi revogada ou a sessao expirou.', 'error')
        else
          Actions = type(context.actions) == 'table' and context.actions or {}
          Context = context
        end
      end
    else
      Wait(1000)
    end
  end
end)

RegisterNetEvent('mz_core:client:characterChanged', function()
  if Open then MZAdminRouter.Close() end
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  if Open and menuReady() then
    pcall(function()
      MZAdminUI.CloseTablet()
    end)
  end
  Open = false
  InputMode = 'blocked'
  CurrentTab = nil
  SelectedPlayer = nil
  PlayerList = {}
end)
