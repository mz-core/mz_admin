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

local router = read('mz_admin/client/router.lua')
local menu = read('mz_admin/client/menu.lua')

-- Modelo unificado: INICIO + JOGADORES + dominios reais permitidos na rail.
expect(router:find('TAB_MAIN', 1, true) ~= nil, 'aba MAIN ausente')
expect(router:find('TAB_PLAYERS', 1, true) ~= nil, 'aba JOGADORES ausente')
expect(router:find('TAB_ADMIN', 1, true) == nil, 'hub ADMIN ainda existe na rail')
expect(router:find('ROOT_ADMIN_ID', 1, true) == nil, 'router ainda navega para o hub legado')
expect(router:find('buildNavigationTabs', 1, true) ~= nil, 'sidebar dinamica ausente')
expect(menu:find('function MZAdminMenu.GetNavigationTabs', 1, true) ~= nil,
  'categorias canonicas nao sao expostas para a sidebar')

-- MAIN: acoes de sessao completas (inclui godmode, wall e ajuda de /tp).
for _, action in ipairs({ 'noclip', 'tpm', 'tpHelp', 'loc', 'selfHeal', 'selfRevive', 'selfArmor', 'selfGodmode', 'wall', 'spectateStop' }) do
  expect(router:find(("{ primary = { action = '%s' }"):format(action), 1, true) ~= nil
      or router:find(("action == '%s'"):format(action), 1, true) ~= nil,
    'acao de sessao ausente: ' .. action)
end

-- JOGADORES: lista com filtros online/offline/todos e modal de 6 abas internas.
for _, tab in ipairs({ 'actions', 'info', 'characters', 'history', 'security', 'punishments' }) do
  expect(router:find(("{ id = '%s'"):format(tab), 1, true) ~= nil, 'aba do modal ausente: ' .. tab)
end
expect(router:find('SearchPlayers(PlayerQuery, PlayerFilter', 1, true) ~= nil, 'busca paginada offline ausente')

-- Acoes em tempo real somente para online (nunca para offline).
expect(router:find('if online then', 1, true) ~= nil, 'guard de acao online ausente')

-- Dominios: cada categoria da rail renderiza sua propria arvore INLINE.
expect(router:find('ShowTabletContext(tab)', 1, true) ~= nil, 'dominio nao renderiza a arvore inline')
expect(router:find('SetTabletAdminTreeMode(true)', 1, true) ~= nil, 'modo de arvore inline nao habilitado')

-- Registro compartilhado da arvore de contextos (sem duplicar menu.lua).
expect(menu:find('function MZAdminMenu.RegisterModules', 1, true) ~= nil, 'RegisterModules ausente em menu.lua')
expect(router:find('MZAdminMenu.RegisterModules(context)', 1, true) ~= nil, 'router nao registra a arvore de contextos')

-- Sem rotas duplicadas de ferramentas/jogadores no hub.
expect(menu:find('mz_admin:section:tools', 1, true) == nil, 'secao Ferramentas rapidas ainda existe')
expect(menu:find("title = 'Jogadores e movimento'", 1, true) == nil, 'secao Jogadores e movimento ainda existe')

-- Contratos de seguranca preservados: client nunca autoriza nem acessa banco.
expect(router:find('HasGlobalPermission', 1, true) == nil, 'router passou a autorizar no client')
expect(router:find('MySQL%.', 1) == nil, 'router passou a acessar banco')

print('mz_admin tablet coverage harness: PASS')
