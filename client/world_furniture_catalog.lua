MZAdminFurniture = MZAdminFurniture or {}

local MENU_ID = 'mz_admin:world:furniture'
local DETAIL_ID = 'mz_admin:world:furniture:detail'
local RECOVERY_ID = 'mz_admin:world:furniture:recovery'
local ACTION_EVENT = 'mz_admin:client:furnitureAction'
local ListedItems = {}
local ParentMenuId
local CanRecover = false

local function notify(message, kind)
  kind = kind or 'inform'
  if GetResourceState('mz_notify') == 'started' then
    local notifyType = kind == 'inform' and 'info' or (kind == 'warn' and 'warning' or kind)
    local ok, result = pcall(function()
      return exports['mz_notify']:Notify({
        type = notifyType,
        title = (type(locale) == 'function' and locale('world_furniture.s_509bcb88c336') or 'Catalogo de moveis'),
        message = tostring(message or ''),
        duration = 4000
      })
    end)
    if ok and result ~= false then return true end
  end
  if type(MZAdminUI) == 'table' then
    return MZAdminUI.Notify(message, kind, 4000, { title = (type(locale) == 'function' and locale('world_furniture.s_509bcb88c336') or 'Catalogo de moveis') })
  end
  return false
end

local function request()
  local result = lib.callback.await('mz_admin:server:listFurnitureCatalog', false)
  if type(result) ~= 'table' or result.ok ~= true then
    notify(((type(locale) == 'function' and locale('world_furniture.s_e2138eba29db') or 'Consulta recusada: %s')):format(tostring(result and result.error or (type(locale) == 'function' and locale('world.s_82a6418075b3') or 'sem resposta'))), 'error')
    return nil
  end
  return result.data or {}
end

local function callback(name, ...)
  local result = lib.callback.await('mz_admin:server:' .. name, false, ...)
  if type(result) ~= 'table' or result.ok ~= true then
    notify(((type(locale) == 'function' and locale('world.s_39f03078b08a') or 'Operacao recusada: %s')):format(tostring(result and result.error or (type(locale) == 'function' and locale('world.s_82a6418075b3') or 'sem resposta'))), 'error')
    return nil
  end
  return result.data or {}
end

local function money(value)
  local amount = math.floor(tonumber(value) or 0)
  local formatted = tostring(amount)
  local count
  repeat
    formatted, count = formatted:gsub('^(-?%d+)(%d%d%d)', '%1.%2')
  until count == 0
  return ('$ %s'):format(formatted)
end

local function bind(option, itemId)
  option.event = ACTION_EVENT
  option.args = { action = 'details', itemId = itemId }
  return option
end

local function showDetails(itemId)
  local item = ListedItems[tonumber(itemId)]
  if not item then
    notify((type(locale) == 'function' and locale('world_furniture.s_ccec8a26dcb3') or 'O catalogo local ficou desatualizado.'), 'error')
    return
  end
  local status = item.archived == true and (type(locale) == 'function' and locale('world_props.s_8d036bd82021') or 'Arquivado')
    or (item.enabled == true and (type(locale) == 'function' and locale('world_furniture.s_2116b0559761') or 'Habilitado') or (type(locale) == 'function' and locale('world_furniture.s_e04eb9f54e8c') or 'Aguardando revisao'))
  local flags = item._flags or {}
  MZAdminUI.RegisterContext({
    id = DETAIL_ID,
    menu = MENU_ID,
    title = tostring(item.label),
    subtitle = ('%s | %s'):format(tostring(item.category), tostring(item.code)),
    options = {
      {
        title = status,
        description = ((type(locale) == 'function' and locale('world_furniture.s_180f1bc263c6') or 'Modelo: %s | hash: %s | revisao: %s')):format(
          tostring(item.modelName or (type(locale) == 'function' and locale('world_furniture.s_d107d17ab719') or 'somente hash')),
          tostring(item.modelHash),
          tostring(item.revision or 1)
        ),
        icon = item.enabled == true and 'circle-check' or 'triangle-exclamation',
        readOnly = true
      },
      {
        title = money(item.price),
        description = ((type(locale) == 'function' and locale('world_furniture.s_cbedb6e0639a') or 'Revenda: %d%% (%s)')):format(
          tonumber(item.resalePercent) or 0,
          money((tonumber(item.price) or 0) * (tonumber(item.resalePercent) or 0) / 100)
        ),
        icon = 'money-bill',
        readOnly = true
      },
      {
        title = (type(locale) == 'function' and locale('world_furniture.s_c0ca52b87fac') or 'Limites fisicos'),
        description = ((type(locale) == 'function' and locale('world_furniture.s_eaa8843ffd45') or 'Raio: %.2fm | maximo por casa: %s | colisao: %s')):format(
          tonumber(item.footprintRadius) or 0,
          tostring(item.maxPerProperty or (type(locale) == 'function' and locale('world_furniture.s_82f365b3d6e8') or 'limite global')),
          item.collisionEnabled == true and (type(locale) == 'function' and locale('security_alerts.s_813221ca5f14') or 'sim') or (type(locale) == 'function' and locale('security_alerts.s_21592d443e0a') or 'nao')
        ),
        icon = 'ruler-combined',
        readOnly = true
      },
      {
        title = (type(locale) == 'function' and locale('world_furniture.s_54061252196c') or 'Uso atual'),
        description = ((type(locale) == 'function' and locale('world_furniture.s_6462d61605d8') or 'Comprados: %d | posicionados: %d')):format(
          tonumber(item.ownedCount) or 0,
          tonumber(item.placedCount) or 0
        ),
        icon = 'chart-column',
        readOnly = true
      },
      {
        title = (type(locale) == 'function' and locale('world_furniture.s_46f1e2d22de8') or 'Rollout do gameplay'),
        description = ((type(locale) == 'function' and locale('world_furniture.s_87e167b5be1e') or 'Loja: %s | compra: %s | placement: %s | revenda: %s')):format(
          flags.catalogEnabled == true and (type(locale) == 'function' and locale('world_furniture.s_c3cdbbf417cb') or 'ligado') or (type(locale) == 'function' and locale('world_furniture.s_ee06676faab4') or 'desligado'),
          flags.purchasesEnabled == true and (type(locale) == 'function' and locale('world_furniture.s_c3cdbbf417cb') or 'ligado') or (type(locale) == 'function' and locale('world_furniture.s_ee06676faab4') or 'desligado'),
          flags.placementEnabled == true and (type(locale) == 'function' and locale('world_furniture.s_c3cdbbf417cb') or 'ligado') or (type(locale) == 'function' and locale('world_furniture.s_ee06676faab4') or 'desligado'),
          flags.resaleEnabled == true and (type(locale) == 'function' and locale('world_furniture.s_c3cdbbf417cb') or 'ligado') or (type(locale) == 'function' and locale('world_furniture.s_ee06676faab4') or 'desligado')
        ),
        icon = 'shield-halved',
        readOnly = true
      }
    }
  })
  MZAdminUI.ShowContext(DETAIL_ID)
end

local function openCatalog()
  local data = request()
  if not data then return end
  local options = {}
  ListedItems = {}
  for _, item in ipairs(data.items or {}) do
    item._flags = data.flags or {}
    ListedItems[tonumber(item.id)] = item
    options[#options + 1] = bind({
      title = tostring(item.label),
      description = ('%s | %s | %s'):format(
        tostring(item.category),
        money(item.price),
        item.archived == true and (type(locale) == 'function' and locale('world_props.s_1f2f7a28ede1') or 'arquivado') or (item.enabled == true and (type(locale) == 'function' and locale('world_furniture.s_58d66bd37fff') or 'habilitado') or (type(locale) == 'function' and locale('world_furniture.s_4275a675b709') or 'revisar'))
      ),
      icon = item.enabled == true and 'couch' or 'clipboard-check'
    }, tonumber(item.id))
  end
  if #options == 0 then
    options[1] = {
      title = (type(locale) == 'function' and locale('world_furniture.s_79bafefb4b9a') or 'Catalogo vazio'),
      description = (type(locale) == 'function' and locale('world_furniture.s_6bc1b6f20dca') or 'Nenhum item foi cadastrado no banco.'),
      icon = 'box-open',
      readOnly = true
    }
  end
  MZAdminUI.RegisterContext({
    id = MENU_ID,
    menu = ParentMenuId,
    title = (type(locale) == 'function' and locale('world_furniture.s_509bcb88c336') or 'Catalogo de moveis'),
    subtitle = ((type(locale) == 'function' and locale('world_furniture.s_36e04bc5f3ac') or '%d item(ns) | consulta segura')):format(#(data.items or {})),
    options = options
  })
  MZAdminUI.ShowContext(MENU_ID)
end

local function showRecovery()
  local data = callback('getFurnitureRecoveryOverview')
  if not data then return end
  local runtime = type(data.runtime) == 'table' and data.runtime or {}
  local options = {
    {
      title = (type(locale) == 'function' and locale('world_furniture.s_8eb4f20ec945') or 'Integridade persistida'),
      description = ((type(locale) == 'function' and locale('world_furniture.s_a08528c1a1f6') or 'Ownership divergente: %d | itens orfaos: %d | placements soltos: %d')):format(
        tonumber(data.ownershipMismatches) or 0,
        tonumber(data.orphanPlacedItems) or 0,
        tonumber(data.danglingPlacements) or 0
      ),
      icon = 'database',
      readOnly = true
    },
    {
      title = ((type(locale) == 'function' and locale('world_furniture.s_4d97d1d0fbbf') or 'Revisoes financeiras: %d')):format(tonumber(data.manualReviewCount) or 0),
      description = (type(locale) == 'function' and locale('world_furniture.s_8624d69d065a') or 'Operacoes ambiguas nunca sao resolvidas por forca; use conciliacao bancaria.'),
      icon = 'money-check-dollar',
      readOnly = true
    },
    {
      title = (type(locale) == 'function' and locale('world_furniture.s_bbb1dfbd72ba') or 'Executar verificacao de consistencia'),
      description = runtime.running == true and (type(locale) == 'function' and locale('world_furniture.s_da89dd94d66f') or 'Uma verificacao ja esta em andamento.')
        or (type(locale) == 'function' and locale('world_furniture.s_47468ff771aa') or 'Recolhe ownership divergente e corrige estados orfaos de forma idempotente.'),
      icon = 'rotate',
      disabled = runtime.running == true,
      event = ACTION_EVENT,
      args = { action = 'runRecovery' }
    },
    {
      title = (type(locale) == 'function' and locale('world_furniture.s_a5d237d7346d') or 'Conciliar jogador online'),
      description = (type(locale) == 'function' and locale('world_furniture.s_5bce85ac5261') or 'Selecione uma sessao ativa para conciliar compras e revendas em revisao.'),
      icon = 'user-check',
      event = ACTION_EVENT,
      args = { action = 'reconcilePlayer' }
    }
  }
  for _, transaction in ipairs(data.manualReviewTransactions or {}) do
    options[#options + 1] = {
      title = ('TX %s | %s'):format(tostring(transaction.id), tostring(transaction.transactionType)),
      description = ((type(locale) == 'function' and locale('world_furniture.s_75131e416438') or 'Cidadao: %s | %s | motivo: %s')):format(
        tostring(transaction.citizenid),
        money(transaction.amount),
        tostring(transaction.reason or (type(locale) == 'function' and locale('world_furniture.s_2bc0c6f12695') or 'resultado ambiguo'))
      ),
      icon = 'triangle-exclamation',
      readOnly = true
    }
  end
  MZAdminUI.RegisterContext({
    id = RECOVERY_ID,
    menu = MENU_ID,
    title = (type(locale) == 'function' and locale('world_furniture.s_71153b9af499') or 'Recuperacao de moveis'),
    subtitle = runtime.lastRunAt and ((type(locale) == 'function' and locale('world_furniture.s_02cebc85d72b') or 'Ultima verificacao: %s')):format(runtime.lastRunAt)
      or (type(locale) == 'function' and locale('world_furniture.s_84a7c3517ad2') or 'Ainda nao executada nesta sessao'),
    options = options
  })
  MZAdminUI.ShowContext(RECOVERY_ID)
end

local function runRecovery()
  local confirmed = MZAdminUI.Confirm(
    (type(locale) == 'function' and locale('world_furniture.s_ab27de50fe3e') or 'Verificar consistencia'),
    (type(locale) == 'function' and locale('world_furniture.s_2e49408cefc5') or 'Executar agora o recolhimento seguro de moveis com ownership divergente e o reparo de estados orfaos?'),
    { labels = { confirm = (type(locale) == 'function' and locale('world_furniture.s_ccdc57bfb6c9') or 'Executar'), cancel = (type(locale) == 'function' and locale('ui.cancel') or 'Cancelar') } }
  )
  if not confirmed then return end
  local result = callback('runFurnitureReconciliation', 'staff_menu_manual_reconciliation')
  if not result then return end
  notify(((type(locale) == 'function' and locale('world_furniture.s_163e6c8bcb96') or 'Verificacao concluida: %d recolhido(s), %d orfao(s), %d placement(s) corrigido(s).')):format(
    tonumber(result.collectedItems) or 0,
    tonumber(result.orphanItems) or 0,
    tonumber(result.danglingPlacements) or 0
  ), 'success')
  SetTimeout(250, showRecovery)
end

local function reconcilePlayer()
  local selected = MZAdminPlayerSelector.Select({
    title = (type(locale) == 'function' and locale('world_furniture.s_8469aa932b88') or 'Selecionar jogador para conciliacao'),
    allowOffline = false
  })
  local targetSource = selected and tonumber(selected.source)
  if not targetSource then return end
  local result = callback('reconcileFurniturePlayer', targetSource, selected.citizenid)
  if not result then return end
  notify(((type(locale) == 'function' and locale('world_furniture.s_216f3027ec1e') or 'Conciliacao concluida para %s.')):format(tostring(result.citizenid)), 'success')
  SetTimeout(250, showRecovery)
end

function MZAdminFurniture.Register(parentId, actions)
  if type(actions) ~= 'table' or actions.furnitureView ~= true then return false end
  ParentMenuId = parentId
  CanRecover = actions.furnitureRecovery == true
  local options = {
    {
      title = (type(locale) == 'function' and locale('world_furniture.s_58cc9cc990b2') or 'Carregar catalogo'),
      description = (type(locale) == 'function' and locale('world_furniture.s_96fb672afbfb') or 'Lista itens, precos, modelos, limites e estado do rollout.'),
      icon = 'couch',
      event = ACTION_EVENT,
      args = { action = 'open' }
    }
  }
  if CanRecover then
    options[#options + 1] = {
      title = (type(locale) == 'function' and locale('world_furniture.s_045628baf010') or 'Recuperacao e consistencia'),
      description = (type(locale) == 'function' and locale('world_furniture.s_7a25fc26d5e0') or 'Ownership, itens orfaos e transacoes financeiras em revisao.'),
      icon = 'screwdriver-wrench',
      event = ACTION_EVENT,
      args = { action = 'recovery' }
    }
  end
  MZAdminUI.RegisterContext({
    id = MENU_ID,
    menu = parentId,
    title = (type(locale) == 'function' and locale('world_furniture.s_509bcb88c336') or 'Catalogo de moveis'),
    subtitle = (type(locale) == 'function' and locale('world_furniture.s_7f1562208862') or 'Catalogo, rollout e recuperacao segura'),
    options = options
  })
  return true
end

function MZAdminFurniture.GetMenuId()
  return MENU_ID
end

AddEventHandler(ACTION_EVENT, function(payload)
  local action = type(payload) == 'table' and tostring(payload.action or '') or ''
  if action == 'open' then openCatalog()
  elseif action == 'details' then showDetails(payload.itemId)
  elseif action == 'recovery' and CanRecover then showRecovery()
  elseif action == 'runRecovery' and CanRecover then runRecovery()
  elseif action == 'reconcilePlayer' and CanRecover then reconcilePlayer()
  end
end)
