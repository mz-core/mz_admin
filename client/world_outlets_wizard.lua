MZAdminChargingOutlets = MZAdminChargingOutlets or {}

local MENU_ID = 'mz_admin:world:charging_outlets'
local LIST_ID = 'mz_admin:world:charging_outlets:list'
local DETAIL_ID = 'mz_admin:world:charging_outlets:detail'
local ACTION_EVENT = 'mz_admin:client:worldChargingOutletAction'
local CurrentActions = {}
local Listed = {}
local Pending

local function notify(message, kind)
  kind = kind or 'inform'
  if GetResourceState('mz_notify') == 'started' then
    local notifyType = kind == 'inform' and 'info' or (kind == 'warn' and 'warning' or kind)
    local ok, result = pcall(function()
      return exports['mz_notify']:Notify({
        type = notifyType,
        title = (type(locale) == 'function' and locale('world.s_26ece3d0d2c1') or 'Tomadas de carregamento'),
        message = tostring(message or ''),
        duration = 4000
      })
    end)
    if ok and result ~= false then return true end
  end
  if type(MZAdminUI) == 'table' then
    return MZAdminUI.Notify(message, kind, 4000, { title = (type(locale) == 'function' and locale('world.s_26ece3d0d2c1') or 'Tomadas de carregamento') })
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
  if #code < 3 then code = 'tomada_' .. tostring(GetGameTimer()) end
  return code:sub(1, 64)
end

local function vector(value)
  value = type(value) == 'table' and value or {}
  return {
    x = tonumber(value.x) or 0.0,
    y = tonumber(value.y) or 0.0,
    z = tonumber(value.z) or 0.0
  }
end

local function closePending(cancelDraft)
  local pending = Pending
  Pending = nil
  if cancelDraft and pending and pending.sessionId then
    lib.callback.await('mz_admin:server:cancelWorldChargingOutletDraft', false, pending.sessionId)
  end
end

local function startPlacement(pending, initial)
  if GetResourceState('mz_world_editor') ~= 'started' then
    notify((type(locale) == 'function' and locale('world.s_c7e1821b9acb') or 'mz_world_editor nao esta iniciado.'), 'error')
    if pending.sessionId then
      lib.callback.await('mz_admin:server:cancelWorldChargingOutletDraft', false, pending.sessionId)
    end
    return false
  end
  Pending = pending
  MZAdminUI.CloseContext()
  local ok, err = exports['mz_world_editor']:StartPropPlacement({
    requestId = pending.requestId,
    title = pending.mode == 'create' and (type(locale) == 'function' and locale('world_outlets.s_c20e3dadcda6') or 'Posicionar tomada customizada') or (type(locale) == 'function' and locale('world_outlets.s_e862cfeb159e') or 'Reposicionar tomada customizada'),
    modelHash = GetHashKey(pending.chargerModel),
    modelName = pending.chargerModel,
    initialCoords = initial and initial.coords or nil,
    initialRotation = initial and initial.rotation or nil,
    initialSurfaceNormal = initial and initial.surfaceNormal or nil,
    fullRotation = true,
    surfaceSnap = true,
    surfaceOffset = tonumber(pending.surfaceOffset) or 0.015
  })
  if ok ~= true then
    closePending(true)
    notify(((type(locale) == 'function' and locale('world_props.s_d26ece520ac4') or 'Nao foi possivel iniciar o placement: %s')):format(tostring(err)), 'error')
    MZAdminUI.ShowContext(MENU_ID)
    return false
  end
  return true
end

local function startCreate()
  local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('world_outlets.s_54fca668ec1b') or 'Nova tomada customizada'), {
    { type = 'input', label = (type(locale) == 'function' and locale('router.s_13030dd962f4') or 'Nome'), required = true, placeholder = (type(locale) == 'function' and locale('world_outlets.s_4bc48a3fc1a8') or 'Tomada - Recepcao') },
    { type = 'input', label = (type(locale) == 'function' and locale('garage.s_ba53a1f3589a') or 'Codigo estrutural'), required = false, placeholder = 'recepcao_01' },
    {
      type = 'number', label = (type(locale) == 'function' and locale('world.s_5f5f25b01c07') or 'Distancia de interacao'), required = true,
      default = 1.8, min = 0.5, max = 4.0
    }
  }, { allowCancel = true })
  if not values then return end
  local label = tostring(values[1] or '')
  local session = request('beginWorldChargingOutletDraft')
  if not session or not session.sessionId then return end
  startPlacement({
    mode = 'create',
    requestId = ('mz_admin:charging_outlet:%s'):format(GetGameTimer()),
    sessionId = session.sessionId,
    chargerModel = tostring(session.chargerModel or 'mz_phone_charger'),
    surfaceOffset = tonumber(session.surfaceOffset) or 0.015,
    label = label,
    code = tostring(values[2] or '') ~= '' and tostring(values[2]) or suggestedCode(label),
    interactionDistance = tonumber(values[3]) or 1.8
  })
end

local function showDetails(outletId)
  local outlet = Listed[tostring(outletId)]
  if not outlet then return end
  local position = vector(outlet.position)
  local options = {
    {
      title = outlet.enabled == false and (type(locale) == 'function' and locale('garage.s_692ec2b46d82') or 'Arquivada') or (type(locale) == 'function' and locale('garage.s_f21c4ff2bbb3') or 'Ativa'),
      description = ('%s | %.3f, %.3f, %.3f'):format(tostring(outlet.code), position.x, position.y, position.z),
      icon = outlet.enabled == false and 'box-archive' or 'plug',
      readOnly = true
    }
  }
  if CurrentActions.worldPropManage == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('world_outlets.s_f41efd5b4a81') or 'Editar nome e distancia'),
      description = ((type(locale) == 'function' and locale('world_outlets.s_62159c88f694') or 'Interacao atual: %.2fm')):format(tonumber(outlet.interactionDistance) or 1.8),
      icon = 'sliders'
    }, 'edit', { outletId = tostring(outlet.id) })
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('world_outlets.s_08aee04d1d7c') or 'Reposicionar no mundo'),
      description = (type(locale) == 'function' and locale('world_outlets.s_1c4c8b0b2c97') or 'Abre o placement com snap em superficie e rotacao XYZ.'),
      icon = 'location-crosshairs'
    }, 'move', { outletId = tostring(outlet.id) })
  end
  if CurrentActions.worldPropArchive == true then
    options[#options + 1] = bind({
      title = outlet.enabled == false and (type(locale) == 'function' and locale('world_outlets.s_13ab9a24e81a') or 'Restaurar tomada') or (type(locale) == 'function' and locale('world_outlets.s_c13721d05d6c') or 'Arquivar tomada'),
      description = (type(locale) == 'function' and locale('world_outlets.s_7a6d982bd9b3') or 'O registro e o historico permanecem no banco.'),
      icon = outlet.enabled == false and 'rotate-left' or 'box-archive'
    }, 'setEnabled', { outletId = tostring(outlet.id), enabled = outlet.enabled == false })
  end
  MZAdminUI.RegisterContext({
    id = DETAIL_ID,
    menu = LIST_ID,
    title = tostring(outlet.label),
    subtitle = tostring(outlet.code),
    options = options
  })
  MZAdminUI.ShowContext(DETAIL_ID)
end

local function openList()
  local data = request('listWorldChargingOutlets')
  if not data then return end
  Listed = {}
  local options = {}
  for _, outlet in ipairs(data.outlets or {}) do
    Listed[tostring(outlet.id)] = outlet
    local position = vector(outlet.position)
    local option = {
      title = tostring(outlet.label),
      description = ('%s | %s | %.2fm | %.1f %.1f %.1f'):format(
        tostring(outlet.code), outlet.enabled == false and (type(locale) == 'function' and locale('garage.s_e46e99168ad6') or 'arquivada') or (type(locale) == 'function' and locale('garage.s_1b9e540e4a17') or 'ativa'),
        tonumber(outlet.interactionDistance) or 1.8, position.x, position.y, position.z
      ),
      icon = outlet.enabled == false and 'box-archive' or 'plug',
      readOnly = CurrentActions.worldPropManage ~= true and CurrentActions.worldPropArchive ~= true
    }
    if not option.readOnly then bind(option, 'details', { outletId = tostring(outlet.id) }) end
    options[#options + 1] = option
  end
  if #options == 0 then
    options[1] = { title = (type(locale) == 'function' and locale('world_outlets.s_f54e1cc23578') or 'Nenhuma tomada customizada'), icon = 'plug', readOnly = true }
  end
  MZAdminUI.RegisterContext({
    id = LIST_ID,
    menu = MENU_ID,
    title = (type(locale) == 'function' and locale('world_outlets.s_8e4bb05fb9a5') or 'Tomadas customizadas'),
    subtitle = ((type(locale) == 'function' and locale('garage.s_4abb390912f0') or '%d cadastrada(s)')):format(#(data.outlets or {})),
    options = options
  })
  MZAdminUI.ShowContext(LIST_ID)
end

function MZAdminChargingOutlets.Register(parentId, actions, ready)
  CurrentActions = type(actions) == 'table' and actions or {}
  if ready ~= true then return false end
  local options = {}
  if CurrentActions.worldPropCreate == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('world_outlets.s_cbb60c82ba0e') or 'Criar tomada customizada'),
      description = (type(locale) == 'function' and locale('world_outlets.s_ea38f70e622c') or 'Ancora invisivel para paredes e tomadas incorporadas ao MLO.'),
      icon = 'plug-circle-plus'
    }, 'create')
  end
  if CurrentActions.worldView == true or CurrentActions.worldPropManage == true
    or CurrentActions.worldPropArchive == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('world_outlets.s_de3b81b59e19') or 'Tomadas cadastradas'),
      description = (type(locale) == 'function' and locale('world_outlets.s_8e91a90fb220') or 'Consultar, reposicionar, arquivar e restaurar.'),
      icon = 'list'
    }, 'list')
  end
  MZAdminUI.RegisterContext({
    id = MENU_ID,
    menu = parentId,
    title = (type(locale) == 'function' and locale('world.s_26ece3d0d2c1') or 'Tomadas de carregamento'),
    subtitle = (type(locale) == 'function' and locale('world_outlets.s_204a93e2f3c6') or 'Fallback persistente para interiores e MLOs'),
    options = options
  })
  return true
end

function MZAdminChargingOutlets.GetMenuId()
  return MENU_ID
end

AddEventHandler(ACTION_EVENT, function(payload)
  local action = type(payload) == 'table' and tostring(payload.action or '') or ''
  if action == 'create' then
    startCreate()
  elseif action == 'list' then
    openList()
  elseif action == 'details' then
    showDetails(payload.outletId)
  elseif action == 'edit' then
    local outlet = Listed[tostring(payload.outletId)]
    if not outlet then return end
    local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('world_outlets.s_16aedf6e57c4') or 'Editar tomada customizada'), {
      { type = 'input', label = (type(locale) == 'function' and locale('router.s_13030dd962f4') or 'Nome'), required = true, default = tostring(outlet.label or '') },
      {
        type = 'number', label = (type(locale) == 'function' and locale('world.s_5f5f25b01c07') or 'Distancia de interacao'), required = true,
        default = tonumber(outlet.interactionDistance) or 1.8, min = 0.5, max = 4.0
      }
    }, { allowCancel = true })
    if not values then return showDetails(outlet.id) end
    local data = request('updateWorldChargingOutlet', outlet.id, {
      label = tostring(values[1] or ''),
      interactionDistance = tonumber(values[2])
    })
    if data and data.outlet then
      Listed[tostring(data.outlet.id)] = data.outlet
      notify((type(locale) == 'function' and locale('world_outlets.s_39e9cd38c8a6') or 'Tomada atualizada.'), 'success')
      showDetails(data.outlet.id)
    end
  elseif action == 'move' then
    local outlet = Listed[tostring(payload.outletId)]
    if not outlet then return end
    local settings = request('getWorldChargingOutletEditorSettings')
    if not settings then return end
    startPlacement({
      mode = 'move',
      requestId = ('mz_admin:charging_outlet_move:%s'):format(GetGameTimer()),
      outletId = tostring(outlet.id),
      chargerModel = tostring(settings.chargerModel or 'mz_phone_charger'),
      surfaceOffset = tonumber(settings.surfaceOffset) or 0.015,
      label = outlet.label,
      interactionDistance = outlet.interactionDistance
    }, {
      coords = outlet.position,
      rotation = outlet.rotation,
      surfaceNormal = outlet.surfaceNormal
    })
  elseif action == 'setEnabled' then
    local verb = payload.enabled == true and (type(locale) == 'function' and locale('world.s_27985c84c2e0') or 'restaurar') or (type(locale) == 'function' and locale('world.s_6675573e1a64') or 'arquivar')
    if MZAdminUI.Confirm(((type(locale) == 'function' and locale('world_outlets.s_16ae481bba80') or 'Deseja %s esta tomada?')):format(verb), (type(locale) == 'function' and locale('world_props.s_5616a66b7665') or 'O registro permanecera no banco.')) then
      local data = request('setWorldChargingOutletEnabled', payload.outletId, payload.enabled == true)
      if data and data.outlet then
        Listed[tostring(data.outlet.id)] = data.outlet
        notify(data.outlet.enabled == true and (type(locale) == 'function' and locale('world_outlets.s_15324f5ae56b') or 'Tomada restaurada.') or (type(locale) == 'function' and locale('world_outlets.s_674d4ce91fe0') or 'Tomada arquivada.'), 'success')
        showDetails(data.outlet.id)
      end
    end
  end
end)

AddEventHandler('mz_world_editor:client:placementResult', function(requestId, placement)
  local pending = Pending
  if not pending or tostring(requestId) ~= tostring(pending.requestId) then return end
  local summary = ((type(locale) == 'function' and locale('world_outlets.s_f06ca5fed61f') or 'Nome: %s\nCoords: %.3f %.3f %.3f\nRotacao: %.2f %.2f %.2f')):format(
    tostring(pending.label),
    tonumber(placement.coords.x) or 0, tonumber(placement.coords.y) or 0, tonumber(placement.coords.z) or 0,
    tonumber(placement.rotation.x) or 0, tonumber(placement.rotation.y) or 0, tonumber(placement.rotation.z) or 0
  )
  if not MZAdminUI.Confirm((type(locale) == 'function' and locale('world_outlets.s_48fd3657088d') or 'Salvar tomada customizada?'), summary, {
    labels = { confirm = (type(locale) == 'function' and locale('garage.s_93bf2d32ec33') or 'Salvar'), cancel = (type(locale) == 'function' and locale('world_props.s_63a77c77e07e') or 'Descartar') }
  }) then
    closePending(true)
    MZAdminUI.ShowContext(MENU_ID)
    return
  end
  local payload = {
    label = pending.label,
    position = placement.coords,
    rotation = placement.rotation,
    surfaceNormal = placement.surfaceNormal,
    interactionDistance = pending.interactionDistance
  }
  local data
  if pending.mode == 'create' then
    payload.code = pending.code
    data = request('createWorldChargingOutlet', pending.sessionId, payload)
  else
    data = request('updateWorldChargingOutlet', pending.outletId, payload)
  end
  closePending(data == nil and pending.mode == 'create')
  if data and data.outlet then
    Listed[tostring(data.outlet.id)] = data.outlet
    notify(pending.mode == 'create' and (type(locale) == 'function' and locale('world_outlets.s_6e9e6f227b89') or 'Tomada criada.') or (type(locale) == 'function' and locale('world_outlets.s_3ff591504d80') or 'Tomada reposicionada.'), 'success')
  end
  MZAdminUI.ShowContext(MENU_ID)
end)

AddEventHandler('mz_world_editor:client:placementCancelled', function(requestId)
  if not Pending or tostring(requestId) ~= tostring(Pending.requestId) then return end
  closePending(true)
  notify((type(locale) == 'function' and locale('world_props.s_8ff23d40d6fa') or 'Placement cancelado.'), 'info')
  MZAdminUI.ShowContext(MENU_ID)
end)

AddEventHandler('onClientResourceStop', function(resource)
  if resource == GetCurrentResourceName() and Pending
    and GetResourceState('mz_world_editor') == 'started' then
    pcall(function()
      exports['mz_world_editor']:CancelActiveSession('mz_admin_resource_stopped')
    end)
    Pending = nil
    return
  end
  if resource ~= 'mz_world_editor' or not Pending then return end
  closePending(true)
  notify((type(locale) == 'function' and locale('world_outlets.s_9e051468756d') or 'Placement cancelado porque o editor foi encerrado.'), 'warn')
end)
