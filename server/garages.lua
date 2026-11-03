local function garageResourceReady()
  if GetResourceState('mz_garagem') ~= 'started' then return false end
  local ok, ready = pcall(function()
    return exports['mz_garagem']:IsManagedGarageReady()
  end)
  return ok and ready == true
end

lib.callback.register('mz_admin:server:listGarageOrganizations', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'garageCreate')
  if not allowed then return { ok = false, error = reason } end

  local ok, rows = pcall(function() return exports['mz_org']:ListOrgs() end)
  if not ok or type(rows) ~= 'table' then
    return { ok = false, error = 'organization_repository_unavailable' }
  end

  local organizations = {}
  for _, org in ipairs(rows) do
    if type(org) == 'table'
      and org.active == true
      and type(org.code) == 'string'
      and org.code ~= ''
    then
      organizations[#organizations + 1] = {
        code = org.code,
        name = tostring(org.name or org.code),
        type = tostring(org.type or org.typeCode or '')
      }
    end
  end

  table.sort(organizations, function(left, right)
    if left.type == right.type then return left.name < right.name end
    return left.type < right.type
  end)

  return { ok = true, data = { organizations = organizations } }
end)

lib.callback.register('mz_admin:server:createManagedGarage', function(source, payload)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'garageCreate')
  if not allowed then return { ok = false, error = reason } end
  if not garageResourceReady() then
    return { ok = false, error = 'managed_repository_unavailable' }
  end

  local callOk, created, result = pcall(function()
    return exports['mz_garagem']:CreateManagedGarage(source, payload)
  end)
  if not callOk then
    print(('[mz_admin] falha ao solicitar criacao de garagem: %s'):format(tostring(created)))
    return { ok = false, error = 'garage_service_failed' }
  end
  if created ~= true then return { ok = false, error = result or 'garage_create_failed' } end
  return { ok = true, data = { garage = result } }
end)

lib.callback.register('mz_admin:server:listManagedGarages', function(source)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'garageView')
  if not allowed then return { ok = false, error = reason } end
  if not garageResourceReady() then
    return { ok = false, error = 'managed_repository_unavailable' }
  end

  local callOk, listed, result = pcall(function()
    return exports['mz_garagem']:ListManagedGaragesForAdmin(source)
  end)
  if not callOk then return { ok = false, error = 'garage_service_failed' } end
  if listed ~= true then return { ok = false, error = result or 'garage_list_failed' } end
  return { ok = true, data = { garages = result } }
end)

lib.callback.register('mz_admin:server:updateManagedGarage', function(source, garageCode, payload)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'garageManage')
  if not allowed then return { ok = false, error = reason } end
  if not garageResourceReady() then
    return { ok = false, error = 'managed_repository_unavailable' }
  end

  local callOk, updated, result = pcall(function()
    return exports['mz_garagem']:UpdateManagedGarage(source, garageCode, payload)
  end)
  if not callOk then return { ok = false, error = 'garage_service_failed' } end
  if updated ~= true then return { ok = false, error = result or 'garage_update_failed' } end
  return { ok = true, data = { garage = result } }
end)

lib.callback.register('mz_admin:server:setManagedGarageActive', function(source, garageCode, active)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'garageManage')
  if not allowed then return { ok = false, error = reason } end
  if not garageResourceReady() then
    return { ok = false, error = 'managed_repository_unavailable' }
  end

  local callOk, changed, result = pcall(function()
    return exports['mz_garagem']:SetManagedGarageActive(source, garageCode, active)
  end)
  if not callOk then return { ok = false, error = 'garage_service_failed' } end
  if changed ~= true then return { ok = false, error = result or 'garage_state_failed' } end
  return { ok = true, data = { garage = result } }
end)
