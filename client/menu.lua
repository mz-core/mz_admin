MZAdminMenu = MZAdminMenu or {}

local ROOT_ID = 'mz_admin:root'
local VEHICLE_SECTION_ID = 'mz_admin:section:vehicles'
local VEHICLE_ID = 'mz_admin:vehicles'
local MANAGEMENT_ID = 'mz_admin:section:management'
local MODERATION_ID = 'mz_admin:section:moderation'
local AUDIT_ID = 'mz_admin:section:audit'
local WORLD_ID = 'mz_admin:world'
local MENU_ACTION_EVENT = 'mz_admin:client:menuAction'
local CurrentActions = {}
local CurrentBanGuardReady = false
local CurrentWarningsReady = false
local CurrentNavigation = {}

local function execute(command, args)
  local line = tostring(command or '')
  if type(args) == 'table' and #args > 0 then
    line = line .. ' ' .. table.concat(args, ' ')
  end
  ExecuteCommand(line)
end

local function input(title, rows)
  return MZAdminUI.InputDialog(title, rows, { allowCancel = true })
end

local function kickAction(selection)
  selection = type(selection) == 'table' and selection or MZAdminPlayerSelector.Select({
    title = 'Selecionar jogador para remover',
    allowOffline = false
  })
  local targetId = selection and tonumber(selection.source)
  if not targetId then return end

  local rows = {
    {
    type = 'textarea',
    label = 'Motivo',
    required = true,
    min = 3,
    max = 256,
    description = 'O motivo sera registrado antes da remocao.'
    }
  }

  local values = input('Remover player da sessao', rows)
  if type(values) ~= 'table' then return end
  local reason = tostring(values[1] or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if #reason < 3 then return end
  TriggerServerEvent(
    'mz_admin:server:kickPlayer',
    math.floor(targetId),
    reason,
    selection.citizenid
  )
end

local function spawnVehicle()
  local values = input('Criar veiculo administrativo', {
    { type = 'input', label = 'Modelo', required = true, min = 1, max = 64 }
  })
  local model = values and tostring(values[1] or '') or ''
  if model == '' then return end
  execute(Config.Commands.spawnVehicle or 'car', { model })
end

local function option(options, condition, data)
  if condition == true then options[#options + 1] = data end
end

local function action(name, payload)
  local args = { action = name }
  for key, value in pairs(type(payload) == 'table' and payload or {}) do
    args[key] = value
  end

  return {
    event = MENU_ACTION_EVENT,
    args = args
  }
end

local function withAction(data, name, payload)
  local binding = action(name, payload)
  data.event = binding.event
  data.args = binding.args
  return data
end

local function registerSelectedPlayerMenu(payload)
  payload = type(payload) == 'table' and payload or {}
  local targetSource = tonumber(payload.source or payload.target)
  local online = payload.online == true and targetSource and targetSource > 0
  local playerName = tostring(payload.characterName or payload.name or payload.citizenid or 'Character')
  local citizenid = tostring(payload.citizenid or ''):gsub('%c', ''):sub(1, 64)
  local accountId = tonumber(payload.accountId)
  local options = {}

  local identity = {
    target = online and math.floor(targetSource) or nil,
    source = online and math.floor(targetSource) or nil,
    name = playerName,
    characterName = playerName,
    citizenid = citizenid,
    accountId = accountId,
    characterId = tonumber(payload.characterId),
    online = online == true,
    ping = math.max(0, tonumber(payload.ping) or 0)
  }

  option(options, online and CurrentActions.gotoPlayer, withAction({
    title = 'Ir ate o player',
    description = 'O servidor resolve a posicao atual do alvo.',
    icon = 'person-walking-arrow-right'
  }, 'gotoSelectedPlayer', identity))
  option(options, online and CurrentActions.bringPlayer, withAction({
    title = 'Trazer o player',
    description = 'O servidor resolve a posicao atual do Staff.',
    icon = 'people-arrows-left-right'
  }, 'bringSelectedPlayer', identity))
  option(options, online and CurrentActions.kick, withAction({
    title = 'Remover o player',
    description = 'Kick protegido por hierarquia e auditoria.',
    icon = 'user-xmark'
  }, 'kickSelectedPlayer', identity))
  option(options, online and CurrentBanGuardReady and CurrentActions.ban, withAction({
    title = 'Banir o player',
    description = 'BanGuard persiste identifiers, tokens e auditoria antes de remover.',
    icon = 'user-lock'
  }, 'banSelectedPlayer', identity))
  option(options, online and CurrentWarningsReady and CurrentActions.warningsIssue, withAction({
    title = 'Aplicar advertencia',
    description = 'Registra motivo e auditoria sem punicao automatica.',
    icon = 'triangle-exclamation'
  }, 'warnSelectedPlayer', identity))
  option(options, CurrentWarningsReady and CurrentActions.warningsView, withAction({
    title = 'Consultar advertencias',
    description = 'Lista o historico persistente desta conta/Character.',
    icon = 'list-check'
  }, 'viewSelectedPlayerWarnings', identity))
  option(options, online and CurrentActions.heal, withAction({
    title = 'Curar o player',
    description = 'Aplica heal no alvo online.',
    icon = 'heart-pulse'
  }, 'healSelectedPlayer', identity))
  option(options, online and CurrentActions.revive, withAction({
    title = 'Reviver o player',
    description = 'Aplica revive no alvo online.',
    icon = 'kit-medical'
  }, 'reviveSelectedPlayer', identity))
  option(options, online and CurrentActions.spectate, withAction({
    title = 'Espectar o player',
    description = 'Protegido por hierarquia e retorno seguro.',
    icon = 'binoculars'
  }, 'spectateSelectedPlayer', identity))

  if #options == 0 then
    options[1] = {
      title = 'Nenhuma acao autorizada',
      description = 'Seu cargo pode consultar o diretorio, mas nao possui uma acao liberada para este jogador.',
      icon = 'lock',
      readOnly = true
    }
  end

  if citizenid ~= '' then
    options[#options + 1] = {
      title = 'Citizen ID', description = citizenid, icon = 'address-card', readOnly = true
    }
  end
  if accountId and CurrentActions.staffManage == true then
    options[#options + 1] = {
      title = 'Account', description = tostring(accountId), icon = 'id-card', readOnly = true
    }
  end

  local contextKey = tostring(payload.characterId or citizenid or targetSource or 'unknown'):gsub('[^%w:_-]', '_')
  local contextId = 'mz_admin:players:selected:' .. contextKey
  MZAdminUI.RegisterContext({
    id = contextId,
    title = playerName,
    subtitle = online and ('Online | Source %d | ping %d ms'):format(targetSource, identity.ping)
      or 'Offline | Character persistente',
    badge = online and 'ONLINE' or 'OFFLINE',
    badgeVariant = online and 'success' or 'muted',
    options = options
  })
  return MZAdminUI.ShowContext(contextId)
end

-- Compatibilidade interna: o caminho canonico de selecao e a aba JOGADORES
-- do MZAdminRouter. Esta funcao permanece apenas para o evento legado
-- mz_admin:client:menuAction (action=onlinePlayers); nao e entrada da rail.
local function openOnlinePlayers()
  local selected = MZAdminPlayerSelector.Select({
    title = 'Selecionar jogador',
    subtitle = 'Online primeiro; offline somente por pesquisa.',
    allowOffline = true
  })
  if not selected then return false end
  return registerSelectedPlayerMenu(selected)
end

AddEventHandler(MENU_ACTION_EVENT, function(payload)
  local selected = type(payload) == 'table' and tostring(payload.action or '') or ''

  if selected == 'tpHelp' then
    MZAdminUI.Notify(
      ('Use /%s x y z [heading] para informar as coordenadas.'):format(Config.Commands.tp or 'tp'),
      'inform'
    )
  elseif selected == 'tpm' then
    execute(Config.Commands.tpm or 'tpm')
  elseif selected == 'onlinePlayers' then
    openOnlinePlayers()
  elseif selected == 'gotoSelectedPlayer' then
    TriggerServerEvent('mz_admin:server:gotoPlayer', math.floor(tonumber(payload.target) or 0), payload.citizenid)
  elseif selected == 'bringSelectedPlayer' then
    TriggerServerEvent('mz_admin:server:bringPlayer', math.floor(tonumber(payload.target) or 0), payload.citizenid)
  elseif selected == 'kickSelectedPlayer' then
    kickAction(payload)
  elseif selected == 'banSelectedPlayer' then
    MZAdminBans.PromptCreate(math.floor(tonumber(payload.target) or 0), payload.citizenid)
  elseif selected == 'warnSelectedPlayer' then
    MZAdminWarnings.PromptIssue(math.floor(tonumber(payload.target) or 0), payload.citizenid)
  elseif selected == 'viewSelectedPlayerWarnings' then
    MZAdminWarnings.OpenForIdentity(payload)
  elseif selected == 'healSelectedPlayer' then
    TriggerServerEvent('mz_admin:server:healPlayer', math.floor(tonumber(payload.target) or 0), payload.citizenid)
  elseif selected == 'reviveSelectedPlayer' then
    TriggerServerEvent('mz_admin:server:revivePlayer', math.floor(tonumber(payload.target) or 0), payload.citizenid)
  elseif selected == 'spectateSelectedPlayer' then
    TriggerServerEvent('mz_admin:server:startSpectate', math.floor(tonumber(payload.target) or 0), payload.citizenid)
  elseif selected == 'spectateStop' then
    execute(Config.SpectateStopCommand or 'specoff')
  elseif selected == 'armor' then
    execute(Config.Commands.armor or 'armor', { 100 })
  elseif selected == 'godMode' then
    execute(Config.Commands.godMode or 'godmode')
  elseif selected == 'spawnVehicle' then
    spawnVehicle()
  elseif selected == 'fixVehicle' then
    execute(Config.Commands.fixVehicle or 'fix')
  elseif selected == 'deleteVehicle' then
    execute(Config.Commands.deleteVehicle or 'dv')
  elseif selected == 'noclip' then
    execute(Config.NoClipCommand or 'noclip')
  elseif selected == 'wall' then
    execute(Config.WallCommand or 'wall')
  elseif selected == 'loc' then
    execute(Config.Commands.loc or 'loc')
  elseif selected == 'staffOrganizations' then
    MZAdminUI.CloseContext()
    -- Delegacao transitoria: fecha o painel unificado antes de abrir o menu
    -- canonico de organizacoes (mz_org revalida sua propria sessao/escopo).
    if MZAdminRouter and type(MZAdminRouter.Close) == 'function' then
      MZAdminRouter.Close()
    end
    -- Garante que nenhuma superficie do mz_admin fique viva caso o roteador
    -- ja estivesse com Open=false por um cleanup anterior.
    if type(MZAdminUI.IsTabletOpen) == 'function' and MZAdminUI.IsTabletOpen() then
      MZAdminUI.CloseTablet()
    end
    execute(Config.StaffOrganizationCommand or 'stafforg')
  elseif selected == 'adminLogs' then
    MZAdminLogs.Open({}, 0, AUDIT_ID)
  elseif selected == 'bans' then
    MZAdminBans.Open({ active = true }, 1)
  elseif selected == 'unbanByPublicId' then
    MZAdminBans.PromptRevoke()
  end
end)

local function registerVehicleMenu(actions, parentId)
  local options = {}
  option(options, actions.spawnVehicle, withAction({
    title = 'Criar veiculo temporario',
    description = 'Cria uma entidade de teste; nao cadastra garagem ou propriedade.',
    icon = 'car'
  }, 'spawnVehicle'))
  option(options, actions.fixVehicle, withAction({
    title = 'Reparar veiculo',
    description = 'Repara o veiculo atual ou o mais proximo.',
    icon = 'screwdriver-wrench'
  }, 'fixVehicle'))
  option(options, actions.deleteVehicle, withAction({
    title = 'Remover veiculo proximo',
    description = 'Remove a entidade atual ou mais proxima.',
    icon = 'trash'
  }, 'deleteVehicle'))

  MZAdminUI.RegisterContext({
    id = VEHICLE_ID,
    menu = parentId,
    title = 'Veículos administrativos',
    subtitle = 'Acoes temporarias sobre entidades',
    options = options
  })
end

local function registerSection(id, title, subtitle, options)
  if type(options) ~= 'table' or #options == 0 then return false end
  MZAdminUI.RegisterContext({
    id = id,
    title = title,
    subtitle = subtitle,
    options = options
  })
  return true
end

function MZAdminMenu.RegisterModules(context)
  context = type(context) == 'table' and context or nil
  if not context then return false, 'permission_denied' end
  local actions = type(context.actions) == 'table' and context.actions or {}
  CurrentActions = actions
  CurrentBanGuardReady = context.banGuardReady == true
  MZAdminBans.Configure(actions, CurrentBanGuardReady, MODERATION_ID)
  local securityAlertsClientAvailable = actions.securityAlertsView == true
    and type(MZAdminSecurityAlerts) == 'table'
    and type(MZAdminSecurityAlerts.Register) == 'function'
    and type(MZAdminSecurityAlerts.GetRootOption) == 'function'
  if securityAlertsClientAvailable then
    MZAdminSecurityAlerts.Register(nil, actions, context.securityCenterAvailable == true)
  end
  local warningsClientAvailable = context.warningsReady == true
    and type(MZAdminWarnings) == 'table'
    and type(MZAdminWarnings.Register) == 'function'
    and type(MZAdminWarnings.GetMenuId) == 'function'
    and type(MZAdminWarnings.PromptIssue) == 'function'
    and type(MZAdminWarnings.OpenForIdentity) == 'function'
    and type(MZAdminWarnings.Open) == 'function'
  CurrentWarningsReady = warningsClientAvailable
  if warningsClientAvailable then
    MZAdminWarnings.Register(MODERATION_ID, actions, true)
  end

  local whitelistClientAvailable = context.whitelistModuleAvailable == true
    and type(MZAdminWhitelist) == 'table'
    and type(MZAdminWhitelist.Register) == 'function'
    and type(MZAdminWhitelist.GetMenuId) == 'function'
  if whitelistClientAvailable then
    MZAdminWhitelist.Register(MODERATION_ID, actions)
  end

  local hasVehicleActions = false
  for _, action in ipairs(MZAdminActionGroups.vehicles or {}) do
    if actions[action] == true then hasVehicleActions = true break end
  end
  if hasVehicleActions then registerVehicleMenu(actions, VEHICLE_SECTION_ID) end
  if context.garageModuleAvailable == true then
    MZAdminGarageWizard.Register(VEHICLE_SECTION_ID, actions)
  end

  local worldClientAvailable = context.worldModuleAvailable == true
    and type(MZAdminWorld) == 'table'
    and type(MZAdminWorld.Register) == 'function'
    and type(MZAdminWorld.GetMenuId) == 'function'
  if worldClientAvailable then
    MZAdminWorld.Register(nil, actions, true, {
      doorsReady = context.worldDoorsReady == true,
      doorsRuntime = context.worldDoorsRuntime == true,
      doorsNativeRuntime = context.worldDoorsNativeRuntime == true,
      propsReady = context.worldPropsReady == true,
      phoneChargingOutletsReady = context.phoneChargingOutletsReady == true,
      furnitureReady = context.furnitureReady == true
    })
  end

  local vehicleOptions = {}
  option(vehicleOptions, hasVehicleActions, {
    title = 'Veículos administrativos',
    description = 'Acoes temporarias sobre entidades.',
    icon = 'car-side',
    menu = VEHICLE_ID,
    arrow = true
  })
  option(vehicleOptions, context.garageModuleAvailable, {
    title = 'Garagens persistentes',
    description = 'Criacao, edicao e ciclo de vida de garagens.',
    icon = 'warehouse',
    menu = MZAdminGarageWizard.GetMenuId(),
    arrow = true
  })

  if context.staffManagementAvailable == true then
    MZAdminStaffManagement.Register(MANAGEMENT_ID)
  end
  local managementOptions = {}
  option(managementOptions, context.organizationAccess, withAction({
    title = 'Administrar organizacoes',
    description = 'Abre o Staff Menu do mz_org, que revalida sua propria sessao.',
    icon = 'building-shield'
  }, 'staffOrganizations'))
  option(managementOptions, context.staffManagementAvailable, {
    title = 'Gerenciar equipe Staff',
    description = 'Cargos globais, hierarquia, permissoes e atribuicoes.',
    icon = 'user-shield',
    menu = MZAdminStaffManagement.GetMenuId(),
    arrow = true
  })

  local moderationOptions = {}
  option(moderationOptions, context.banModuleAvailable, withAction({
    title = 'Banimentos',
    description = 'Consulta e revogacao pelo contrato oficial do MZ BanGuard.',
    icon = 'shield-virus'
  }, 'bans'))
  option(moderationOptions, CurrentBanGuardReady and actions.banRevoke, withAction({
    title = 'Desbanir por Public ID',
    description = 'Informe o codigo MBG e o motivo da revogacao.',
    icon = 'user-check'
  }, 'unbanByPublicId'))
  option(moderationOptions, whitelistClientAvailable, {
    title = 'Whitelist',
    description = 'Solicitacoes de entrada, aprovacoes, recusas e revogacoes.',
    icon = 'user-shield',
    menu = MZAdminWhitelist.GetMenuId(),
    arrow = true
  })
  option(moderationOptions, warningsClientAvailable and context.warningsModuleAvailable == true, {
    title = 'Advertencias',
    description = 'Consulta, aplicacao e revogacao conforme permissoes separadas.',
    icon = 'triangle-exclamation',
    menu = MZAdminWarnings.GetMenuId(),
    arrow = true
  })

  local auditOptions = {}
  option(auditOptions, actions.logsView, withAction({
    title = 'Logs administrativos',
    description = 'Eventos globais da Staff com filtros e paginacao.',
    icon = 'clipboard-list'
  }, 'adminLogs'))

  local rootOptions = {}
  option(rootOptions, worldClientAvailable, {
    title = 'Mundo e cenários',
    description = context.worldDoorsRuntime == true
      and 'Portas, props e ferramentas de edicao visual.'
      or 'Configuracao V2 disponivel; runtime ainda em modo seguro.',
    icon = 'earth-americas',
    menu = WORLD_ID,
    arrow = true
  })
  option(rootOptions, registerSection(
    VEHICLE_SECTION_ID,
    'Veículos e garagens',
    'Entidades temporarias e estruturas persistentes',
    vehicleOptions
  ), {
    title = 'Veículos e garagens',
    description = 'Ferramentas de veiculo e gerenciamento de garagens.',
    icon = 'warehouse',
    menu = VEHICLE_SECTION_ID,
    arrow = true
  })
  option(rootOptions, registerSection(
    MANAGEMENT_ID,
    'Organizações e equipe',
    'Estrutura organizacional e hierarquia Staff',
    managementOptions
  ), {
    title = 'Organizações e equipe',
    description = 'Organizacoes, cargos, permissoes e atribuicoes Staff.',
    icon = 'building-shield',
    menu = MANAGEMENT_ID,
    arrow = true
  })
  option(rootOptions, registerSection(
    MODERATION_ID,
    'Moderação e acesso',
    'Banimentos, whitelist e advertencias',
    moderationOptions
  ), {
    title = 'Moderação e acesso',
    description = 'Punicoes administrativas e controle de entrada.',
    icon = 'shield-halved',
    menu = MODERATION_ID,
    arrow = true
  })
  option(rootOptions, registerSection(
    AUDIT_ID,
    'Auditoria',
    'Consulta de eventos administrativos globais',
    auditOptions
  ), {
    title = 'Auditoria',
    description = 'Logs globais, filtros e rastreabilidade.',
    icon = 'clipboard-list',
    menu = AUDIT_ID,
    arrow = true
  })
  if securityAlertsClientAvailable then
    local securityOption = MZAdminSecurityAlerts.GetRootOption()
    if securityOption then rootOptions[#rootOptions + 1] = securityOption end
  end

  if #rootOptions == 0 then
    rootOptions[1] = {
      title = 'Nenhuma area autorizada',
      description = 'O acesso ao painel nao concede permissoes operacionais.',
      icon = 'lock',
      readOnly = true
    }
  end

  CurrentNavigation = {}
  for _, rootOption in ipairs(rootOptions) do
    if rootOption.menu then
      CurrentNavigation[#CurrentNavigation + 1] = {
        id = rootOption.menu,
        label = rootOption.title,
        icon = rootOption.icon
      }
    end
  end

  -- Compatibilidade: o root nao e uma entrada da rail. Ele permanece
  -- registrado apenas para ShowContext/eventos legados; a navegacao principal
  -- e a rail de dominios montada por GetNavigationTabs.
  MZAdminUI.RegisterContext({
    id = ROOT_ID,
    title = 'Administração',
    subtitle = 'Central operacional da MZ Framework',
    brand = 'MZ Admin',
    headerIcon = 'shield-halved',
    badge = 'STAFF',
    searchable = true,
    searchPlaceholder = 'Buscar ferramenta, modulo ou acao...',
    theme = {
      accent = '#009FE3',
      accent2 = '#67C9F1',
      position = 'left',
      width = 420
    },
    options = rootOptions
  })
  return true
end

function MZAdminMenu.GetNavigationTabs()
  local tabs = {}
  for index, item in ipairs(CurrentNavigation) do
    tabs[index] = { id = item.id, label = item.label, icon = item.icon }
  end
  return tabs
end

function MZAdminMenu.Open()
  -- Unico owner de abertura: o MZAdminRouter. O fallback por ContextStore
  -- existe somente para ambientes onde o roteador ainda nao foi carregado.
  if MZAdminRouter and type(MZAdminRouter.Open) == 'function' then
    return MZAdminRouter.Open('blocked')
  end

  if type(MZAdminUI) ~= 'table' then return false, 'admin_ui_unavailable' end

  local context = MZAdminClient.GetMenuContext()
  if not context then return false, 'permission_denied' end

  local ok = MZAdminMenu.RegisterModules(context)
  if not ok then return false, 'permission_denied' end

  return MZAdminUI.ShowContext(ROOT_ID)
end

RegisterCommand(Config.AdminCommand or 'admin', function()
  if MZAdminRouter and type(MZAdminRouter.Open) == 'function' then
    MZAdminRouter.Open('blocked')
  else
    MZAdminMenu.Open()
  end
end, false)

exports('OpenAdminMenu', function()
  if MZAdminRouter and type(MZAdminRouter.Open) == 'function' then
    return MZAdminRouter.Open('blocked')
  end
  return MZAdminMenu.Open()
end)

exports('CloseAdminMenu', function()
  return MZAdminRouter and MZAdminRouter.Close and MZAdminRouter.Close() or false
end)

exports('ToggleAdminMenu', function()
  return MZAdminRouter and MZAdminRouter.Toggle and MZAdminRouter.Toggle('blocked') or false
end)

exports('IsAdminMenuOpen', function()
  return MZAdminRouter and MZAdminRouter.IsOpen and MZAdminRouter.IsOpen() or false
end)

AddEventHandler('mz_admin:client:openAdmin', function()
  if MZAdminRouter and MZAdminRouter.Open then MZAdminRouter.Open('blocked') end
end)

AddEventHandler('mz_admin:client:closeAdmin', function()
  if MZAdminRouter and MZAdminRouter.Close then MZAdminRouter.Close() end
end)

AddEventHandler('mz_admin:client:toggleAdmin', function()
  if MZAdminRouter and MZAdminRouter.Toggle then MZAdminRouter.Toggle('blocked') end
end)
