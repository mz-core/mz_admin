-- Regressao navegacional do MZ Admin Unificado (MAIN -> JOGADORES -> ADMIN -> MAIN).
-- Harness estatico (strings): nao substitui validacao de runtime no FiveM.

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
local app = read('mz_admin/web/app.js')
local menu = read('mz_admin/client/menu.lua')
local tablet = read('mz_admin/client/tablet.lua')
local ui = read('mz_admin/client/ui.lua')

-- Entrypoints: /admin e /mztablet (TAB) conduzem ao MESMO roteador.
expect(menu:find('MZAdminRouter.Open', 1, true) ~= nil, '/admin nao roteia ao MZAdminRouter')
expect(tablet:find('MZAdminRouter.Toggle', 1, true) ~= nil, '/mztablet (TAB) nao roteia ao MZAdminRouter')

-- Navegacao por abas: MAIN, JOGADORES e dominios; sem hub ADMIN duplicado.
expect(router:find("tab == TAB_MAIN", 1, true) ~= nil, 'navegacao MAIN ausente')
expect(router:find("tab == TAB_PLAYERS", 1, true) ~= nil, 'navegacao JOGADORES ausente')
expect(router:find('TAB_ADMIN', 1, true) == nil, 'hub ADMIN ainda existe na rail')
expect(router:find('NavigationTabs[tab]', 1, true) ~= nil, 'navegacao por dominio ausente')

-- F6 abre no modo livre; TAB e contratos historicos abrem no modo bloqueado.
expect(router:find('function MZAdminRouter.Toggle(inputMode)', 1, true) ~= nil,
  'roteador nao distingue os modos de input')
expect(router:find("InputMode = InputMode == 'free' and 'blocked' or 'free'", 1, true) ~= nil,
  'F6 nao alterna livre/bloqueado mantendo o painel')
expect(router:find("if InputMode == 'blocked' then return MZAdminRouter.Close() end", 1, true) ~= nil,
  'TAB bloqueado nao fecha o painel')
expect(router:find('if InputMode == inputMode then return MZAdminRouter.Close() end', 1, true) == nil,
  'condicao antiga ainda fecha o painel ao repetir F6')
expect(tablet:find("MZAdminRouter.Toggle('blocked')", 1, true) ~= nil,
  'TAB nao usa o modo bloqueado')
expect(ui:find("MZAdminRouter.Toggle('free')", 1, true) ~= nil,
  'F6 nao usa o modo livre')
expect(app:find('post("tabletBlockedToggle")', 1, true) ~= nil
  and app:find('post("tabletFreeToggle")', 1, true) ~= nil,
  'NUI nao encaminha os toggles ao mesmo roteador')

-- ESC com modal aberto fecha o modal primeiro (preserva a pagina).
expect(app:find('tablet.modal !== null && !dialog', 1, true) ~= nil,
  'ESC nao fecha o modal antes do resto')
expect(app:find('closeTabletModal(true)', 1, true) ~= nil, 'fechamento do modal ausente')

-- Modal de jogador com navegacao interna (6 abas) sem refetch.
expect(router:find('SetTabletModal', 1, true) ~= nil, 'router nao abre modal de jogador')
expect(app:find('renderTabletModalTabs', 1, true) ~= nil, 'abas internas do modal ausentes no frontend')

-- Acoes em tempo real desabilitadas para offline (guard server + client).
expect(router:find('if online then', 1, true) ~= nil, 'acoes offline nao bloqueadas no client')

print('mz_admin unified router harness: PASS')
