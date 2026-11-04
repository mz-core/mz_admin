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

local adminUi = read('mz_admin/client/ui.lua')
local adminApp = read('mz_admin/web/app.js')
local adminCss = read('mz_admin/web/style.css')
local adminRouter = read('mz_admin/client/router.lua')
local adminTablet = read('mz_admin/client/tablet.lua')
local adminMenu = read('mz_admin/client/menu.lua')
local serverTablet = read('mz_admin/server/tablet.lua')
local serverSecurity = read('mz_admin/server/security.lua')
local config = read('mz_admin/shared/config.lua')
local manifest = read('mz_admin/fxmanifest.lua')
local menuClient = read('mz_menu/client/main.lua')
local menuHtml = read('mz_menu/web/index.html')
local menuApp = read('mz_menu/web/app.js')
local menuCss = read('mz_menu/web/style.css')

-- mz_admin possui sua propria primitiva de apresentacao, incluindo abas,
-- contexto inline e modal, sem depender do resource mz_menu.
for _, exportName in ipairs({
  'OpenTablet', 'SetTabletView', 'CloseTablet', 'IsTabletOpen', 'SetTabletCallbacks',
  'SetTabletAdminTreeMode', 'ShowTabletContext', 'SetTabletContext', 'SetTabletModal', 'CloseTabletModal'
}) do
  expect(adminUi:find(("exports('%s'"):format(exportName), 1, true) ~= nil, 'export de tablet ausente: ' .. exportName)
end
for _, callback in ipairs({
  'tabletNavigate', 'tabletAction', 'tabletRowAction', 'tabletSearch', 'tabletClose',
  'tabletContextSelect', 'tabletContextBack', 'tabletFilter', 'tabletModalAction', 'tabletModalClose'
}) do
  expect(adminUi:find(("RegisterNUICallback('%s'"):format(callback), 1, true) ~= nil, 'callback NUI de tablet ausente: ' .. callback)
end
expect(adminUi:find('function MZAdminUI.OpenTablet', 1, true) ~= nil, 'primitiva OpenTablet ausente')
expect(adminUi:find('function MZAdminUI.CloseTablet', 1, true) ~= nil, 'primitiva CloseTablet ausente')
expect(adminUi:find('function MZAdminUI.ShowTabletContext', 1, true) ~= nil, 'primitiva ShowTabletContext ausente')
expect(adminUi:find('function MZAdminUI.SetTabletModal', 1, true) ~= nil, 'primitiva SetTabletModal ausente')

-- O renderer local continua sem autoridade, capability ou acesso a banco.
expect(adminUi:find('HasGlobalPermission', 1, true) == nil, 'renderer passou a autorizar no client')
expect(adminUi:find('staff%.', 1) == nil, 'renderer recebeu capability Staff')
expect(adminUi:find('MySQL%.', 1) == nil, 'renderer passou a acessar banco')

-- frontend renderiza o painel unificado (abas + contexto inline + modal).
for _, action in ipairs({ 'openTablet', 'tabletView', 'tabletContext', 'tabletModal', 'tabletClose' }) do
  expect(adminApp:find(("case \"%s\":"):format(action), 1, true) ~= nil, 'frontend nao trata ' .. action)
end
expect(adminApp:find('post("tabletClose"', 1, true) ~= nil, 'frontend nao envia fechamento do tablet')
expect(adminApp:find('"tabletContextSelect"', 1, true) ~= nil, 'frontend nao envia selecao de contexto inline')
expect(adminApp:find('"tabletModalAction"', 1, true) ~= nil, 'frontend nao envia acao do modal')
expect(adminApp:find('postLocked', 1, true) ~= nil, 'frontend nao protege clique duplo em acoes')

-- Anatomia visual adaptada do Flight Admin (sem importar sua logica administrativa).
for _, contract in ipairs({
  'width: min(600px', 'height: min(775px', 'height: 50px', 'flex: 0 0 80px',
  'grid-template-columns: repeat(3, minmax(0, 1fr))'
}) do
  expect(adminCss:find(contract, 1, true) ~= nil, 'contrato visual Flight ausente: ' .. contract)
end

-- entrypoint unico: TAB (/mztablet) e /admin conduzem ao MZAdminRouter.
expect(adminTablet:find("RegisterCommand((cfg()).OpenCommand or 'mztablet'", 1, true) ~= nil, 'comando /mztablet ausente')
expect(adminTablet:find('RegisterKeyMapping(', 1, true) ~= nil, 'key mapping do tablet ausente')
expect(adminTablet:find('MZAdminRouter.Toggle', 1, true) ~= nil, 'shim do tablet nao roteia para o router')
expect(adminMenu:find('MZAdminRouter.Open', 1, true) ~= nil, '/admin nao roteia para o router')
for _, contract in ipairs({ 'OpenAdminMenu', 'CloseAdminMenu', 'ToggleAdminMenu', 'IsAdminMenuOpen' }) do
  expect(adminMenu:find(("exports('%s'"):format(contract), 1, true) ~= nil, 'export publico ausente: ' .. contract)
end
for _, event in ipairs({ 'openAdmin', 'closeAdmin', 'toggleAdmin' }) do
  expect(adminMenu:find('mz_admin:client:' .. event, 1, true) ~= nil, 'evento cliente ausente: ' .. event)
end

-- roteador reutiliza a autoridade existente e registra a arvore de contextos.
expect(adminRouter:find('GetMenuContext(true)', 1, true) ~= nil, 'verificacao staff ausente (getMenuContext)')
expect(adminRouter:find('MZAdminMenu.RegisterModules(context)', 1, true) ~= nil, 'arvore de contextos nao registrada')
expect(adminRouter:find('MZAdminClient.SearchPlayers', 1, true) ~= nil, 'lista de jogadores ausente (SearchPlayers)')
expect(adminRouter:find('SetTabletCallbacks', 1, true) ~= nil, 'registro de callbacks do router ausente')

-- allowlist tipada no servidor: cada acao tem um handler especifico.
for _, callback in ipairs({
  'mz_admin:server:tabletGoto', 'mz_admin:server:tabletBring', 'mz_admin:server:tabletKick',
  'mz_admin:server:tabletHeal', 'mz_admin:server:tabletRevive', 'mz_admin:server:tabletArmor',
  'mz_admin:server:tabletSpectateStart', 'mz_admin:server:tabletSpectateStop'
}) do
  expect(serverTablet:find(callback, 1, true) ~= nil, 'handler tipado ausente: ' .. callback)
end
expect(serverTablet:find('MZAdminSecurity.Authorize', 1, true) ~= nil, 'servidor nao revalida capability')
expect(serverTablet:find('ValidateTargetIdentity', 1, true) ~= nil, 'servidor nao valida identidade do alvo')
expect(serverTablet:find('CanStaffActOnPlayer', 1, true) ~= nil, 'servidor nao valida hierarquia')
expect(serverTablet:find('RegisterNetEvent', 1, true) == nil, 'servidor do tablet nao pode aceitar eventos arbitrarios')
expect(serverTablet:find('ExecuteCommand', 1, true) == nil, 'servidor do tablet nao pode executar comandos arbitrarios')

-- consulta de personagens (offline) usa contrato canonico do mz_core.
expect(serverSecurity:find('mz_admin:server:getAccountCharacters', 1, true) ~= nil, 'callback de personagens ausente')
expect(serverSecurity:find("GetCharactersForAccount", 1, true) ~= nil, 'personagens nao usam contrato canonico do mz_core')

-- feature flag reversivel.
expect(config:find('Tablet = {', 1, true) ~= nil, 'flag Config.Tablet ausente')
expect(config:find('Enabled = true', 1, true) ~= nil, 'flag de habilitacao ausente')
expect(config:find("GetConvar('ox:locale', 'pt-br')", 1, true) ~= nil, 'locale global nao e herdado do servidor')
expect(adminRouter:find("locale = tostring(Config.Locale or 'pt-BR')", 1, true) ~= nil, 'locale nao chega ao modelo da NUI')
expect(adminApp:find('document.documentElement.lang', 1, true) ~= nil, 'NUI nao aplica o locale global')
expect(manifest:find('client/router.lua', 1, true) ~= nil, 'client/router.lua ausente do manifest')
expect(manifest:find('client/ui.lua', 1, true) ~= nil, 'client/ui.lua ausente do manifest')
expect(manifest:find("ui_page 'web/index.html'", 1, true) ~= nil, 'ui_page propria ausente do manifest')
expect(manifest:find("'mz_menu'", 1, true) == nil, 'mz_menu ainda e dependencia do mz_admin')
expect(manifest:find('client/tablet.lua', 1, true) ~= nil, 'client/tablet.lua ausente do manifest')
expect(manifest:find('server/tablet.lua', 1, true) ~= nil, 'server/tablet.lua ausente do manifest')

-- mz_menu permanece uma biblioteca generica e nao carrega componentes admin.
for _, source in ipairs({ menuClient, menuHtml, menuApp, menuCss }) do
  expect(source:lower():find('tablet', 1, true) == nil, 'renderer administrativo ainda existe no mz_menu')
end

print('mz_admin tablet contract harness: PASS')
