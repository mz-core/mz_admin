local function response(ok, data, err)
  return { ok = ok == true, data = ok == true and data or nil, error = ok == true and nil or tostring(err or 'unknown_error') }
end

local function authorize(source, action)
  local allowed, reason = MZAdminSecurity.Authorize(source, action)
  if not allowed then return false, response(false, nil, reason) end
  if GetResourceState('mz_banguard') ~= 'started' then
    return false, response(false, nil, 'security_center_unavailable')
  end
  return true
end

local function invoke(source, action, callback)
  local allowed, denied = authorize(source, action)
  if not allowed then return denied end
  local ok, guardResponse = pcall(callback)
  if not ok or type(guardResponse) ~= 'table' then
    return response(false, nil, 'security_center_unavailable')
  end
  return guardResponse
end

lib.callback.register('mz_admin:server:securityAlertSummary', function(source)
  return invoke(source, 'securityAlertsView', function()
    return exports['mz_banguard']:GetSecurityAlertSummary(source)
  end)
end)

lib.callback.register('mz_admin:server:playerStateObservability', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'securityAlertsView')
  if not allowed then return response(false, nil, reason) end
  if GetResourceState('mz_core') ~= 'started' then return response(false, nil, 'core_unavailable') end
  local callOk, ok, result = pcall(function()
    return exports['mz_core']:GetPlayerStateObservability()
  end)
  if not callOk or ok ~= true then return response(false, nil, callOk and result or 'core_unavailable') end
  return response(true, result)
end)

lib.callback.register('mz_admin:server:securityIncidentList', function(source, filters)
  return invoke(source, 'securityAlertsView', function()
    return exports['mz_banguard']:ListSecurityIncidents(source, type(filters) == 'table' and filters or {})
  end)
end)

lib.callback.register('mz_admin:server:securityIncidentDetails', function(source, incidentId, includeIdentifiers)
  local action = includeIdentifiers == true and 'securityAlertIdentifiers' or 'securityAlertDetails'
  return invoke(source, action, function()
    return exports['mz_banguard']:GetSecurityIncident(source, incidentId, includeIdentifiers == true)
  end)
end)

lib.callback.register('mz_admin:server:securityIncidentAcknowledge', function(source, incidentId)
  return invoke(source, 'securityAlertAcknowledge', function()
    return exports['mz_banguard']:AcknowledgeSecurityIncident(source, incidentId)
  end)
end)

lib.callback.register('mz_admin:server:securityIncidentNote', function(source, incidentId, note)
  return invoke(source, 'securityAlertNote', function()
    return exports['mz_banguard']:AddSecurityIncidentNote(source, incidentId, note)
  end)
end)

lib.callback.register('mz_admin:server:securityIncidentStatus', function(source, incidentId, status)
  return invoke(source, 'securityAlertClear', function()
    return exports['mz_banguard']:SetSecurityIncidentStatus(source, incidentId, status)
  end)
end)

lib.callback.register('mz_admin:server:securityIncidentExport', function(source, incidentId, format)
  return invoke(source, 'securityAlertDetails', function()
    return exports['mz_banguard']:ExportSecurityIncidentEvidence(source, incidentId, format)
  end)
end)

lib.callback.register('mz_admin:server:securityIncidentLab', function(source, targetSource, enabled, durationSeconds, reason)
  return invoke(source, 'securityAlertLab', function()
    return exports['mz_banguard']:SetSecurityLabSubject(source, targetSource, enabled, durationSeconds, reason)
  end)
end)

lib.callback.register('mz_admin:server:securityIncidentAction', function(source, incidentId, action)
  action = tostring(action or ''):lower()
  local permissionAction = action == 'spectate' and 'securityAlertSpectate'
    or (action == 'goto' and 'securityAlertGoto' or nil)
  if not permissionAction then return response(false, nil, 'action_not_implemented') end
  return invoke(source, permissionAction, function()
    return exports['mz_banguard']:PrepareSecurityIncidentAction(source, incidentId, action)
  end)
end)
