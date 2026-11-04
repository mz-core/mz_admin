local failures = {}
local checks = 0

local function check(condition, label)
  checks = checks + 1
  if not condition then failures[#failures + 1] = label end
end

local function read(path)
  local file = assert(io.open(path, 'rb'))
  local contents = file:read('*a')
  file:close()
  return contents
end

local manifest = read('fxmanifest.lua')
local permissions = read('shared/permissions.lua')
local client = read('client/security_alerts.lua')
local server = read('server/security_alerts.lua')
local english = read('locales/en-us.json')

check(manifest:find("'client/security_alerts.lua'", 1, true) ~= nil, 'client module is in manifest')
check(manifest:find("'server/security_alerts.lua'", 1, true) ~= nil, 'server module is in manifest')
check(permissions:find('securityAlertIdentifiers', 1, true) ~= nil, 'identifier permission is separate')
check(permissions:find('securityAlertSpectate', 1, true) ~= nil, 'spectate permission is separate')
check(permissions:find('securityAlertGoto', 1, true) ~= nil, 'goto permission is separate')
check(client:find('Nenhum incidente encontrado', 1, true) ~= nil, 'empty menu state exists')
check(client:find("item.severity == 'critical'", 1, true) ~= nil, 'critical incident presentation exists')
check(client:find('ALERTAS %d', 1, true) ~= nil, 'unacknowledged badge fallback exists')
check(client:find("runtime = (type(locale) == 'function'", 1, true) ~= nil
  and client:find("canary = (type(locale) == 'function'", 1, true) ~= nil
  and english:find('"s_36a55c366f72": "Client runtime"', 1, true) ~= nil
  and english:find('"s_79945f0dfe7d": "Canaries"', 1, true) ~= nil
  and client:find('canary_triggered', 1, true) ~= nil,
  'V3 runtime/canary filters and labels are exposed')
check(client:find('TriggerServerEvent', 1, true) == nil, 'client has no direct incident mutation event')
check(client:find('RegisterNetEvent', 1, true) == nil, 'client cannot register an incident creation endpoint')
check(server:find("lib.callback.register('mz_admin:server:securityIncidentList', function(source", 1, true) ~= nil, 'list callback captures source')
check(server:find("lib.callback.register('mz_admin:server:securityIncidentDetails', function(source", 1, true) ~= nil, 'details callback captures source')
check(server:find("lib.callback.register('mz_admin:server:securityIncidentAction', function(source", 1, true) ~= nil, 'action callback captures source')
check(server:find("action == 'spectate'", 1, true) ~= nil and server:find("action == 'goto'", 1, true) ~= nil, 'only investigation actions are routed')
check(server:find("action == 'kick'", 1, true) == nil and server:find("action == 'ban'", 1, true) == nil, 'quick kick and ban are absent')

if #failures > 0 then
  io.stderr:write(('security_alert_center_contract_harness: %d/%d checks failed\n'):format(#failures, checks))
  for _, failure in ipairs(failures) do io.stderr:write(' - ' .. failure .. '\n') end
  os.exit(1)
end

print(('security_alert_center_contract_harness: ok (%d checks)'):format(checks))
