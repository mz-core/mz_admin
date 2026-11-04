MZAdminProps = MZAdminProps or {}

local MENU_ID = 'mz_admin:world:props'
local LIST_ID = 'mz_admin:world:props:list'
local DETAIL_ID = 'mz_admin:world:props:detail'
local ACTION_EVENT = 'mz_admin:client:worldPropAction'
local CurrentActions = {}
local PendingPlacement
local ListedProps = {}
local MIN_STREAM_DISTANCE = 10
local MAX_STREAM_DISTANCE = 2000

local function notify(message, kind)
  kind = kind or 'inform'
  if GetResourceState('mz_notify') == 'started' then
    local notifyType = kind == 'inform' and 'info' or (kind == 'warn' and 'warning' or kind)
    local ok, result = pcall(function()
      return exports['mz_notify']:Notify({
        type = notifyType,
        title = (type(locale) == 'function' and locale('world.s_433fff088a2c') or 'Gestao de mundo'),
        message = tostring(message or ''),
        duration = 4000
      })
    end)
    if ok and result ~= false then return true end
  end
  if type(MZAdminUI) == 'table' then
    return MZAdminUI.Notify(message, kind, 4000, { title = (type(locale) == 'function' and locale('world.s_433fff088a2c') or 'Gestao de mundo') })
  end
  return false
end

local function request(name, ...)
  local result = lib.callback.await('mz_admin:server:' .. name, false, ...)
  if type(result) ~= 'table' or result.ok ~= true then
    notify(((type(locale) == 'function' and locale('world.s_39f03078b08a') or 'Operacao recusada: %s')):format(tostring(result and result.error or (type(locale) == 'function' and locale('world.s_82a6418075b3') or 'sem resposta'))), 'error')
    return nil
  end
  return result.data or {}
end

local function bind(option, action, args)
  args = type(args) == 'table' and args or {}
  args.action = action
  option.event = ACTION_EVENT
  option.args = args
  return option
end

local function suggestedCode(label)
  local code = tostring(label or ''):lower()
  code = code:gsub('[^a-z0-9]+', '_'):gsub('^_+', ''):gsub('_+$', '')
  if #code < 3 then code = 'prop_' .. tostring(GetGameTimer()) end
  return code:sub(1, 64)
end

local function cancelPending(reason)
  if not PendingPlacement then return end
  lib.callback.await('mz_admin:server:cancelWorldPropDraft', false, PendingPlacement.sessionId)
  PendingPlacement = nil
  if reason then notify(reason, 'info') end
end

local function startCreate()
  if GetResourceState('mz_world_editor') ~= 'started' then
    notify((type(locale) == 'function' and locale('world.s_c7e1821b9acb') or 'mz_world_editor nao esta iniciado.'), 'error')
    return
  end
  local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('world_props.s_93a3cc68df79') or 'Novo prop persistente'), {
    { type = 'input', label = (type(locale) == 'function' and locale('garage.s_6f4b8c6403f4') or 'Nome de exibicao'), required = true, placeholder = (type(locale) == 'function' and locale('world_props.s_7ebe8cf12ca3') or 'Barreira - Praca central') },
    {
      type = 'input', label = (type(locale) == 'function' and locale('world_props.s_843d8a520103') or 'Modelo GTA'), required = true, placeholder = 'prop_barrier_work05',
      description = (type(locale) == 'function' and locale('world_props.s_ded06f5faa9a') or 'Aceita nome do modelo ou hash numerico.')
    },
    { type = 'input', label = (type(locale) == 'function' and locale('garage.s_ba53a1f3589a') or 'Codigo estrutural'), required = false, placeholder = 'praca_barreira_01' },
    {
      type = 'number', label = (type(locale) == 'function' and locale('world_props.s_05bf503012b0') or 'Distancia de streaming e visibilidade'), required = true,
      default = 120, min = MIN_STREAM_DISTANCE, max = MAX_STREAM_DISTANCE,
      description = (type(locale) == 'function' and locale('world_props.s_eb8f0ea95268') or 'Controla quando o prop existe e ate onde o GTA o desenha. Valores altos custam mais desempenho.')
    },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('world_props.s_2a5813b9f958') or 'Congelado'), checked = true },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('world_props.s_a4cffe8ef61b') or 'Colisao habilitada'), checked = true },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('world_props.s_6539f77d95f6') or 'Visivel'), checked = true }
  }, { allowCancel = true })
  if not values then return end

  local name = tostring(values[1] or '')
  local modelInput = tostring(values[2] or ''):gsub('^%s+', ''):gsub('%s+$', '')
  local modelHash = tonumber(modelInput) or GetHashKey(modelInput)
  if modelInput == '' or not IsModelInCdimage(modelHash) or not IsModelValid(modelHash)
    or IsModelAVehicle(modelHash) or IsModelAPed(modelHash) then
    notify((type(locale) == 'function' and locale('world_props.s_d981cdd7a7ec') or 'Modelo invalido ou nao e um objeto GTA.'), 'error')
    return
  end

  local session = request('beginWorldPropDraft')
  if not session or not session.sessionId then return end
  local requestId = ('mz_admin:prop:%s'):format(GetGameTimer())
  PendingPlacement = {
    requestId = requestId,
    sessionId = session.sessionId,
    name = name,
    code = tostring(values[3] or '') ~= '' and tostring(values[3]) or suggestedCode(name),
    modelHash = modelHash,
    modelName = tonumber(modelInput) and nil or modelInput,
    streamDistance = tonumber(values[4]) or 120,
    frozen = values[5] == true,
    collisionEnabled = values[6] == true,
    visible = values[7] == true
  }

  MZAdminUI.CloseContext()
  local ok, err = exports['mz_world_editor']:StartPropPlacement({
    requestId = requestId,
    title = ((type(locale) == 'function' and locale('world_props.s_6eef320aed9d') or 'Posicionar %s')):format(name),
    modelHash = modelHash,
    modelName = PendingPlacement.modelName
  })
  if ok ~= true then
    cancelPending()
    notify(((type(locale) == 'function' and locale('world_props.s_d26ece520ac4') or 'Nao foi possivel iniciar o placement: %s')):format(tostring(err)), 'error')
    MZAdminUI.ShowContext(MENU_ID)
  end
end

local function showPropDetails(propId)
  local prop = ListedProps[tonumber(propId)]
  if not prop then return end
  local options = {
    {
      title = prop.active == false and (type(locale) == 'function' and locale('world_props.s_8d036bd82021') or 'Arquivado') or (type(locale) == 'function' and locale('router.s_8263fde6ccc4') or 'Ativo'),
      description = ('%s | hash %s'):format(tostring(prop.code or 'sem_codigo'), tostring(prop.model_hash)),
      icon = prop.active == false and 'box-archive' or 'cube',
      readOnly = true
    },
    {
      title = (type(locale) == 'function' and locale('world_props.s_d46eae232c89') or 'Posicao e streaming'),
      description = ('%.3f, %.3f, %.3f | %.0fm'):format(
        tonumber(prop.x) or 0, tonumber(prop.y) or 0, tonumber(prop.z) or 0,
        tonumber(prop.stream_distance) or 0
      ),
      icon = 'location-dot',
      readOnly = true
    }
  }
  if CurrentActions.worldPropArchive == true then
    options[#options + 1] = bind({
      title = prop.active == false and (type(locale) == 'function' and locale('world_props.s_5ae417439bd5') or 'Restaurar prop') or (type(locale) == 'function' and locale('world_props.s_32a66602ae6c') or 'Arquivar prop'),
      description = prop.active == false
        and (type(locale) == 'function' and locale('world_props.s_396175f49519') or 'Volta a transmitir este prop aos jogadores proximos.')
        or (type(locale) == 'function' and locale('world_props.s_72260fe8da54') or 'Retira do mundo sem apagar o historico.'),
      icon = prop.active == false and 'rotate-left' or 'box-archive'
    }, 'setActive', { propId = tonumber(prop.id), active = prop.active == false })
  end
  if CurrentActions.worldPropManage == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('world_props.s_3b8150300ad8') or 'Editar configuracao'),
      description = (type(locale) == 'function' and locale('world_props.s_c8fb937bb21d') or 'Nome, streaming, congelamento, colisao e visibilidade.'),
      icon = 'sliders'
    }, 'edit', { propId = tonumber(prop.id) })
  end
  MZAdminUI.RegisterContext({
    id = DETAIL_ID,
    menu = LIST_ID,
    title = tostring(prop.name),
    subtitle = tostring(prop.code or prop.id),
    options = options
  })
  MZAdminUI.ShowContext(DETAIL_ID)
end

local function openList()
  local data = request('listWorldProps')
  if not data then return end
  ListedProps = {}
  local options = {}
  for _, prop in ipairs(data.props or {}) do
    ListedProps[tonumber(prop.id)] = prop
    local option = {
      title = tostring(prop.name),
      description = ('%s | %s | stream %.0fm'):format(
        tostring(prop.code or ('ID ' .. tostring(prop.id))),
        prop.active == false and (type(locale) == 'function' and locale('world_props.s_1f2f7a28ede1') or 'arquivado') or (type(locale) == 'function' and locale('garage.s_4d53355a2818') or 'ativo'),
        tonumber(prop.stream_distance) or 0
      ),
      icon = prop.active == false and 'box-archive' or 'cube',
      readOnly = CurrentActions.worldPropArchive ~= true and CurrentActions.worldPropManage ~= true
    }
    if not option.readOnly then bind(option, 'details', { propId = tonumber(prop.id) }) end
    options[#options + 1] = option
  end
  if #options == 0 then options[1] = { title = (type(locale) == 'function' and locale('world_props.s_cf4b2153c4f6') or 'Nenhum prop persistente'), icon = 'cube', readOnly = true } end
  MZAdminUI.RegisterContext({
    id = LIST_ID,
    menu = MENU_ID,
    title = (type(locale) == 'function' and locale('world.s_d2cbfda1a6fb') or 'Props persistentes'),
    subtitle = ((type(locale) == 'function' and locale('world_props.s_9ea26ed41966') or '%d cadastrado(s)')):format(#(data.props or {})),
    options = options
  })
  MZAdminUI.ShowContext(LIST_ID)
end

function MZAdminProps.Register(parentId, actions, ready)
  CurrentActions = type(actions) == 'table' and actions or {}
  if ready ~= true then return false end
  local options = {}
  if CurrentActions.worldPropCreate == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('world_props.s_29a026a63a1b') or 'Criar prop com placement'),
      description = (type(locale) == 'function' and locale('world_props.s_9631c98d6a4c') or 'Escolha o modelo e posicione um fantasma diretamente no mundo.'),
      icon = 'cube'
    }, 'create')
  end
  if CurrentActions.worldView == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('world_props.s_8e3351cdac7f') or 'Props cadastrados'),
      description = (type(locale) == 'function' and locale('world_props.s_a491b5b3bcee') or 'Consultar ativos e arquivados.'),
      icon = 'list'
    }, 'list')
  end
  MZAdminUI.RegisterContext({
    id = MENU_ID,
    menu = parentId,
    title = (type(locale) == 'function' and locale('world.s_d2cbfda1a6fb') or 'Props persistentes'),
    subtitle = (type(locale) == 'function' and locale('world_props.s_126d9a8523b6') or 'Placement, streaming e ciclo de vida'),
    options = options
  })
  return true
end

function MZAdminProps.GetMenuId()
  return MENU_ID
end

AddEventHandler(ACTION_EVENT, function(payload)
  local action = type(payload) == 'table' and tostring(payload.action or '') or ''
  if action == 'create' then
    startCreate()
  elseif action == 'list' then
    openList()
  elseif action == 'details' then
    showPropDetails(payload.propId)
  elseif action == 'edit' then
    local prop = ListedProps[tonumber(payload.propId)]
    if not prop then return end
    local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('world_props.s_32b745b34687') or 'Editar prop persistente'), {
      { type = 'input', label = (type(locale) == 'function' and locale('garage.s_6f4b8c6403f4') or 'Nome de exibicao'), required = true, default = tostring(prop.name or '') },
      {
        type = 'number', label = (type(locale) == 'function' and locale('world_props.s_ca8a08b170d5') or 'Distancia de streaming'), required = true,
        default = tonumber(prop.stream_distance) or 120,
        min = MIN_STREAM_DISTANCE, max = MAX_STREAM_DISTANCE,
        description = (type(locale) == 'function' and locale('world_props.s_a5a9116e9ef4') or 'Tambem controla a distancia visual (LOD). Maximo: 2000 metros.')
      },
      { type = 'checkbox', label = (type(locale) == 'function' and locale('world_props.s_2a5813b9f958') or 'Congelado'), checked = prop.frozen == true },
      { type = 'checkbox', label = (type(locale) == 'function' and locale('world_props.s_a4cffe8ef61b') or 'Colisao habilitada'), checked = prop.collision_enabled == true },
      { type = 'checkbox', label = (type(locale) == 'function' and locale('world_props.s_6539f77d95f6') or 'Visivel'), checked = prop.visible == true }
    }, { allowCancel = true })
    if values then
      local data = request('updateWorldProp', prop.id, {
        name = values[1],
        stream_distance = values[2],
        frozen = values[3] == true,
        collision_enabled = values[4] == true,
        visible = values[5] == true
      })
      if data and data.prop then
        ListedProps[tonumber(data.prop.id)] = data.prop
        notify((type(locale) == 'function' and locale('world_props.s_68a937d2f73e') or 'Configuracao do prop atualizada.'), 'success')
        showPropDetails(data.prop.id)
      end
    end
  elseif action == 'setActive' then
    local verb = payload.active == true and (type(locale) == 'function' and locale('world.s_27985c84c2e0') or 'restaurar') or (type(locale) == 'function' and locale('world.s_6675573e1a64') or 'arquivar')
    if MZAdminUI.Confirm(((type(locale) == 'function' and locale('world_props.s_341c646601c2') or 'Deseja %s este prop?')):format(verb), (type(locale) == 'function' and locale('world_props.s_5616a66b7665') or 'O registro permanecera no banco.')) then
      local data = request('setWorldPropActive', payload.propId, payload.active == true)
      if data and data.prop then
        ListedProps[tonumber(data.prop.id)] = data.prop
        notify(data.prop.active == true and (type(locale) == 'function' and locale('world_props.s_5dc0efe00dda') or 'Prop restaurado.') or (type(locale) == 'function' and locale('world_props.s_46e6adf6edbe') or 'Prop arquivado.'), 'success')
        showPropDetails(data.prop.id)
      end
    end
  end
end)

AddEventHandler('mz_world_editor:client:placementResult', function(requestId, placement)
  local draft = PendingPlacement
  if not draft or tostring(requestId) ~= tostring(draft.requestId) then return end
  local summary = ((type(locale) == 'function' and locale('world_props.s_4eea02bdc431') or 'Nome: %s\nCodigo: %s\nModelo: %s\nCoords: %.3f %.3f %.3f\nHeading: %.2f')):format(
    draft.name, draft.code, tostring(draft.modelName or draft.modelHash),
    tonumber(placement.coords.x) or 0,
    tonumber(placement.coords.y) or 0,
    tonumber(placement.coords.z) or 0,
    tonumber(placement.heading) or 0
  )
  if not MZAdminUI.Confirm((type(locale) == 'function' and locale('world_props.s_9e8ecbd1740c') or 'Criar prop persistente?'), summary, {
    labels = { confirm = (type(locale) == 'function' and locale('garage.s_af3d3c69e687') or 'Criar'), cancel = (type(locale) == 'function' and locale('world_props.s_63a77c77e07e') or 'Descartar') }
  }) then
    cancelPending((type(locale) == 'function' and locale('world_props.s_d2bfd117284d') or 'Placement descartado.'))
    MZAdminUI.ShowContext(MENU_ID)
    return
  end
  local data = request('createWorldProp', draft.sessionId, {
    name = draft.name,
    code = draft.code,
    model_hash = placement.model_hash,
    model_name = placement.model_name or draft.modelName,
    coords = placement.coords,
    rotation = placement.rotation,
    heading = placement.heading,
    stream_distance = draft.streamDistance,
    frozen = draft.frozen,
    collision_enabled = draft.collisionEnabled,
    visible = draft.visible
  })
  if data and data.prop then
    notify(((type(locale) == 'function' and locale('world_props.s_168723ce2649') or 'Prop "%s" criado com sucesso.')):format(data.prop.name or draft.name), 'success')
  end
  PendingPlacement = nil
  MZAdminUI.ShowContext(MENU_ID)
end)

AddEventHandler('mz_world_editor:client:placementCancelled', function(requestId)
  if not PendingPlacement or tostring(requestId) ~= tostring(PendingPlacement.requestId) then return end
  cancelPending((type(locale) == 'function' and locale('world_props.s_8ff23d40d6fa') or 'Placement cancelado.'))
  MZAdminUI.ShowContext(MENU_ID)
end)
