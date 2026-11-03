-- mz_admin - comandos administrativos protegidos pelo mz_core.

local function notify(message, notifyType, title)
  local payload = {
    type = notifyType or 'inform',
    title = title or Config.NotifyTitle or 'Admin',
    message = message,
    description = message,
    duration = 4000,
    icon = 'shield'
  }

  if GetResourceState('mz_notify') == 'started' then
    exports['mz_notify']:Notify(payload)
    return
  end

  if lib and lib.notify then
    lib.notify({
      type = payload.type,
      title = payload.title,
      description = payload.description,
      duration = payload.duration
    })
    return
  end

  TriggerEvent('chat:addMessage', {
    color = { 80, 180, 255 },
    args = { payload.title, payload.description }
  })
end

local function authorize(action)
  return MZAdminClient and MZAdminClient.Authorize and MZAdminClient.Authorize(action) == true
end

local function round(value, decimals)
  local multiplier = 10 ^ (decimals or 2)
  return math.floor((value * multiplier) + 0.5) / multiplier
end

local function coordsText(coords, heading)
  return {
    vector3 = ('vector3(%.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z),
    vector4 = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z, heading or 0.0),
    raw = ('%.2f, %.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z, heading or 0.0)
  }
end

local function getGroundCoordsForEntity(entity)
  local coords = GetEntityCoords(entity)

  local height = GetEntityHeightAboveGround(entity)
  if height and height > 0.01 and height < 10.0 then
    return vector3(coords.x, coords.y, coords.z - height)
  end

  local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)
  if foundGround then
    return vector3(coords.x, coords.y, groundZ)
  end

  -- Fallback seguro para copiar pontos de marker/interact quando a native não encontra o solo.
  return vector3(coords.x, coords.y, coords.z - 1.0)
end

local function teleportEntity(entity, coords, heading)
  if entity == 0 or not DoesEntityExist(entity) then return false end

  DoScreenFadeOut(150)
  Wait(160)

  RequestCollisionAtCoord(coords.x, coords.y, coords.z)
  SetEntityCoordsNoOffset(entity, coords.x, coords.y, coords.z, false, false, false)

  if heading then
    SetEntityHeading(entity, heading + 0.0)
  end

  local timeout = GetGameTimer() + 1500
  while not HasCollisionLoadedAroundEntity(entity) and GetGameTimer() < timeout do
    Wait(0)
  end

  DoScreenFadeIn(150)
  return true
end

local function getTeleportEntity()
  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)
  if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
    return vehicle
  end
  return ped
end

local function loadModel(model)
  local hash = type(model) == 'number' and model or joaat(model)
  if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
    return nil, 'Modelo inválido.'
  end

  RequestModel(hash)
  local timeout = GetGameTimer() + 5000
  while not HasModelLoaded(hash) do
    Wait(0)
    if GetGameTimer() > timeout then
      return nil, 'Timeout ao carregar modelo.'
    end
  end

  return hash
end

local TestWeapons = {
  pistol = 'WEAPON_PISTOL',
  combatpistol = 'WEAPON_COMBATPISTOL',
  pistol50 = 'WEAPON_PISTOL50',
  snspistol = 'WEAPON_SNSPISTOL',
  heavypistol = 'WEAPON_HEAVYPISTOL',
  revolver = 'WEAPON_REVOLVER',

  smg = 'WEAPON_SMG',
  microsmg = 'WEAPON_MICROSMG',
  combatpdw = 'WEAPON_COMBATPDW',
  machinepistol = 'WEAPON_MACHINEPISTOL',

  carbinerifle = 'WEAPON_CARBINERIFLE',
  specialcarbine = 'WEAPON_SPECIALCARBINE',
  assaultrifle = 'WEAPON_ASSAULTRIFLE',
  bullpuprifle = 'WEAPON_BULLPUPRIFLE',
  advancedrifle = 'WEAPON_ADVANCEDRIFLE',

  pumpshotgun = 'WEAPON_PUMPSHOTGUN',
  shotgun = 'WEAPON_PUMPSHOTGUN',
  sawnoffshotgun = 'WEAPON_SAWNOFFSHOTGUN',
  assaultshotgun = 'WEAPON_ASSAULTSHOTGUN',

  sniper = 'WEAPON_SNIPERRIFLE',
  sniperrifle = 'WEAPON_SNIPERRIFLE',
  heavysniper = 'WEAPON_HEAVYSNIPER',

  knife = 'WEAPON_KNIFE',
  bat = 'WEAPON_BAT',
  crowbar = 'WEAPON_CROWBAR',
  machete = 'WEAPON_MACHETE',
  hammer = 'WEAPON_HAMMER',
  bottle = 'WEAPON_BOTTLE',
  knuckle = 'WEAPON_KNUCKLE',

  grenade = 'WEAPON_GRENADE',
  molotov = 'WEAPON_MOLOTOV',
  stickybomb = 'WEAPON_STICKYBOMB',
  flare = 'WEAPON_FLARE',

  fireextinguisher = 'WEAPON_FIREEXTINGUISHER',
  petrolcan = 'WEAPON_PETROLCAN',
  flashlight = 'WEAPON_FLASHLIGHT',
  stun = 'WEAPON_STUNGUN',
  stungun = 'WEAPON_STUNGUN'
}

local TestWeaponKits = {
  basic = {
    'WEAPON_PISTOL',
    'WEAPON_SMG',
    'WEAPON_CARBINERIFLE',
    'WEAPON_PUMPSHOTGUN',
    'WEAPON_KNIFE'
  },
  police = {
    'WEAPON_COMBATPISTOL',
    'WEAPON_STUNGUN',
    'WEAPON_NIGHTSTICK',
    'WEAPON_FLASHLIGHT',
    'WEAPON_CARBINERIFLE',
    'WEAPON_PUMPSHOTGUN'
  },
  heavy = {
    'WEAPON_PISTOL50',
    'WEAPON_ASSAULTRIFLE',
    'WEAPON_SPECIALCARBINE',
    'WEAPON_ASSAULTSHOTGUN',
    'WEAPON_SNIPERRIFLE'
  }
}

local function normalizeWeaponName(name)
  name = tostring(name or ''):upper():gsub('%s+', '')
  if name == '' then return nil end

  if name:sub(1, 7) ~= 'WEAPON_' then
    local alias = TestWeapons[name:lower()]
    if alias then
      return alias
    end
    name = 'WEAPON_' .. name
  end

  return name
end

local function getWeaponHashFromInput(input)
  local weaponName = normalizeWeaponName(input)
  if not weaponName then
    return nil, nil, 'Arma inválida.'
  end

  return joaat(weaponName), weaponName
end

local function nativeWeaponCommandsEnabled()
  return Config.Debug == true or Config.AllowNativeWeaponCommands == true
end

local function blockNativeWeaponCommand(commandName)
  print(('[mz_admin][weapon_admin_command_blocked] command=%s'):format(tostring(commandName or 'unknown')))
  notify('Comando de arma nativa desativado. Use o inventario do mz_core para testes de arma.', 'error')
end

local function giveTestWeapon(weaponInput, ammo)
  -- Test-only path: bypasses mz_core inventory ownership and may be removed by inventory weapon enforcement.
  local ped = PlayerPedId()
  local weaponHash, weaponName, err = getWeaponHashFromInput(weaponInput)
  if not weaponHash then
    return false, err or 'Arma inválida.'
  end

  ammo = tonumber(ammo) or Config.DefaultWeaponAmmo or 250
  ammo = math.max(0, math.min(9999, math.floor(ammo)))

  GiveWeaponToPed(ped, weaponHash, ammo, false, true)
  SetPedAmmo(ped, weaponHash, ammo)
  SetCurrentPedWeapon(ped, weaponHash, true)

  return true, weaponName, ammo
end

local function weaponListText()
  return 'pistol, combatpistol, smg, combatpdw, carbinerifle, specialcarbine, assaultrifle, shotgun, sniper, knife, bat, stun'
end

local function deleteVehicle(vehicle)
  if vehicle == 0 or not DoesEntityExist(vehicle) then return false end

  NetworkRequestControlOfEntity(vehicle)
  local timeout = GetGameTimer() + 1200
  while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do
    Wait(0)
    NetworkRequestControlOfEntity(vehicle)
  end

  SetEntityAsMissionEntity(vehicle, true, true)
  DeleteVehicle(vehicle)

  if DoesEntityExist(vehicle) then
    DeleteEntity(vehicle)
  end

  return not DoesEntityExist(vehicle)
end

local function getClosestVehicle(radius)
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  return GetClosestVehicle(coords.x, coords.y, coords.z, radius or 6.0, 0, 70)
end


local function requestVehicleControl(vehicle)
  if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
  if NetworkHasControlOfEntity(vehicle) then return true end

  NetworkRequestControlOfEntity(vehicle)
  local timeout = GetGameTimer() + 1500
  while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do
    Wait(0)
    NetworkRequestControlOfEntity(vehicle)
  end

  return NetworkHasControlOfEntity(vehicle)
end

local function randomInt(minValue, maxValue)
  minValue = math.floor(tonumber(minValue) or 0)
  maxValue = math.floor(tonumber(maxValue) or minValue)
  if maxValue < minValue then minValue, maxValue = maxValue, minValue end
  return math.random(minValue, maxValue)
end

local function setMaxVehicleMod(vehicle, modType)
  local count = GetNumVehicleMods(vehicle, modType)
  if count and count > 0 then
    SetVehicleMod(vehicle, modType, count - 1, false)
    return true
  end
  return false
end

local function setRandomVehicleMod(vehicle, modType, customTires)
  local count = GetNumVehicleMods(vehicle, modType)
  if not count or count <= 0 then return false end
  SetVehicleMod(vehicle, modType, randomInt(0, count - 1), customTires == true)
  return true
end

local function applyMaxPerformance(vehicle)
  SetVehicleModKit(vehicle, 0)

  -- Performance: engine, brakes, transmission, suspension and armor.
  for _, modType in ipairs({ 11, 12, 13, 15, 16 }) do
    setMaxVehicleMod(vehicle, modType)
  end

  -- Turbo is a toggle mod.
  ToggleVehicleMod(vehicle, 18, true)

  local tuning = Config.VehicleTuning or {}
  SetVehicleEnginePowerMultiplier(vehicle, tonumber(tuning.EnginePowerMultiplier) or 100.0)
  SetVehicleEngineTorqueMultiplier(vehicle, tonumber(tuning.EngineTorqueMultiplier) or 2.0)
  ModifyVehicleTopSpeed(vehicle, tonumber(tuning.TopSpeedMultiplier) or 2.0)
end

local function applyRandomVisualTuning(vehicle)
  local tuning = Config.VehicleTuning or {}
  SetVehicleModKit(vehicle, 0)

  -- Todos os slots cosmeticos de carroceria/interior conhecidos, excluindo performance.
  local visualMods = {
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37,
    38, 39, 40, 41, 42, 43, 44, 45, 46, 48
  }

  for _, modType in ipairs(visualMods) do
    setRandomVehicleMod(vehicle, modType, false)
  end

  -- Rodas: sorteia familia e modelo, mantendo pneus customizados aleatorios.
  SetVehicleWheelType(vehicle, randomInt(tuning.WheelTypeMin or 0, tuning.WheelTypeMax or 12))
  setRandomVehicleMod(vehicle, 23, randomInt(0, 1) == 1)
  setRandomVehicleMod(vehicle, 24, randomInt(0, 1) == 1)

  -- Pintura e acabamento.
  local paintMin = tuning.PaintColorMin or 0
  local paintMax = tuning.PaintColorMax or 160
  SetVehicleColours(vehicle, randomInt(paintMin, paintMax), randomInt(paintMin, paintMax))
  SetVehicleExtraColours(vehicle, randomInt(paintMin, paintMax), randomInt(paintMin, paintMax))
  SetVehicleInteriorColour(vehicle, randomInt(paintMin, paintMax))
  SetVehicleDashboardColour(vehicle, randomInt(paintMin, paintMax))

  -- Vidros, placa e livery nativa quando existir.
  SetVehicleWindowTint(vehicle, randomInt(tuning.WindowTintMin or 0, tuning.WindowTintMax or 6))
  SetVehicleNumberPlateTextIndex(vehicle, randomInt(tuning.PlateStyleMin or 0, tuning.PlateStyleMax or 5))

  local liveryCount = GetVehicleLiveryCount(vehicle)
  if liveryCount and liveryCount > 0 then
    SetVehicleLivery(vehicle, randomInt(0, liveryCount - 1))
  end

  -- Xenon, neon e tyre smoke.
  ToggleVehicleMod(vehicle, 22, true)
  if SetVehicleXenonLightsColour then
    SetVehicleXenonLightsColour(vehicle, randomInt(0, 12))
  end

  ToggleVehicleMod(vehicle, 20, true)
  SetVehicleTyreSmokeColor(vehicle, randomInt(0, 255), randomInt(0, 255), randomInt(0, 255))

  local neonR, neonG, neonB = randomInt(0, 255), randomInt(0, 255), randomInt(0, 255)
  SetVehicleNeonLightsColour(vehicle, neonR, neonG, neonB)
  local anyNeon = false
  for neonIndex = 0, 3 do
    local enabled = randomInt(0, 1) == 1
    SetVehicleNeonLightEnabled(vehicle, neonIndex, enabled)
    anyNeon = anyNeon or enabled
  end
  if not anyNeon then
    SetVehicleNeonLightEnabled(vehicle, randomInt(0, 3), true)
  end

  -- Extras do modelo (a native usa disable=true para desligar).
  if tuning.RandomizeExtras ~= false then
    for extraId = 0, 20 do
      if DoesExtraExist(vehicle, extraId) then
        local enabled = randomInt(0, 1) == 1
        SetVehicleExtra(vehicle, extraId, not enabled)
      end
    end
  end
end

local function fullRandomTune(vehicle)
  if vehicle == 0 or not DoesEntityExist(vehicle) then
    return false, 'invalid_vehicle'
  end

  if not requestVehicleControl(vehicle) then
    return false, 'no_control'
  end

  -- Comeca de um estado mecanico integro antes de aplicar o tuning.
  SetVehicleFixed(vehicle)
  SetVehicleDeformationFixed(vehicle)
  SetVehicleDirtLevel(vehicle, 0.0)
  SetVehicleEngineHealth(vehicle, 1000.0)
  SetVehicleBodyHealth(vehicle, 1000.0)
  SetVehiclePetrolTankHealth(vehicle, 1000.0)

  applyMaxPerformance(vehicle)
  applyRandomVisualTuning(vehicle)
  SetVehicleEngineOn(vehicle, true, true, false)

  return true
end

RegisterCommand(Config.Commands.loc or 'loc', function()
  if not authorize('loc') then return end
  local ped = PlayerPedId()
  local entityCoords = GetEntityCoords(ped)
  local groundCoords = getGroundCoordsForEntity(ped)
  local heading = GetEntityHeading(ped)

  local markerText = coordsText(groundCoords, heading)
  local entityText = coordsText(entityCoords, heading)

  print(('[mz_admin loc] CHAO/MARKER %s'):format(markerText.vector4))
  print(('[mz_admin loc] ENTIDADE/TP %s'):format(entityText.vector4))

  TriggerEvent('chat:addMessage', {
    color = { 80, 180, 255 },
    multiline = true,
    args = {
      'LOC',
      ('CHÃO / MARKER:\n%s\n%s\n%s\n\nENTIDADE / TP:\n%s\n%s\n%s'):format(
        markerText.vector3,
        markerText.vector4,
        markerText.raw,
        entityText.vector3,
        entityText.vector4,
        entityText.raw
      )
    }
  })
end, false)

RegisterCommand(Config.Commands.tp or 'tp', function(_, args)
  if not authorize('tp') then return end
  local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
  local h = tonumber(args[4])

  if not x or not y or not z then
    notify('Uso: /tp x y z [heading]', 'error')
    return
  end

  local entity = getTeleportEntity()
  if teleportEntity(entity, vector3(x, y, z), h) then
    notify(('Teleportado para %.2f, %.2f, %.2f'):format(x, y, z), 'success')
  end
end, false)

RegisterCommand(Config.Commands.tpm or 'tpm', function()
  if not authorize('tpm') then return end
  local waypoint = GetFirstBlipInfoId(8)
  if not DoesBlipExist(waypoint) then
    notify('Nenhum waypoint marcado no mapa.', 'error')
    return
  end

  local blipCoords = GetBlipInfoIdCoord(waypoint)
  local entity = getTeleportEntity()
  local foundGround, groundZ = false, 0.0
  local testHeights = { 50.0, 100.0, 150.0, 250.0, 500.0, 750.0, 1000.0, 1250.0 }

  DoScreenFadeOut(150)
  Wait(160)

  for _, height in ipairs(testHeights) do
    SetEntityCoordsNoOffset(entity, blipCoords.x, blipCoords.y, height, false, false, false)
    RequestCollisionAtCoord(blipCoords.x, blipCoords.y, height)
    Wait(80)
    foundGround, groundZ = GetGroundZFor_3dCoord(blipCoords.x, blipCoords.y, height, false)
    if foundGround then break end
  end

  local finalZ = foundGround and (groundZ + 1.0) or 100.0
  SetEntityCoordsNoOffset(entity, blipCoords.x, blipCoords.y, finalZ, false, false, false)
  DoScreenFadeIn(150)
  notify('Teleportado para o waypoint.', 'success')
end, false)

RegisterCommand(Config.Commands.gotoPlayer or 'goto', function(_, args)
  local target = tonumber(args[1])
  if not target then
    notify('Uso: /goto id', 'error')
    return
  end
  TriggerServerEvent('mz_admin:server:gotoPlayer', target)
end, false)

RegisterCommand(Config.Commands.bringPlayer or 'bring', function(_, args)
  local target = tonumber(args[1])
  if not target then
    notify('Uso: /bring id', 'error')
    return
  end
  TriggerServerEvent('mz_admin:server:bringPlayer', target)
end, false)

RegisterCommand(Config.Commands.kickPlayer or 'kick', function(_, args)
  local target = tonumber(args[1])
  local reason = table.concat(args, ' ', 2):gsub('^%s+', ''):gsub('%s+$', '')
  if not target or reason == '' then
    notify('Uso: /kick id motivo', 'error')
    return
  end
  if not lib or not lib.callback or type(lib.callback.await) ~= 'function' then
    notify('Nao foi possivel validar a identidade do alvo.', 'error')
    return
  end
  local ok, response = pcall(lib.callback.await, 'mz_admin:server:resolveTargetIdentity', false, target, 'kick')
  if not ok or type(response) ~= 'table' or response.ok ~= true or not response.citizenid then
    notify('Nao foi possivel validar a identidade do alvo.', 'error')
    return
  end
  TriggerServerEvent('mz_admin:server:kickPlayer', target, reason, response.citizenid)
end, false)

RegisterNetEvent('mz_admin:client:teleportToCoords', function(coords, heading)
  if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return end
  local targetCoords = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
  teleportEntity(getTeleportEntity(), targetCoords, tonumber(heading))
end)

RegisterCommand(Config.Commands.deleteVehicle or 'dv', function(_, args)
  if not authorize('deleteVehicle') then return end
  local radius = tonumber(args[1]) or 6.0
  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)

  if vehicle == 0 then
    vehicle = getClosestVehicle(radius)
  end

  if vehicle == 0 or not DoesEntityExist(vehicle) then
    notify('Nenhum veículo encontrado.', 'error')
    return
  end

  if deleteVehicle(vehicle) then
    notify('Veículo deletado.', 'success')
  else
    notify('Não foi possível deletar o veículo.', 'error')
  end
end, false)

RegisterCommand(Config.Commands.spawnVehicle or 'car', function(_, args)
  if not authorize('spawnVehicle') then return end
  local model = args[1]
  if not model or model == '' then
    notify('Uso: /car modelo', 'error')
    return
  end

  local hash, err = loadModel(model)
  if not hash then
    notify(err or 'Modelo inválido.', 'error')
    return
  end

  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)
  local forward = GetEntityForwardVector(ped)
  local spawnCoords = coords + (forward * 3.0)

  local oldVehicle = GetVehiclePedIsIn(ped, false)
  if oldVehicle ~= 0 and GetPedInVehicleSeat(oldVehicle, -1) == ped then
    deleteVehicle(oldVehicle)
  end

  local vehicle = CreateVehicle(hash, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, false)
  if vehicle == 0 then
    notify('Falha ao criar veículo.', 'error')
    SetModelAsNoLongerNeeded(hash)
    return
  end

  SetVehicleOnGroundProperly(vehicle)
  SetPedIntoVehicle(ped, vehicle, -1)
  SetVehicleEngineOn(vehicle, true, true, false)
  SetVehRadioStation(vehicle, 'OFF')
  SetVehicleRadioEnabled(vehicle, false)
  SetModelAsNoLongerNeeded(hash)
  notify(('Veículo %s criado.'):format(model), 'success')
end, false)

RegisterCommand(Config.Commands.fixVehicle or 'fix', function()
  if not authorize('fixVehicle') then return end
  local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
  if vehicle == 0 then
    vehicle = getClosestVehicle(6.0)
  end

  if vehicle == 0 or not DoesEntityExist(vehicle) then
    notify('Nenhum veículo para reparar.', 'error')
    return
  end

  SetVehicleFixed(vehicle)
  SetVehicleDeformationFixed(vehicle)
  SetVehicleDirtLevel(vehicle, 0.0)
  SetVehicleEngineHealth(vehicle, 1000.0)
  SetVehiclePetrolTankHealth(vehicle, 1000.0)
  notify('Veículo reparado.', 'success')
end, false)


RegisterCommand(Config.Commands.tuneVehicle or 'tuning', function()
  if not authorize('tuneVehicle') then return end

  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)
  if vehicle == 0 then
    vehicle = getClosestVehicle(6.0)
  end

  if vehicle == 0 or not DoesEntityExist(vehicle) then
    notify('Nenhum veículo encontrado para tunar.', 'error')
    return
  end

  local ok, reason = fullRandomTune(vehicle)
  if not ok then
    notify(reason == 'no_control'
      and 'Não foi possível obter controle do veículo.'
      or 'Não foi possível aplicar o tuning.', 'error')
    return
  end

  notify('Tuning aplicado: performance máxima + visual aleatório.', 'success')
end, false)

RegisterCommand(Config.Commands.heal or 'heal', function(_, args)
  local target = tonumber(args[1])
  TriggerServerEvent(
    'mz_admin:server:healPlayer',
    target or GetPlayerServerId(PlayerId())
  )
end, false)

RegisterCommand(Config.Commands.armor or 'armor', function(_, args)
  local amount = tonumber(args[1]) or 100
  TriggerServerEvent('mz_admin:server:setArmor', math.max(0, math.min(100, amount)))
end, false)

RegisterCommand(Config.Commands.weapon or 'arma', function(_, args)
  if not authorize('weapon') then return end
  if not nativeWeaponCommandsEnabled() then
    blockNativeWeaponCommand(Config.Commands.weapon or 'arma')
    return
  end

  local weaponInput = args[1]
  local ammo = tonumber(args[2]) or Config.DefaultWeaponAmmo or 250

  if not weaponInput or weaponInput == '' or weaponInput == 'lista' or weaponInput == 'list' then
    notify(('Uso: /%s nome [municao]. Exemplos: pistol, smg, carbinerifle, shotgun. Lista rápida: %s'):format(Config.Commands.weapon or 'arma', weaponListText()), 'inform')
    return
  end

  local ok, weaponName, finalAmmo = giveTestWeapon(weaponInput, ammo)
  if not ok then
    notify(weaponName or 'Arma inválida.', 'error')
    return
  end

  notify(('Arma %s entregue com %s munições.'):format(weaponName, finalAmmo), 'success')
end, false)

RegisterCommand(Config.Commands.weaponAlias or 'weapon', function(_, args)
  if not nativeWeaponCommandsEnabled() then
    blockNativeWeaponCommand(Config.Commands.weaponAlias or 'weapon')
    return
  end

  ExecuteCommand(('%s %s'):format(Config.Commands.weapon or 'arma', table.concat(args, ' ')))
end, false)

RegisterCommand(Config.Commands.weaponKit or 'armas', function(_, args)
  if not authorize('weaponKit') then return end
  if not nativeWeaponCommandsEnabled() then
    blockNativeWeaponCommand(Config.Commands.weaponKit or 'armas')
    return
  end

  local kitName = tostring(args[1] or 'basic'):lower()
  local kit = TestWeaponKits[kitName]

  if not kit then
    notify('Kit inválido. Use: /armas basic, /armas police ou /armas heavy', 'error')
    return
  end

  local ammo = tonumber(args[2]) or Config.DefaultWeaponAmmo or 250
  local given = 0

  for _, weaponName in ipairs(kit) do
    local ok = giveTestWeapon(weaponName, ammo)
    if ok then
      given = given + 1
    end
  end

  notify(('Kit %s entregue com %s armas.'):format(kitName, given), 'success')
end, false)

RegisterCommand(Config.Commands.clearWeapons or 'limpararmas', function()
  if not authorize('clearWeapons') then return end
  if not nativeWeaponCommandsEnabled() then
    blockNativeWeaponCommand(Config.Commands.clearWeapons or 'limpararmas')
    return
  end

  RemoveAllPedWeapons(PlayerPedId(), true)
  notify('Armas removidas.', 'success')
end, false)

RegisterCommand(Config.Commands.revive or 'revive', function(_, args)
  local target = tonumber(args[1])
  TriggerServerEvent(
    'mz_admin:server:revivePlayer',
    target or GetPlayerServerId(PlayerId())
  )
end, false)

RegisterCommand(Config.Commands.medicalRecover or 'medicalrecover', function(_, args)
  TriggerServerEvent('mz_admin:server:recoverMedicalPlayer', tonumber(args[1]) or GetPlayerServerId(PlayerId()))
end, false)

RegisterCommand(Config.Commands.medicalDead or 'medicaldead', function(_, args)
  TriggerServerEvent('mz_admin:server:forcePlayerDead', tonumber(args[1]) or GetPlayerServerId(PlayerId()))
end, false)

RegisterCommand(Config.Commands.medicalCancel or 'medicalcancel', function(_, args)
  TriggerServerEvent('mz_admin:server:cancelMedicalOperation', tonumber(args[1]) or GetPlayerServerId(PlayerId()))
end, false)

RegisterCommand(Config.Commands.godMode or 'godmode', function()
  if not lib or not lib.callback or type(lib.callback.await) ~= 'function' then return end
  local ok, response = pcall(lib.callback.await, 'mz_admin:server:toggleGodMode', false)
  if not ok or type(response) ~= 'table' or response.ok ~= true then
    notify('Nao foi possivel alterar o godmode.', 'error')
    return
  end
  local ped = PlayerPedId()
  local enabled = response.enabled == true
  SetPlayerInvincible(PlayerId(), enabled)
  SetEntityInvincible(ped, enabled)
  notify(enabled and 'Godmode ativado.' or 'Godmode desativado.', enabled and 'success' or 'inform')
end, false)

-- Godmode is server-authorized but applied through client natives. Never leave
-- those natives enabled across a client resource restart, when the server-side
-- authorization table is rebuilt empty.
local function disableGodModeNatives()
  local ped = PlayerPedId()
  SetPlayerInvincible(PlayerId(), false)
  if ped and ped ~= 0 then SetEntityInvincible(ped, false) end
end

AddEventHandler('onClientResourceStart', function(resourceName)
  if resourceName == GetCurrentResourceName() then disableGodModeNatives() end
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  disableGodModeNatives()
end)

RegisterNetEvent('mz_admin:client:stateActionConfirmed', function(action, value)
  if action == 'heal' then
    notify('Vida, fome e sede restauradas.', 'success')
  elseif action == 'revive' then
    notify('Revive canonico concluido.', 'success')
  elseif action == 'armor' then
    notify(('Colete canonico definido para %s.'):format(tonumber(value) or 0), 'success')
  elseif action == 'medical_dead' then
    notify(('Estado dead aplicado ao ID %s.'):format(tonumber(value) or 0), 'success')
  elseif action == 'medical_recovery' then
    notify(('Recovery medico aplicado ao ID %s.'):format(tonumber(value) or 0), 'success')
  elseif action == 'medical_cancel' then
    notify(('Operacao medica cancelada para ID %s.'):format(tonumber(value) or 0), 'success')
  end
end)
