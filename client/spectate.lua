MZAdminSpectateClient = MZAdminSpectateClient or {
  active = false,
  target = nil,
  lastSync = nil,
  saved = nil
}

local function notify(message, kind)
  if type(MZAdminUI) == 'table' then
    MZAdminUI.Notify(message, kind or 'inform')
  elseif lib and lib.notify then
    lib.notify({
      type = kind or 'inform',
      title = Config.NotifyTitle or 'Admin',
      description = message
    })
  end
end

local function validCoords(coords)
  return type(coords) == 'table'
    and tonumber(coords.x) ~= nil
    and tonumber(coords.y) ~= nil
    and tonumber(coords.z) ~= nil
end

local function applyHiddenState()
  local ped = PlayerPedId()
  SetEntityVisible(ped, false, false)
  SetEntityInvincible(ped, true)
  FreezeEntityPosition(ped, true)
  SetEntityCollision(ped, false, false)
  NetworkSetEntityInvisibleToNetwork(ped, true)
end

local function restorePedState(ped, saved)
  if not ped or ped == 0 then return end
  NetworkSetInSpectatorMode(false, ped)
  NetworkSetEntityInvisibleToNetwork(ped, false)
  ResetEntityAlpha(ped)
  SetEntityVisible(ped, saved.visible ~= false, false)
  SetEntityInvincible(ped, saved.invincible == true)
  FreezeEntityPosition(ped, false)
  SetEntityCollision(ped, true, true)
end

local function stopLocal(payload, forceSilent)
  payload = type(payload) == 'table' and payload or {}
  if MZAdminSpectateClient.active ~= true and not MZAdminSpectateClient.saved then return end
  local wasActive = MZAdminSpectateClient.active == true
  local saved = MZAdminSpectateClient.saved or {}
  local ped = PlayerPedId()

  MZAdminSpectateClient.active = false
  MZAdminSpectateClient.target = nil
  MZAdminSpectateClient.lastSync = nil

  restorePedState(ped, saved)

  local coords = validCoords(payload.coords) and payload.coords or saved.coords
  if validCoords(coords) then
    SetEntityCoordsNoOffset(
      ped,
      tonumber(coords.x) + 0.0,
      tonumber(coords.y) + 0.0,
      tonumber(coords.z) + 0.0,
      false, false, false
    )
    SetEntityHeading(ped, tonumber(payload.heading) or tonumber(saved.heading) or 0.0)
  end

  MZAdminSpectateClient.saved = nil

  -- O native de spectator e o loop de render podem concluir no mesmo frame do
  -- stop. Reaplicar por poucos frames evita deixar o ped invisivel localmente.
  CreateThread(function()
    for _ = 1, 5 do
      Wait(0)
      if MZAdminSpectateClient.active == true then return end
      restorePedState(PlayerPedId(), saved)
    end
  end)

  if wasActive and forceSilent ~= true and payload.silent ~= true then
    notify('Spectate encerrado.', 'inform')
  end
end

local function updateTarget(payload)
  if not MZAdminSpectateClient.active or type(payload) ~= 'table' then return end
  local target = tonumber(payload.target)
  if not target or target ~= MZAdminSpectateClient.target or not validCoords(payload.coords) then return end

  MZAdminSpectateClient.lastSync = payload
  local ped = PlayerPedId()
  local offset = tonumber(Config.Spectate and Config.Spectate.targetOffset) or 6.0
  SetEntityCoordsNoOffset(
    ped,
    tonumber(payload.coords.x) + 0.0,
    tonumber(payload.coords.y) - offset,
    tonumber(payload.coords.z) + 1.0,
    false, false, false
  )
  SetEntityHeading(ped, tonumber(payload.heading) or 0.0)
  applyHiddenState()

  local playerIndex = GetPlayerFromServerId(target)
  if playerIndex ~= -1 then
    local targetPed = GetPlayerPed(playerIndex)
    if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
      NetworkSetInSpectatorMode(true, targetPed)
    end
  end
end

RegisterNetEvent('mz_admin:client:startSpectate', function(payload, switched)
  if type(payload) ~= 'table' or not tonumber(payload.target) then return end

  if MZAdminSpectateClient.active ~= true then
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    MZAdminSpectateClient.saved = {
      visible = IsEntityVisible(ped),
      invincible = GetPlayerInvincible(PlayerId()),
      coords = { x = coords.x, y = coords.y, z = coords.z },
      heading = GetEntityHeading(ped)
    }
    if IsPedInAnyVehicle(ped, false) then
      TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
    end
  else
    NetworkSetInSpectatorMode(false, PlayerPedId())
  end

  MZAdminSpectateClient.active = true
  MZAdminSpectateClient.target = tonumber(payload.target)
  MZAdminSpectateClient.lastSync = nil
  applyHiddenState()
  updateTarget(payload)
  notify(
    switched == true and ('Alvo do spectate alterado para ID %d.'):format(payload.target)
      or ('Espectando ID %d. Use /%s para sair.'):format(
        payload.target,
        Config.SpectateStopCommand or 'specoff'
      ),
    'inform'
  )
end)

RegisterNetEvent('mz_admin:client:syncSpectateTarget', updateTarget)

RegisterNetEvent('mz_admin:client:stopSpectate', function(payload)
  stopLocal(payload, false)
end)

RegisterCommand(Config.SpectateCommand or 'spectate', function(_, args)
  local targetId = tonumber(args[1])
  if not targetId or targetId <= 0 then
    notify(('Uso: /%s id'):format(Config.SpectateCommand or 'spectate'), 'error')
    return
  end
  if MZNoClip and MZNoClip.active == true and MZAdminSpectateClient.active ~= true then
    notify('Desative o noclip antes de usar spectate.', 'error')
    return
  end
  TriggerServerEvent('mz_admin:server:startSpectate', math.floor(targetId))
end, false)

RegisterCommand(Config.SpectateStopCommand or 'specoff', function()
  TriggerServerEvent('mz_admin:server:stopSpectate', 'requested')
end, false)

local function requestCleanup(reason)
  if MZAdminSpectateClient.active ~= true then return end
  TriggerServerEvent('mz_admin:server:stopSpectate', reason)
end

RegisterNetEvent('mz_core:client:characterChanged', function()
  requestCleanup('character_changed')
end)

RegisterNetEvent('mz_core:client:playerDeath', function()
  requestCleanup('actor_died')
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  stopLocal({}, true)
end)

CreateThread(function()
  while true do
    if MZAdminSpectateClient.active ~= true then
      Wait(250)
    else
      Wait(0)
      DisableControlAction(0, 23, true)
      DisableControlAction(0, 24, true)
      DisableControlAction(0, 25, true)
      DisableControlAction(0, 75, true)
      DisableControlAction(0, 200, true)
      applyHiddenState()
    end
  end
end)
