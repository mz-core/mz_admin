local function callStaffExport(source, exportName, ...)
  local allowed, reason = MZAdminSecurity.Authorize(source, 'staffManage')
  if not allowed then return { ok = false, error = reason } end
  local args = { ... }
  local callOk, resultOk, result = pcall(function()
    if exportName == 'ListStaffManagement' then
      return exports['mz_core']:ListStaffManagement(source)
    elseif exportName == 'CreateStaffRole' then
      return exports['mz_core']:CreateStaffRole(source, args[1])
    elseif exportName == 'UpdateStaffRole' then
      return exports['mz_core']:UpdateStaffRole(source, args[1], args[2])
    elseif exportName == 'SetStaffRolePermissions' then
      return exports['mz_core']:SetStaffRolePermissions(source, args[1], args[2], args[3])
    elseif exportName == 'AssignStaffRole' then
      return exports['mz_core']:AssignStaffRole(source, args[1], args[2], args[3])
    elseif exportName == 'RevokeStaffRole' then
      return exports['mz_core']:RevokeStaffRole(source, args[1], args[2])
    end
    return false, 'unsupported_staff_contract'
  end)
  if not callOk then
    print(('[mz_admin] falha no contrato Staff %s: %s'):format(exportName, tostring(resultOk)))
    return { ok = false, error = 'staff_service_failed' }
  end
  if resultOk ~= true then return { ok = false, error = result or 'staff_operation_failed' } end
  return { ok = true, data = result }
end

lib.callback.register('mz_admin:server:listStaffManagement', function(source)
  return callStaffExport(source, 'ListStaffManagement')
end)

lib.callback.register('mz_admin:server:createStaffRole', function(source, payload)
  return callStaffExport(source, 'CreateStaffRole', payload)
end)

lib.callback.register('mz_admin:server:updateStaffRole', function(source, code, payload)
  return callStaffExport(source, 'UpdateStaffRole', code, payload)
end)

lib.callback.register('mz_admin:server:setStaffRolePermissions', function(source, code, permissions, reason)
  return callStaffExport(source, 'SetStaffRolePermissions', code, permissions, reason)
end)

lib.callback.register('mz_admin:server:assignStaffRole', function(source, accountId, roleCode, reason)
  return callStaffExport(source, 'AssignStaffRole', accountId, roleCode, reason)
end)

lib.callback.register('mz_admin:server:revokeStaffRole', function(source, accountId, reason)
  return callStaffExport(source, 'RevokeStaffRole', accountId, reason)
end)
