MZNoClip = {
  active = false,
  entity = 0,
  speedIndex = 2,
  speeds = { 0.35, 0.75, 1.5, 3.0, 6.0 },
  wasVisible = true,
  wasInvincible = false,
  wasCollisionEnabled = true
}

local function notify(message, notifyType)
  local payload = {
    type = notifyType or 'inform',
    title = Config.NotifyTitle or 'Admin',
    message = message,
    description = message,
    duration = 3500,
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

local function rotationToDirection(rotation)
  local z = math.rad(rotation.z)
  local x = math.rad(rotation.x)
  local cosX = math.abs(math.cos(x))

  return vector3(
    -math.sin(z) * cosX,
    math.cos(z) * cosX,
    math.sin(x)
  )
end

local function getRightVector(forward)
  return vector3(forward.y, -forward.x, 0.0)
end

local function getNoClipEntity()
  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)

  if vehicle ~= 0 then
    return vehicle
  end

  return ped
end

local function setEntityNoClipState(entity, enabled)
  if entity == 0 or not DoesEntityExist(entity) then return end

  SetEntityInvincible(entity, enabled)
  SetEntityCollision(entity, not enabled, not enabled)
  FreezeEntityPosition(entity, enabled)

  if IsEntityAPed(entity) then
    SetPedCanRagdoll(entity, not enabled)
    SetEntityVisible(entity, not enabled, false)
  else
    SetEntityVisible(entity, not enabled, false)
  end
end

local function restoreEntity(entity)
  if entity == 0 or not DoesEntityExist(entity) then return end

  FreezeEntityPosition(entity, false)
  SetEntityCollision(entity, true, true)
  SetEntityInvincible(entity, false)
  SetEntityVisible(entity, true, false)

  if IsEntityAPed(entity) then
    SetPedCanRagdoll(entity, true)
  end
end

local function disableNoClipControls()
  DisableControlAction(0, 30, true) -- move left/right
  DisableControlAction(0, 31, true) -- move forward/back
  DisableControlAction(0, 32, true) -- W
  DisableControlAction(0, 33, true) -- S
  DisableControlAction(0, 34, true) -- A
  DisableControlAction(0, 35, true) -- D
  DisableControlAction(0, 21, true) -- SHIFT
  DisableControlAction(0, 22, true) -- SPACE
  DisableControlAction(0, 36, true) -- CTRL
  DisableControlAction(0, 44, true) -- Q
  DisableControlAction(0, 38, true) -- E
  DisableControlAction(0, 24, true) -- Attack
  DisableControlAction(0, 25, true) -- Aim
  DisableControlAction(0, 140, true)
  DisableControlAction(0, 141, true)
  DisableControlAction(0, 142, true)
end

local function drawHelpText(text)
  BeginTextCommandDisplayHelp('STRING')
  AddTextComponentSubstringPlayerName(text)
  EndTextCommandDisplayHelp(0, false, true, -1)
end

function MZNoClip.toggle()
  if MZNoClip.active then
    MZNoClip.stop()
    return
  end

  local entity = getNoClipEntity()
  if entity == 0 or not DoesEntityExist(entity) then
    notify('Entidade inválida para noclip.', 'error')
    return
  end

  MZNoClip.entity = entity
  MZNoClip.active = true
  setEntityNoClipState(entity, true)
  notify('Noclip administrativo ativado.', 'success')
end

function MZNoClip.stop()
  if not MZNoClip.active then return end

  local entity = MZNoClip.entity
  MZNoClip.active = false
  MZNoClip.entity = 0

  restoreEntity(entity)
  restoreEntity(PlayerPedId())
  notify('Noclip administrativo desativado.', 'inform')
end

CreateThread(function()
  while true do
    if not MZNoClip.active then
      Wait(250)
    else
      Wait(0)

      local entity = MZNoClip.entity
      if entity == 0 or not DoesEntityExist(entity) then
        MZNoClip.stop()
      else
        disableNoClipControls()

        if IsDisabledControlJustPressed(0, 14) then -- scroll down
          MZNoClip.speedIndex = math.max(1, MZNoClip.speedIndex - 1)
        elseif IsDisabledControlJustPressed(0, 15) then -- scroll up
          MZNoClip.speedIndex = math.min(#MZNoClip.speeds, MZNoClip.speedIndex + 1)
        end

        local speed = MZNoClip.speeds[MZNoClip.speedIndex] or 1.0
        if IsDisabledControlPressed(0, 21) then -- SHIFT
          speed = speed * 2.0
        end

        local camRot = GetGameplayCamRot(2)
        local forward = rotationToDirection(camRot)
        local right = getRightVector(forward)
        local pos = GetEntityCoords(entity)
        local move = vector3(0.0, 0.0, 0.0)

        if IsDisabledControlPressed(0, 32) then -- W
          move = move + forward
        end
        if IsDisabledControlPressed(0, 33) then -- S
          move = move - forward
        end
        if IsDisabledControlPressed(0, 35) then -- D
          move = move + right
        end
        if IsDisabledControlPressed(0, 34) then -- A
          move = move - right
        end
        if IsDisabledControlPressed(0, 22) then -- SPACE
          move = move + vector3(0.0, 0.0, 1.0)
        end
        if IsDisabledControlPressed(0, 36) or IsDisabledControlPressed(0, 44) then -- CTRL/Q
          move = move - vector3(0.0, 0.0, 1.0)
        end

        if #(move) > 0.0 then
          local newPos = pos + (move * speed)
          SetEntityCoordsNoOffset(entity, newPos.x, newPos.y, newPos.z, true, true, true)
        end

        SetEntityVelocity(entity, 0.0, 0.0, 0.0)
        SetEntityHeading(entity, camRot.z)

        drawHelpText(('~g~NOCLIP TESTE~s~\nWASD mover | SPACE subir | CTRL/Q descer\nSHIFT rápido | Scroll velocidade: ~b~%sx~s~\n/%s desativa'):format(MZNoClip.speedIndex, Config.NoClipCommand or 'noclip'))
      end
    end
  end
end)

AddEventHandler('onResourceStop', function(resource)
  if resource == GetCurrentResourceName() then
    MZNoClip.stop()
  end
end)

local function toggleAuthorizedNoClip()
  if not lib or not lib.callback or type(lib.callback.await) ~= 'function' then return end
  local ok, response = pcall(lib.callback.await, 'mz_admin:server:toggleNoClip', false)
  if not ok or type(response) ~= 'table' or response.ok ~= true then
    notify('Noclip negado pelo servidor.', 'error')
    return
  end
  if response.enabled == true then MZNoClip.toggle() else MZNoClip.stop() end
end

RegisterCommand(Config.NoClipCommand or 'noclip', toggleAuthorizedNoClip, false)
RegisterKeyMapping(Config.NoClipCommand or 'noclip', 'Ativar/desativar noclip administrativo', 'keyboard', '')

local function stopAuthorizedNoClip()
  if MZNoClip.active then MZNoClip.stop() end
  TriggerServerEvent('mz_admin:server:stopNoClip')
end

RegisterNetEvent('mz_core:client:playerDeath', stopAuthorizedNoClip)
RegisterNetEvent('mz_core:client:characterChanged', stopAuthorizedNoClip)
