MZAdminClient = MZAdminClient or {}

local function notifyDenied(reason)
  local message = reason == 'rate_limited'
    and (type(locale) == 'function' and locale('errors.rate_limited') or 'Aguarde um instante antes de repetir esta acao.')
    or (type(locale) == 'function' and locale('auth.s_1bf4aa7d83c0') or 'Voce nao possui permissao para esta acao.')

  if type(MZAdminUI) == 'table' then
    MZAdminUI.Notify(message, 'error')
    return
  end

  if lib and lib.notify then
    lib.notify({ type = 'error', title = Config.NotifyTitle or 'Admin', description = message })
  end
end

local function awaitCallback(name, ...)
  if not lib or not lib.callback or type(lib.callback.await) ~= 'function' then
    return nil, 'callback_unavailable'
  end

  local ok, response = pcall(lib.callback.await, name, false, ...)
  if not ok or type(response) ~= 'table' then
    return nil, 'callback_failed'
  end
  return response
end

function MZAdminClient.Authorize(action, silent)
  local response, err = awaitCallback('mz_admin:server:authorizeAction', action)
  if not response or response.ok ~= true then
    if silent ~= true then notifyDenied(response and response.error or err) end
    return false
  end
  return true
end

function MZAdminClient.GetMenuContext(silent)
  local response, err = awaitCallback('mz_admin:server:getMenuContext')
  if not response or response.ok ~= true or type(response.data) ~= 'table' then
    if silent ~= true then notifyDenied(response and response.error or err) end
    return nil
  end
  return response.data
end

function MZAdminClient.ListOnlinePlayers()
  local response, err = awaitCallback('mz_admin:server:listOnlinePlayers')
  if not response or response.ok ~= true or type(response.data) ~= 'table' then
    notifyDenied(response and response.error or err)
    return nil
  end
  return type(response.data.players) == 'table' and response.data.players or {}
end

function MZAdminClient.SearchPlayers(query, filter, page, pageSize)
  local response, err = awaitCallback('mz_admin:server:searchPlayers', {
    query = query,
    filter = filter,
    page = page,
    pageSize = pageSize
  })
  if not response or response.ok ~= true or type(response.data) ~= 'table' then
    notifyDenied(response and response.error or err)
    return {
      items = {},
      total = 0,
      page = page or 1,
      pageSize = pageSize or 25,
      hasMore = false,
      hint = (type(locale) == 'function' and locale('auth.s_b94f4048014c') or 'Nao foi possivel buscar jogadores agora.')
    }
  end
  return response.data
end

function MZAdminClient.ListGarageOrganizations()
  local response, err = awaitCallback('mz_admin:server:listGarageOrganizations')
  if not response or response.ok ~= true or type(response.data) ~= 'table' then
    notifyDenied(response and response.error or err)
    return nil
  end
  return type(response.data.organizations) == 'table' and response.data.organizations or {}
end

function MZAdminClient.CreateManagedGarage(payload)
  local response, err = awaitCallback('mz_admin:server:createManagedGarage', payload)
  if not response or response.ok ~= true then
    return nil, response and response.error or err
  end
  return response.data and response.data.garage or nil
end

function MZAdminClient.ListManagedGarages()
  local response, err = awaitCallback('mz_admin:server:listManagedGarages')
  if not response or response.ok ~= true or type(response.data) ~= 'table' then
    notifyDenied(response and response.error or err)
    return nil
  end
  return type(response.data.garages) == 'table' and response.data.garages or {}
end

function MZAdminClient.UpdateManagedGarage(code, payload)
  local response, err = awaitCallback('mz_admin:server:updateManagedGarage', code, payload)
  if not response or response.ok ~= true then return nil, response and response.error or err end
  return response.data and response.data.garage or nil
end

function MZAdminClient.SetManagedGarageActive(code, active)
  local response, err = awaitCallback('mz_admin:server:setManagedGarageActive', code, active)
  if not response or response.ok ~= true then return nil, response and response.error or err end
  return response.data and response.data.garage or nil
end

function MZAdminClient.StaffRequest(callbackName, ...)
  local response, err = awaitCallback('mz_admin:server:' .. tostring(callbackName), ...)
  if not response or response.ok ~= true then return nil, response and response.error or err end
  return response.data
end

function MZAdminClient.ListAdminLogs(filters)
  local response, err = awaitCallback('mz_admin:server:listAdminLogs', filters)
  if not response or response.ok ~= true or type(response.data) ~= 'table' then
    notifyDenied(response and response.error or err)
    return nil
  end
  return response.data
end

function MZAdminClient.NotifyDenied(reason)
  notifyDenied(reason)
end
