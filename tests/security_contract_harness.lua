local callbacks = {}
local events = {}
local exported = {}
local clientEvents = {}
local granted = {}
local timer = 0
local coreStarted = true
local garageStarted = true
local garageReady = true
local banGuardStarted = false
local banGuardReady = false
local auditAvailable = true
local stateMutationAllowed = true
local survivalMutationAllowed = true
local survivalRestores = {}
local auditLogs = {}
local hierarchyAllowed = true
local hierarchyReason = 'target_not_staff'
local actorPedAvailable = true
local routingBuckets = { [1] = 0, [2] = 7 }
local capturedLogFilters
local droppedPlayers = {}
local targetCitizenid = 'PLAYER002'
local hierarchyContext = {
  relationship = 'target_not_staff',
  actor = {
    source = 1,
    citizenid = 'STAFF001',
    name = 'Staff Test',
    owner = false,
    staff = true,
    level = 700,
    role = { code = 'administrador', name = 'Administrador', level = 700 }
  },
  target = {
    source = 2,
    citizenid = 'PLAYER002',
    name = 'Player Test',
    owner = false,
    staff = false,
    level = 0
  }
}
local capturedThreads = {}

function GetConvarInt(_, defaultValue) return defaultValue end

local function expect(condition, message)
  if not condition then error(message, 2) end
end

lib = {
  callback = {
    register = function(name, handler)
      callbacks[name] = handler
    end
  }
}

exports = setmetatable({
  mz_core = {
    HasGlobalPermission = function(_, sourceId, permission)
      return sourceId == 1 and granted[permission] == true
    end,
    CanStaffActOnPlayer = function(_, actorSource, targetSource)
      if actorSource ~= 1 or targetSource ~= 2 then return false, 'invalid_test_target' end
      return hierarchyAllowed, hierarchyReason, hierarchyContext
    end,
    GetStaffContext = function(_, sourceId)
      if sourceId ~= 1 then return nil end
      return {
        owner = false,
        citizenid = 'STAFF001',
        role = { code = 'administrador', name = 'Administrador', level = 700 }
      }
    end,
    ResolvePlayerIdentity = function(_, sourceId)
      if sourceId == 1 then return { ok = true, citizenid = 'STAFF001', accountId = 10, characterId = 100, firstname = 'Staff', lastname = 'Test' } end
      if sourceId == 2 then return { ok = true, citizenid = targetCitizenid, accountId = 20, characterId = 200, firstname = 'Player', lastname = 'Test' } end
      return { ok = false, error = 'not_found' }
    end,
    SearchCharacters = function(_, search, page, pageSize)
      if search ~= 'mateus' then return { items = {}, total = 0, page = page, pageSize = pageSize, hasMore = false } end
      return {
        items = {
          { characterId = 300, accountId = 30, citizenid = 'MATEUS003', firstname = 'Mateus', lastname = 'Queiroz' }
        },
        total = 1,
        page = page,
        pageSize = pageSize,
        hasMore = false
      }
    end,
    CreateDetailedLog = function(_, scope, action, payload)
      if not auditAvailable then return nil end
      auditLogs[#auditLogs + 1] = { scope = scope, action = action, payload = payload }
      return #auditLogs
    end,
    SetStatus = function(_, targetSource, statusName, value, context)
      if not stateMutationAllowed then return false, { code = 'forced_core_failure' } end
      local heal = targetSource == 2 and statusName == 'health' and value == 200
        and type(context) == 'table' and context.reason == 'admin_heal'
      local armor = targetSource == 1 and statusName == 'armor' and value == 75
        and type(context) == 'table' and context.reason == 'admin_armor'
      if not heal and not armor then
        return false, { code = 'invalid_test_state_call' }
      end
      return true, { changed = true, revision = 1 }
    end,
    RevivePlayer = function(_, targetSource, context)
      if not stateMutationAllowed then return false, { code = 'forced_core_failure' } end
      if targetSource ~= 2 or type(context) ~= 'table' or context.administrative ~= true then
        return false, { code = 'invalid_test_state_call' }
      end
      return true, { changed = true, revision = 1 }
    end,
    ListGlobalLogsSecure = function(_, sourceId, filters)
      if sourceId ~= 1 then return false, 'forbidden' end
      capturedLogFilters = filters
      return {
        {
          id = 91,
          createdAt = '2026-07-27 12:00:00',
          category = 'admin',
          action = 'admin.spectate.started',
          severity = 'info',
          scope = 'global',
          actorName = 'Staff Test',
          targetName = 'Player Test',
          reason = 'target_not_staff'
        }
      }
    end,
    ListOrgs = function()
      return {
        { code = 'mafia', name = 'Mafia', type = 'gang', active = true },
        { code = 'arquivo', name = 'Arquivo', type = 'job', active = false }
      }
    end,
    ListStaffManagement = function(_, sourceId)
      return sourceId == 1, sourceId == 1 and { roles = {}, assignments = {}, catalog = {} } or 'permission_denied'
    end,
    CreateStaffRole = function(_, sourceId, payload)
      return sourceId == 1, sourceId == 1 and { code = payload.code } or 'permission_denied'
    end,
    UpdateStaffRole = function(_, sourceId, code, payload)
      return sourceId == 1, sourceId == 1 and { code = code, name = payload.name } or 'permission_denied'
    end,
    SetStaffRolePermissions = function(_, sourceId, code, permissions)
      return sourceId == 1, sourceId == 1 and { code = code, permissions = permissions } or 'permission_denied'
    end,
    AssignStaffRole = function(_, sourceId, accountId, roleCode)
      return sourceId == 1, sourceId == 1 and { accountId = accountId, roleCode = roleCode } or 'permission_denied'
    end,
    RevokeStaffRole = function(_, sourceId, accountId)
      return sourceId == 1, sourceId == 1 and { accountId = accountId, active = false } or 'permission_denied'
    end
  },
  mz_garagem = {
    IsManagedGarageReady = function()
      return garageReady
    end,
    CreateManagedGarage = function(_, sourceId, payload)
      if sourceId ~= 1 or type(payload) ~= 'table' then return false, 'invalid_payload' end
      return true, { id = payload.code, kind = payload.kind }
    end,
    ListManagedGaragesForAdmin = function(_, sourceId)
      if sourceId ~= 1 then return false, 'permission_denied' end
      return true, {
        { code = 'central', label = 'Garagem Pública', kind = 'public', active = true }
      }
    end,
    UpdateManagedGarage = function(_, sourceId, code, payload)
      if sourceId ~= 1 then return false, 'permission_denied' end
      return true, { code = code, label = payload.label, active = true }
    end,
    SetManagedGarageActive = function(_, sourceId, code, active)
      if sourceId ~= 1 then return false, 'permission_denied' end
      return true, { code = code, active = active }
    end
  },
  mz_org = {
    ListOrgs = function()
      return {
        { code = 'mafia', name = 'Mafia', type = 'gang', active = true },
        { code = 'arquivo', name = 'Arquivo', type = 'job', active = false }
      }
    end
  },
  mz_status = {
    RestoreSurvivalStatus = function(_, targetSource, context)
      survivalRestores[#survivalRestores + 1] = { target = targetSource, context = context }
      if not survivalMutationAllowed then return false, { code = 'forced_status_failure' } end
      if targetSource ~= 2 or type(context) ~= 'table' or context.actorSource ~= 1 then
        return false, { code = 'invalid_test_status_call' }
      end
      return true, { changed = true, revision = 2 }
    end
  },
  mz_banguard = {
    IsReady = function()
      return banGuardReady
    end
  }
}, {
  __call = function(_, name, handler)
    exported[name] = handler
  end
})

function GetResourceState(resource)
  if resource == 'mz_core' then return coreStarted and 'started' or 'missing' end
  if resource == 'mz_status' then return 'started' end
  if resource == 'mz_garagem' then return garageStarted and 'started' or 'missing' end
  if resource == 'mz_banguard' then return banGuardStarted and 'started' or 'missing' end
  return 'missing'
end

function GetGameTimer()
  timer = timer + 200
  return timer
end

function RegisterNetEvent(name, handler)
  events[name] = handler
end

function AddEventHandler(name, handler)
  events[name] = handler
end

function TriggerClientEvent(name, target, ...)
  clientEvents[#clientEvents + 1] = { name = name, target = target, args = { ... } }
end

function DropPlayer(target, reason)
  droppedPlayers[#droppedPlayers + 1] = {
    target = tonumber(target),
    reason = tostring(reason or '')
  }
end

function CreateThread(handler)
  capturedThreads[#capturedThreads + 1] = handler
end

function Wait()
end

function GetPlayerPing(target)
  target = tonumber(target)
  if target == 1 then return 15 end
  if target == 2 then return 30 end
  return 0
end

function GetPlayers()
  return { '2', '1' }
end

function GetPlayerName(target)
  return tonumber(target) == 1 and 'Staff Test' or tonumber(target) == 2 and 'Player Test' or nil
end

function GetPlayerPed(target)
  if tonumber(target) == 1 then return actorPedAvailable and 101 or 0 end
  return tonumber(target) == 2 and 202 or 0
end

function GetEntityCoords(ped)
  return { x = ped + 0.1, y = ped + 0.2, z = ped + 0.3 }
end

function GetEntityHeading(ped)
  return ped + 0.4
end

function GetPlayerRoutingBucket(target)
  return routingBuckets[tonumber(target)] or 0
end

function SetPlayerRoutingBucket(target, bucket)
  routingBuckets[tonumber(target)] = tonumber(bucket) or 0
end

function GetCurrentResourceName()
  return 'mz_admin'
end

dofile('mz_admin/shared/config.lua')
dofile('mz_admin/shared/permissions.lua')
dofile('mz_admin/server/security.lua')
dofile('mz_admin/server/staff.lua')
dofile('mz_admin/server/logs.lua')
dofile('mz_admin/server/garages.lua')
dofile('mz_admin/server/wall.lua')
dofile('mz_admin/server/spectate.lua')
dofile('mz_admin/server/main.lua')

expect(MZAdminPermissions.loc == 'staff.coords.copy', 'loc nao usa permissao granular')
expect(MZAdminPermissions.noclip == 'staff.noclip', 'noclip nao usa permissao granular')
expect(MZAdminPermissions.wall == 'staff.wall', 'wall nao usa permissao granular')
expect(MZAdminPermissions.spectate == 'staff.spectate', 'spectate nao usa permissao granular')
expect(MZAdminPermissions.logsView == 'staff.logs.view', 'logs nao usam permissao granular')
expect(MZAdminPermissions.kick == 'staff.players.kick', 'kick nao usa permissao granular')
expect(MZAdminPermissions.ban == 'staff.players.ban', 'ban nao usa permissao granular')
expect(MZAdminPermissions.banView == 'staff.bans.view', 'consulta de ban nao usa permissao granular')
expect(MZAdminPermissions.banRevoke == 'staff.bans.revoke', 'revogacao de ban nao usa permissao granular')
expect(MZAdminPermissions.tp == 'staff.teleport' and MZAdminPermissions.tpm == 'staff.teleport', 'teleporte nao usa permissao dedicada')
expect(MZAdminPermissions.playersList == 'staff.players.list', 'lista de players nao usa permissao dedicada')
expect(MZAdminPermissions.gotoPlayer == 'staff.players.goto', 'goto nao usa permissao dedicada')
expect(MZAdminPermissions.bringPlayer == 'staff.players.bring', 'bring nao usa permissao dedicada')
expect(MZAdminPermissions.heal == 'staff.players.heal', 'heal nao usa permissao dedicada')
expect(MZAdminPermissions.revive == 'staff.players.revive', 'revive nao usa permissao dedicada')
expect(MZAdminPermissions.spawnVehicle == 'staff.vehicles.spawn', 'spawn de veiculo nao usa permissao dedicada')
expect(MZAdminPermissions.fixVehicle == 'staff.vehicles.repair', 'reparo de veiculo nao usa permissao dedicada')
expect(MZAdminPermissions.tuneVehicle == 'staff.vehicles.tune', 'tuning de veiculo nao usa permissao dedicada')
expect(MZAdminPermissions.deleteVehicle == 'staff.vehicles.delete', 'delete de veiculo nao usa permissao dedicada')
expect(MZAdminPermissions.staffManage == 'staff.roles.manage', 'gestao Staff ainda usa permissao antiga')

expect(type(callbacks['mz_admin:server:authorizeAction']) == 'function', 'callback de autorizacao ausente')
expect(type(callbacks['mz_admin:server:getMenuContext']) == 'function', 'callback de menu ausente')
expect(type(callbacks['mz_admin:server:toggleNoClip']) == 'function', 'callback de noclip ausente')
expect(type(callbacks['mz_admin:server:toggleWall']) == 'function', 'callback de wall ausente')
expect(type(callbacks['mz_admin:server:listOnlinePlayers']) == 'function', 'callback de players ausente')
expect(type(callbacks['mz_admin:server:searchPlayers']) == 'function', 'callback do Player Selector ausente')
expect(type(callbacks['mz_admin:server:listGarageOrganizations']) == 'function', 'callback de organizacoes para garagem ausente')
expect(type(callbacks['mz_admin:server:createManagedGarage']) == 'function', 'callback de criacao de garagem ausente')
expect(type(callbacks['mz_admin:server:listManagedGarages']) == 'function', 'callback de listagem de garagem ausente')
expect(type(callbacks['mz_admin:server:updateManagedGarage']) == 'function', 'callback de edicao de garagem ausente')
expect(type(callbacks['mz_admin:server:setManagedGarageActive']) == 'function', 'callback de ciclo de vida ausente')
expect(type(callbacks['mz_admin:server:listStaffManagement']) == 'function', 'callback de hierarquia Staff ausente')
expect(type(callbacks['mz_admin:server:listAdminLogs']) == 'function', 'callback de logs administrativos ausente')
expect(type(exported.IsPlayerInNoClip) == 'function', 'export legado de noclip ausente')
expect(type(exported.IsPlayerUsingWall) == 'function', 'export de estado do wall ausente')
expect(type(exported.IsPlayerSpectating) == 'function', 'export de estado do spectate ausente')
expect(type(exported.GetSpectateTarget) == 'function', 'export de alvo do spectate ausente')

local unknown = callbacks['mz_admin:server:authorizeAction'](1, 'invented')
expect(unknown.ok == false and unknown.error == 'invalid_action', 'acao desconhecida nao falhou fechado')

local denied = callbacks['mz_admin:server:authorizeAction'](1, 'tp')
expect(denied.ok == false and denied.error == 'permission_denied', 'tp sem permissao foi autorizado')

local logsDenied = callbacks['mz_admin:server:listAdminLogs'](1, {})
expect(logsDenied.ok == false and logsDenied.error == 'permission_denied', 'logs sem permissao foram expostos')

granted['staff.logs.view'] = true
local adminLogs = callbacks['mz_admin:server:listAdminLogs'](1, {
  search = string.rep('x', 120),
  offset = 12,
  limit = 999,
  orgCode = 'mafia',
  auditOnly = true,
  invented = 'ignored'
})
expect(adminLogs.ok == true and adminLogs.data.scope == 'global', 'logs globais autorizados nao foram listados')
expect(adminLogs.data.items[1].action == 'admin.spectate.started', 'DTO de logs foi alterado')
expect(capturedLogFilters.limit == 25 and capturedLogFilters.offset == 12, 'paginacao de logs nao foi normalizada')
expect(#capturedLogFilters.search == 80, 'busca de logs nao foi limitada')
expect(capturedLogFilters.auditOnly == true, 'filtro auditOnly foi perdido')
expect(capturedLogFilters.orgCode == nil and capturedLogFilters.invented == nil, 'payload inventou escopo de logs')

granted['staff.teleport'] = true
coreStarted = false
local unavailable = callbacks['mz_admin:server:authorizeAction'](1, 'tpm')
expect(unavailable.ok == false and unavailable.error == 'permission_denied', 'falha do mz_core nao negou')
coreStarted = true
granted['staff.teleport'] = nil

granted['staff.panel.open'] = true
local menu = callbacks['mz_admin:server:getMenuContext'](1)
expect(menu.ok == true, 'menu com staff.panel.open foi negado')
expect(menu.data.actions.menu == true, 'grant do menu nao foi refletido')
expect(menu.data.actions.tp == false, 'tp apareceu sem staff.teleport')
expect(menu.data.organizationAccess == false, 'atalho de org apareceu sem permissao org')
expect(menu.data.garageCreationAvailable == false, 'garagem inexistente apareceu disponivel')
expect(menu.data.banGuardReady == false and menu.data.banModuleAvailable == false, 'BanGuard ausente apareceu no menu')

granted['staff.bans.view'] = true
banGuardStarted = true
banGuardReady = true
menu = callbacks['mz_admin:server:getMenuContext'](1)
expect(menu.ok == true and menu.data.banModuleAvailable == true, 'BanGuard pronto nao apareceu com permissao')
banGuardReady = false
menu = callbacks['mz_admin:server:getMenuContext'](1)
expect(menu.ok == true and menu.data.banModuleAvailable == false, 'BanGuard sem schema apareceu no menu')
banGuardStarted = false
granted['staff.bans.view'] = nil

granted['staff.orgs.view'] = true
menu = callbacks['mz_admin:server:getMenuContext'](1)
expect(menu.ok == true and menu.data.organizationAccess == true, 'atalho org nao refletiu grant real')

granted['staff.garages.create'] = true
menu = callbacks['mz_admin:server:getMenuContext'](1)
expect(menu.ok == true and menu.data.garageCreationAvailable == true, 'garagem pronta nao apareceu com permissao')
expect(menu.data.garageModuleAvailable == true, 'modulo de garagem nao apareceu com permissao de criacao')
garageReady = false
menu = callbacks['mz_admin:server:getMenuContext'](1)
expect(menu.ok == true and menu.data.garageCreationAvailable == false, 'garagem indisponivel apareceu no menu')
garageReady = true

local garageOrgs = callbacks['mz_admin:server:listGarageOrganizations'](1)
expect(garageOrgs.ok == true and #garageOrgs.data.organizations == 1, 'seletor nao filtrou organizacoes ativas')
expect(garageOrgs.data.organizations[1].code == 'mafia', 'seletor alterou o DTO da organizacao')

local garageCreate = callbacks['mz_admin:server:createManagedGarage'](1, { code = 'mafia_sede', kind = 'org' })
expect(garageCreate.ok == true and garageCreate.data.garage.id == 'mafia_sede', 'criacao autorizada nao delegou ao mz_garagem')

granted['staff.garages.view'] = true
local managedList = callbacks['mz_admin:server:listManagedGarages'](1)
expect(managedList.ok == true and managedList.data.garages[1].code == 'central', 'listagem nao delegou ao mz_garagem')

granted['staff.garages.manage'] = true
local managedUpdate = callbacks['mz_admin:server:updateManagedGarage'](1, 'central', { label = 'Editada' })
expect(managedUpdate.ok == true and managedUpdate.data.garage.label == 'Editada', 'edicao nao delegou ao mz_garagem')
local managedState = callbacks['mz_admin:server:setManagedGarageActive'](1, 'central', false)
expect(managedState.ok == true and managedState.data.garage.active == false, 'arquivamento nao delegou ao mz_garagem')

granted['staff.roles.manage'] = true
local staffList = callbacks['mz_admin:server:listStaffManagement'](1)
expect(staffList.ok == true and type(staffList.data.roles) == 'table', 'listagem Staff nao delegou ao core')
local staffRole = callbacks['mz_admin:server:createStaffRole'](1, { code = 'mod' })
expect(staffRole.ok == true and staffRole.data.code == 'mod', 'criacao de cargo Staff nao delegou ao core')
local staffUpdate = callbacks['mz_admin:server:updateStaffRole'](1, 'mod', { name = 'Moderador' })
expect(staffUpdate.ok == true and staffUpdate.data.name == 'Moderador', 'edicao de cargo Staff nao delegou ao core')
local staffPermissions = callbacks['mz_admin:server:setStaffRolePermissions'](1, 'mod', { 'staff.panel.open' }, 'teste')
expect(
  staffPermissions.ok == true and staffPermissions.data.permissions[1] == 'staff.panel.open',
  'permissoes de cargo Staff nao delegaram ao core'
)
local staffAssignment = callbacks['mz_admin:server:assignStaffRole'](1, 101, 'mod', 'teste')
expect(
  staffAssignment.ok == true and staffAssignment.data.accountId == 101,
  'atribuicao Staff nao delegou ao core'
)
local staffRevocation = callbacks['mz_admin:server:revokeStaffRole'](1, 'PLAYER001', 'teste')
expect(
  staffRevocation.ok == true and staffRevocation.data.active == false,
  'revogacao Staff nao delegou ao core'
)

source = 1
events['mz_admin:server:bringPlayer'](2, { x = 9999, y = 9999, z = 9999 }, 9999)
expect(#clientEvents == 1 and clientEvents[1].name == 'chat:addMessage', 'bring sem permissao nao foi negado')
expect(
  auditLogs[#auditLogs] and auditLogs[#auditLogs].action == 'admin.player.bring.denied'
    and auditLogs[#auditLogs].payload.context.permission == 'staff.players.bring',
  'negacao de bring nao foi auditada com permissao'
)

granted['staff.roles.manage'] = nil
local selectorDenied = callbacks['mz_admin:server:searchPlayers'](1, { query = 'player', filter = 'all' })
expect(selectorDenied.ok == false and selectorDenied.error == 'permission_denied', 'Player Selector sem permissao expôs jogadores')

granted['staff.players.list'] = true
granted['staff.players.bring'] = true
granted['staff.players.heal'] = true
granted['staff.players.armor'] = true
granted['staff.players.revive'] = true
local online = callbacks['mz_admin:server:listOnlinePlayers'](1)
expect(online.ok == true and online.data.total == 2, 'lista online nao retornou players validos')
expect(online.data.players[1].source == 1 and online.data.players[1].self == true, 'lista online nao ordenou/marcou o Staff')
expect(online.data.players[2].source == 2 and online.data.players[2].name == 'Player Test', 'lista online vazou ou perdeu DTO')
expect(online.data.players[1].citizenid == 'STAFF001', 'lista online nao resolveu CitizenID do Staff')
expect(online.data.players[2].citizenid == 'PLAYER002', 'lista online nao resolveu CitizenID do player')

local onlineByName = callbacks['mz_admin:server:searchPlayers'](1, { query = 'player', filter = 'online' })
expect(onlineByName.ok == true and #onlineByName.data.items == 1 and onlineByName.data.items[1].source == 2, 'busca online por nome falhou')
local onlineByCitizen = callbacks['mz_admin:server:searchPlayers'](1, { query = 'player002', filter = 'online' })
expect(onlineByCitizen.ok == true and onlineByCitizen.data.items[1].citizenid == 'PLAYER002', 'busca online por citizenid falhou')
local onlineBySource = callbacks['mz_admin:server:searchPlayers'](1, { query = '2', filter = 'online' })
expect(onlineBySource.ok == true and onlineBySource.data.items[1].source == 2, 'busca online por source falhou')

local offlineSearch = callbacks['mz_admin:server:searchPlayers'](1, {
  query = 'mateus', filter = 'all', page = 1, pageSize = 25
})
expect(offlineSearch.ok == true and offlineSearch.data.total == 1, 'busca offline paginada falhou')
expect(#offlineSearch.data.items == 1 and offlineSearch.data.items[1].citizenid == 'MATEUS003', 'busca offline perdeu DTO do Character')
expect(offlineSearch.data.items[1].online == false and offlineSearch.data.items[1].source == nil, 'Character offline ganhou sessao inventada')

clientEvents = {}
events['mz_admin:server:bringPlayer'](2, 'OUTRO_CHARACTER')
expect(#clientEvents == 1 and clientEvents[1].name == 'chat:addMessage', 'source reutilizado nao foi rejeitado')
expect(auditLogs[#auditLogs].payload.meta.reason == 'stale_target', 'source stale nao foi auditado')

clientEvents = {}
events['mz_admin:server:bringPlayer'](2, { x = 9999, y = 9999, z = 9999 }, 9999)
expect(#clientEvents == 1, 'bring autorizado nao produziu um unico evento')
expect(clientEvents[1].name == 'mz_admin:client:teleportToCoords', 'bring nao usou evento oficial')
expect(clientEvents[1].target == 2, 'bring enviou para alvo incorreto')
expect(clientEvents[1].args[1].x == 101.1, 'bring confiou nas coordenadas do cliente')
expect(clientEvents[1].args[2] == 101.4, 'bring confiou no heading do cliente')
expect(
  auditLogs[#auditLogs] and auditLogs[#auditLogs].action == 'admin.player.bring.authorized'
    and auditLogs[#auditLogs].payload.context.relationship == 'target_not_staff'
    and auditLogs[#auditLogs].payload.actor.level == 700,
  'bring autorizado nao registrou hierarquia'
)

hierarchyAllowed = false
hierarchyReason = 'target_higher_or_equal'
hierarchyContext.relationship = hierarchyReason
hierarchyContext.target.staff = true
hierarchyContext.target.level = 700
hierarchyContext.target.role = { code = 'administrador', name = 'Administrador', level = 700 }
clientEvents = {}
events['mz_admin:server:bringPlayer'](2)
expect(
  #clientEvents == 1 and clientEvents[1].name == 'chat:addMessage',
  'bring contra Staff igual nao foi bloqueado'
)
expect(
  auditLogs[#auditLogs] and auditLogs[#auditLogs].action == 'admin.player.bring.denied'
    and auditLogs[#auditLogs].payload.meta.reason == 'target_higher_or_equal',
  'negacao hierarquica nao foi auditada'
)

hierarchyAllowed = true
hierarchyReason = 'target_not_staff'
hierarchyContext.relationship = hierarchyReason
hierarchyContext.target.staff = false
hierarchyContext.target.level = 0
hierarchyContext.target.role = nil
actorPedAvailable = false
clientEvents = {}
events['mz_admin:server:bringPlayer'](2)
expect(
  #clientEvents == 1 and clientEvents[1].name == 'chat:addMessage',
  'bring sem ped do ator nao foi cancelado'
)
expect(
  auditLogs[#auditLogs] and auditLogs[#auditLogs].action == 'admin.player.bring.denied'
    and auditLogs[#auditLogs].payload.meta.reason == 'actor_ped_unavailable',
  'falha de preflight do bring nao foi auditada'
)
actorPedAvailable = true

auditAvailable = false
clientEvents = {}
events['mz_admin:server:bringPlayer'](2)
expect(
  #clientEvents == 1 and clientEvents[1].name == 'chat:addMessage',
  'falha de auditoria nao cancelou bring'
)
auditAvailable = true

clientEvents = {}
events['mz_admin:server:bringPlayer'](nil)
expect(
  #clientEvents == 1 and clientEvents[1].name == 'chat:addMessage',
  'alvo nulo de bring nao falhou fechado'
)
expect(
  auditLogs[#auditLogs] and auditLogs[#auditLogs].payload.meta.reason == 'invalid_target',
  'alvo nulo de bring nao foi auditado'
)

clientEvents = {}
events['mz_admin:server:healPlayer'](2)
expect(clientEvents[1] and clientEvents[1].name == 'mz_admin:client:stateActionConfirmed'
  and clientEvents[1].args[1] == 'heal', 'heal autorizado nao confirmou sync canonico')
expect(survivalRestores[#survivalRestores] and survivalRestores[#survivalRestores].target == 2
  and survivalRestores[#survivalRestores].context.actorSource == 1,
  'heal autorizado nao restaurou fome e sede pelo mz_status')
expect(auditLogs[#auditLogs].action == 'admin.player.heal.authorized', 'heal autorizado nao foi auditado')

clientEvents = {}
events['mz_admin:server:revivePlayer'](2)
expect(clientEvents[1] and clientEvents[1].name == 'mz_admin:client:stateActionConfirmed'
  and clientEvents[1].args[1] == 'revive', 'revive autorizado nao confirmou sync canonico')
expect(auditLogs[#auditLogs].action == 'admin.player.revive.authorized', 'revive autorizado nao foi auditado')

clientEvents = {}
events['mz_admin:server:setArmor'](75)
expect(clientEvents[1] and clientEvents[1].name == 'mz_admin:client:stateActionConfirmed'
  and clientEvents[1].args[1] == 'armor' and clientEvents[1].args[2] == 75,
  'armor autorizada nao passou pelo estado canonico')

stateMutationAllowed = false
clientEvents = {}
events['mz_admin:server:healPlayer'](2)
expect(#clientEvents == 1 and clientEvents[1].name == 'chat:addMessage',
  'falha do core permitiu confirmacao/aplicacao fisica administrativa')
stateMutationAllowed = true

survivalMutationAllowed = false
clientEvents = {}
events['mz_admin:server:healPlayer'](2)
expect(#clientEvents == 1 and clientEvents[1].name == 'chat:addMessage',
  'falha do mz_status permitiu confirmacao completa do heal')
survivalMutationAllowed = true

droppedPlayers = {}
clientEvents = {}
events['mz_admin:server:kickPlayer'](2, 'teste autorizado')
expect(#droppedPlayers == 0, 'kick sem permissao removeu player')
expect(auditLogs[#auditLogs].action == 'admin.player.kick.denied', 'kick negado nao foi auditado')

granted['staff.players.kick'] = true
local resolvedKickTarget = callbacks['mz_admin:server:resolveTargetIdentity'](1, 2, 'kick')
expect(resolvedKickTarget.ok == true and resolvedKickTarget.citizenid == 'PLAYER002',
  'callback nao resolveu identidade estavel do alvo')
events['mz_admin:server:kickPlayer'](2, 'identidade ausente')
expect(#droppedPlayers == 0 and auditLogs[#auditLogs].payload.meta.reason == 'expected_identity_required',
  'kick sem identidade esperada nao falhou fechado: ' .. tostring(auditLogs[#auditLogs].payload.meta.reason))
targetCitizenid = 'PLAYER-REUSED'
events['mz_admin:server:kickPlayer'](2, 'source reutilizado', resolvedKickTarget.citizenid)
expect(#droppedPlayers == 0 and auditLogs[#auditLogs].payload.meta.reason == 'stale_target',
  'kick atingiria novo jogador apos source reuse')
targetCitizenid = 'PLAYER002'
events['mz_admin:server:kickPlayer'](2, 'teste autorizado', resolvedKickTarget.citizenid)
expect(#droppedPlayers == 1 and droppedPlayers[1].target == 2, 'kick autorizado nao removeu alvo')
expect(droppedPlayers[1].reason:find('teste autorizado', 1, true) ~= nil, 'kick perdeu motivo na mensagem')
expect(auditLogs[#auditLogs].action == 'admin.player.kick.authorized', 'kick autorizado nao foi auditado')
expect(auditLogs[#auditLogs].payload.meta.message == 'teste autorizado', 'motivo do kick nao foi auditado')

events['mz_admin:server:kickPlayer'](2, 'x', 'PLAYER002')
expect(#droppedPlayers == 1, 'kick aceitou motivo invalido')
expect(auditLogs[#auditLogs].payload.meta.reason == 'invalid_reason', 'motivo invalido nao foi auditado')

hierarchyAllowed = false
hierarchyReason = 'target_higher_or_equal'
hierarchyContext.relationship = hierarchyReason
hierarchyContext.target.staff = true
hierarchyContext.target.level = 700
hierarchyContext.target.role = { code = 'administrador', name = 'Administrador', level = 700 }
events['mz_admin:server:kickPlayer'](2, 'nivel igual', 'PLAYER002')
expect(#droppedPlayers == 1, 'kick ignorou hierarquia igual')
expect(auditLogs[#auditLogs].payload.meta.reason == 'target_higher_or_equal', 'hierarquia do kick nao foi auditada')

hierarchyAllowed = true
hierarchyReason = 'target_not_staff'
hierarchyContext.relationship = hierarchyReason
hierarchyContext.target.staff = false
hierarchyContext.target.level = 0
hierarchyContext.target.role = nil
auditAvailable = false
events['mz_admin:server:kickPlayer'](2, 'auditoria indisponivel', 'PLAYER002')
expect(#droppedPlayers == 1, 'kick executou sem auditoria persistida')
auditAvailable = true

granted['staff.noclip'] = true
local noclip = callbacks['mz_admin:server:toggleNoClip'](1)
expect(noclip.ok == true and noclip.enabled == true, 'noclip autorizado nao ativou')
expect(exported.IsPlayerInNoClip(1) == true, 'export nao refletiu noclip ativo')
noclip = callbacks['mz_admin:server:toggleNoClip'](1)
expect(noclip.ok == true and noclip.enabled == false, 'noclip nao desativou')
expect(exported.IsPlayerInNoClip(1) == false, 'export nao limpou noclip')

local wallLogCount = #auditLogs
local wallDenied = callbacks['mz_admin:server:toggleWall'](1)
expect(wallDenied.ok == false and wallDenied.error == 'permission_denied', 'wall sem permissao foi autorizado')
expect(auditLogs[#auditLogs].action == 'admin.wall.denied', 'negacao do wall nao foi auditada')

granted['staff.wall'] = true
local wall = callbacks['mz_admin:server:toggleWall'](1)
expect(wall.ok == true and wall.enabled == true, 'wall autorizado nao ativou')
expect(exported.IsPlayerUsingWall(1) == true, 'export nao refletiu wall ativo')
expect(auditLogs[#auditLogs].action == 'admin.wall.enabled', 'ativacao do wall nao foi auditada')

local snapshot = MZAdminWall.BuildSnapshot(1000)
expect(#snapshot == 2 and snapshot[1].id == 1 and snapshot[2].id == 2, 'snapshot do wall nao foi ordenado')
expect(snapshot[1].staffTag == 'STAFF', 'snapshot nao marcou Staff conhecido')
expect(snapshot[1].citizenid == 'STAFF001', 'snapshot nao resolveu CitizenID do Staff')
expect(snapshot[2].citizenid == 'PLAYER002', 'snapshot nao resolveu CitizenID do player')
expect(snapshot[1].identifiers == nil, 'snapshot vazou identifiers')

wall = callbacks['mz_admin:server:toggleWall'](1)
expect(wall.ok == true and wall.enabled == false, 'wall nao desativou')
expect(exported.IsPlayerUsingWall(1) == false, 'export nao limpou wall')
expect(auditLogs[#auditLogs].action == 'admin.wall.disabled', 'desativacao do wall nao foi auditada')

auditAvailable = false
wall = callbacks['mz_admin:server:toggleWall'](1)
expect(wall.ok == false and wall.error == 'audit_failed', 'wall ativou sem auditoria disponivel')
expect(exported.IsPlayerUsingWall(1) == false, 'falha de auditoria deixou wall ativo')
auditAvailable = true
expect(#auditLogs >= wallLogCount + 3, 'fluxo do wall nao produziu logs esperados')

wall = callbacks['mz_admin:server:toggleWall'](1)
expect(wall.ok == true and wall.enabled == true, 'wall nao reativou para teste de revogacao')
clientEvents = {}
granted['staff.wall'] = nil
MZAdminWall.Tick(10000)
expect(exported.IsPlayerUsingWall(1) == false, 'revogacao de permissao nao encerrou wall')
expect(clientEvents[1] and clientEvents[1].name == 'mz_admin:client:setWallState', 'revogacao nao avisou client')
expect(auditLogs[#auditLogs].action == 'admin.wall.revoked', 'revogacao do wall nao foi auditada')

clientEvents = {}
events['mz_admin:server:startSpectate'](2)
expect(exported.IsPlayerSpectating(1) == false, 'spectate sem permissao foi iniciado')
expect(clientEvents[1] and clientEvents[1].name == 'chat:addMessage', 'negacao do spectate nao avisou ator')
expect(auditLogs[#auditLogs].action == 'admin.spectate.denied', 'negacao do spectate nao foi auditada')

granted['staff.spectate'] = true
clientEvents = {}
events['mz_admin:server:startSpectate'](2)
expect(exported.IsPlayerSpectating(1) == true, 'spectate autorizado nao iniciou')
expect(exported.GetSpectateTarget(1) == 2, 'spectate registrou alvo incorreto')
expect(routingBuckets[1] == 7, 'spectate nao colocou ator no bucket do alvo')
expect(clientEvents[1] and clientEvents[1].name == 'mz_admin:client:startSpectate', 'spectate nao avisou client')
expect(auditLogs[#auditLogs].action == 'admin.spectate.started', 'inicio do spectate nao foi auditado')

clientEvents = {}
MZAdminSpectate.Tick(20000)
expect(
  clientEvents[1] and clientEvents[1].name == 'mz_admin:client:syncSpectateTarget',
  'tick do spectate nao sincronizou alvo'
)

clientEvents = {}
events['mz_admin:server:stopSpectate']('requested')
expect(exported.IsPlayerSpectating(1) == false, 'specoff nao encerrou spectate')
expect(routingBuckets[1] == 0, 'specoff nao restaurou bucket original')
expect(clientEvents[1] and clientEvents[1].name == 'mz_admin:client:stopSpectate', 'specoff nao avisou client')
expect(auditLogs[#auditLogs].action == 'admin.spectate.stopped', 'fim do spectate nao foi auditado')

hierarchyAllowed = false
hierarchyReason = 'target_higher_or_equal'
hierarchyContext.relationship = hierarchyReason
hierarchyContext.target.staff = true
hierarchyContext.target.level = 700
hierarchyContext.target.role = { code = 'administrador', name = 'Administrador', level = 700 }
clientEvents = {}
events['mz_admin:server:startSpectate'](2)
expect(exported.IsPlayerSpectating(1) == false, 'spectate ignorou hierarquia igual')
expect(auditLogs[#auditLogs].payload.meta.reason == 'target_higher_or_equal', 'negacao hierarquica nao foi registrada')

hierarchyAllowed = true
hierarchyReason = 'target_not_staff'
hierarchyContext.relationship = hierarchyReason
hierarchyContext.target.staff = false
hierarchyContext.target.level = 0
hierarchyContext.target.role = nil
auditAvailable = false
events['mz_admin:server:startSpectate'](2)
expect(exported.IsPlayerSpectating(1) == false, 'spectate iniciou sem auditoria')
expect(routingBuckets[1] == 0, 'falha de auditoria alterou bucket')
auditAvailable = true

events['mz_admin:server:startSpectate'](2)
expect(exported.IsPlayerSpectating(1) == true, 'spectate nao reativou para teste de revogacao')
clientEvents = {}
granted['staff.spectate'] = nil
MZAdminSpectate.Tick(30000)
expect(exported.IsPlayerSpectating(1) == false, 'revogacao nao encerrou spectate')
expect(routingBuckets[1] == 0, 'revogacao nao restaurou bucket')
expect(clientEvents[1] and clientEvents[1].name == 'mz_admin:client:stopSpectate', 'revogacao nao avisou client')
expect(auditLogs[#auditLogs].action == 'admin.spectate.revoked', 'revogacao do spectate nao foi auditada')

print('mz_admin security contract harness: PASS')
