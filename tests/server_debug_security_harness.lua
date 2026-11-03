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

local manifest = read('mz_admin/fxmanifest.lua')
local ui = read('mz_admin/client/ui.lua')
local router = read('mz_admin/client/router.lua')

expect(manifest:find("'mz_menu'", 1, true) == nil, 'mz_menu permanece como dependencia')
expect(manifest:find("ui_page 'web/index.html'", 1, true) ~= nil, 'NUI propria nao declarada')
expect(manifest:find("'client/ui.lua'", 1, true) ~= nil, 'bridge NUI proprio nao carregado')
expect(ui:find("RegisterNetEvent('mz_admin_ui:server:debug'", 1, true) == nil,
  'evento de debug mutavel exposto pelo renderer')
expect(ui:find("exports('Notify', MZAdminUI.Notify)", 1, true) ~= nil,
  'export de notificacao proprio ausente')
expect(ui:find("exports('OpenTablet', MZAdminUI.OpenTablet)", 1, true) ~= nil,
  'export de tablet proprio ausente')
expect(router:find("GetMenuContext(true)", 1, true) ~= nil,
  'abertura nao exige contexto autorizado do servidor')
expect(router:find("Wait(3000)", 1, true) ~= nil,
  'sessao aberta nao revalida permissao')

print('mz_admin UI security contract harness: PASS')
