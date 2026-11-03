MZAdminWallClient = MZAdminWallClient or {
  active = false,
  snapshot = {},
  bucket = 0,
  smooth = {}
}

local function setting(name, fallback)
  local value = Config.Wall and Config.Wall[name]
  if value == nil then return fallback end
  return value
end

local function clamp(value, minimum, maximum)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function cleanText(value, maximum)
  value = tostring(value or ''):gsub('[%c~]', '')
  maximum = tonumber(maximum) or 64
  if #value > maximum then value = value:sub(1, math.max(1, maximum - 3)) .. '...' end
  return value
end

local function color(name, fallback)
  local colors = Config.Wall and Config.Wall.colors
  local value = type(colors) == 'table' and colors[name] or nil
  return type(value) == 'table' and value or fallback
end

local function vehicleLabel(vehicle)
  if not vehicle or vehicle == 0 then return nil end
  local model = GetEntityModel(vehicle)
  if not model or model == 0 then return nil end
  local display = GetDisplayNameFromVehicleModel(model)
  if not display or display == '' then return nil end
  local label = GetLabelText(display)
  if not label or label == '' or label == 'NULL' then label = display end
  return cleanText(label, setting('vehicleNameMaxLength', 18))
end

local function drawText(x, y, text, scale, rgba)
  SetTextFont(4)
  SetTextScale(scale, scale)
  SetTextProportional(1)
  SetTextOutline()
  SetTextCentre(true)
  SetTextColour(rgba[1] or 255, rgba[2] or 255, rgba[3] or 255, rgba[4] or 255)
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(text)
  EndTextCommandDisplayText(x, y)
end

local function notify(enabled)
  local message = enabled and 'Wall ativado.' or 'Wall desativado.'
  if type(MZAdminUI) == 'table' then
    MZAdminUI.Notify(message, enabled and 'success' or 'info')
  elseif lib and lib.notify then
    lib.notify({
      type = enabled and 'success' or 'info',
      title = Config.NotifyTitle or 'Admin',
      description = message
    })
  end
end

function MZAdminWallClient.SetState(enabled, silent)
  enabled = enabled == true
  MZAdminWallClient.active = enabled
  if not enabled then
    MZAdminWallClient.snapshot = {}
    MZAdminWallClient.smooth = {}
  end
  if silent ~= true then notify(enabled) end
end

RegisterNetEvent('mz_admin:client:setWallState', function(enabled)
  MZAdminWallClient.SetState(enabled)
end)

RegisterNetEvent('mz_admin:client:updateWall', function(snapshot, bucket)
  if MZAdminWallClient.active ~= true then return end
  MZAdminWallClient.snapshot = type(snapshot) == 'table' and snapshot or {}
  MZAdminWallClient.bucket = tonumber(bucket) or 0

  if setting('smooth', true) ~= true then return end
  local now = GetGameTimer()
  for _, row in ipairs(MZAdminWallClient.snapshot) do
    local id = tonumber(row.id)
    local x, y, z = tonumber(row.x), tonumber(row.y), tonumber(row.z)
    if id and x and y and z then
      local current = MZAdminWallClient.smooth[id]
      if not current then
        MZAdminWallClient.smooth[id] = {
          x = x, y = y, z = z,
          targetX = x, targetY = y, targetZ = z,
          updatedAt = now
        }
      else
        current.targetX, current.targetY, current.targetZ = x, y, z
        current.updatedAt = now
      end
    end
  end
end)

local function toggleWall()
  if not lib or not lib.callback or type(lib.callback.await) ~= 'function' then
    MZAdminClient.NotifyDenied('callback_unavailable')
    return
  end

  local ok, response = pcall(lib.callback.await, 'mz_admin:server:toggleWall', false)
  if not ok or type(response) ~= 'table' or response.ok ~= true then
    MZAdminClient.NotifyDenied(type(response) == 'table' and response.error or 'callback_failed')
    return
  end
  MZAdminWallClient.SetState(response.enabled == true)
end

RegisterCommand(Config.WallCommand or 'wall', toggleWall, false)
RegisterKeyMapping(Config.WallCommand or 'wall', 'Ativar/desativar wall administrativo', 'keyboard', '')

local function cleanupWall()
  if MZAdminWallClient.active ~= true then return end
  MZAdminWallClient.SetState(false, true)
  TriggerServerEvent('mz_admin:server:disableWall')
end

RegisterNetEvent('mz_core:client:characterChanged', cleanupWall)
RegisterNetEvent('mz_core:client:playerDeath', cleanupWall)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  cleanupWall()
end)

CreateThread(function()
  while true do
    Wait(1000)
    if setting('smooth', true) ~= true then
      MZAdminWallClient.smooth = {}
    else
      local now = GetGameTimer()
      local maximumAge = tonumber(setting('smoothDropAfterMs', 3000)) or 3000
      for id, state in pairs(MZAdminWallClient.smooth) do
        if not state.updatedAt or now - state.updatedAt > maximumAge then
          MZAdminWallClient.smooth[id] = nil
        end
      end
    end
  end
end)

CreateThread(function()
  while true do
    if MZAdminWallClient.active ~= true then
      Wait(250)
    else
      Wait(0)
      local ownPed = PlayerPedId()
      local ownCoords = GetEntityCoords(ownPed)
      local ownServerId = GetPlayerServerId(PlayerId())

      for _, row in ipairs(MZAdminWallClient.snapshot) do
        local id = tonumber(row.id)
        local x, y, z = tonumber(row.x), tonumber(row.y), tonumber(row.z)
        if id and x and y and z and (setting('showSelf', false) == true or id ~= ownServerId) then
          if setting('smooth', true) == true then
            local state = MZAdminWallClient.smooth[id]
            if state and state.targetX then
              local factor = tonumber(setting('smoothFactor', 0.28)) or 0.28
              factor = clamp(factor, 0.05, 1.0)
              state.x = state.x + (state.targetX - state.x) * factor
              state.y = state.y + (state.targetY - state.y) * factor
              state.z = state.z + (state.targetZ - state.z) * factor
              x, y, z = state.x, state.y, state.z
            end
          end

          local otherBucket = tonumber(row.bucket) ~= MZAdminWallClient.bucket
          if not otherBucket or setting('showOtherBuckets', true) == true then
            local playerIndex = GetPlayerFromServerId(id)
            local ped = playerIndex ~= -1 and GetPlayerPed(playerIndex) or 0
            if ped ~= 0 and setting('preferStreamedCoords', true) == true then
              local streamedCoords = GetEntityCoords(ped)
              x, y, z = streamedCoords.x, streamedCoords.y, streamedCoords.z
            end

            local dx, dy, dz = ownCoords.x - x, ownCoords.y - y, ownCoords.z - z
            local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
            if distance <= (tonumber(setting('drawDistance', 800.0)) or 800.0) then
              local healthText, armorText, movementText, weaponText = '??', '??', 'FORA STREAM', 'SEM INFO'
              local isDead = false

              if ped ~= 0 then
                local health = tonumber(GetEntityHealth(ped)) or 0
                local maximumHealth = math.max(101, tonumber(GetEntityMaxHealth(ped)) or 200)
                healthText = tostring(clamp(math.floor(((health - 100) / (maximumHealth - 100)) * 100), 0, 100))
                armorText = tostring(clamp(math.floor(tonumber(GetPedArmour(ped)) or 0), 0, 100))
                isDead = IsEntityDead(ped)

                if IsPedInAnyVehicle(ped, false) then
                  movementText = 'VEICULO'
                  if setting('showVehicleName', true) == true then
                    local label = vehicleLabel(GetVehiclePedIsIn(ped, false))
                    if label then movementText = 'VEI:' .. label end
                  end
                else
                  movementText = 'A PE'
                end

                if setting('showWeaponState', true) == true then
                  weaponText = IsPedArmed(ped, 7) and 'ARMADO' or 'DESARMADO'
                end
              end

              local rgba = color('default', { 255, 255, 255, 255 })
              if row.staffTag then rgba = color('staff', { 255, 220, 0, 255 }) end
              if isDead then rgba = color('dead', { 255, 70, 70, 255 }) end

              local staffText = row.staffTag and (' [%s]'):format(cleanText(row.staffTag, 12)) or ''
              local bucketText = otherBucket and ('DIM:%s*'):format(row.bucket) or ('DIM:%s'):format(row.bucket)
              local citizenText = cleanText(
                row.citizenid or 'indisponivel',
                setting('citizenIdMaxLength', 24)
              )
              local line1 = ('[%d] %s%s | CID:%s'):format(
                id,
                cleanText(row.name, 32),
                staffText,
                citizenText
              )
              local line2 = ('HP:%s  AR:%s  |  %s'):format(healthText, armorText, movementText)
              local line3 = ('%s  |  %s  |  %.0fm'):format(bucketText, weaponText, distance)

              if setting('drawLines', true) == true
                and distance <= (tonumber(setting('lineDistance', 200.0)) or 200.0) then
                DrawLine(
                  ownCoords.x, ownCoords.y, ownCoords.z + 0.8,
                  x, y, z + 0.8,
                  rgba[1] or 255, rgba[2] or 255, rgba[3] or 255,
                  tonumber(setting('lineAlpha', 160)) or 160
                )
              end

              local visible, screenX, screenY =
                World3dToScreen2d(x, y, z + (tonumber(setting('textZOffset', 1.15)) or 1.15))
              if visible then
                local scale = tonumber(setting('textScale', 0.30)) or 0.30
                local spacing = tonumber(setting('screenLineSpacing', 0.024)) or 0.024
                drawText(screenX, screenY, line1, scale, rgba)
                drawText(screenX, screenY + spacing, line2, scale, { 255, 255, 255, 255 })
                drawText(screenX, screenY + spacing * 2, line3, scale, { 255, 255, 255, 255 })
              end
            end
          end
        end
      end
    end
  end
end)
