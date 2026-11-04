local function translate(key, fallback)
  local text = type(locale) == 'function' and locale(key) or nil
  return type(text) == 'string' and text ~= '' and text ~= key and text or fallback
end

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
  if ERROR_MESSAGES[err] and type(locale) == 'function' then
    local key = 'errors.' .. err
    local text = locale(key)
    if type(text) == 'string' and text ~= '' and text ~= key then return text end
  end
  return ERROR_MESSAGES[err] or (translate('router.s_d9c4ffa0dedc', 'Acao negada: ') .. err)
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
    rows[#rows + 1] = row('NoClip', translate('router.s_bf6828a57bc4', 'Alterna modo livre autorizado pelo servidor.'), 'person-flying',
      { primary = { action = 'noclip' } })
  end
  if Actions.tpm then
    rows[#rows + 1] = row(translate('router.s_86b143431d4f', 'Teleportar ao waypoint'), translate('router.s_17556bb603fe', 'Vai ate o ponto marcado no mapa.'), 'map-location-dot',
      { primary = { action = 'tpm' } })
  end
  if Actions.tp then
    rows[#rows + 1] = row(translate('router.s_b55ffb57ac71', 'Teleportar por coordenadas'), (translate('router.s_5839bf0b88e6', 'Use /%s x y z [heading].')):format(Config.Commands.tp or 'tp'), 'location-dot',
      { primary = { action = 'tpHelp' } })
  end
  if Actions.loc then
    rows[#rows + 1] = row(translate('router.s_47e07710854c', 'Copiar coordenadas'), translate('router.s_9e5357b3169e', 'Exibe coords de entidade e de solo.'), 'crosshairs',
      { primary = { action = 'loc' } })
  end
  if Actions.heal then
    rows[#rows + 1] = row(translate('router.s_eeba67a999e3', 'Curar a si mesmo'), translate('router.s_a6c30a351d6a', 'Restaura vida, fome e sede.'), 'heart-pulse',
      { primary = { action = 'selfHeal' } })
  end
  if Actions.revive then
    rows[#rows + 1] = row(translate('router.s_85a512b2fdf8', 'Reviver a si mesmo'), translate('router.s_24434430a5ba', 'Conclui o ciclo canonico de respawn.'), 'kit-medical',
      { primary = { action = 'selfRevive' } })
  end
  if Actions.armor then
    rows[#rows + 1] = row(translate('router.s_2365a947e4cd', 'Colete 100'), translate('router.s_be36cdd59a7f', 'Define o colete canonico em 100.'), 'shield',
      { primary = { action = 'selfArmor' } })
  end
  if Actions.godMode then
    rows[#rows + 1] = row('Godmode', translate('router.s_b228ef9be552', 'Alterna invencibilidade local autorizada.'), 'shield-halved',
      { primary = { action = 'selfGodmode' } })
  end
  if Actions.wall then
    rows[#rows + 1] = row('Wall', translate('router.s_f2596f452164', 'Exibe players em tempo real com estado autorizado.'), 'eye',
      { primary = { action = 'wall' } })
  end
  if Actions.spectate then
    rows[#rows + 1] = row(translate('router.s_1d202c1009c7', 'Encerrar spectate'), translate('router.s_de328d585546', 'Retorna a posicao e dimensao originais.'), 'eye-slash',
      { primary = { action = 'spectateStop' } })
  end

  return {
    tab = TAB_MAIN,
    category = TAB_MAIN,
    title = translate('menu.s_f3b86b13dbbc', 'Principal'),
    subtitle = translate('menu.s_6eadd2754722', 'Acoes rapidas da sua sessao'),
    rows = rows,
    empty = translate('router.s_7502f010eeb3', 'Nenhuma acao de sessao autorizada.')
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
  if Actions.gotoPlayer then buttons[#buttons + 1] = btn('goto', translate('router.s_10aae029a54c', 'Ir até'), 'arrow-right') end
  if Actions.bringPlayer then buttons[#buttons + 1] = btn('bring', translate('router.s_aeab6abd2cd9', 'Trazer'), 'users') end
  if Actions.spectate then buttons[#buttons + 1] = btn('spectate', translate('router.s_f66501474ab1', 'Esp.'), 'eye') end
  if Actions.heal then buttons[#buttons + 1] = btn('heal', translate('router.s_da395f9022ff', 'Curar'), 'heart-pulse') end
  if Actions.revive then buttons[#buttons + 1] = btn('revive', translate('router.s_659e476f9aad', 'Reviver'), 'kit-medical') end
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
        or p.name or (online and ('ID ' .. tostring(p.source)) or translate('router.s_4d2c3997653f', 'Character offline'))
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
    title = translate('menu.s_c702ea656c01', 'Jogadores'),
    subtitle = PlayerHint and PlayerHint or (translate('router.s_1e9d28cee237', 'Filtro: %s · %d resultado(s)')):format(PlayerFilter == 'all' and translate('menu.s_a4114a83f4c6', 'Todos') or (PlayerFilter == 'offline' and 'Offline' or 'Online'), #PlayerList),
    searchable = true,
    query = PlayerQuery,
    workspace = true,
    layout = 'grid',
    filters = {
      { id = 'online', label = 'Online' },
      { id = 'offline', label = 'Offline' },
      { id = 'all', label = translate('menu.s_a4114a83f4c6', 'Todos') }
    },
    activeFilter = PlayerFilter,
    rows = rows,
    empty = query == '' and translate('router.s_13e67df939ea', 'Nenhum jogador encontrado.') or translate('router.s_98ba36176f0a', 'Nenhum jogador encontrado para a busca.')
  }
end

-- ---------------------------------------------------------------- player modal

local function promptReason(title, extraRow)
  local rows = type(extraRow) == 'table' and extraRow or {}
  rows[#rows + 1] = {
    type = 'textarea',
    label = translate('menu.s_cbeec536b2f8', 'Motivo'),
    required = true,
    min = 3,
    max = 256,
    description = translate('menu.s_b99d5d3540d4', 'O motivo sera registrado em auditoria.')
  }
  local values = MZAdminUI.InputDialog(title, rows, {
    allowCancel = true,
    labels = { confirm = translate('ui.confirm', 'Confirmar'), cancel = translate('ui.cancel', 'Cancelar') }
  })
  if type(values) ~= 'table' then return nil end
  return values
end

local function buildActionRows(p, online)
  local rows = {}
  local args = { source = online and tonumber(p.source) or nil, citizenid = p.citizenid }

  if online then
    if Actions.gotoPlayer then
      rows[#rows + 1] = row(translate('router.s_0178ee04394c', 'Ir até o player'), translate('router.s_37d64f2e163a', 'O servidor resolve a posicao do alvo.'), 'person-walking-arrow-right',
        { primary = { action = 'goto', args = args } })
    end
    if Actions.bringPlayer then
      rows[#rows + 1] = row(translate('menu.s_ebb84a01ae1e', 'Trazer o player'), translate('router.s_d3ff1d9b732a', 'O servidor resolve a posicao do Staff.'), 'people-arrows-left-right',
        { primary = { action = 'bring', args = args } })
    end
    if Actions.spectate then
      rows[#rows + 1] = row(translate('menu.s_3f19ca6ec09b', 'Espectar o player'), translate('menu.s_4aefc40744f0', 'Protegido por hierarquia e retorno seguro.'), 'binoculars',
        { primary = { action = 'spectate', args = args } })
    end
    if Actions.heal then
      rows[#rows + 1] = row(translate('menu.s_4061a4fcfb15', 'Curar o player'), translate('menu.s_7e99ff5e7cdd', 'Aplica heal no alvo online.'), 'heart-pulse',
        { primary = { action = 'heal', args = args } })
    end
    if Actions.revive then
      rows[#rows + 1] = row(translate('menu.s_bcea19a4cc83', 'Reviver o player'), translate('menu.s_43b12c742fd8', 'Aplica revive no alvo online.'), 'kit-medical',
        { primary = { action = 'revive', args = args } })
    end
    if Context.warningsReady and Actions.warningsIssue then
      rows[#rows + 1] = row(translate('menu.s_2c5414ebdd8e', 'Aplicar advertencia'), translate('router.s_bd983b4e402e', 'Registra motivo e auditoria.'), 'triangle-exclamation',
        { primary = { action = 'warn', args = args }, tone = 'warning' })
    end
    if Actions.kick then
      rows[#rows + 1] = row(translate('menu.s_c147cdf6ea1c', 'Remover o player'), translate('menu.s_8815285e811c', 'Kick protegido por hierarquia e auditoria.'), 'user-xmark',
        { primary = { action = 'kick', args = args }, tone = 'danger' })
    end
    if Context.banGuardReady and Actions.ban then
      rows[#rows + 1] = row(translate('menu.s_e5222ebe5bd0', 'Banir o player'), translate('router.s_0bdec94e9380', 'BanGuard persiste identifiers e auditoria.'), 'user-lock',
        { primary = { action = 'ban', args = args }, tone = 'danger' })
    end
  end

  return rows
end

local function buildInfoRows(p, online)
  local rows = {
    row(translate('router.s_13030dd962f4', 'Nome'), tostring(p.characterName or p.name or '-'), 'user'),
    row('Citizen ID', tostring(p.citizenid or translate('router.s_735388ef2f3c', 'indisponivel')), 'address-card'),
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
    rows[#rows + 1] = row(translate('router.s_4d07517575be', 'Conta'), ('#%s'):format(tostring(p.accountId)), 'id-card')
  end
  if p.characterId then
    rows[#rows + 1] = row(translate('router.s_e5a2a32e47eb', 'Personagem'), ('#%s'):format(tostring(p.characterId)), 'id-card')
  end
  return rows
end

local function buildCharactersRows(p)
  local accountId = tonumber(p.accountId)
  if not accountId then
    return { empty = translate('router.s_6e30bf51fc99', 'Conta nao disponivel para este personagem.') }
  end
  local data, err = awaitCallback('mz_admin:server:getAccountCharacters', accountId)
  if not data then
    return { empty = errorMessage(err) }
  end
  local rows = {}
  for _, char in ipairs(data.characters or {}) do
    local name = (tostring(char.firstname or '') .. ' ' .. tostring(char.lastname or '')):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    rows[#rows + 1] = row(
      name ~= '' and name or (translate('router.s_d6de34bce578', 'Personagem #%s')):format(tostring(char.characterId or '-')),
      ('CID %s · %s'):format(tostring(char.citizenid or '-'), tostring(char.status or 'active')),
      char.citizenid == p.citizenid and 'circle-check' or 'user'
    )
  end
  return { rows = rows, empty = translate('router.s_9d77ede33219', 'Nenhum personagem persistido para esta conta.') }
end

local function buildHistoryRows(p)
  local citizenid = tostring(p.citizenid or '')
  if citizenid == '' then
    return { empty = translate('router.s_79ac9753140d', 'Identidade persistente indisponivel.') }
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
        ('%s · %s'):format(ban.active == true and translate('router.s_8263fde6ccc4', 'Ativo') or translate('router.s_4391b7de4835', 'Revogado'), displayDate(ban.createdAt)),
        ban.active == true and 'lock' or 'unlock'
      )
    end
  end
  return { rows = rows, empty = translate('router.s_3eb59093648b', 'Nenhum historico de warns/bans para este personagem.') }
end

local function buildSecurityRows(p)
  local citizenid = tostring(p.citizenid or '')
  if citizenid == '' or not (Actions.securityAlertsView == true) then
    return { empty = translate('router.s_bff2d538fcef', 'Central de alertas indisponivel para seu contexto.') }
  end
  local data, err = awaitCallback('mz_admin:server:securityIncidentList', { player = citizenid })
  if not data then
    return { empty = errorMessage(err) }
  end
  local rows = {}
  for _, incident in ipairs(data.incidents or {}) do
    rows[#rows + 1] = row(
      ('[%s] %s'):format(tostring(incident.severity or 'info'):upper(), tostring(incident.playerName or incident.citizenid or '-')),
      (translate('router.s_47445204e531', '%s · risco %d')):format(tostring(incident.human and incident.human.title or incident.code or translate('router.s_f430038bf4ad', 'incidente')), tonumber(incident.riskScore) or 0),
      incident.severity == 'critical' and 'triangle-exclamation' or 'shield'
    )
  end
  return { rows = rows, empty = translate('router.s_cbd5ef5ed75f', 'Nenhum incidente de seguranca para este personagem.') }
end

local function buildPunishmentRows(p)
  local citizenid = tostring(p.citizenid or '')
  if citizenid == '' then
    return { empty = translate('router.s_79ac9753140d', 'Identidade persistente indisponivel.') }
  end
  local rows = {}
  if Context.banGuardReady and Actions.banView then
    local bans, _ = awaitCallback('mz_admin:server:listBans', { search = citizenid, page = 1 })
    for _, ban in ipairs(type(bans) == 'table' and bans.items or {}) do
      local buttons = {}
      if ban.active == true and Actions.banRevoke then
        buttons[#buttons + 1] = btn('revokeBan', translate('router.s_d4ec79be0fea', 'Revogar'), 'unlock', 'danger', { publicId = ban.publicId })
      end
      rows[#rows + 1] = row(
        ('%s'):format(tostring(ban.publicId or '-')),
        ('%s · %s'):format(tostring(ban.reason or ''), displayDate(ban.createdAt)),
        ban.active == true and 'lock' or 'unlock',
        { buttons = buttons }
      )
    end
  end
  return { rows = rows, empty = translate('router.s_21671996d6e9', 'Nenhuma punicao ativa para este personagem.') }
end

local function openPlayerModal(p)
  if not p then return end
  SelectedPlayer = p
  local online = p.online == true and tonumber(p.source) and tonumber(p.source) > 0
  local title = (p.characterName and p.characterName ~= '') and p.characterName or p.name or translate('router.s_a87c0c205c1d', 'Jogador')

  MZAdminUI.SetTabletModal({
    title = title,
    subtitle = online and ('Online · ID %s'):format(tostring(p.source)) or translate('router.s_fb9982f5b139', 'Offline · consulta persistida'),
    tabs = {
      { id = 'actions', label = translate('menu.s_66c341b3e963', 'Ações'), icon = 'bolt' },
      { id = 'info', label = translate('menu.s_a3ac9377628f', 'Informações'), icon = 'info' },
      { id = 'characters', label = translate('menu.s_792ba986413d', 'Personagens'), icon = 'users' },
      { id = 'history', label = translate('menu.s_bea29e92ac2b', 'Histórico'), icon = 'history' },
      { id = 'security', label = translate('menu.s_27a0286c70df', 'Segurança'), icon = 'shield' },
      { id = 'punishments', label = translate('menu.s_828cedfdd76d', 'Punições'), icon = 'ban' }
    },
    content = {
      actions = { rows = buildActionRows(p, online), empty = translate('router.s_3f7ec1cebfea', 'Jogador offline: acoes em tempo real indisponiveis.') },
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
  local values = promptReason((translate('router.s_69a3815fa794', 'Remover player (ID %s)')):format(tostring(source)))
  if not values then return end
  local reason = tostring(values[1] or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if #reason < 3 then notify(translate('router.s_53067c623d62', 'Motivo muito curto.'), 'error') return end
  local data, err = awaitCallback('mz_admin:server:tabletKick', source, reason, citizenid)
  if not data then notify(errorMessage(err), 'error') else notify(translate('router.s_7528901eedb7', 'Player removido.'), 'success') end
end

local function banPlayer(args)
  local source, citizenid = targetArgs(args)
  local values = promptReason((translate('router.s_125b2a4ee013', 'Banir player (ID %s)')):format(tostring(source)), {
    { type = 'input', label = translate('menu.s_9bd8554a89a4', 'Duracao'), default = 'perm', required = true, min = 1, max = 16, description = translate('menu.s_9f5bb500ed8c', 'Use perm, 30m, 12h ou 7d.') }
  })
  if not values then return end
  local duration = tostring(values[1] or ''):gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', '')
  local reason = tostring(values[2] or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if duration == '' or #reason < 3 then notify(translate('router.s_e844a2af1255', 'Preencha duracao e motivo.'), 'error') return end
  local data, err = awaitCallback('mz_admin:server:createBan', source, duration, reason, citizenid)
  if not data then notify(errorMessage(err), 'error') else notify((translate('router.s_47b6fffe1309', 'Ban criado: %s')):format(tostring(data.ban and data.ban.publicId or '')), 'success') end
end

local function warnPlayer(args)
  local source, citizenid = targetArgs(args)
  local values = promptReason((translate('router.s_2357eb06bbd7', 'Advertir player (ID %s)')):format(tostring(source)))
  if not values then return end
  local reason = tostring(values[1] or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if #reason < 3 then notify(translate('router.s_53067c623d62', 'Motivo muito curto.'), 'error') return end
  local data, err = awaitCallback('mz_admin:server:issueWarning', source, reason, citizenid)
  if not data then notify(errorMessage(err), 'error') else notify(translate('router.s_f6abd08052e7', 'Advertencia aplicada.'), 'success') end
end

local function revokeBan(publicId)
  local values = promptReason(translate('router.s_3081c2977f16', 'Revogar banimento'))
  if not values then return end
  local reason = tostring(values[1] or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if #reason < 3 then notify(translate('router.s_53067c623d62', 'Motivo muito curto.'), 'error') return end
  local data, err = awaitCallback('mz_admin:server:revokeBan', tostring(publicId):upper(), reason)
  if not data then notify(errorMessage(err), 'error') else notify((translate('router.s_92a63c204352', 'Ban revogado: %s')):format(tostring(publicId)), 'success') end
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
    if not data then notify(errorMessage(err), 'error') else notify(translate('router.s_a0d40fafa6d2', 'Player curado.'), 'success') end
  elseif action == 'revive' then
    local source, citizenid = targetArgs(args)
    local data, err = awaitCallback('mz_admin:server:tabletRevive', source, citizenid)
    if not data then notify(errorMessage(err), 'error') else notify(translate('router.s_4268feb19188', 'Player revivido.'), 'success') end
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
    notify((translate('router.s_8d1a3f92444c', 'Use /%s x y z [heading] para informar as coordenadas.')):format(Config.Commands.tp or 'tp'), 'inform')
  elseif action == 'loc' then
    runClientCommand(Config.Commands.loc or 'loc')
  elseif action == 'wall' then
    runClientCommand(Config.WallCommand or 'wall')
  elseif action == 'spectateStop' then
    local data, err = awaitCallback('mz_admin:server:tabletSpectateStop')
    if not data then notify(errorMessage(err), 'error') end
  elseif action == 'selfHeal' then
    local data, err = awaitCallback('mz_admin:server:tabletHeal', selfTarget(), nil)
    if not data then notify(errorMessage(err), 'error') else notify(translate('router.s_22db1bd461ab', 'Vida restaurada.'), 'success') end
  elseif action == 'selfRevive' then
    local data, err = awaitCallback('mz_admin:server:tabletRevive', selfTarget(), nil)
    if not data then notify(errorMessage(err), 'error') else notify(translate('router.s_8661a35a5c98', 'Revive concluido.'), 'success') end
  elseif action == 'selfArmor' then
    local data, err = awaitCallback('mz_admin:server:tabletArmor', 100)
    if not data then notify(errorMessage(err), 'error') else notify(translate('router.s_663497dc3cde', 'Colete definido para 100.'), 'success') end
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
    { id = TAB_MAIN, label = translate('menu.s_3b2c8bf51797', 'INÍCIO'), icon = 'home' },
    { id = TAB_PLAYERS, label = translate('menu.s_32b8840c22ca', 'JOGADORES'), icon = 'user-search' }
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
    notify(translate('router.s_6f19de0a4ff5', 'Tablet administrativo desativado.'), 'error')
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
          notify(translate('router.s_3151999b88ef', 'Sua permissao administrativa foi revogada ou a sessao expirou.'), 'error')
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
