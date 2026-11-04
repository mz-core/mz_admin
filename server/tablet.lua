-- mz_admin/server/tablet.lua
-- Callbacks estruturados e tipados para o MZ Admin Tablet.
--
-- Cada handler revalida no SERVIDOR: source, capability exata, alvo online,
-- identidade (stale target) e hierarquia Staff. Nenhum payload do client e confiado.
-- Nao ha endpoint generico: cada acao exposta possui um callback proprio na allowlist abaixo.

local function normalizeSource(value)
  value = tonumber(value)
  if not value or value <= 0 then return nil end
  return math.floor(value)
end

local function validOnline(targetId)
  targetId = normalizeSource(targetId)
  return targetId and GetPlayerPing(targetId) > 0
end

local function safeName(sourceId)
  sourceId = normalizeSource(sourceId)
  if not sourceId then return nil end
  return tostring(GetPlayerName(sourceId) or ('ID ' .. tostring(sourceId))):gsub('%c', ''):sub(1, 64)
end

local function audit(sourceId, targetId, action, allowed, reason)
  if GetResourceState('mz_core') ~= 'started' then
    return true -- auditoria nao bloqueia a acao; apenas registra quando disponivel.
  end

  local ok = pcall(function()
    return exports['mz_core']:CreateDetailedLog(
      'admin',
      ('admin.tablet.%s.%s'):format(action, allowed and 'authorized' or 'denied'),
      {
        actor = { type = 'player', source = sourceId, name = safeName(sourceId) },
        target = targetId and { type = 'player', source = targetId, name = safeName(targetId) } or nil,
        context = {
          resource = 'mz_admin',
          action = action,
          permission = MZAdminPermissions[action],
          decision = allowed and 'authorized' or 'denied'
        },
        meta = { reason = tostring(reason or (allowed and 'authorized' or 'denied')) }
      }
    )
  end)

  if not ok then
    print(('[mz_admin][tablet] audit unavailable action=%s source=%s'):format(tostring(action), tostring(sourceId)))
  end
  return true
end

local function hierarchy(sourceId, targetId)
  if GetResourceState('mz_core') ~= 'started' then return false, 'hierarchy_unavailable' end
  local ok, allowed, reason = pcall(function()
    return exports['mz_core']:CanStaffActOnPlayer(sourceId, targetId)
  end)
  if not ok then return false, 'hierarchy_unavailable' end
  if allowed == true then return true end
  return false, reason or 'hierarchy_denied'
end

-- Valida permissao, liveness do alvo, identidade (stale) e hierarquia.
-- Retorna (targetId) em sucesso ou (nil, error) em falha.
local function authorizeTarget(sourceId, targetId, action, expectedCitizenid, requireIdentity)
  sourceId = normalizeSource(sourceId)

  local allowed, reason = MZAdminSecurity.Authorize(sourceId, action)
  if not allowed then
    audit(sourceId, targetId, action, false, reason)
    return nil, reason
  end

  if not validOnline(targetId) then
    audit(sourceId, targetId, action, false, 'invalid_target')
    return nil, 'invalid_target'
  end

  local identityOk, identityReason = MZAdminSecurity.ValidateTargetIdentity(targetId, expectedCitizenid, requireIdentity == true)
  if identityOk ~= true then
    audit(sourceId, targetId, action, false, identityReason or 'stale_target')
    return nil, identityReason or 'stale_target'
  end

  local hierarchyOk, hierarchyReason = hierarchy(sourceId, targetId)
  if not hierarchyOk then
    audit(sourceId, targetId, action, false, hierarchyReason)
    return nil, hierarchyReason
  end

  return targetId
end

local function ok(data)
  return { ok = true, data = data or nil }
end

local function fail(err)
  return { ok = false, error = tostring(err or 'unknown_error') }
end

lib.callback.register('mz_admin:server:tabletGoto', function(source, targetId, expectedCitizenid)
  local sourceId = normalizeSource(source)
  local resolved, err = authorizeTarget(sourceId, targetId, 'gotoPlayer', expectedCitizenid)
  if not resolved then return fail(err) end

  local targetPed = GetPlayerPed(resolved)
  if targetPed == 0 then
    audit(sourceId, resolved, 'gotoPlayer', false, 'ped_unavailable')
    return fail('ped_unavailable')
  end

  audit(sourceId, resolved, 'gotoPlayer', true, 'authorized')
  TriggerClientEvent('mz_admin:client:teleportToCoords', sourceId, GetEntityCoords(targetPed), GetEntityHeading(targetPed))
  return ok()
end)

lib.callback.register('mz_admin:server:tabletBring', function(source, targetId, expectedCitizenid)
  local sourceId = normalizeSource(source)
  local actorPed = GetPlayerPed(sourceId)
  if actorPed == 0 then return fail('actor_ped_unavailable') end

  local resolved, err = authorizeTarget(sourceId, targetId, 'bringPlayer', expectedCitizenid)
  if not resolved then return fail(err) end

  audit(sourceId, resolved, 'bringPlayer', true, 'authorized')
  TriggerClientEvent('mz_admin:client:teleportToCoords', resolved, GetEntityCoords(actorPed), GetEntityHeading(actorPed))
  return ok()
end)

lib.callback.register('mz_admin:server:tabletKick', function(source, targetId, reason, expectedCitizenid)
  local sourceId = normalizeSource(source)
  reason = type(reason) == 'string' and reason:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '') or ''
  if #reason > 256 then reason = reason:sub(1, 256) end

  local resolved, err = authorizeTarget(sourceId, targetId, 'kick', expectedCitizenid, true)
  if not resolved then return fail(err) end

  if resolved == sourceId then
    audit(sourceId, resolved, 'kick', false, 'self_target')
    return fail('self_target')
  end
  if #reason < 3 then
    audit(sourceId, resolved, 'kick', false, 'invalid_reason')
    return fail('invalid_reason')
  end

  audit(sourceId, resolved, 'kick', true, 'authorized')
  DropPlayer(resolved, ((type(locale) == 'function' and locale('server_messages.s_0e836f0e3915') or 'Voce foi removido pela Staff.\nMotivo: %s')):format(reason))
  return ok()
end)

lib.callback.register('mz_admin:server:tabletHeal', function(source, targetId, expectedCitizenid)
  local sourceId = normalizeSource(source)
  local resolved, err = authorizeTarget(sourceId, targetId, 'heal', expectedCitizenid)
  if not resolved then return fail(err) end

  local callOk, changed = pcall(function()
    return exports['mz_core']:SetStatus(resolved, 'health', 200, {
      actorSource = sourceId, reason = 'admin_heal', administrative = true
    })
  end)
  if not callOk or changed ~= true then
    audit(sourceId, resolved, 'heal', false, 'status_unavailable')
    return fail('status_unavailable')
  end

  local survivalOk, survivalChanged = pcall(function()
    return exports['mz_status']:RestoreSurvivalStatus(resolved, { actorSource = sourceId })
  end)
  if not survivalOk or survivalChanged ~= true then
    audit(sourceId, resolved, 'heal', true, 'authorized_partial')
    return { ok = true, data = { partial = 'survival_unavailable' } }
  end

  audit(sourceId, resolved, 'heal', true, 'authorized')
  TriggerClientEvent('mz_admin:client:stateActionConfirmed', resolved, 'heal')
  return ok()
end)

lib.callback.register('mz_admin:server:tabletRevive', function(source, targetId, expectedCitizenid)
  local sourceId = normalizeSource(source)
  local resolved, err = authorizeTarget(sourceId, targetId, 'revive', expectedCitizenid)
  if not resolved then return fail(err) end

  local callOk, changed = pcall(function()
    return exports['mz_core']:RevivePlayer(resolved, {
      actorSource = sourceId, reason = 'admin_revive', administrative = true
    })
  end)
  if not callOk or changed ~= true then
    audit(sourceId, resolved, 'revive', false, 'status_unavailable')
    return fail('status_unavailable')
  end

  audit(sourceId, resolved, 'revive', true, 'authorized')
  TriggerClientEvent('mz_admin:client:stateActionConfirmed', resolved, 'revive')
  return ok()
end)

lib.callback.register('mz_admin:server:tabletArmor', function(source, amount)
  local sourceId = normalizeSource(source)
  local allowed, reason = MZAdminSecurity.Authorize(sourceId, 'armor')
  if not allowed then
    audit(sourceId, nil, 'armor', false, reason)
    return fail(reason)
  end

  amount = math.max(0, math.min(100, math.floor(tonumber(amount) or 100)))
  local callOk, changed = pcall(function()
    return exports['mz_core']:SetStatus(sourceId, 'armor', amount, {
      actorSource = sourceId, reason = 'admin_armor', administrative = true
    })
  end)
  if not callOk or changed ~= true then
    audit(sourceId, nil, 'armor', false, 'status_unavailable')
    return fail('status_unavailable')
  end

  audit(sourceId, nil, 'armor', true, 'authorized')
  TriggerClientEvent('mz_admin:client:stateActionConfirmed', sourceId, 'armor', amount)
  return ok({ amount = amount })
end)

lib.callback.register('mz_admin:server:tabletSpectateStart', function(source, targetId, expectedCitizenid)
  local sourceId = normalizeSource(source)
  local allowed, reason = MZAdminSecurity.Authorize(sourceId, 'spectate')
  if not allowed then return fail(reason) end
  if type(MZAdminSpectate) ~= 'table' or type(MZAdminSpectate.Start) ~= 'function' then
    return fail('spectate_unavailable')
  end

  local started = MZAdminSpectate.Start(sourceId, targetId, expectedCitizenid)
  if not started then return fail('spectate_denied') end
  return ok({ active = MZAdminSpectate.IsActive(sourceId) == true })
end)

lib.callback.register('mz_admin:server:tabletSpectateStop', function(source)
  local sourceId = normalizeSource(source)
  if type(MZAdminSpectate) ~= 'table' or type(MZAdminSpectate.Stop) ~= 'function' then
    return fail('spectate_unavailable')
  end
  MZAdminSpectate.Stop(sourceId, 'tablet_requested', false, 'stopped')
  return ok({ active = false })
end)
