local function expect(condition, message)
  if not condition then error(message, 2) end
end

local function read(path)
  local file, err = io.open(path, 'rb')
  if not file then error(err, 2) end
  local content = file:read('*a')
  file:close()
  return content
end

local wizard = read('mz_admin/client/garage_wizard.lua')

expect(wizard:find('IsControlJustReleased(0, 47)', 1, true) ~= nil, 'atalho G ausente')
expect(wizard:find('FreezeEntityPosition(entity, true)', 1, true) ~= nil, 'travamento de entidade ausente')
expect(
  wizard:find('FreezeEntityPosition(PlacementFrozenEntity, false)', 1, true) ~= nil,
  'destravamento de entidade ausente'
)
expect(wizard:find('GetPedInVehicleSeat(vehicle, -1) ~= ped', 1, true) ~= nil, 'passageiro pode travar veiculo')
expect(wizard:find("type(IsEntityPositionFrozen) == 'function'", 1, true) ~= nil, 'estado anterior nao e preservado')
expect(wizard:find('setPlacementLocked(false, true)', 1, true) ~= nil, 'cleanup automatico ausente')
expect(wizard:find('IsControlJustReleased(0, 38)', 1, true) ~= nil, 'captura E foi removida')
expect(wizard:find('IsControlJustReleased(0, 73)', 1, true) ~= nil, 'cancelamento X foi removido')
expect(wizard:find("AddEventHandler('onResourceStop'", 1, true) ~= nil, 'cleanup de resource ausente')
expect(wizard:find('TriggerServerEvent', 1, true) == nil, 'posicionamento envia entidade/trava ao servidor')

print('mz_admin garage placement contract harness: PASS')
