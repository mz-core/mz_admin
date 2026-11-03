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
        title = 'Catalogo de moveis',
        message = tostring(message or ''),
        duration = 4000
      })
    end)
    if ok and result ~= false then return true end
  end
  if type(MZAdminUI) == 'table' then
    return MZAdminUI.Notify(message, kind, 4000, { title = 'Catalogo de moveis' })
  end
  return false
end

local function request()
  local result = lib.callback.await('mz_admin:server:listFurnitureCatalog', false)
  if type(result) ~= 'table' or result.ok ~= true then
    notify(('Consulta recusada: %s'):format(tostring(result and result.error or 'sem resposta')), 'error')
    return nil
  end
  return result.data or {}
end

local function callback(name, ...)
  local result = lib.callback.await('mz_admin:server:' .. name, false, ...)
  if type(result) ~= 'table' or result.ok ~= true then
    notify(('Operacao recusada: %s'):format(tostring(result and result.error or 'sem resposta')), 'error')
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
    notify('O catalogo local ficou desatualizado.', 'error')
    return
  end
  local status = item.archived == true and 'Arquivado'
    or (item.enabled == true and 'Habilitado' or 'Aguardando revisao')
  local flags = item._flags or {}
  MZAdminUI.RegisterContext({
    id = DETAIL_ID,
    menu = MENU_ID,
    title = tostring(item.label),
    subtitle = ('%s | %s'):format(tostring(item.category), tostring(item.code)),
    options = {
      {
        title = status,
        description = ('Modelo: %s | hash: %s | revisao: %s'):format(
          tostring(item.modelName or 'somente hash'),
          tostring(item.modelHash),
          tostring(item.revision or 1)
        ),
        icon = item.enabled == true and 'circle-check' or 'triangle-exclamation',
        readOnly = true
      },
      {
        title = money(item.price),
        description = ('Revenda: %d%% (%s)'):format(
          tonumber(item.resalePercent) or 0,
          money((tonumber(item.price) or 0) * (tonumber(item.resalePercent) or 0) / 100)
        ),
        icon = 'money-bill',
        readOnly = true
      },
      {
        title = 'Limites fisicos',
        description = ('Raio: %.2fm | maximo por casa: %s | colisao: %s'):format(
          tonumber(item.footprintRadius) or 0,
          tostring(item.maxPerProperty or 'limite global'),
          item.collisionEnabled == true and 'sim' or 'nao'
        ),
        icon = 'ruler-combined',
        readOnly = true
      },
      {
        title = 'Uso atual',
        description = ('Comprados: %d | posicionados: %d'):format(
          tonumber(item.ownedCount) or 0,
          tonumber(item.placedCount) or 0
        ),
        icon = 'chart-column',
        readOnly = true
      },
      {
        title = 'Rollout do gameplay',
        description = ('Loja: %s | compra: %s | placement: %s | revenda: %s'):format(
          flags.catalogEnabled == true and 'on' or 'off',
          flags.purchasesEnabled == true and 'on' or 'off',
          flags.placementEnabled == true and 'on' or 'off',
          flags.resaleEnabled == true and 'on' or 'off'
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
        item.archived == true and 'arquivado' or (item.enabled == true and 'habilitado' or 'revisar')
      ),
      icon = item.enabled == true and 'couch' or 'clipboard-check'
    }, tonumber(item.id))
  end
  if #options == 0 then
    options[1] = {
      title = 'Catalogo vazio',
      description = 'Nenhum item foi cadastrado no banco.',
      icon = 'box-open',
      readOnly = true
    }
  end
  MZAdminUI.RegisterContext({
    id = MENU_ID,
    menu = ParentMenuId,
    title = 'Catalogo de moveis',
    subtitle = ('%d item(ns) | consulta segura'):format(#(data.items or {})),
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
      title = 'Integridade persistida',
      description = ('Ownership divergente: %d | itens orfaos: %d | placements soltos: %d'):format(
        tonumber(data.ownershipMismatches) or 0,
        tonumber(data.orphanPlacedItems) or 0,
        tonumber(data.danglingPlacements) or 0
      ),
      icon = 'database',
      readOnly = true
    },
    {
      title = ('Revisoes financeiras: %d'):format(tonumber(data.manualReviewCount) or 0),
      description = 'Operacoes ambiguas nunca sao resolvidas por forca; use conciliacao bancaria.',
      icon = 'money-check-dollar',
      readOnly = true
    },
    {
      title = 'Executar verificacao de consistencia',
      description = runtime.running == true and 'Uma verificacao ja esta em andamento.'
        or 'Recolhe ownership divergente e corrige estados orfaos de forma idempotente.',
      icon = 'rotate',
      disabled = runtime.running == true,
      event = ACTION_EVENT,
      args = { action = 'runRecovery' }
    },
    {
      title = 'Conciliar jogador online',
      description = 'Selecione uma sessao ativa para conciliar compras e revendas em revisao.',
      icon = 'user-check',
      event = ACTION_EVENT,
      args = { action = 'reconcilePlayer' }
    }
  }
  for _, transaction in ipairs(data.manualReviewTransactions or {}) do
    options[#options + 1] = {
      title = ('TX %s | %s'):format(tostring(transaction.id), tostring(transaction.transactionType)),
      description = ('Cidadao: %s | %s | motivo: %s'):format(
        tostring(transaction.citizenid),
        money(transaction.amount),
        tostring(transaction.reason or 'resultado ambiguo')
      ),
      icon = 'triangle-exclamation',
      readOnly = true
    }
  end
  MZAdminUI.RegisterContext({
    id = RECOVERY_ID,
    menu = MENU_ID,
    title = 'Recuperacao de moveis',
    subtitle = runtime.lastRunAt and ('Ultima verificacao: %s'):format(runtime.lastRunAt)
      or 'Ainda nao executada nesta sessao',
    options = options
  })
  MZAdminUI.ShowContext(RECOVERY_ID)
end

local function runRecovery()
  local confirmed = MZAdminUI.Confirm(
    'Verificar consistencia',
    'Executar agora o recolhimento seguro de moveis com ownership divergente e o reparo de estados orfaos?',
    { labels = { confirm = 'Executar', cancel = 'Cancelar' } }
  )
  if not confirmed then return end
  local result = callback('runFurnitureReconciliation', 'staff_menu_manual_reconciliation')
  if not result then return end
  notify(('Verificacao concluida: %d recolhido(s), %d orfao(s), %d placement(s) corrigido(s).'):format(
    tonumber(result.collectedItems) or 0,
    tonumber(result.orphanItems) or 0,
    tonumber(result.danglingPlacements) or 0
  ), 'success')
  SetTimeout(250, showRecovery)
end

local function reconcilePlayer()
  local selected = MZAdminPlayerSelector.Select({
    title = 'Selecionar jogador para conciliacao',
    allowOffline = false
  })
  local targetSource = selected and tonumber(selected.source)
  if not targetSource then return end
  local result = callback('reconcileFurniturePlayer', targetSource, selected.citizenid)
  if not result then return end
  notify(('Conciliacao concluida para %s.'):format(tostring(result.citizenid)), 'success')
  SetTimeout(250, showRecovery)
end

function MZAdminFurniture.Register(parentId, actions)
  if type(actions) ~= 'table' or actions.furnitureView ~= true then return false end
  ParentMenuId = parentId
  CanRecover = actions.furnitureRecovery == true
  local options = {
    {
      title = 'Carregar catalogo',
      description = 'Lista itens, precos, modelos, limites e estado do rollout.',
      icon = 'couch',
      event = ACTION_EVENT,
      args = { action = 'open' }
    }
  }
  if CanRecover then
    options[#options + 1] = {
      title = 'Recuperacao e consistencia',
      description = 'Ownership, itens orfaos e transacoes financeiras em revisao.',
      icon = 'screwdriver-wrench',
      event = ACTION_EVENT,
      args = { action = 'recovery' }
    }
  end
  MZAdminUI.RegisterContext({
    id = MENU_ID,
    menu = parentId,
    title = 'Catalogo de moveis',
    subtitle = 'Catalogo, rollout e recuperacao segura',
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
