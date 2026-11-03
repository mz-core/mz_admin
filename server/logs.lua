local function trim(value, maximum)
  if type(value) ~= 'string' then return nil end
  value = value:gsub('^%s+', ''):gsub('%s+$', '')
  if value == '' then return nil end
  maximum = tonumber(maximum) or 64
  if #value > maximum then value = value:sub(1, maximum) end
  return value
end

local function normalizeFilters(payload)
  payload = type(payload) == 'table' and payload or {}
  return {
    category = trim(payload.category or payload.scope, 32),
    severity = trim(payload.severity, 24),
    action = trim(payload.action, 96),
    actor = trim(payload.actor, 96),
    auditId = trim(payload.auditId or payload.audit_id, 96),
    search = trim(payload.search, 80),
    dateFrom = trim(payload.dateFrom or payload.date_from, 32),
    dateTo = trim(payload.dateTo or payload.date_to, 32),
    auditOnly = payload.auditOnly == true,
    limit = 25,
    offset = math.max(0, math.min(math.floor(tonumber(payload.offset) or 0), 10000))
  }
end

lib.callback.register('mz_admin:server:listAdminLogs', function(source, payload)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'logsView')
  if not allowed then return { ok = false, error = reason } end
  if GetResourceState('mz_core') ~= 'started' then
    return { ok = false, error = 'log_service_unavailable' }
  end

  local filters = normalizeFilters(payload)
  local callOk, rows, listError = pcall(function()
    return exports['mz_core']:ListGlobalLogsSecure(source, filters)
  end)
  if not callOk then
    print(('[mz_admin] falha ao listar logs globais: %s'):format(tostring(rows)))
    return { ok = false, error = 'log_service_failed' }
  end
  if type(rows) ~= 'table' then
    return { ok = false, error = listError or 'logs_unavailable' }
  end

  return {
    ok = true,
    data = {
      items = rows,
      scope = 'global',
      filters = filters,
      pagination = {
        limit = filters.limit,
        offset = filters.offset,
        returned = #rows
      }
    }
  }
end)
