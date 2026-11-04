MZAdminSecurity = MZAdminSecurity or {}

local lastRequestAt = {}
local REQUEST_COOLDOWN_MS = 150

local function normalizeSource(source)
  source = tonumber(source)
  if not source or source <= 0 then return nil end
  return math.floor(source)
end

local function normalizeAction(action)
  if type(action) ~= 'string' then return nil end
  action = action:gsub('^%s+', ''):gsub('%s+$', '')
  if action == '' or #action > 64 then return nil end
  if type(MZAdminPermissions) ~= 'table' or not MZAdminPermissions[action] then return nil end
  return action
end

local function rateAllowed(source, bucket)
  local now = GetGameTimer()
  local key = ('%s:%s'):format(source, bucket)
  local previous = lastRequestAt[key]
  if previous and now - previous < REQUEST_COOLDOWN_MS then return false end
  lastRequestAt[key] = now
  return true
end

function MZAdminSecurity.HasGlobalPermission(source, permission)
  source = normalizeSource(source)
  if not source or type(permission) ~= 'string' or permission == '' then return false end
  if GetResourceState('mz_core') ~= 'started' then return false end

  local ok, allowed = pcall(function()
    return exports['mz_core']:HasGlobalPermission(source, permission)
  end)
  return ok and allowed == true
end

function MZAdminSecurity.Authorize(source, action, options)
  source = normalizeSource(source)
  action = normalizeAction(action)
  if not source or not action then return false, 'invalid_action' end

  options = type(options) == 'table' and options or {}
  if options.rateLimit ~= false and not rateAllowed(source, action) then
    return false, 'rate_limited'
  end

  local permission = MZAdminPermissions[action]
  if not MZAdminSecurity.HasGlobalPermission(source, permission) then
    return false, 'permission_denied'
  end

  return true, permission
end

function MZAdminSecurity.MenuContext(source)
  local allowed, err = MZAdminSecurity.Authorize(source, 'menu')
  if not allowed then return false, err end

  local actions = {}
  for action, permission in pairs(MZAdminPermissions or {}) do
    actions[action] = MZAdminSecurity.HasGlobalPermission(source, permission)
  end

  local organizationAccess = MZAdminSecurity.HasGlobalPermission(source, 'staff.panel.open')
    and (
      MZAdminSecurity.HasGlobalPermission(source, 'staff.orgs.view')
      or MZAdminSecurity.HasGlobalPermission(source, 'staff.orgs.create')
      or MZAdminSecurity.HasGlobalPermission(source, 'staff.orgs.manage')
    )

  local garageReady = false
  if GetResourceState('mz_garagem') == 'started' then
    local readyOk, ready = pcall(function()
      return exports['mz_garagem']:IsManagedGarageReady()
    end)
    garageReady = readyOk and ready == true
  end

  local garageCreationAvailable = garageReady and actions.garageCreate == true
  local garageModuleAvailable = garageReady and (
    actions.garageView == true
    or actions.garageCreate == true
  )

  local worldDoorsReady = false
  local worldDoorsRuntime = false
  local worldDoorsNativeRuntime = false
  if GetResourceState('mz_doors') == 'started' then
    local readyOk, loaded, runtimeEnabled, nativeRuntimeEnabled = pcall(function()
      return exports['mz_doors']:IsV2Ready()
    end)
    worldDoorsReady = readyOk and loaded == true
    worldDoorsRuntime = readyOk and runtimeEnabled == true
    worldDoorsNativeRuntime = readyOk and nativeRuntimeEnabled == true
  end
  local worldPropsReady = false
  if GetResourceState('mz_props') == 'started' then
    local readyOk, ready = pcall(function()
      return exports['mz_props']:IsReady()
    end)
    worldPropsReady = readyOk and ready == true
  end
  local phoneChargingOutletsReady = false
  if GetResourceState('mz_phone') == 'started' then
    local readyOk, ready = pcall(function()
      return exports['mz_phone']:IsChargingOutletsReady()
    end)
    phoneChargingOutletsReady = readyOk and ready == true
  end
  local furnitureReady = false
  if GetResourceState('mz_furniture') == 'started' then
    local readyOk, ready = pcall(function()
      return exports['mz_furniture']:IsReady()
    end)
    furnitureReady = readyOk and ready == true
  end
  local hasDoorAction = actions.worldView == true
    or actions.worldDoorCreate == true
    or actions.worldDoorManage == true
    or actions.worldDoorArchive == true
  local hasPropAction = actions.worldView == true
    or actions.worldPropCreate == true
    or actions.worldPropManage == true
    or actions.worldPropArchive == true
  local hasFurnitureAction = actions.furnitureView == true
    or actions.furnitureCreate == true
    or actions.furnitureManage == true
    or actions.furnitureArchive == true
    or actions.furnitureRecovery == true
  local worldModuleAvailable = (worldDoorsReady and hasDoorAction)
    or (worldPropsReady and hasPropAction)
    or (phoneChargingOutletsReady and hasPropAction)
    or (furnitureReady and hasFurnitureAction)

  local banGuardReady = false
  local securityCenterAvailable = false
  if GetResourceState('mz_banguard') == 'started' then
    local readyOk, ready = pcall(function()
      return exports['mz_banguard']:IsReady()
    end)
    banGuardReady = readyOk and ready == true
    if actions.securityAlertsView == true then
      local alertOk, alertStatus = pcall(function()
        return exports['mz_banguard']:GetWeaponGuardStatus(source)
      end)
      securityCenterAvailable = alertOk and type(alertStatus) == 'table' and alertStatus.ok == true
    end
  end

  local whitelistReady = false
  if GetResourceState('mz_whitelist') == 'started' then
    local readyOk, ready = pcall(function()
      return exports['mz_whitelist']:IsReady()
    end)
    whitelistReady = readyOk and ready == true
  end

  local warningsReady = false
  if GetResourceState('mz_warns') == 'started' then
    local readyOk, ready = pcall(function()
      return exports['mz_warns']:IsReady()
    end)
    warningsReady = readyOk and ready == true
  end

  return true, {
    actions = actions,
    organizationAccess = organizationAccess,
    staffManagementAvailable = actions.staffManage == true,
    garageCreationAvailable = garageCreationAvailable,
    garageModuleAvailable = garageModuleAvailable,
    worldModuleAvailable = worldModuleAvailable,
    worldDoorsReady = worldDoorsReady,
    worldDoorsRuntime = worldDoorsRuntime,
    worldDoorsNativeRuntime = worldDoorsNativeRuntime,
    worldPropsReady = worldPropsReady,
    phoneChargingOutletsReady = phoneChargingOutletsReady,
    furnitureReady = furnitureReady,
    banGuardReady = banGuardReady,
    securityCenterAvailable = securityCenterAvailable,
    banCreationAvailable = banGuardReady and actions.ban == true,
    banModuleAvailable = banGuardReady and actions.banView == true,
    whitelistReady = whitelistReady,
    whitelistModuleAvailable = whitelistReady and actions.whitelistView == true,
    warningsReady = warningsReady,
    warningsModuleAvailable = warningsReady and actions.warningsView == true,
    warningIssueAvailable = warningsReady and actions.warningsIssue == true
  }
end

local function resolvePlayerIdentity(sourceId)
  if GetResourceState('mz_core') ~= 'started' then return nil end
  local ok, identity = pcall(function()
    return exports['mz_core']:ResolvePlayerIdentity(sourceId)
  end)
  if not ok or type(identity) ~= 'table' or identity.ok ~= true then return nil end
  local citizenid = tostring(identity.citizenid or ''):gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', '')
  if citizenid == '' then return nil end
  local firstname = tostring(identity.firstname or ''):gsub('%c', ' '):sub(1, 64)
  local lastname = tostring(identity.lastname or ''):gsub('%c', ' '):sub(1, 64)
  return {
    citizenid = citizenid:sub(1, 64),
    accountId = tonumber(identity.accountId),
    characterId = tonumber(identity.characterId),
    characterName = (firstname .. ' ' .. lastname):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  }
end

-- Identidade publica do proprio Staff, para o cabecalho do tablet.
-- Nunca expoe identifiers privados (license/ip/token).
function MZAdminSecurity.SelfContext(source)
  local identity = resolvePlayerIdentity(source)
  local name = tostring(GetPlayerName(source) or ('ID ' .. tostring(source))):gsub('%c', ' '):sub(1, 96)
  if identity and identity.characterName ~= '' then
    name = identity.characterName
  end

  local role
  if GetResourceState('mz_core') == 'started' then
    local ok, context = pcall(function()
      return exports['mz_core']:GetStaffContext(source)
    end)
    if ok and type(context) == 'table' then
      if context.owner == true then
        role = { code = 'owner', name = 'Owner', level = 999 }
      elseif type(context.role) == 'table' then
        role = {
          code = tostring(context.role.code or ''):sub(1, 48),
          name = tostring(context.role.name or ''):sub(1, 48),
          level = tonumber(context.role.level) or 0
        }
      end
    end
  end

  return {
    name = name,
    citizenid = identity and identity.citizenid,
    role = role
  }
end

local function selectorAuthorized(source)
  for _, action in ipairs({ 'playersList', 'staffManage', 'ban', 'warningsIssue', 'furnitureRecovery' }) do
    local permission = MZAdminPermissions[action]
    if permission and MZAdminSecurity.HasGlobalPermission(source, permission) then
      return MZAdminSecurity.Authorize(source, action)
    end
  end
  return false, 'permission_denied'
end

function MZAdminSecurity.ValidateTargetIdentity(targetSource, expectedCitizenid, requireExpected)
  if expectedCitizenid == nil or type(expectedCitizenid) ~= 'string' then
    if requireExpected == true then return false, 'expected_identity_required' end
    return true
  end
  expectedCitizenid = tostring(expectedCitizenid or ''):gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 64)
  if expectedCitizenid == '' then
    if requireExpected == true then return false, 'expected_identity_required' end
    return true
  end
  local identity = resolvePlayerIdentity(targetSource)
  if not identity then return false, 'invalid_target' end
  if identity.citizenid ~= expectedCitizenid then return false, 'stale_target' end
  return true, nil, identity
end

local function onlinePlayerRows(requester, query, includeAccountId)
  query = tostring(query or ''):lower()
  local rows = {}
  for _, playerId in ipairs(GetPlayers()) do
    local targetSource = tonumber(playerId)
    if targetSource and targetSource > 0 and GetPlayerPing(targetSource) > 0 then
      local identity = resolvePlayerIdentity(targetSource) or {}
      local name = tostring(GetPlayerName(targetSource) or ('ID ' .. targetSource)):gsub('%c', ' '):sub(1, 96)
      local haystack = table.concat({
        tostring(targetSource), name, tostring(identity.characterName or ''), tostring(identity.citizenid or '')
      }, ' '):lower()
      if query == '' or haystack:find(query, 1, true) then
        rows[#rows + 1] = {
          key = identity.citizenid and ('character:' .. identity.citizenid) or ('source:' .. targetSource),
          source = targetSource,
          name = name,
          characterName = identity.characterName,
          citizenid = identity.citizenid,
          accountId = includeAccountId == true and identity.accountId or nil,
          characterId = identity.characterId,
          online = true,
          ping = math.max(0, math.floor(tonumber(GetPlayerPing(targetSource)) or 0)),
          self = targetSource == tonumber(requester)
        }
      end
    end
  end
  table.sort(rows, function(left, right)
    if left.self ~= right.self then return left.self == true end
    return tostring(left.characterName or left.name):lower() < tostring(right.characterName or right.name):lower()
  end)
  return rows
end

lib.callback.register('mz_admin:server:authorizeAction', function(source, action)
  local allowed, reason = MZAdminSecurity.Authorize(source, action)
  if allowed == true and (action == 'tp' or action == 'tpm')
    and GetResourceState('mz_banguard') == 'started' then
    pcall(function()
      exports['mz_banguard']:RegisterSecurityLease(source, 'movement.teleport', 10000, {
        reason = tostring(action)
      })
    end)
  end
  if allowed == true and action == 'spawnVehicle'
    and GetResourceState('mz_banguard') == 'started' then
    pcall(function()
      exports['mz_banguard']:RegisterSecurityLease(source, 'entity.spawn.vehicle', 5000, {
        quantity = 1, reason = 'staff_spawn_vehicle'
      })
    end)
  end
  return {
    ok = allowed == true,
    error = allowed and nil or reason
  }
end)

lib.callback.register('mz_admin:server:getMenuContext', function(source)
  local ok, result = MZAdminSecurity.MenuContext(source)
  if not ok then
    return { ok = false, error = result }
  end
  result.self = MZAdminSecurity.SelfContext(source)
  return { ok = true, data = result }
end)

-- Leitura autorizada dos personagens de uma conta (identidade canonica mz_core).
-- Nao inventa SQL nem facades: apenas projeta o contrato persistente existente.
lib.callback.register('mz_admin:server:getAccountCharacters', function(source, accountId)
  local allowed, reason = selectorAuthorized(source)
  if not allowed then return { ok = false, error = reason } end

  accountId = tonumber(accountId)
  if not accountId or accountId <= 0 then
    return { ok = false, error = 'invalid_target' }
  end

  if GetResourceState('mz_core') ~= 'started' then
    return { ok = false, error = 'identity_unavailable' }
  end

  local ok, characters = pcall(function()
    return exports['mz_core']:GetCharactersForAccount(accountId)
  end)
  if not ok or type(characters) ~= 'table' then
    return { ok = false, error = 'identity_unavailable' }
  end

  local items = {}
  for _, character in ipairs(characters) do
    if type(character) == 'table' then
      local charinfo = type(character.charinfo) == 'table' and character.charinfo or {}
      items[#items + 1] = {
        characterId = tonumber(character.characterId),
        accountId = tonumber(character.accountId),
        citizenid = tostring(character.citizenid or ''):gsub('%c', ''):sub(1, 64),
        firstname = tostring(charinfo.firstname or ''):gsub('%c', ' '):sub(1, 64),
        lastname = tostring(charinfo.lastname or ''):gsub('%c', ' '):sub(1, 64),
        status = tostring(character.status or 'active'):sub(1, 32)
      }
    end
  end

  return { ok = true, data = { characters = items, total = #items } }
end)

lib.callback.register('mz_admin:server:listOnlinePlayers', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'playersList')
  if not allowed then
    return { ok = false, error = reason }
  end

  local rows = onlinePlayerRows(source, '', false)

  return {
    ok = true,
    data = {
      players = rows,
      total = #rows
    }
  }
end)

lib.callback.register('mz_admin:server:resolveTargetIdentity', function(source, targetSource, action)
  action = tostring(action or '')
  if action ~= 'kick' and action ~= 'ban' then
    return { ok = false, error = 'invalid_action' }
  end

  local permission = MZAdminPermissions[action]
  if type(permission) ~= 'string' or permission == ''
    or MZAdminSecurity.HasGlobalPermission(source, permission) ~= true then
    return { ok = false, error = 'permission_denied' }
  end

  targetSource = math.floor(tonumber(targetSource) or 0)
  if targetSource <= 0 or GetPlayerPing(targetSource) <= 0 then
    return { ok = false, error = 'invalid_target' }
  end

  local identity = resolvePlayerIdentity(targetSource)
  if not identity then
    return { ok = false, error = 'identity_unavailable' }
  end

  return {
    ok = true,
    source = targetSource,
    citizenid = identity.citizenid
  }
end)

lib.callback.register('mz_admin:server:searchPlayers', function(source, request)
  local allowed, reason = selectorAuthorized(source)
  if not allowed then return { ok = false, error = reason } end
  request = type(request) == 'table' and request or {}
  local query = tostring(request.query or ''):gsub('%c', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 64)
  local filter = tostring(request.filter or 'all'):lower()
  if filter ~= 'all' and filter ~= 'online' and filter ~= 'offline' then filter = 'all' end
  local page = math.max(1, math.floor(tonumber(request.page) or 1))
  local pageSize = math.max(1, math.min(25, math.floor(tonumber(request.pageSize) or 25)))
  local includeAccountId = MZAdminSecurity.HasGlobalPermission(source, MZAdminPermissions.staffManage)
    or MZAdminSecurity.HasGlobalPermission(source, MZAdminPermissions.warningsView)
  local matchingOnline = onlinePlayerRows(source, query, includeAccountId)
  local online = filter == 'offline' and {} or matchingOnline
  local items = {}
  if page == 1 then
    for _, row in ipairs(online) do items[#items + 1] = row end
  end

  local offlineTotal, hasMore = 0, false
  local hint
  if filter ~= 'online' then
    if #query < 2 then
      hint = filter == 'offline'
        and (type(locale) == 'function' and locale('server_messages.s_f2652510586d') or 'Digite ao menos 2 caracteres para buscar Characters offline.')
        or (type(locale) == 'function' and locale('server_messages.s_76010fa3c0b1') or 'Online primeiro. Digite ao menos 2 caracteres para incluir offline.')
    elseif GetResourceState('mz_core') == 'started' then
      local callOk, result = pcall(function()
        return exports['mz_core']:SearchCharacters(query, page, pageSize)
      end)
      if callOk and type(result) == 'table' then
        offlineTotal = math.max(0, tonumber(result.total) or 0)
        hasMore = result.hasMore == true
        local onlineCitizenids = {}
        for _, row in ipairs(matchingOnline) do
          if row.citizenid then onlineCitizenids[row.citizenid] = true end
        end
        for _, character in ipairs(type(result.items) == 'table' and result.items or {}) do
          local citizenid = tostring(character.citizenid or '')
          if citizenid ~= '' and not onlineCitizenids[citizenid] then
            local characterName = (tostring(character.firstname or '') .. ' ' .. tostring(character.lastname or ''))
              :gsub('%c', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
            items[#items + 1] = {
              key = 'character:' .. citizenid,
              citizenid = citizenid,
              accountId = includeAccountId and tonumber(character.accountId) or nil,
              characterId = tonumber(character.characterId),
              characterName = characterName,
              online = false
            }
          end
        end
      else
        hint = (type(locale) == 'function' and locale('server_messages.s_3089c4f978ae') or 'Busca offline indisponivel no momento.')
      end
    else
      hint = (type(locale) == 'function' and locale('server_messages.s_3089c4f978ae') or 'Busca offline indisponivel no momento.')
    end
  end

  return {
    ok = true,
    data = {
      items = items,
      total = #online + offlineTotal,
      page = page,
      pageSize = pageSize,
      hasMore = hasMore,
      hint = hint
    }
  }
end)

AddEventHandler('playerDropped', function()
  local sourceId = tonumber(source)
  if not sourceId then return end
  local prefix = tostring(sourceId) .. ':'
  for key in pairs(lastRequestAt) do
    if key:sub(1, #prefix) == prefix then lastRequestAt[key] = nil end
  end
end)
