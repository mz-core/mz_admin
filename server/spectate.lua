MZAdminSpectate = MZAdminSpectate or {}

local sessions = {}

local function normalizeSource(value)
  value = tonumber(value)
  if not value or value <= 0 then return nil end
  return math.floor(value)
end

local function online(sourceId)
  sourceId = normalizeSource(sourceId)
  return sourceId and GetPlayerPing(sourceId) > 0
end

local function safeName(sourceId)
  sourceId = normalizeSource(sourceId)
  if not sourceId then return nil end
  local name = tostring(GetPlayerName(sourceId) or ('ID ' .. tostring(sourceId)))
  name = name:gsub('[%c~]', '')
  if #name > 64 then name = name:sub(1, 64) end
  return name
end

local function rolePayload(role)
  role = type(role) == 'table' and role or {}
  return {
    code = tostring(role.code or ''),
    name = tostring(role.name or ''),
    level = tonumber(role.level) or 0
  }
end

local function staffContext(sourceId)
  if GetResourceState('mz_core') ~= 'started' then return nil end
  local ok, context = pcall(function()
    return exports['mz_core']:GetStaffContext(sourceId)
  end)
  return ok and type(context) == 'table' and context or nil
end

local function entityPayload(sourceId, hierarchyEntity)
  hierarchyEntity = type(hierarchyEntity) == 'table' and hierarchyEntity or {}
  local context = staffContext(sourceId) or {}
  local role = hierarchyEntity.role or context.role
  return {
    type = 'player',
    id = hierarchyEntity.citizenid or context.citizenid or ('source:%s'):format(tostring(sourceId)),
    source = normalizeSource(sourceId),
    citizenid = hierarchyEntity.citizenid or context.citizenid,
    name = hierarchyEntity.name or safeName(sourceId),
    owner = hierarchyEntity.owner == true or context.owner == true,
    staff = hierarchyEntity.staff == true or role ~= nil,
    level = tonumber(hierarchyEntity.level) or tonumber(role and role.level) or 0,
    role = rolePayload(role)
  }
end

local function audit(sourceId, targetId, action, reason, hierarchy)
  hierarchy = type(hierarchy) == 'table' and hierarchy or {}
  if GetResourceState('mz_core') ~= 'started' then
    print(('[mz_admin][spectate-audit] actor=%s target=%s action=%s reason=%s error=mz_core_unavailable'):format(
      tostring(sourceId), tostring(targetId), tostring(action), tostring(reason)
    ))
    return false
  end

  local ok, auditId = pcall(function()
    return exports['mz_core']:CreateDetailedLog('admin', 'admin.spectate.' .. action, {
      actor = entityPayload(sourceId, hierarchy.actor),
      target = entityPayload(targetId, hierarchy.target),
      context = {
        resource = 'mz_admin',
        permission = MZAdminPermissions.spectate,
        relationship = hierarchy.relationship,
        state = action
      },
      meta = {
        reason = tostring(reason or action)
      }
    })
  end)

  if not ok or not auditId then
    print(('[mz_admin][spectate-audit] actor=%s target=%s action=%s reason=%s error=%s'):format(
      tostring(sourceId),
      tostring(targetId),
      tostring(action),
      tostring(reason),
      tostring(ok and 'audit_not_persisted' or auditId)
    ))
    return false
  end
  return true
end

local function notifyDenied(sourceId, message)
  TriggerClientEvent('chat:addMessage', sourceId, {
    args = { 'Admin', message or (type(locale) == 'function' and locale('errors.spectate_denied') or 'Spectate negado.') }
  })
end

local function hierarchyMessage(reason)
  if reason == 'target_owner' then return (type(locale) == 'function' and locale('server_messages.s_973bfc122a24') or 'O Staff Supremo esta protegido.') end
  if reason == 'target_higher_or_equal' then
    return (type(locale) == 'function' and locale('server_messages.s_06688f7956f9') or 'Voce nao pode espectar Staff de nivel igual ou superior.')
  end
  if reason == 'actor_without_staff_level' then
    return (type(locale) == 'function' and locale('server_messages.s_d3e3a3348d61') or 'Seu contexto Staff nao possui nivel para espectar este alvo.')
  end
  if reason == 'actor_not_loaded' or reason == 'target_not_loaded' then
    return (type(locale) == 'function' and locale('server_messages.s_7f1bd59e7e5b') or 'Contexto Staff indisponivel.')
  end
  return (type(locale) == 'function' and locale('server_messages.s_60560aab37a8') or 'Spectate negado pela hierarquia Staff.')
end

local function resolveHierarchy(sourceId, targetId)
  if GetResourceState('mz_core') ~= 'started' then
    return false, 'hierarchy_unavailable'
  end
  local ok, allowed, reason, hierarchy = pcall(function()
    return exports['mz_core']:CanStaffActOnPlayer(sourceId, targetId)
  end)
  if not ok then return false, 'hierarchy_unavailable' end
  return allowed == true, reason or 'hierarchy_denied', hierarchy
end

local function targetState(targetId)
  local ped = GetPlayerPed(targetId)
  if not ped or ped == 0 then return nil end
  local coords = GetEntityCoords(ped)
  return {
    target = targetId,
    coords = {
      x = tonumber(coords.x) or 0.0,
      y = tonumber(coords.y) or 0.0,
      z = tonumber(coords.z) or 0.0
    },
    heading = tonumber(GetEntityHeading(ped)) or 0.0,
    bucket = tonumber(GetPlayerRoutingBucket(targetId)) or 0
  }
end

local function restoreBucket(sourceId, bucket)
  local ok, err = pcall(SetPlayerRoutingBucket, sourceId, tonumber(bucket) or 0)
  if not ok then
    print(('[mz_admin][spectate] restore bucket failed source=%s bucket=%s error=%s'):format(
      tostring(sourceId), tostring(bucket), tostring(err)
    ))
  end
  return ok
end

function MZAdminSpectate.Stop(sourceId, reason, silent, auditAction)
  sourceId = normalizeSource(sourceId)
  local session = sourceId and sessions[sourceId] or nil
  if not session then return false, 'not_spectating' end

  sessions[sourceId] = nil
  restoreBucket(sourceId, session.returnBucket)
  TriggerClientEvent('mz_admin:client:stopSpectate', sourceId, {
    coords = session.returnCoords,
    heading = session.returnHeading,
    bucket = session.returnBucket,
    reason = reason or 'stopped',
    silent = silent == true
  })
  audit(sourceId, session.target, auditAction or 'stopped', reason or 'stopped', session.hierarchy)
  return true
end

function MZAdminSpectate.IsActive(sourceId)
  return sessions[normalizeSource(sourceId)] ~= nil
end

exports('IsSpectating', function(sourceId)
  return MZAdminSpectate.IsActive(sourceId)
end)

local function deny(sourceId, targetId, reason, message, hierarchy)
  audit(sourceId, targetId, 'denied', reason, hierarchy)
  notifyDenied(sourceId, message)
  return false
end

function MZAdminSpectate.Start(sourceId, requestedTarget, expectedCitizenid)
  sourceId = normalizeSource(sourceId)
  local targetId = normalizeSource(requestedTarget)
  local current = sourceId and sessions[sourceId] or nil

  if current and current.target == targetId then
    return MZAdminSpectate.Stop(sourceId, 'same_target_toggle', false, 'stopped')
  end

  local allowed, permissionReason = MZAdminSecurity.Authorize(sourceId, 'spectate')
  if not allowed then
    return deny(sourceId, targetId, permissionReason, (type(locale) == 'function' and locale('server_messages.s_2794020323f0') or 'Sem permissao para spectate.'))
  end
  if not online(targetId) then
    return deny(sourceId, targetId, 'invalid_target', (type(locale) == 'function' and locale('server_messages.s_c3f6ae238137') or 'Player invalido.'))
  end
  local identityMatches, identityReason = MZAdminSecurity.ValidateTargetIdentity(targetId, expectedCitizenid)
  if not identityMatches then
    return deny(
      sourceId,
      targetId,
      identityReason,
      identityReason == 'stale_target'
        and (type(locale) == 'function' and locale('server_messages.s_3186f3c6df13') or 'A sessao selecionada mudou de Character. Selecione o jogador novamente.')
        or (type(locale) == 'function' and locale('server_messages.s_ce8bb340f504') or 'Nao foi possivel validar a identidade do alvo.')
    )
  end
  if sourceId == targetId then
    return deny(sourceId, targetId, 'self_target', (type(locale) == 'function' and locale('server_messages.s_61cd6f6419d3') or 'Voce nao pode espectar a si mesmo.'))
  end

  local hierarchyAllowed, hierarchyReason, hierarchy = resolveHierarchy(sourceId, targetId)
  if not hierarchyAllowed then
    return deny(sourceId, targetId, hierarchyReason, hierarchyMessage(hierarchyReason), hierarchy)
  end

  if not current and MZAdminNoClip and MZAdminNoClip.IsEnabled
    and MZAdminNoClip.IsEnabled(sourceId) then
    return deny(sourceId, targetId, 'noclip_active', (type(locale) == 'function' and locale('spectate.s_13cd4d1bf44b') or 'Desative o noclip antes de usar spectate.'), hierarchy)
  end

  local actorPed = GetPlayerPed(sourceId)
  local target = targetState(targetId)
  if not actorPed or actorPed == 0 or not target then
    return deny(sourceId, targetId, 'ped_unavailable', (type(locale) == 'function' and locale('server_messages.s_d5dc0dcebf63') or 'Ped do Staff ou do alvo indisponivel.'), hierarchy)
  end

  if current then
    if not audit(sourceId, targetId, 'switched', hierarchyReason, hierarchy) then
      notifyDenied(sourceId, (type(locale) == 'function' and locale('server_messages.s_d350d6036c3d') or 'Auditoria indisponivel. Troca de alvo cancelada.'))
      return false
    end
    current.target = targetId
    current.hierarchy = hierarchy
    current.nextAuthorizationAt = 0
    restoreBucket(sourceId, target.bucket)
    TriggerClientEvent('mz_admin:client:startSpectate', sourceId, target, true)
    return true
  end

  local actorCoords = GetEntityCoords(actorPed)
  local session = {
    target = targetId,
    returnCoords = {
      x = tonumber(actorCoords.x) or 0.0,
      y = tonumber(actorCoords.y) or 0.0,
      z = tonumber(actorCoords.z) or 0.0
    },
    returnHeading = tonumber(GetEntityHeading(actorPed)) or 0.0,
    returnBucket = tonumber(GetPlayerRoutingBucket(sourceId)) or 0,
    hierarchy = hierarchy,
    nextAuthorizationAt = 0
  }

  if not audit(sourceId, targetId, 'started', hierarchyReason, hierarchy) then
    notifyDenied(sourceId, (type(locale) == 'function' and locale('server_messages.s_b6251ff28c0f') or 'Auditoria indisponivel. Spectate cancelado.'))
    return false
  end

  sessions[sourceId] = session
  restoreBucket(sourceId, target.bucket)
  TriggerClientEvent('mz_admin:client:startSpectate', sourceId, target, false)
  return true
end

function MZAdminSpectate.Tick(now)
  if not next(sessions) then return end
  now = tonumber(now) or GetGameTimer()
  local authorizationInterval =
    tonumber(Config.Spectate and Config.Spectate.authorizationInterval) or 1500
  authorizationInterval = math.max(500, math.min(10000, math.floor(authorizationInterval)))

  for sourceId, session in pairs(sessions) do
    if not online(sourceId) then
      sessions[sourceId] = nil
    elseif not online(session.target) then
      MZAdminSpectate.Stop(sourceId, 'target_disconnected', false, 'target_lost')
    else
      if now >= (session.nextAuthorizationAt or 0) then
        session.nextAuthorizationAt = now + authorizationInterval
        if not MZAdminSecurity.HasGlobalPermission(sourceId, MZAdminPermissions.spectate) then
          MZAdminSpectate.Stop(sourceId, 'permission_revoked', false, 'revoked')
        else
          local hierarchyAllowed, hierarchyReason, hierarchy =
            resolveHierarchy(sourceId, session.target)
          if not hierarchyAllowed then
            session.hierarchy = hierarchy or session.hierarchy
            MZAdminSpectate.Stop(sourceId, hierarchyReason, false, 'revoked')
          else
            session.hierarchy = hierarchy
          end
        end
      end

      session = sessions[sourceId]
      if session then
        local target = targetState(session.target)
        if not target then
          MZAdminSpectate.Stop(sourceId, 'target_ped_unavailable', false, 'target_lost')
        else
          if tonumber(GetPlayerRoutingBucket(sourceId)) ~= target.bucket then
            restoreBucket(sourceId, target.bucket)
          end
          TriggerClientEvent('mz_admin:client:syncSpectateTarget', sourceId, target)
        end
      end
    end
  end
end

RegisterNetEvent('mz_admin:server:startSpectate', function(targetId, expectedCitizenid)
  MZAdminSpectate.Start(source, targetId, expectedCitizenid)
end)

RegisterNetEvent('mz_admin:server:stopSpectate', function(reason)
  MZAdminSpectate.Stop(source, tostring(reason or 'requested'), false, 'stopped')
end)

CreateThread(function()
  while true do
    local interval = tonumber(Config.Spectate and Config.Spectate.updateInterval) or 250
    interval = math.max(100, math.min(2000, math.floor(interval)))
    Wait(interval)
    MZAdminSpectate.Tick()
  end
end)

AddEventHandler('playerDropped', function()
  local sourceId = normalizeSource(source)
  if not sourceId then return end

  if sessions[sourceId] then sessions[sourceId] = nil end
  local affected = {}
  for watcher, session in pairs(sessions) do
    if session.target == sourceId then affected[#affected + 1] = watcher end
  end
  for _, watcher in ipairs(affected) do
    MZAdminSpectate.Stop(watcher, 'target_disconnected', false, 'target_lost')
  end
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  for sourceId, session in pairs(sessions) do
    restoreBucket(sourceId, session.returnBucket)
    TriggerClientEvent('mz_admin:client:stopSpectate', sourceId, {
      coords = session.returnCoords,
      heading = session.returnHeading,
      bucket = session.returnBucket,
      reason = 'resource_stop',
      silent = true
    })
  end
  sessions = {}
end)

exports('IsPlayerSpectating', function(playerId)
  return sessions[normalizeSource(playerId)] ~= nil
end)

exports('GetSpectateTarget', function(playerId)
  local session = sessions[normalizeSource(playerId)]
  return session and session.target or nil
end)
