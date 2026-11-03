MZAdminNoClip = MZAdminNoClip or {}

if GetConvarInt('mz_admin_runtime_diagnostic', 0) == 1 then
  local resource = GetCurrentResourceName()
  print(('[mz_admin][runtime] resource=%s version=%s path=%s ui_page=%s'):format(
    resource,
    GetResourceMetadata(resource, 'version', 0) or 'unknown',
    GetResourcePath(resource) or 'unknown',
    GetResourceMetadata(resource, 'ui_page', 0) or 'unknown'
  ))
end

local noClipPlayers = {}

local TARGET_ACTION_NAMES = {
  noclip = 'noclip',
  bringPlayer = 'bring',
  kick = 'kick',
  heal = 'heal',
  revive = 'revive'
}

local function validOnlinePlayer(targetId)
  targetId = tonumber(targetId)
  if not targetId or targetId <= 0 or GetPlayerPing(targetId) <= 0 then return nil end
  return math.floor(targetId)
end

local function notifyDenied(sourceId, message)
  TriggerClientEvent('chat:addMessage', sourceId, {
    args = { 'Admin', message or 'Acao negada.' }
  })
end

local function authorize(sourceId, action)
  local allowed, reason = MZAdminSecurity.Authorize(sourceId, action)
  if not allowed then
    notifyDenied(sourceId, reason == 'rate_limited'
      and 'Aguarde um instante antes de repetir esta acao.'
      or 'Sem permissao para esta acao.')
    return false, reason
  end
  return true, reason
end

local function hierarchyRole(role)
  if type(role) ~= 'table' then return nil end
  return {
    code = tostring(role.code or ''),
    name = tostring(role.name or ''),
    level = tonumber(role.level) or 0
  }
end

local function safePlayerName(sourceId)
  sourceId = tonumber(sourceId)
  if not sourceId or sourceId <= 0 then return nil end
  return GetPlayerName(math.floor(sourceId))
end

local function auditTargetAction(sourceId, targetId, action, allowed, reason, hierarchy, auditMeta)
  local actionName = TARGET_ACTION_NAMES[action] or tostring(action or 'unknown')
  hierarchy = type(hierarchy) == 'table' and hierarchy or {}
  local actor = type(hierarchy.actor) == 'table' and hierarchy.actor or {}
  local target = type(hierarchy.target) == 'table' and hierarchy.target or {}
  local payload = {
    actor = {
      type = 'player',
      id = actor.citizenid or ('source:%s'):format(tostring(sourceId)),
      source = tonumber(sourceId),
      citizenid = actor.citizenid,
      name = actor.name or safePlayerName(sourceId),
      owner = actor.owner == true,
      staff = actor.staff == true,
      level = tonumber(actor.level) or 0,
      role = hierarchyRole(actor.role)
    },
    target = {
      type = 'player',
      id = target.citizenid or ('source:%s'):format(tostring(targetId)),
      source = tonumber(targetId),
      citizenid = target.citizenid,
      name = target.name or safePlayerName(targetId),
      owner = target.owner == true,
      staff = target.staff == true,
      level = tonumber(target.level) or 0,
      role = hierarchyRole(target.role)
    },
    context = {
      resource = 'mz_admin',
      action = actionName,
      permission = MZAdminPermissions[action],
      decision = allowed == true and 'authorized' or 'denied',
      relationship = hierarchy.relationship
    },
    meta = {
      reason = tostring(reason or (allowed and 'authorized' or 'denied')),
      message = type(auditMeta) == 'table' and auditMeta.message or nil
    }
  }

  if GetResourceState('mz_core') ~= 'started' then
    print(('[mz_admin][audit] action=%s decision=%s actor=%s target=%s reason=%s error=mz_core_unavailable'):format(
      actionName,
      allowed and 'authorized' or 'denied',
      tostring(sourceId),
      tostring(targetId),
      tostring(reason)
    ))
    return false
  end

  local ok, auditId = pcall(function()
    return exports['mz_core']:CreateDetailedLog(
      'admin',
      ('admin.player.%s.%s'):format(actionName, allowed and 'authorized' or 'denied'),
      payload
    )
  end)
  if not ok or not auditId then
    print(('[mz_admin][audit] action=%s decision=%s actor=%s target=%s reason=%s error=%s'):format(
      actionName,
      allowed and 'authorized' or 'denied',
      tostring(sourceId),
      tostring(targetId),
      tostring(reason),
      tostring(ok and 'audit_not_persisted' or auditId)
    ))
    return false
  end
  return true
end

local function resolveTargetHierarchy(sourceId, targetId)
  if GetResourceState('mz_core') ~= 'started' then return false, 'hierarchy_unavailable' end
  local callOk, allowed, reason, hierarchy = pcall(function()
    return exports['mz_core']:CanStaffActOnPlayer(sourceId, targetId)
  end)
  if not callOk then
    print(('[mz_admin] falha no guard Staff actor=%s target=%s error=%s'):format(
      tostring(sourceId),
      tostring(targetId),
      tostring(allowed)
    ))
    return false, 'hierarchy_unavailable'
  end
  return allowed == true, reason or 'hierarchy_denied', hierarchy
end

local function hierarchyDeniedMessage(reason)
  if reason == 'target_owner' then return 'O Staff Supremo esta protegido.' end
  if reason == 'target_higher_or_equal' then return 'Voce nao pode agir sobre Staff de nivel igual ou superior.' end
  if reason == 'actor_without_staff_level' then return 'Seu contexto Staff nao possui nivel para agir sobre este alvo.' end
  if reason == 'target_not_loaded' then return 'Contexto do alvo indisponivel.' end
  return 'Acao negada pela hierarquia Staff.'
end

local function authorizeTargetAction(sourceId, targetId, action, preflight, auditMeta, expectedCitizenid)
  local requestedTargetId = targetId
  local allowed, reason = MZAdminSecurity.Authorize(sourceId, action)
  if not allowed then
    auditTargetAction(sourceId, targetId, action, false, reason)
    notifyDenied(sourceId, reason == 'rate_limited'
      and 'Aguarde um instante antes de repetir esta acao.'
      or 'Sem permissao para esta acao.')
    return nil
  end

  targetId = validOnlinePlayer(targetId)
  if not targetId then
    auditTargetAction(sourceId, requestedTargetId, action, false, 'invalid_target')
    notifyDenied(sourceId, 'Player invalido.')
    return nil
  end

  local identityValid, identityReason = MZAdminSecurity.ValidateTargetIdentity(
    targetId,
    expectedCitizenid,
    action == 'kick'
  )
  if identityValid ~= true then
    auditTargetAction(sourceId, targetId, action, false, identityReason or 'stale_target')
    notifyDenied(sourceId, 'O alvo mudou de sessao. Selecione novamente.')
    return nil
  end

  local hierarchyAllowed, hierarchyReason, hierarchy = resolveTargetHierarchy(sourceId, targetId)
  if not hierarchyAllowed then
    auditTargetAction(sourceId, targetId, action, false, hierarchyReason, hierarchy)
    notifyDenied(sourceId, hierarchyDeniedMessage(hierarchyReason))
    return nil
  end

  if type(preflight) == 'function' then
    local preflightOk, preflightReason, preflightMessage = preflight(targetId, hierarchy)
    if preflightOk ~= true then
      preflightReason = preflightReason or 'preflight_failed'
      auditTargetAction(sourceId, targetId, action, false, preflightReason, hierarchy)
      notifyDenied(sourceId, preflightMessage or 'Acao indisponivel neste momento.')
      return nil
    end
  end

  if not auditTargetAction(sourceId, targetId, action, true, hierarchyReason, hierarchy, auditMeta) then
    notifyDenied(sourceId, 'Auditoria administrativa indisponivel. Acao cancelada.')
    return nil
  end

  return targetId
end

local function setNoClipState(sourceId, enabled)
  sourceId = tonumber(sourceId)
  if not sourceId or sourceId <= 0 then return false end
  noClipPlayers[sourceId] = enabled == true or nil
  return true
end

function MZAdminNoClip.IsEnabled(sourceId)
  return noClipPlayers[tonumber(sourceId)] == true
end

local function issueNoClipLease(sourceId)
  if GetResourceState('mz_banguard') ~= 'started' then return true end
  local ok, leaseId = pcall(function()
    return exports['mz_banguard']:RegisterSecurityLease(sourceId, 'movement.noclip.staff', 15000, {
      quantity = 8, reason = 'admin_noclip_enabled'
    })
  end)
  return ok and leaseId ~= nil and leaseId ~= false
end

lib.callback.register('mz_admin:server:toggleNoClip', function(source)
  if not authorize(source, 'noclip') then
    return { ok = false, error = 'permission_denied' }
  end

  local enabled = noClipPlayers[source] ~= true
  if enabled and not issueNoClipLease(source) then
    auditTargetAction(source, source, 'noclip', false, 'security_lease_unavailable')
    return { ok = false, error = 'security_lease_unavailable' }
  end
  if not auditTargetAction(source, source, 'noclip', true, enabled and 'enabled' or 'disabled') then
    return { ok = false, error = 'audit_unavailable' }
  end
  setNoClipState(source, enabled)
  return { ok = true, enabled = enabled }
end)

-- Evento legado preservado, agora fail-closed e autorizado no servidor.
RegisterNetEvent('mz_admin:server:requestNoClip', function()
  local sourceId = source
  if not authorize(sourceId, 'noclip') then
    TriggerClientEvent('mz_admin:client:authorizeNoClip', sourceId, false)
    return
  end

  local enabled = noClipPlayers[sourceId] ~= true
  if enabled and not issueNoClipLease(sourceId) then
    auditTargetAction(sourceId, sourceId, 'noclip', false, 'security_lease_unavailable')
    TriggerClientEvent('mz_admin:client:authorizeNoClip', sourceId, false)
    return
  end
  if not auditTargetAction(sourceId, sourceId, 'noclip', true, enabled and 'enabled' or 'disabled') then
    TriggerClientEvent('mz_admin:client:authorizeNoClip', sourceId, false)
    return
  end
  setNoClipState(sourceId, enabled)
  TriggerClientEvent('mz_admin:client:authorizeNoClip', sourceId, true, enabled)
end)

RegisterNetEvent('mz_admin:server:stopNoClip', function()
  local sourceId = tonumber(source)
  if sourceId and noClipPlayers[sourceId] == true
    and auditTargetAction(sourceId, sourceId, 'noclip', true, 'disabled') then
    setNoClipState(sourceId, false)
  end
end)

RegisterNetEvent('mz_admin:server:gotoPlayer', function(targetId)
  local sourceId = source
  if not authorize(sourceId, 'gotoPlayer') then return end

  targetId = validOnlinePlayer(targetId)
  if not targetId then
    notifyDenied(sourceId, 'Player invalido.')
    return
  end

  local targetPed = GetPlayerPed(targetId)
  if targetPed == 0 then
    notifyDenied(sourceId, 'Ped do player indisponivel.')
    return
  end

  TriggerClientEvent(
    'mz_admin:client:teleportToCoords',
    sourceId,
    GetEntityCoords(targetPed),
    GetEntityHeading(targetPed)
  )
end)

RegisterNetEvent('mz_admin:server:bringPlayer', function(targetId, expectedCitizenid)
  local sourceId = source
  local actorPed
  targetId = authorizeTargetAction(sourceId, targetId, 'bringPlayer', function()
    actorPed = GetPlayerPed(sourceId)
    if actorPed == 0 then
      return false, 'actor_ped_unavailable', 'Ped do Staff indisponivel.'
    end
    return true
  end, nil, expectedCitizenid)
  if not targetId then return end

  -- As coordenadas sao resolvidas no servidor; payload client nunca e confiado.
  TriggerClientEvent(
    'mz_admin:client:teleportToCoords',
    targetId,
    GetEntityCoords(actorPed),
    GetEntityHeading(actorPed)
  )
end)

RegisterNetEvent('mz_admin:server:kickPlayer', function(targetId, reason, expectedCitizenid)
  local sourceId = source
  reason = type(reason) == 'string' and reason:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '') or ''
  if #reason > 256 then reason = reason:sub(1, 256) end

  targetId = authorizeTargetAction(sourceId, targetId, 'kick', function(resolvedTarget)
    if resolvedTarget == sourceId then
      return false, 'self_target', 'Voce nao pode remover a si mesmo.'
    end
    if #reason < 3 then
      return false, 'invalid_reason', 'Informe um motivo com pelo menos 3 caracteres.'
    end
    return true
  end, { message = reason }, expectedCitizenid)
  if not targetId then return end

  DropPlayer(targetId, ('Voce foi removido pela Staff.\nMotivo: %s'):format(reason))
end)

RegisterNetEvent('mz_admin:server:healPlayer', function(targetId)
  local sourceId = source
  targetId = authorizeTargetAction(sourceId, targetId, 'heal')
  if not targetId then return end
  local ok, changed = pcall(function()
    return exports['mz_core']:SetStatus(targetId, 'health', 200, {
      actorSource = sourceId, reason = 'admin_heal', administrative = true
    })
  end)
  if not ok or changed ~= true then
    notifyDenied(sourceId, 'Estado canonico indisponivel.')
    return
  end
  -- shortcut: vida e sobrevivencia usam owners distintos; criar operacao composta somente se atomicidade virar requisito.
  local survivalOk, survivalChanged = pcall(function()
    return exports['mz_status']:RestoreSurvivalStatus(targetId, {
      actorSource = sourceId
    })
  end)
  if not survivalOk or survivalChanged ~= true then
    notifyDenied(sourceId, 'Vida restaurada, mas fome e sede nao puderam ser restauradas.')
    return
  end
  TriggerClientEvent('mz_admin:client:stateActionConfirmed', targetId, 'heal')
end)

RegisterNetEvent('mz_admin:server:revivePlayer', function(targetId)
  local sourceId = source
  targetId = authorizeTargetAction(sourceId, targetId, 'revive')
  if not targetId then return end
  local ok, changed = pcall(function()
    return exports['mz_core']:RevivePlayer(targetId, {
      actorSource = sourceId, reason = 'admin_revive', administrative = true
    })
  end)
  if not ok or changed ~= true then
    notifyDenied(sourceId, 'Estado canonico indisponivel.')
    return
  end
  TriggerClientEvent('mz_admin:client:stateActionConfirmed', targetId, 'revive')
end)

RegisterNetEvent('mz_admin:server:setArmor', function(amount)
  local sourceId = tonumber(source)
  local allowed = authorize(sourceId, 'armor')
  amount = tonumber(amount)
  if not allowed or not amount then return end
  amount = math.max(0, math.min(100, math.floor(amount)))
  local ok, changed = pcall(function()
    return exports['mz_core']:SetStatus(sourceId, 'armor', amount, {
      actorSource = sourceId, reason = 'admin_armor', administrative = true
    })
  end)
  if not ok or changed ~= true then
    notifyDenied(sourceId, 'Estado canonico indisponivel.')
    return
  end
  TriggerClientEvent('mz_admin:client:stateActionConfirmed', sourceId, 'armor', amount)
end)

AddEventHandler('playerDropped', function()
  noClipPlayers[source] = nil
end)

exports('IsPlayerInNoClip', function(playerId)
  return MZAdminNoClip.IsEnabled(playerId)
end)

exports('IsNoClipEnabled', function(playerId)
  return MZAdminNoClip.IsEnabled(playerId)
end)
