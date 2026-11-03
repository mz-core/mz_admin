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

local client = read('mz_admin/client/ui.lua')
local config = client
local app = read('mz_admin/web/app.js')
local html = read('mz_admin/web/index.html')
local panel = read('mz_admin/frontend/src/components/ContextPanel.tsx')
local stateSource = read('mz_admin/frontend/src/lib/state.ts')

for _, exportName in ipairs({
  'Notify', 'OpenContext', 'OpenMenu', 'RegisterContext', 'RegisterSimpleMenu',
  'ShowContext', 'CloseContext', 'CloseMenu', 'HideContext', 'InputDialog',
  'AlertDialog', 'Confirm', 'IsReady', 'GetBackend'
}) do
  expect(
    client:find(("exports('%s'"):format(exportName), 1, true) ~= nil,
    'export legado ausente: ' .. exportName
  )
end

for _, exportName in ipairs({
  'SetContextFocus', 'ToggleContextFocus', 'IsContextFocused',
  'SetMovementEnabled', 'ToggleMovement', 'IsMovementEnabled'
}) do
  expect(
    client:find(("exports('%s'"):format(exportName), 1, true) ~= nil,
    'export de interacao ausente: ' .. exportName
  )
end

expect(
  config:find('EnableMovementWhileOpen = true', 1, true) ~= nil,
  'movimento global nao inicia habilitado'
)
expect(
  config:find("MovementToggleKey = 'F6'", 1, true) ~= nil,
  'tecla padrao de movimento nao e F6'
)
expect(
  config:find('MovementEnabledByDefault = false', 1, true) ~= nil,
  'nova sessao de menu nao inicia com movimento travado'
)
expect(
  config:find('EnableFocusToggle = true', 1, true) ~= nil
    and config:find("FocusToggleKey = 'F6'", 1, true) ~= nil,
  'aliases legados de foco foram removidos'
)

expect(client:find('function MZAdminUI.SetMovementEnabled', 1, true) ~= nil, 'setter de movimento ausente')
expect(client:find('function MZAdminUI.ToggleMovement', 1, true) ~= nil, 'toggle de movimento ausente')
expect(client:find('function MZAdminUI.IsMovementEnabled', 1, true) ~= nil, 'consulta de movimento ausente')
expect(
  client:find("RegisterNUICallback('toggleMovement'", 1, true) ~= nil,
  'callback NUI de movimento ausente'
)
expect(
  client:find("'mz_admin_ui_movement_toggle'", 1, true) ~= nil
    and client:find('RegisterKeyMapping(', 1, true) ~= nil,
  'key mapping de movimento ausente'
)
expect(
  client:find('SetNuiFocusKeepInput(enabled and not TextInputFocused)', 1, true) ~= nil,
  'keep input nao acompanha movimento e foco de texto'
)
expect(client:find("RegisterNUICallback('tabletInputFocus'", 1, true) ~= nil,
  'callback de foco de texto do tablet ausente')
expect(
  client:find('local MovementEnabled = false', 1, true) ~= nil
    and client:find('local contextAlreadyOpen = CurrentContextId ~= nil', 1, true) ~= nil
    and client:find('if not contextAlreadyOpen then', 1, true) ~= nil
    and client:find('MovementEnabled = defaultMovementEnabled()', 1, true) ~= nil,
  'estado de movimento nao inicia travado ou nao e preservado entre contextos'
)
expect(
  client:find('local previousMovement = beginNuiDialog()', 1, true) ~= nil
    and client:find('restoreMovementAfterDialog(previousMovement)', 1, true) ~= nil,
  'dialogo nao trava e restaura o movimento'
)
expect(
  client:find('DisableControlAction(0, control, true)', 1, true) ~= nil
    and client:find('local COMBAT_CONTROLS = {', 1, true) ~= nil,
  'controles de combate nao sao protegidos durante o repasse de input'
)
expect(panel:find('id="focusToggleBtn"', 1, true) ~= nil, 'botao de rodape ausente')
expect(app:find('post("toggleMovement")', 1, true) ~= nil, 'frontend nao solicita alternancia de movimento')
expect(app:find('case "movementMode":', 1, true) ~= nil, 'frontend nao reflete o movimento')
expect(stateSource:find('movement: { enabled: false', 1, true) ~= nil, 'frontend nao inicia visualmente travado')
expect(
  app:find('setMovementMode(true, movementToggleKey);', 1, true) == nil,
  'frontend reinicia movimento ao trocar de contexto'
)
expect(
  app:find('state.movement.enabled ? "travar movimento" : "liberar movimento"', 1, true) ~= nil,
  'frontend nao informa corretamente a acao do toggle'
)
expect(client:find('HasGlobalPermission', 1, true) == nil, 'renderer recebeu regra de permissao')
expect(client:find('staff%.', 1) == nil, 'renderer recebeu capability Staff')

print('mz_admin movement passthrough contract harness: PASS')
