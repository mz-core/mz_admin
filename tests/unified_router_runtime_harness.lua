-- Regressao de NAVEGACAO em runtime do MZ Admin Unificado.
--
-- Diferente dos harnesses estaticos (que so validam strings), este carrega e
-- EXECUTA client/router.lua com globals FiveM simulados e percorre o fluxo real:
--   RECOLHIDO -> MAIN -> JOGADORES -> lista -> selecionar jogador -> modal -> fechar modal
--   -> ADMIN -> MAIN.
--
-- Se uma funcao local for referenciada antes da declaracao (forward reference),
-- o passo correspondente lanca "attempt to call a nil value" e o harness FALHA.

local function expect(cond, msg)
  if not cond then error(msg, 2) end
end

-- ---------------------------------------------------------------- globals stub

local capturedCallbacks = nil
local openedTablet = nil
local views = {}
local contexts = {}
local modal = nil
local openedMovement = nil
local movementStates = {}
local gameTimer = 0
local openTabletCalls = 0
local closeTabletCalls = 0

_G.Config = {
  AdminCommand = 'admin', StaffOrganizationCommand = 'stafforg',
  NoClipCommand = 'noclip', WallCommand = 'wall', SpectateStopCommand = 'specoff',
  Commands = { tpm = 'tpm', loc = 'loc', godMode = 'godmode' },
  Tablet = { Enabled = true, OpenCommand = 'mztablet', OpenKey = 'TAB', RefreshPlayersMs = 5000 }
}
_G.GetResourceState = function() return 'started' end
_G.IsPauseMenuActive = function() return false end
_G.GetPlayerServerId = function() return 1 end
_G.PlayerId = function() return 0 end
_G.GetGameTimer = function() gameTimer = gameTimer + 500 return gameTimer end
_G.GetCurrentResourceName = function() return 'mz_admin' end
_G.GetResourceMetadata = function(_, key) return key == 'version' and '0.3.1' or nil end
_G.ExecuteCommand = function() end
_G.Wait = function() end
_G.TriggerEvent = function() end
_G.RegisterCommand = function() end
_G.RegisterKeyMapping = function() end
_G.RegisterNetEvent = function() end
_G.AddEventHandler = function() end
_G.CreateThread = function() end -- nao executa loops de polling no harness
_G.locale = function(key)
  local english = {
    ['menu.s_3b2c8bf51797'] = 'HOME',
    ['menu.s_32b8840c22ca'] = 'PLAYERS',
    ['menu.s_f3b86b13dbbc'] = 'Home',
    ['menu.s_c702ea656c01'] = 'Players'
  }
  return english[key] or key
end

_G.exports = {}
_G.MZAdminUI = {
  Notify = function() end,
  InputDialog = function() return nil end,
  Confirm = function() return false end,
  SetTabletCallbacks = function(cb) capturedCallbacks = cb end,
  OpenTablet = function(model, movement)
    openTabletCalls = openTabletCalls + 1
    openedTablet = model
    openedMovement = movement
    return true
  end,
  SetMovementEnabled = function(enabled) movementStates[#movementStates + 1] = enabled return true, enabled end,
  SetTabletView = function(view) views[view.tab or view.category] = view end,
  SetTabletAdminTreeMode = function() end,
  ShowTabletContext = function(id) contexts[id] = true end,
  SetTabletModal = function(m) modal = m end,
  CloseTabletModal = function() end,
  CloseTablet = function() closeTabletCalls = closeTabletCalls + 1 end
}
_G.exports['mz_core'] = { GetPlayerSession = function() return { id = 1 } end }
_G.exports['mz_inventory'] = { IsOpen = function() return false end }

_G.lib = {
  callback = { await = function() return { ok = true, data = {} } end },
  notify = function() end
}

_G.MZAdminClient = {
  GetMenuContext = function()
    return {
      actions = { playersList = true, gotoPlayer = true, noclip = true },
      self = { name = 'Staff Teste', role = { name = 'Owner' } },
      warningsReady = true, banGuardReady = true
    }
  end,
  SearchPlayers = function()
    return {
      items = {
        { key = 'character:ABC123', source = 2, citizenid = 'ABC123', accountId = 7,
          characterId = 3, characterName = 'Player Teste', name = 'Player Teste',
          online = true, ping = 15 }
      },
      total = 1, page = 1, pageSize = 25, hasMore = false
    }
  end
}

_G.MZAdminMenu = {
  RegisterModules = function() end,
  GetNavigationTabs = function()
    return {
      { id = 'mz_admin:world', label = 'Mundo e cenários', icon = 'earth-americas' }
    }
  end
}

-- ---------------------------------------------------------------- carrega o router

local chunk, loadErr = loadfile('mz_admin/client/router.lua')
expect(chunk ~= nil, 'nao foi possivel carregar router.lua: ' .. tostring(loadErr))

local loaded, runErr = pcall(chunk)
expect(loaded, 'erro ao executar router.lua: ' .. tostring(runErr))

expect(type(_G.MZAdminRouter) == 'table', 'MZAdminRouter nao definido')
expect(type(_G.MZAdminRouter.Open) == 'function', 'MZAdminRouter.Open ausente')

-- ---------------------------------------------------------------- fluxo

local function step(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    error(('FALHA em "%s": %s'):format(name, tostring(err)), 2)
  end
end

step('Open', function()
  expect(_G.MZAdminRouter.Open() == true, 'Open retornou false')
  expect(openedTablet ~= nil, 'OpenTablet nao chamado')
  expect(openedTablet.tabs ~= nil and #openedTablet.tabs == 3, 'deveria haver 3 abas (INICIO, JOGADORES, dominio)')
  local ids = {}
  for _, tab in ipairs(openedTablet.tabs) do ids[tab.id] = true end
  expect(openedTablet.tabs[1].label == 'HOME' and openedTablet.tabs[2].label == 'PLAYERS',
    'abas nao usam as traducoes do locale')
  expect(ids.main == true and ids.players == true and ids['mz_admin:world'] == true,
    'abas canonicas ausentes')
  expect(ids.admin == nil and ids['mz_admin:root'] == nil, 'hub Administracao ainda esta na rail')
  expect(openedTablet.title == '0.3.1', 'versao nao veio do manifest')
  expect(openedMovement == false, 'Open padrao deveria bloquear movimento')
  expect(capturedCallbacks ~= nil, 'SetTabletCallbacks nao chamado')
end)

step('recolhido inicial', function()
  expect(views['main'] == nil, 'nenhuma secao deve renderizar na abertura')
end)

step('MAIN por clique', function()
  capturedCallbacks.onNavigate('main')
  expect(views['main'] ~= nil, 'MAIN nao renderizada apos navegacao')
  expect(views['main'].title == 'Home', 'titulo MAIN nao usa o locale')
end)

step('recolher MAIN', function()
  capturedCallbacks.onNavigate('')
end)

step('JOGADORES (lista)', function()
  capturedCallbacks.onNavigate('players')
  expect(views['players'] ~= nil, 'JOGADORES nao renderizou a lista')
  expect(views['players'].title == 'Players', 'titulo JOGADORES nao usa o locale')
  expect(views['players'].rows ~= nil and #views['players'].rows == 1, 'lista de jogadores vazia/ausente')
end)

step('selecionar jogador -> modal', function()
  capturedCallbacks.onRowAction('players', 'character:ABC123', 'select', {})
  expect(modal ~= nil, 'modal de jogador nao abriu')
  expect(modal.tabs ~= nil and #modal.tabs == 6, 'modal sem as 6 abas internas')
end)

step('fechar modal (preserva pagina)', function()
  capturedCallbacks.onModalClose()
  expect(views['players'] ~= nil, 'fechar modal derrubou a pagina JOGADORES')
end)

step('dominio (arvore inline)', function()
  capturedCallbacks.onNavigate('mz_admin:world')
  expect(contexts['mz_admin:world'] == true, 'dominio nao renderizou a arvore inline')
end)

step('MAIN (retorno)', function()
  capturedCallbacks.onNavigate('main')
  expect(views['main'] ~= nil, 'MAIN nao retornou ao final do ciclo')
end)

step('modos F6 livre e TAB bloqueado', function()
  expect(_G.MZAdminRouter.Close() == true, 'Close bloqueado falhou')
  expect(_G.MZAdminRouter.Toggle('free') == true, 'F6 nao abriu em modo livre')
  expect(openedMovement == true, 'F6 nao repassou movimento livre ao renderer')
  local openCalls = openTabletCalls
  local closeCalls = closeTabletCalls
  local callbacks = capturedCallbacks
  capturedCallbacks.onNavigate('main')
  local preservedView = views['main']

  expect(_G.MZAdminRouter.Toggle('free') == true, 'segundo F6 nao bloqueou movimento')
  expect(movementStates[#movementStates] == false, 'segundo F6 nao aplicou modo bloqueado')
  expect(_G.MZAdminRouter.IsOpen() == true, 'segundo F6 fechou o painel')
  expect(openTabletCalls == openCalls and closeTabletCalls == closeCalls,
    'segundo F6 reconstruiu ou fechou a NUI')
  expect(capturedCallbacks == callbacks and views['main'] == preservedView,
    'segundo F6 perdeu navegacao ou dados exibidos')

  expect(_G.MZAdminRouter.Toggle('free') == true, 'terceiro F6 nao liberou movimento')
  expect(movementStates[#movementStates] == true, 'terceiro F6 nao aplicou modo livre')
  expect(_G.MZAdminRouter.IsOpen() == true, 'terceiro F6 fechou o painel')

  expect(_G.MZAdminRouter.Toggle('blocked') == true, 'TAB nao trocou para modo bloqueado')
  expect(movementStates[#movementStates] == false, 'TAB nao bloqueou movimento')
  expect(_G.MZAdminRouter.IsOpen() == true, 'troca de modo fechou o painel')
  expect(_G.MZAdminRouter.Toggle('blocked') == true, 'segundo TAB nao fechou o painel')
  expect(_G.MZAdminRouter.IsOpen() == false, 'painel continuou aberto apos toggle TAB')

  expect(_G.MZAdminRouter.Toggle('blocked') == true, 'TAB nao abriu o painel bloqueado')
  expect(openedMovement == false, 'TAB fechado nao abriu em modo bloqueado')
  expect(_G.MZAdminRouter.Toggle('free') == true, 'F6 nao mudou TAB bloqueado para livre')
  expect(_G.MZAdminRouter.Toggle('free') == true, 'F6 repetido nao voltou ao bloqueado')
  expect(_G.MZAdminRouter.IsOpen() == true, 'alternancia F6 apos TAB fechou o painel')

  capturedCallbacks.onClose('escape')
  expect(_G.MZAdminRouter.IsOpen() == false, 'ESC nao limpou a visibilidade do roteador')
end)

print('mz_admin unified router runtime harness: PASS')
