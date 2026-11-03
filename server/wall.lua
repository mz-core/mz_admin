MZAdminWall = MZAdminWall or {}

local watchers = {}
local staffTagCache = {}
local identityCache = {}
local nextAuthorizationAt = {}
local STAFF_TAG_TTL_MS = 2000
local IDENTITY_TTL_MS = 2000

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
  local name = tostring(GetPlayerName(sourceId) or ('ID ' .. tostring(sourceId)))
  name = name:gsub('[%c~]', '')
  if #name > 64 then name = name:sub(1, 64) end
  return name
end

local function staffContext(sourceId)
  if GetResourceState('mz_core') ~= 'started' then return nil end
  local ok, context = pcall(function()
    return exports['mz_core']:GetStaffContext(sourceId)
  end)
  return ok and type(context) == 'table' and context or nil
end

local function citizenId(sourceId, now)
  local cached = identityCache[sourceId]
  if cached and now < cached.expiresAt then return cached.citizenid end

  local resolved
  if GetResourceState('mz_core') == 'started' then
    local ok, identity = pcall(function()
      return exports['mz_core']:ResolvePlayerIdentity(sourceId)
    end)
    if ok and type(identity) == 'table' and identity.ok == true then
      resolved = tostring(identity.citizenid or ''):gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', '')
      if resolved == '' then resolved = nil end
      if resolved and #resolved > 64 then resolved = resolved:sub(1, 64) end
    end
  end

  identityCache[sourceId] = {
    citizenid = resolved,
    expiresAt = now + IDENTITY_TTL_MS
  }
  return resolved
end

local function actorPayload(sourceId)
  local context = staffContext(sourceId) or {}
  local role = type(context.role) == 'table' and context.role or {}
  return {
    type = 'player',
    id = context.citizenid or ('source:%s'):format(tostring(sourceId)),
    source = sourceId,
    citizenid = context.citizenid,
    name = safeName(sourceId),
    owner = context.owner == true,
    role = {
      code = tostring(role.code or ''),
      name = tostring(role.name or ''),
      level = tonumber(role.level) or 0
    }
  }
end

local function audit(sourceId, action, reason)
  if GetResourceState('mz_core') ~= 'started' then
    print(('[mz_admin][wall-audit] actor=%s action=%s reason=%s error=mz_core_unavailable'):format(
      tostring(sourceId),
      tostring(action),
      tostring(reason)
    ))
    return false
  end

  local ok, auditId = pcall(function()
    return exports['mz_core']:CreateDetailedLog('admin', 'admin.wall.' .. action, {
      actor = actorPayload(sourceId),
      target = {
        type = 'tool',
        id = 'wall'
      },
      context = {
        resource = 'mz_admin',
        permission = MZAdminPermissions.wall,
        state = action
      },
      meta = {
        reason = tostring(reason or action)
      }
    })
  end)

  if not ok or not auditId then
    print(('[mz_admin][wall-audit] actor=%s action=%s reason=%s error=%s'):format(
      tostring(sourceId),
      tostring(action),
      tostring(reason),
      tostring(ok and 'audit_not_persisted' or auditId)
    ))
    return false
  end
  return true
end

local function setState(sourceId, enabled)
  sourceId = normalizeSource(sourceId)
  if not sourceId then return false end
  watchers[sourceId] = enabled == true or nil
  nextAuthorizationAt[sourceId] = enabled == true and 0 or nil
  return true
end

local function staffTag(sourceId, now)
  local cached = staffTagCache[sourceId]
  if cached and now < cached.expiresAt then return cached.tag end

  local context = staffContext(sourceId)
  local tag
  if context then
    tag = context.owner == true and 'OWNER' or 'STAFF'
  end
  staffTagCache[sourceId] = {
    tag = tag,
    expiresAt = now + STAFF_TAG_TTL_MS
  }
  return tag
end

function MZAdminWall.IsEnabled(sourceId)
  return watchers[normalizeSource(sourceId)] == true
end

function MZAdminWall.BuildSnapshot(now)
  local snapshot = {}
  now = tonumber(now) or GetGameTimer()

  for _, rawPlayerId in ipairs(GetPlayers()) do
    local playerId = normalizeSource(rawPlayerId)
    if online(playerId) then
      local ped = GetPlayerPed(playerId)
      if ped and ped ~= 0 then
        local coords = GetEntityCoords(ped)
        snapshot[#snapshot + 1] = {
          id = playerId,
          name = safeName(playerId),
          x = tonumber(coords.x) or 0.0,
          y = tonumber(coords.y) or 0.0,
          z = tonumber(coords.z) or 0.0,
          bucket = tonumber(GetPlayerRoutingBucket(playerId)) or 0,
          staffTag = staffTag(playerId, now),
          citizenid = citizenId(playerId, now)
        }
      end
    end
  end

  table.sort(snapshot, function(left, right)
    return left.id < right.id
  end)
  return snapshot
end

local function filteredSnapshot(snapshot, watcherBucket)
  if Config.Wall and Config.Wall.showOtherBuckets == true then return snapshot end
  local result = {}
  for _, row in ipairs(snapshot) do
    if row.bucket == watcherBucket then result[#result + 1] = row end
  end
  return result
end

lib.callback.register('mz_admin:server:toggleWall', function(source)
  local sourceId = normalizeSource(source)
  if not sourceId then return { ok = false, error = 'invalid_source' } end

  if watchers[sourceId] == true then
    setState(sourceId, false)
    audit(sourceId, 'disabled', 'requested')
    return { ok = true, enabled = false }
  end

  local allowed, reason = MZAdminSecurity.Authorize(sourceId, 'wall')
  if not allowed then
    audit(sourceId, 'denied', reason)
    return { ok = false, error = reason }
  end

  if not audit(sourceId, 'enabled', 'requested') then
    return { ok = false, error = 'audit_failed' }
  end

  setState(sourceId, true)
  return { ok = true, enabled = true }
end)

RegisterNetEvent('mz_admin:server:disableWall', function()
  local sourceId = normalizeSource(source)
  if not sourceId or watchers[sourceId] ~= true then return end
  setState(sourceId, false)
  audit(sourceId, 'disabled', 'client_cleanup')
end)

function MZAdminWall.Tick(now)
  if not next(watchers) then return end

  now = tonumber(now) or GetGameTimer()
  local snapshot = MZAdminWall.BuildSnapshot(now)
  local authorizationInterval = tonumber(Config.Wall and Config.Wall.authorizationInterval) or 1500
  authorizationInterval = math.max(500, math.min(10000, math.floor(authorizationInterval)))

  for watcher in pairs(watchers) do
    if not online(watcher) then
      watchers[watcher] = nil
      nextAuthorizationAt[watcher] = nil
    else
      local authAt = nextAuthorizationAt[watcher] or 0
      if now >= authAt then
        nextAuthorizationAt[watcher] = now + authorizationInterval
        local allowed = MZAdminSecurity.HasGlobalPermission(watcher, MZAdminPermissions.wall)
        if not allowed then
          setState(watcher, false)
          TriggerClientEvent('mz_admin:client:setWallState', watcher, false)
          audit(watcher, 'revoked', 'permission_revoked')
        end
      end

      if watchers[watcher] == true then
        local bucket = tonumber(GetPlayerRoutingBucket(watcher)) or 0
        TriggerClientEvent(
          'mz_admin:client:updateWall',
          watcher,
          filteredSnapshot(snapshot, bucket),
          bucket
        )
      end
    end
  end
end

CreateThread(function()
  while true do
    local interval = tonumber(Config.Wall and Config.Wall.updateInterval) or 250
    interval = math.max(100, math.min(2000, math.floor(interval)))
    Wait(interval)
    MZAdminWall.Tick()
  end
end)

AddEventHandler('playerDropped', function()
  local sourceId = normalizeSource(source)
  if not sourceId then return end
  watchers[sourceId] = nil
  nextAuthorizationAt[sourceId] = nil
  staffTagCache[sourceId] = nil
  identityCache[sourceId] = nil
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  for watcher in pairs(watchers) do
    TriggerClientEvent('mz_admin:client:setWallState', watcher, false)
  end
end)

exports('IsPlayerUsingWall', function(playerId)
  return MZAdminWall.IsEnabled(playerId)
end)
