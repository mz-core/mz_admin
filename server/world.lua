local function doorsReady()
  if GetResourceState('mz_doors') ~= 'started' then return false end
  local ok, ready = pcall(function()
    local loaded = exports['mz_doors']:IsV2Ready()
    return loaded == true
  end)
  return ok and ready == true
end

local function propsReady()
  if GetResourceState('mz_props') ~= 'started' then return false end
  local ok, ready = pcall(function()
    return exports['mz_props']:IsReady()
  end)
  return ok and ready == true
end

local function furnitureReady()
  if GetResourceState('mz_furniture') ~= 'started' then return false end
  local ok, ready = pcall(function()
    return exports['mz_furniture']:IsReady()
  end)
  return ok and ready == true
end

local function phoneOutletsReady()
  if GetResourceState('mz_phone') ~= 'started' then return false end
  local ok, ready = pcall(function()
    return exports['mz_phone']:IsChargingOutletsReady()
  end)
  return ok and ready == true
end

local function phoneOutletEditorSettings()
  local ok, settings = pcall(function()
    return exports['mz_phone']:GetChargingOutletEditorSettings()
  end)
  if not ok or type(settings) ~= 'table' then
    return { chargerModel = 'mz_phone_charger', surfaceOffset = 0.015 }
  end
  return settings
end

local DraftSessions = {}
local PropDraftSessions = {}
local OutletDraftSessions = {}
local SESSION_TTL_SECONDS = 600

local function isEnabled(value)
  return value == true or value == 1 or value == '1' or value == 'true'
end

local function newSessionId(source)
  return ('world-door:%s:%s:%s'):format(source, os.time(), math.random(100000, 999999))
end

lib.callback.register('mz_admin:server:beginWorldDoorDraft', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldDoorCreate')
  if not allowed then return { ok = false, error = reason } end
  if not doorsReady() then return { ok = false, error = 'doors_v2_unavailable' } end
  local sessionId = newSessionId(source)
  DraftSessions[source] = {
    id = sessionId,
    expiresAt = os.time() + SESSION_TTL_SECONDS,
    used = false
  }
  return { ok = true, data = { sessionId = sessionId, expiresAt = DraftSessions[source].expiresAt } }
end)

lib.callback.register('mz_admin:server:listWorldOrganizations', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldDoorCreate')
  if not allowed then return { ok = false, error = reason } end
  if GetResourceState('mz_core') ~= 'started' then
    return { ok = false, error = 'organization_repository_unavailable' }
  end
  local ok, rows = pcall(function()
    return exports['mz_org']:ListOrgs()
  end)
  if not ok or type(rows) ~= 'table' then
    return { ok = false, error = 'organization_repository_unavailable' }
  end

  local organizations = {}
  for _, org in ipairs(rows) do
    if type(org) == 'table' and isEnabled(org.active)
      and type(org.code) == 'string' and org.code ~= '' then
      organizations[#organizations + 1] = {
        code = tostring(org.code):lower(),
        name = tostring(org.name or org.code),
        type = tostring(org.typeName or org.type or org.typeCode or org.type_name or org.type_code or '')
      }
    end
  end
  table.sort(organizations, function(left, right)
    if left.type == right.type then return left.name < right.name end
    return left.type < right.type
  end)
  return { ok = true, data = { organizations = organizations } }
end)

lib.callback.register('mz_admin:server:listWorldDoors', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldView')
  if not allowed then
    allowed, reason = MZAdminSecurity.Authorize(source, 'worldDoorManage')
  end
  if not allowed then return { ok = false, error = reason } end
  if not doorsReady() then return { ok = false, error = 'doors_v2_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_doors']:ListV2DoorsForAdmin(source)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'doors_service_failed' } end
  return { ok = true, data = { doors = result } }
end)

lib.callback.register('mz_admin:server:listWorldDoorGroups', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldView')
  if not allowed then
    allowed, reason = MZAdminSecurity.Authorize(source, 'worldDoorCreate')
  end
  if not allowed then
    allowed, reason = MZAdminSecurity.Authorize(source, 'worldDoorManage')
  end
  if not allowed then return { ok = false, error = reason } end
  if not doorsReady() then return { ok = false, error = 'doors_v2_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_doors']:ListV2DoorGroupsForAdmin(source)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'doors_service_failed' } end
  return { ok = true, data = { groups = result } }
end)

lib.callback.register('mz_admin:server:createWorldDoorGroup', function(source, payload)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldDoorManage')
  if not allowed then return { ok = false, error = reason } end
  if not doorsReady() then return { ok = false, error = 'doors_v2_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_doors']:CreateV2DoorGroup(source, payload)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'doors_service_failed' } end
  return { ok = true, data = { group = result } }
end)

lib.callback.register('mz_admin:server:setWorldDoorGroup', function(source, doorId, groupId)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldDoorManage')
  if not allowed then return { ok = false, error = reason } end
  if not doorsReady() then return { ok = false, error = 'doors_v2_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_doors']:SetV2DoorGroupForAdmin(source, doorId, groupId)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'doors_service_failed' } end
  return { ok = true, data = { door = result } }
end)

lib.callback.register('mz_admin:server:updateWorldDoorPresentation', function(source, doorId, payload)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldDoorManage')
  if not allowed then return { ok = false, error = reason } end
  if not doorsReady() then return { ok = false, error = 'doors_v2_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_doors']:UpdateV2DoorPresentationForAdmin(source, doorId, payload)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'doors_service_failed' } end
  return { ok = true, data = { door = result } }
end)

lib.callback.register('mz_admin:server:createWorldDoor', function(source, sessionId, payload)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldDoorCreate')
  if not allowed then return { ok = false, error = reason } end
  if not doorsReady() then return { ok = false, error = 'doors_v2_unavailable' } end
  local session = DraftSessions[source]
  if not session or session.id ~= tostring(sessionId or '') then
    return { ok = false, error = 'invalid_draft_session' }
  end
  if session.used == true or os.time() > session.expiresAt then
    DraftSessions[source] = nil
    return { ok = false, error = 'expired_draft_session' }
  end
  local callOk, success, result = pcall(function()
    return exports['mz_doors']:CreateV2Door(source, payload)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'doors_service_failed' } end
  session.used = true
  DraftSessions[source] = nil
  return { ok = true, data = { door = result } }
end)

lib.callback.register('mz_admin:server:setWorldDoorLocked', function(source, doorId, locked)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldDoorManage')
  if not allowed then return { ok = false, error = reason } end
  if not doorsReady() then return { ok = false, error = 'doors_v2_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_doors']:SetV2DoorLockedForAdmin(source, doorId, locked == true)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'doors_service_failed' } end
  return { ok = true, data = { door = result } }
end)

lib.callback.register('mz_admin:server:setWorldDoorActive', function(source, doorId, active)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldDoorArchive')
  if not allowed then return { ok = false, error = reason } end
  if not doorsReady() then return { ok = false, error = 'doors_v2_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_doors']:SetV2DoorActiveForAdmin(source, doorId, active == true)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'doors_service_failed' } end
  return { ok = true, data = { door = result } }
end)

lib.callback.register('mz_admin:server:cancelWorldDoorDraft', function(source, sessionId)
  local session = DraftSessions[source]
  if session and session.id == tostring(sessionId or '') then DraftSessions[source] = nil end
  return { ok = true }
end)

lib.callback.register('mz_admin:server:beginWorldPropDraft', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldPropCreate')
  if not allowed then return { ok = false, error = reason } end
  if not propsReady() then return { ok = false, error = 'props_unavailable' } end
  local sessionId = newSessionId(source):gsub('world%-door', 'world-prop')
  PropDraftSessions[source] = {
    id = sessionId,
    expiresAt = os.time() + SESSION_TTL_SECONDS,
    used = false
  }
  return { ok = true, data = { sessionId = sessionId, expiresAt = PropDraftSessions[source].expiresAt } }
end)

lib.callback.register('mz_admin:server:createWorldProp', function(source, sessionId, payload)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldPropCreate')
  if not allowed then return { ok = false, error = reason } end
  if not propsReady() then return { ok = false, error = 'props_unavailable' } end
  local session = PropDraftSessions[source]
  if not session or session.id ~= tostring(sessionId or '') then
    return { ok = false, error = 'invalid_draft_session' }
  end
  if session.used == true or os.time() > session.expiresAt then
    PropDraftSessions[source] = nil
    return { ok = false, error = 'expired_draft_session' }
  end
  local callOk, success, result = pcall(function()
    return exports['mz_props']:CreatePropForAdmin(source, payload)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'props_service_failed' } end
  session.used = true
  PropDraftSessions[source] = nil
  return { ok = true, data = { prop = result } }
end)

lib.callback.register('mz_admin:server:listWorldProps', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldView')
  if not allowed then return { ok = false, error = reason } end
  if not propsReady() then return { ok = false, error = 'props_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_props']:ListPropsForAdmin(source)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'props_service_failed' } end
  return { ok = true, data = { props = result } }
end)

lib.callback.register('mz_admin:server:listFurnitureCatalog', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'furnitureView')
  if not allowed then return { ok = false, error = reason } end
  if not furnitureReady() then return { ok = false, error = 'furniture_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_furniture']:ListCatalogForAdmin(source)
  end)
  if not callOk or success ~= true then
    return { ok = false, error = result or 'furniture_service_failed' }
  end
  return { ok = true, data = result }
end)

lib.callback.register('mz_admin:server:getFurnitureRecoveryOverview', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'furnitureRecovery')
  if not allowed then return { ok = false, error = reason } end
  if not furnitureReady() then return { ok = false, error = 'furniture_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_furniture']:GetRecoveryOverviewForAdmin(source)
  end)
  if not callOk or success ~= true then
    return { ok = false, error = result or 'furniture_recovery_overview_failed' }
  end
  return { ok = true, data = result }
end)

lib.callback.register('mz_admin:server:runFurnitureReconciliation', function(source, reason)
  local allowed, permission = MZAdminSecurity.Authorize(source, 'furnitureRecovery')
  if not allowed then return { ok = false, error = permission } end
  if not furnitureReady() then return { ok = false, error = 'furniture_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_furniture']:RunOwnerReconciliationForAdmin(source, reason)
  end)
  if not callOk or success ~= true then
    return { ok = false, error = result or 'furniture_reconciliation_failed' }
  end
  return { ok = true, data = result }
end)

lib.callback.register('mz_admin:server:reconcileFurniturePlayer', function(source, targetSource, expectedCitizenid)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'furnitureRecovery')
  if not allowed then return { ok = false, error = reason } end
  if not furnitureReady() then return { ok = false, error = 'furniture_unavailable' } end
  local identityMatches, identityReason = MZAdminSecurity.ValidateTargetIdentity(targetSource, expectedCitizenid)
  if not identityMatches then return { ok = false, error = identityReason } end
  local callOk, success, result = pcall(function()
    return exports['mz_furniture']:ReconcilePlayerFinancesForAdmin(source, targetSource)
  end)
  if not callOk or success ~= true then
    return { ok = false, error = result or 'furniture_financial_reconciliation_failed' }
  end
  return { ok = true, data = result }
end)

lib.callback.register('mz_admin:server:setWorldPropActive', function(source, propId, active)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldPropArchive')
  if not allowed then return { ok = false, error = reason } end
  if not propsReady() then return { ok = false, error = 'props_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_props']:SetPropActiveForAdmin(source, propId, active == true)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'props_service_failed' } end
  return { ok = true, data = { prop = result } }
end)

lib.callback.register('mz_admin:server:updateWorldProp', function(source, propId, payload)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldPropManage')
  if not allowed then return { ok = false, error = reason } end
  if not propsReady() then return { ok = false, error = 'props_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_props']:UpdatePropForAdmin(source, propId, payload)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'props_service_failed' } end
  return { ok = true, data = { prop = result } }
end)

lib.callback.register('mz_admin:server:cancelWorldPropDraft', function(source, sessionId)
  local session = PropDraftSessions[source]
  if session and session.id == tostring(sessionId or '') then PropDraftSessions[source] = nil end
  return { ok = true }
end)

lib.callback.register('mz_admin:server:getWorldChargingOutletEditorSettings', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldPropManage')
  if not allowed then return { ok = false, error = reason } end
  if not phoneOutletsReady() then return { ok = false, error = 'charging_outlets_unavailable' } end
  return { ok = true, data = phoneOutletEditorSettings() }
end)

lib.callback.register('mz_admin:server:beginWorldChargingOutletDraft', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldPropCreate')
  if not allowed then return { ok = false, error = reason } end
  if not phoneOutletsReady() then return { ok = false, error = 'charging_outlets_unavailable' } end
  local sessionId = newSessionId(source):gsub('world%-door', 'world-charging-outlet')
  OutletDraftSessions[source] = {
    id = sessionId,
    expiresAt = os.time() + SESSION_TTL_SECONDS,
    used = false
  }
  local settings = phoneOutletEditorSettings()
  return { ok = true, data = {
    sessionId = sessionId,
    expiresAt = OutletDraftSessions[source].expiresAt,
    chargerModel = settings.chargerModel,
    surfaceOffset = settings.surfaceOffset
  } }
end)

lib.callback.register('mz_admin:server:listWorldChargingOutlets', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldView')
  if not allowed then allowed, reason = MZAdminSecurity.Authorize(source, 'worldPropManage') end
  if not allowed then allowed, reason = MZAdminSecurity.Authorize(source, 'worldPropArchive') end
  if not allowed then return { ok = false, error = reason } end
  if not phoneOutletsReady() then return { ok = false, error = 'charging_outlets_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_phone']:ListChargingOutletsForAdmin(source)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'charging_outlets_service_failed' } end
  return { ok = true, data = { outlets = result } }
end)

lib.callback.register('mz_admin:server:createWorldChargingOutlet', function(source, sessionId, payload)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldPropCreate')
  if not allowed then return { ok = false, error = reason } end
  if not phoneOutletsReady() then return { ok = false, error = 'charging_outlets_unavailable' } end
  local session = OutletDraftSessions[source]
  if not session or session.id ~= tostring(sessionId or '') then
    return { ok = false, error = 'invalid_draft_session' }
  end
  if session.used == true or os.time() > session.expiresAt then
    OutletDraftSessions[source] = nil
    return { ok = false, error = 'expired_draft_session' }
  end
  local callOk, success, result = pcall(function()
    return exports['mz_phone']:CreateChargingOutletForAdmin(source, payload)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'charging_outlets_service_failed' } end
  session.used = true
  OutletDraftSessions[source] = nil
  return { ok = true, data = { outlet = result } }
end)

lib.callback.register('mz_admin:server:updateWorldChargingOutlet', function(source, outletId, payload)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldPropManage')
  if not allowed then return { ok = false, error = reason } end
  if not phoneOutletsReady() then return { ok = false, error = 'charging_outlets_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_phone']:UpdateChargingOutletForAdmin(source, outletId, payload)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'charging_outlets_service_failed' } end
  return { ok = true, data = { outlet = result } }
end)

lib.callback.register('mz_admin:server:setWorldChargingOutletEnabled', function(source, outletId, enabled)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'worldPropArchive')
  if not allowed then return { ok = false, error = reason } end
  if not phoneOutletsReady() then return { ok = false, error = 'charging_outlets_unavailable' } end
  local callOk, success, result = pcall(function()
    return exports['mz_phone']:SetChargingOutletEnabledForAdmin(source, outletId, enabled == true)
  end)
  if not callOk or success ~= true then return { ok = false, error = result or 'charging_outlets_service_failed' } end
  return { ok = true, data = { outlet = result } }
end)

lib.callback.register('mz_admin:server:cancelWorldChargingOutletDraft', function(source, sessionId)
  local session = OutletDraftSessions[source]
  if session and session.id == tostring(sessionId or '') then OutletDraftSessions[source] = nil end
  return { ok = true }
end)

AddEventHandler('playerDropped', function()
  DraftSessions[source] = nil
  PropDraftSessions[source] = nil
  OutletDraftSessions[source] = nil
end)
