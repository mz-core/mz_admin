MZAdminBansServer = MZAdminBansServer or {}

local function response(ok, data, err)
  return {
    ok = ok == true,
    data = ok == true and data or nil,
    error = ok == true and nil or tostring(err or 'unknown_error')
  }
end

local function banGuardCall(exportName, ...)
  if GetResourceState('mz_banguard') ~= 'started' then
    return nil, 'banguard_unavailable'
  end

  local args = { ... }
  local ok, result = pcall(function()
    -- Exports dinamicos podem deslocar o primeiro argumento no proxy FiveM.
    -- Mantenha cada chamada oficial explicita.
    if exportName == 'CreateOnlineBan' then
      return exports['mz_banguard']:CreateOnlineBan(args[1], args[2], args[3], args[4], args[5])
    elseif exportName == 'RevokeBan' then
      return exports['mz_banguard']:RevokeBan(args[1], args[2], args[3])
    elseif exportName == 'ListBans' then
      return exports['mz_banguard']:ListBans(args[1], args[2])
    elseif exportName == 'GetBan' then
      return exports['mz_banguard']:GetBan(args[1], args[2])
    end
    error(('unsupported mz_banguard export: %s'):format(tostring(exportName)))
  end)
  if not ok or type(result) ~= 'table' then
    print(('[mz_admin][bans] export=%s error=%s'):format(
      tostring(exportName),
      tostring(ok and 'invalid_response' or result)
    ))
    return nil, 'banguard_call_failed'
  end
  return result
end

local function auditResult(sourceId, action, resultData, context)
  if GetResourceState('mz_core') ~= 'started' then return false end
  context = type(context) == 'table' and context or {}
  local succeeded = type(resultData) == 'table' and resultData.ok == true
  local ban = succeeded and resultData.data and resultData.data.ban or nil

  local ok, auditId = pcall(function()
    return exports['mz_core']:CreateDetailedLog(
      'admin',
      ('admin.ban.%s.%s'):format(action, succeeded and 'completed' or 'denied'),
      {
        actor = {
          type = 'player',
          source = tonumber(sourceId),
          name = GetPlayerName(sourceId)
        },
        target = {
          type = action == 'create' and 'player' or 'ban',
          source = tonumber(context.targetSource),
          id = ban and ban.publicId or context.publicId,
          name = ban and ban.playerName or nil
        },
        context = {
          resource = 'mz_admin',
          action = action,
          decision = succeeded and 'completed' or 'denied'
        },
        meta = {
          reason = succeeded and context.reason or (resultData and resultData.error or 'banguard_unavailable'),
          duration = context.duration,
          publicId = ban and ban.publicId or context.publicId
        }
      }
    )
  end)
  return ok and auditId ~= nil
end

function MZAdminBansServer.Create(sourceId, targetSource, duration, reason, expectedCitizenid)
  local allowed, authError = MZAdminSecurity.Authorize(sourceId, 'ban')
  if not allowed then
    local denied = response(false, nil, authError)
    auditResult(sourceId, 'create', denied, { targetSource = targetSource })
    return denied
  end
  local identityMatches, identityReason = MZAdminSecurity.ValidateTargetIdentity(targetSource, expectedCitizenid, true)
  if not identityMatches then
    local denied = response(false, nil, identityReason)
    auditResult(sourceId, 'create', denied, { targetSource = targetSource })
    return denied
  end

  local resultData, callError = banGuardCall(
    'CreateOnlineBan', sourceId, targetSource, duration, reason, expectedCitizenid
  )
  if not resultData then resultData = response(false, nil, callError) end
  auditResult(sourceId, 'create', resultData, {
    targetSource = targetSource,
    duration = duration,
    reason = reason
  })
  return resultData
end

function MZAdminBansServer.Revoke(sourceId, publicId, reason)
  local allowed, authError = MZAdminSecurity.Authorize(sourceId, 'banRevoke')
  if not allowed then
    local denied = response(false, nil, authError)
    auditResult(sourceId, 'revoke', denied, { publicId = publicId })
    return denied
  end

  local resultData, callError = banGuardCall('RevokeBan', sourceId, publicId, reason)
  if not resultData then resultData = response(false, nil, callError) end
  auditResult(sourceId, 'revoke', resultData, {
    publicId = publicId,
    reason = reason
  })
  return resultData
end

function MZAdminBansServer.List(sourceId, filters)
  local allowed, authError = MZAdminSecurity.Authorize(sourceId, 'banView')
  if not allowed then return response(false, nil, authError) end

  local resultData, callError = banGuardCall('ListBans', sourceId, {
    active = type(filters) == 'table' and filters.active or nil,
    search = type(filters) == 'table' and filters.search or nil,
    page = type(filters) == 'table' and filters.page or nil,
    pageSize = 25
  })
  return resultData or response(false, nil, callError)
end

function MZAdminBansServer.Get(sourceId, publicId)
  local allowed, authError = MZAdminSecurity.Authorize(sourceId, 'banView')
  if not allowed then return response(false, nil, authError) end
  local resultData, callError = banGuardCall('GetBan', sourceId, publicId)
  return resultData or response(false, nil, callError)
end

lib.callback.register('mz_admin:server:createBan', function(source, targetSource, duration, reason, expectedCitizenid)
  return MZAdminBansServer.Create(source, targetSource, duration, reason, expectedCitizenid)
end)

lib.callback.register('mz_admin:server:revokeBan', function(source, publicId, reason)
  return MZAdminBansServer.Revoke(source, publicId, reason)
end)

lib.callback.register('mz_admin:server:listBans', function(source, filters)
  return MZAdminBansServer.List(source, filters)
end)

lib.callback.register('mz_admin:server:getBan', function(source, publicId)
  return MZAdminBansServer.Get(source, publicId)
end)

RegisterNetEvent('mz_admin:server:banPlayer', function(targetSource, duration, reason, expectedCitizenid)
  local sourceId = source
  local resultData = MZAdminBansServer.Create(sourceId, targetSource, duration, reason, expectedCitizenid)
  TriggerClientEvent('mz_admin:client:banResult', sourceId, 'create', resultData)
end)

RegisterNetEvent('mz_admin:server:revokeBan', function(publicId, reason)
  local sourceId = source
  local resultData = MZAdminBansServer.Revoke(sourceId, publicId, reason)
  TriggerClientEvent('mz_admin:client:banResult', sourceId, 'revoke', resultData)
end)
