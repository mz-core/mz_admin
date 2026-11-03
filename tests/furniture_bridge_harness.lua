local function read(path)
  local file = assert(io.open(path, 'rb'))
  local value = file:read('*a')
  file:close()
  return value
end

local function expect(condition, message)
  if not condition then error(message, 2) end
end

local permissions = read('mz_admin/shared/permissions.lua')
local security = read('mz_admin/server/security.lua')
local bridge = read('mz_admin/server/world.lua')
local client = read('mz_admin/client/world_furniture_catalog.lua')
local manifest = read('mz_admin/fxmanifest.lua')
local resourceConfig = read('mz_furniture/shared/config.lua')

expect(permissions:find("furnitureView = 'staff.furniture.view'", 1, true), 'admin permission is missing')
expect(security:find("GetResourceState('mz_furniture')", 1, true), 'menu readiness check is missing')
expect(bridge:find("Authorize(source, 'furnitureView')", 1, true), 'server bridge authorization is missing')
expect(bridge:find("exports['mz_furniture']:ListCatalogForAdmin(source)", 1, true), 'catalog export bridge is missing')
expect(client:find("mz_admin:server:listFurnitureCatalog", 1, true), 'client callback is missing')
expect(manifest:find("'client/world_furniture_catalog.lua'", 1, true), 'client module is not in the manifest')
expect(resourceConfig:find('PurchasesEnabled = true', 1, true), 'Phase 3 purchases must be enabled')
expect(resourceConfig:find('PlacementEnabled = true', 1, true), 'Phase 4 placement must be enabled')
expect(resourceConfig:find('ResaleEnabled = true', 1, true),
  'phase 6 must enable guarded warehouse resale')
expect(resourceConfig:find('OwnerReconciliationEnabled = true', 1, true),
  'phase 7 must enable owner reconciliation')
expect(bridge:find("Authorize(source, 'furnitureRecovery')", 1, true),
  'phase 7 recovery bridge must require its dedicated permission')

print('mz_admin furniture bridge harness: PASS')
