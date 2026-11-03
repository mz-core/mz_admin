MZAdminWhitelistServer = MZAdminWhitelistServer or {}

local function response(ok, data, err)
  return {
    ok = ok == true,
    data = ok == true and data or nil,
    error = ok == true and nil or tostring(err or 'unknown_error')
  }
end

local function whitelistCall(operation, ...)
  if GetResourceState('mz_whitelist') ~= 'started' then
    return nil, 'whitelist_unavailable'
  end
  local args = { ... }
  local ok, result = pcall(function()
    if operation == 'list' then
      return exports['mz_whitelist']:ListEntries(args[1], args[2])
    end
    if operation == 'decide' then
      return exports['mz_whitelist']:Decide(args[1], args[2], args[3], args[4])
    end
    error('unsupported whitelist operation')
  end)
  if not ok or type(result) ~= 'table' then
    print(('[mz_admin][whitelist] operation=%s error=%s'):format(
      tostring(operation),
      tostring(ok and 'invalid_response' or result)
    ))
    return nil, 'whitelist_call_failed'
  end
  return result
end

function MZAdminWhitelistServer.List(sourceId, filters)
  local allowed, authError = MZAdminSecurity.Authorize(sourceId, 'whitelistView')
  if not allowed then return response(false, nil, authError) end
  local resultData, callError = whitelistCall('list', sourceId, filters)
  return resultData or response(false, nil, callError)
end

function MZAdminWhitelistServer.Decide(sourceId, publicId, action, reason)
  local allowed, authError = MZAdminSecurity.Authorize(sourceId, 'whitelistManage')
  if not allowed then return response(false, nil, authError) end
  local resultData, callError = whitelistCall(
    'decide',
    sourceId,
    publicId,
    action,
    reason
  )
  return resultData or response(false, nil, callError)
end

lib.callback.register('mz_admin:server:listWhitelist', function(source, filters)
  return MZAdminWhitelistServer.List(source, filters)
end)

lib.callback.register('mz_admin:server:decideWhitelist', function(source, publicId, action, reason)
  return MZAdminWhitelistServer.Decide(source, publicId, action, reason)
end)
