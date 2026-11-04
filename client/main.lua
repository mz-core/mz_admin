local function applyNoClipState(enabled)
  if not MZNoClip then return end

  if enabled == true then
    if MZNoClip.active ~= true and MZNoClip.toggle then MZNoClip.toggle() end
  elseif MZNoClip.stop then
    MZNoClip.stop()
  end
end

local function toggleNoClipAuthorized()
  if not lib or not lib.callback or type(lib.callback.await) ~= 'function' then
    MZAdminClient.NotifyDenied('callback_unavailable')
    return
  end

  local ok, response = pcall(lib.callback.await, 'mz_admin:server:toggleNoClip', false)
  if not ok or type(response) ~= 'table' or response.ok ~= true then
    MZAdminClient.NotifyDenied(type(response) == 'table' and response.error or 'callback_failed')
    return
  end

  applyNoClipState(response.enabled == true)
end

RegisterCommand(Config.NoClipCommand or 'noclip', toggleNoClipAuthorized, false)
RegisterKeyMapping(Config.NoClipCommand or 'noclip', (type(locale) == 'function' and locale('noclip.s_170910a2b36b') or 'Ativar/desativar noclip administrativo'), 'keyboard', '')

RegisterNetEvent('mz_admin:client:authorizeNoClip', function(allowed, enabled)
  if allowed ~= true then
    MZAdminClient.NotifyDenied('permission_denied')
    return
  end
  applyNoClipState(enabled == true)
end)

local function stopNoClip()
  if MZNoClip and MZNoClip.stop then MZNoClip.stop() end
  TriggerServerEvent('mz_admin:server:stopNoClip')
end

RegisterNetEvent('mz_core:client:playerDeath', stopNoClip)
RegisterNetEvent('mz_core:client:characterChanged', stopNoClip)
RegisterNetEvent('mz_core:client:playerSpawned', stopNoClip)
