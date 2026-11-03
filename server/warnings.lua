MZAdminWarningsServer = MZAdminWarningsServer or {}

local function response(ok, data, err)
  return {
    ok = ok == true,
    data = ok == true and data or nil,
    error = ok == true and nil or tostring(err or 'unknown_error')
  }
end

local function warnsCall(exportName, ...)
  if GetResourceState('mz_warns') ~= 'started' then
    return nil, 'warnings_unavailable'
  end

  local args = { ... }
  local ok, result = pcall(function()
    if exportName == 'Issue' then
      return exports['mz_warns']:Issue(args[1], args[2], args[3])
    elseif exportName == 'List' then
      return exports['mz_warns']:List(args[1], args[2])
    elseif exportName == 'Revoke' then
      return exports['mz_warns']:Revoke(args[1], args[2], args[3])
    end
    error(('unsupported mz_warns export: %s'):format(tostring(exportName)))
  end)
  if not ok or type(result) ~= 'table' then
    print(('[mz_admin][warnings] export=%s error=%s'):format(
      tostring(exportName),
      tostring(ok and 'invalid_response' or result)
    ))
    return nil, 'warnings_call_failed'
  end
  return result
end

function MZAdminWarningsServer.Issue(sourceId, targetSource, reason, expectedCitizenid)
  local allowed, authError = MZAdminSecurity.Authorize(sourceId, 'warningsIssue')
  if not allowed then return response(false, nil, authError) end
  local identityMatches, identityReason = MZAdminSecurity.ValidateTargetIdentity(targetSource, expectedCitizenid)
  if not identityMatches then return response(false, nil, identityReason) end
  local resultData, callError = warnsCall('Issue', sourceId, targetSource, reason)
  return resultData or response(false, nil, callError)
end

function MZAdminWarningsServer.List(sourceId, filters)
  local allowed, authError = MZAdminSecurity.Authorize(sourceId, 'warningsView')
  if not allowed then return response(false, nil, authError) end
  filters = type(filters) == 'table' and filters or {}
  local resultData, callError = warnsCall('List', sourceId, {
    status = filters.status,
    targetSource = filters.targetSource,
    search = filters.search,
    page = filters.page,
    pageSize = 25
  })
  return resultData or response(false, nil, callError)
end

function MZAdminWarningsServer.Revoke(sourceId, publicId, reason)
  local allowed, authError = MZAdminSecurity.Authorize(sourceId, 'warningsRevoke')
  if not allowed then return response(false, nil, authError) end
  local resultData, callError = warnsCall('Revoke', sourceId, publicId, reason)
  return resultData or response(false, nil, callError)
end

lib.callback.register('mz_admin:server:issueWarning', function(source, targetSource, reason, expectedCitizenid)
  return MZAdminWarningsServer.Issue(source, targetSource, reason, expectedCitizenid)
end)

lib.callback.register('mz_admin:server:listWarnings', function(source, filters)
  return MZAdminWarningsServer.List(source, filters)
end)

lib.callback.register('mz_admin:server:revokeWarning', function(source, publicId, reason)
  return MZAdminWarningsServer.Revoke(source, publicId, reason)
end)
