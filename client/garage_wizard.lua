MZAdminGarageWizard = MZAdminGarageWizard or {}

local GARAGE_ID = 'mz_admin:garages'
local DRAFT_ID = 'mz_admin:garages:draft'
local LIST_ID = 'mz_admin:garages:list'
local WIZARD_EVENT = 'mz_admin:client:garageWizardAction'
local Draft
local PlacementActive = false
local PlacementLocked = false
local PlacementFrozenEntity
local PlacementEntityWasFrozen = false
local CurrentActions = {}
local CurrentParentId = 'mz_admin:section:vehicles'
local ManagedRowsByCode = {}

local CATEGORY_OPTIONS = {
  { value = 'car', label = 'Carros' },
  { value = 'bike', label = 'Motos' },
  { value = 'car_bike', label = 'Carros e motos' },
  { value = 'boat', label = 'Barcos' },
  { value = 'plane', label = 'Aeronaves' }
}

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function notify(message, kind)
  MZAdminUI.Notify(message, kind or 'inform')
end

local function binding(action, args)
  args = type(args) == 'table' and args or {}
  args.action = action
  return { event = WIZARD_EVENT, args = args }
end

local function withBinding(option, action, args)
  local event = binding(action, args)
  option.event = event.event
  option.args = event.args
  return option
end

local function coordinate(entity, withHeading)
  local coords = GetEntityCoords(entity)
  local out = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
  if withHeading then out.w = GetEntityHeading(entity) + 0.0 end
  return out
end

local function formatCoordinate(value, heading)
  if type(value) ~= 'table' then return 'nao capturado' end
  local base = ('%.2f, %.2f, %.2f'):format(value.x or 0, value.y or 0, value.z or 0)
  return heading and (base .. (' | h %.1f'):format(value.w or 0)) or base
end

local function input(title, rows, confirmLabel)
  return MZAdminUI.InputDialog(title, rows, {
    allowCancel = true,
    labels = { confirm = confirmLabel or 'Continuar', cancel = 'Cancelar' }
  })
end

local function confirmOverwrite()
  if not Draft then return true end
  return MZAdminUI.Confirm(
    'Substituir rascunho?',
    ('O rascunho atual de "%s" sera descartado.'):format(Draft.label or Draft.code or 'garagem'),
    { labels = { confirm = 'Substituir', cancel = 'Manter' } }
  )
end

local function identityStep(kind, step)
  local values = input(
    ('Nova garagem %s - %s'):format(kind == 'public' and 'publica' or 'organizacional', step or '1/2'),
    {
      {
        type = 'input',
        label = 'Codigo estrutural',
        required = true,
        placeholder = kind == 'public' and 'praca_central' or 'mafia_sede',
        description = 'Unico, em minusculas; aceita letras, numeros, _ e -.'
      },
      {
        type = 'input',
        label = 'Nome de exibicao',
        required = false,
        placeholder = kind == 'public' and 'Garagem Pública' or 'Garagem - nome da organizacao',
        description = 'Opcional. Vazio usa o nome padrao tambem no blip.'
      }
    },
    'Proximo'
  )
  if type(values) ~= 'table' then return nil end
  return { code = trim(values[1]):lower(), label = trim(values[2]) }
end

local function startPublic()
  if not confirmOverwrite() then return end
  local identity = identityStep('public', '1/2')
  if not identity then return end
  local settings = input('Garagem publica - 2/2', {
    {
      type = 'select', label = 'Veiculos aceitos', required = true,
      default = 'car', options = CATEGORY_OPTIONS
    },
    {
      type = 'select', label = 'Vinculo das vagas', required = true, default = 'strict',
      options = {
        { value = 'strict', label = 'Somente esta garagem' },
        { value = 'shared', label = 'Pool publico compartilhado' }
      },
      description = 'No modo estrito, o veiculo volta somente para esta garagem.'
    },
    { type = 'checkbox', label = 'Exibir blip no mapa', checked = true },
    { type = 'checkbox', label = 'Permitir retirada de apreendidos', checked = true }
  }, 'Criar rascunho')
  if type(settings) ~= 'table' then return end

  Draft = {
    code = identity.code,
    label = identity.label,
    kind = 'public',
    settings = {
      categoryMode = settings[1],
      strictGarage = settings[2] == 'strict',
      blipEnabled = settings[3] == true,
      allowImpounded = settings[4] == true
    }
  }
  MZAdminGarageWizard.ShowDraft()
end

local function startOrganization()
  if not confirmOverwrite() then return end
  local organizations = MZAdminClient.ListGarageOrganizations()
  if not organizations then return end
  if #organizations == 0 then
    notify('Nenhuma organizacao ativa foi encontrada.', 'error')
    return
  end

  local orgOptions = {}
  for _, org in ipairs(organizations) do
    orgOptions[#orgOptions + 1] = {
      value = org.code,
      label = ('%s [%s]'):format(org.name or org.code, org.type or '')
    }
  end

  local selected = input('Garagem organizacional - 1/3', {
    {
      type = 'select', label = 'Organizacao', required = true,
      options = orgOptions, default = orgOptions[1].value
    }
  }, 'Proximo')
  if type(selected) ~= 'table' then return end

  local identity = identityStep('org', '2/3')
  if not identity then return end
  local access = input('Garagem organizacional - 3/3', {
    {
      type = 'select', label = 'Veiculos aceitos', required = true,
      default = 'car', options = CATEGORY_OPTIONS
    },
    {
      type = 'select', label = 'Vinculo das vagas', required = true, default = 'strict',
      options = {
        { value = 'strict', label = 'Somente esta garagem' },
        { value = 'shared', label = 'Pool da organizacao' }
      }
    },
    { type = 'checkbox', label = 'Exigir duty ativo', checked = false },
    { type = 'checkbox', label = 'Exigir organizacao primaria', checked = false },
    {
      type = 'number', label = 'Nivel minimo do cargo', required = true,
      default = 0, min = 0, max = 1000
    },
    { type = 'checkbox', label = 'Exibir blip no mapa', checked = false }
  }, 'Criar rascunho')
  if type(access) ~= 'table' then return end

  Draft = {
    code = identity.code,
    label = identity.label,
    kind = 'org',
    orgCode = trim(selected[1]):lower(),
    settings = {
      categoryMode = access[1],
      strictGarage = access[2] == 'strict',
      requireDuty = access[3] == true,
      primaryOnly = access[4] == true,
      minGradeLevel = tonumber(access[5]) or 0,
      blipEnabled = access[6] == true,
      allowImpounded = false
    }
  }
  MZAdminGarageWizard.ShowDraft()
end

local function capturePoint(point)
  if not Draft then return false end
  local ped = PlayerPedId()
  if point == 'entry' then
    Draft.entry = coordinate(ped, false)
  elseif point == 'spawn' then
    local vehicle = GetVehiclePedIsIn(ped, false)
    Draft.spawn = coordinate(vehicle ~= 0 and vehicle or ped, true)
  elseif point == 'store' then
    Draft.store = coordinate(ped, false)
  else
    return false
  end
  return true
end

local PLACEMENT_LABELS = {
  entry = 'entrada da garagem',
  spawn = 'ponto de spawn',
  store = 'ponto de armazenamento'
}

local function hidePlacementHelp()
  if lib and type(lib.hideTextUI) == 'function' then
    pcall(lib.hideTextUI)
  end
end

local function setPlacementLocked(enabled, silent)
  enabled = enabled == true

  if not enabled then
    if PlacementFrozenEntity
      and DoesEntityExist(PlacementFrozenEntity)
      and PlacementEntityWasFrozen ~= true then
      FreezeEntityPosition(PlacementFrozenEntity, false)
    end
    local wasLocked = PlacementLocked
    PlacementLocked = false
    PlacementFrozenEntity = nil
    PlacementEntityWasFrozen = false
    if wasLocked and silent ~= true then notify('Movimento destravado.', 'inform') end
    return true
  end

  if PlacementLocked then return true end
  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)
  local entity = ped
  if vehicle ~= 0 then
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
      if silent ~= true then
        notify('Para travar um veiculo, ocupe o banco do motorista.', 'error')
      end
      return false
    end
    entity = vehicle
  end
  if not entity or entity == 0 or not DoesEntityExist(entity) then
    if silent ~= true then notify('Entidade de posicionamento indisponivel.', 'error') end
    return false
  end

  PlacementEntityWasFrozen = type(IsEntityPositionFrozen) == 'function'
    and IsEntityPositionFrozen(entity) == true
    or false
  FreezeEntityPosition(entity, true)
  PlacementLocked = true
  PlacementFrozenEntity = entity
  if silent ~= true then
    notify(vehicle ~= 0 and 'Veiculo travado para posicionamento.' or 'Movimento travado para posicionamento.', 'success')
  end
  return true
end

local function showPlacementHelp(point, current, total)
  local label = PLACEMENT_LABELS[point] or point
  local vehicleHint = point == 'spawn' and ' Entre em um veiculo para usar sua posicao e heading.' or ''
  local lockHint = PlacementLocked and '[G] Destravar movimento' or '[G] Travar movimento'
  if lib and type(lib.showTextUI) == 'function' then
    pcall(lib.showTextUI, (
      '[E] Capturar %s (%d/%d)  |  %s  |  [X] Cancelar.%s'
    ):format(label, current, total, lockHint, vehicleHint), {
      position = 'right-center',
      icon = point == 'spawn' and 'car-side' or 'location-dot'
    })
  end
end

local function startPlacement(points)
  if PlacementActive or not Draft or type(points) ~= 'table' or #points == 0 then return end
  setPlacementLocked(false, true)
  PlacementActive = true
  MZAdminUI.CloseContext()

  CreateThread(function()
    local index = 1
    local cancelled = false
    showPlacementHelp(points[index], index, #points)

    while PlacementActive and Draft and index <= #points do
      if IsControlJustReleased(0, 73) then
        cancelled = true
        break
      end

      if IsControlJustReleased(0, 47) then
        if setPlacementLocked(not PlacementLocked) then
          showPlacementHelp(points[index], index, #points)
        end
        Wait(200)
      end

      if IsControlJustReleased(0, 38) then
        local point = points[index]
        if capturePoint(point) then
          setPlacementLocked(false, true)
          notify(('%s capturado.'):format(PLACEMENT_LABELS[point] or point), 'success')
          index = index + 1
          if index <= #points then
            showPlacementHelp(points[index], index, #points)
          end
          Wait(250)
        end
      end

      Wait(0)
    end

    setPlacementLocked(false, true)
    PlacementActive = false
    hidePlacementHelp()
    if cancelled then notify('Posicionamento cancelado; capturas anteriores foram mantidas.', 'warning') end
    if Draft then
      Wait(100)
      MZAdminGarageWizard.ShowDraft()
    end
  end)
end

local ERROR_MESSAGES = {
  invalid_code = 'Codigo invalido ou fora do padrao.',
  invalid_label = 'Nome de exibicao invalido.',
  invalid_coordinates = 'Uma das coordenadas capturadas e invalida.',
  coordinates_too_far = 'Os pontos devem ficar a no maximo 250 metros da entrada.',
  invalid_org = 'A organizacao nao existe mais.',
  org_archived = 'A organizacao foi arquivada.',
  garage_code_exists = 'Ja existe uma garagem com este codigo.',
  garage_code_immutable = 'O codigo estrutural nao pode ser alterado.',
  garage_kind_immutable = 'O tipo da garagem nao pode ser alterado.',
  garage_org_immutable = 'A organizacao vinculada nao pode ser alterada.',
  garage_not_found = 'A garagem nao existe mais.',
  managed_repository_unavailable = 'O repositorio persistente de garagens esta indisponivel.',
  permission_denied = 'Sua permissao para criar garagens foi revogada.',
  database_error = 'O banco recusou a criacao da garagem.'
}

local function draftLabel(draft)
  if trim(draft and draft.label) ~= '' then return trim(draft.label) end
  return draft and draft.kind == 'org' and 'Nome padrao da organizacao' or 'Garagem Pública'
end

local function editManagedGarage(row)
  if CurrentActions.garageManage ~= true or type(row) ~= 'table' then return end
  local settings = type(row.settings) == 'table' and row.settings or {}
  local rows = {
    {
      type = 'input',
      label = 'Nome de exibicao',
      required = false,
      default = row.label,
      description = 'Pode ficar vazio para restaurar o nome padrao.'
    },
    {
      type = 'select', label = 'Veiculos aceitos', required = true,
      default = settings.categoryMode or 'car', options = CATEGORY_OPTIONS
    },
    {
      type = 'select', label = 'Vinculo das vagas', required = true,
      default = settings.strictGarage == true and 'strict' or 'shared',
      options = {
        { value = 'strict', label = 'Somente esta garagem' },
        { value = 'shared', label = row.kind == 'org' and 'Pool da organizacao' or 'Pool publico compartilhado' }
      }
    },
    { type = 'checkbox', label = 'Exibir blip no mapa', checked = settings.blipEnabled == true }
  }
  if row.kind == 'public' then
    rows[#rows + 1] = {
      type = 'checkbox', label = 'Permitir retirada de apreendidos',
      checked = settings.allowImpounded == true
    }
  else
    rows[#rows + 1] = { type = 'checkbox', label = 'Exigir duty ativo', checked = settings.requireDuty == true }
    rows[#rows + 1] = { type = 'checkbox', label = 'Exigir organizacao primaria', checked = settings.primaryOnly == true }
    rows[#rows + 1] = {
      type = 'number', label = 'Nivel minimo do cargo', required = true,
      default = tonumber(settings.minGradeLevel) or 0, min = 0, max = 1000
    }
  end

  local values = input(('Editar %s'):format(row.code), rows, 'Abrir rascunho')
  if type(values) ~= 'table' then return end
  local nextSettings = {
    categoryMode = values[2],
    strictGarage = values[3] == 'strict',
    blipEnabled = values[4] == true,
    allowImpounded = row.kind == 'public' and values[5] == true or false
  }
  if row.kind == 'org' then
    nextSettings.requireDuty = values[5] == true
    nextSettings.primaryOnly = values[6] == true
    nextSettings.minGradeLevel = tonumber(values[7]) or 0
  end

  Draft = {
    operation = 'edit',
    originalCode = row.code,
    code = row.code,
    label = trim(values[1]),
    kind = row.kind,
    orgCode = row.orgCode,
    entry = row.entry,
    spawn = row.spawn,
    store = row.store,
    settings = nextSettings
  }
  MZAdminGarageWizard.ShowDraft()
end

local function openManagedList()
  if CurrentActions.garageView ~= true then return false end
  local garages = MZAdminClient.ListManagedGarages()
  if not garages then return false end

  ManagedRowsByCode = {}
  local options = {}
  for _, garage in ipairs(garages) do
    if type(garage) == 'table' and trim(garage.code) ~= '' then
      ManagedRowsByCode[garage.code] = garage
      options[#options + 1] = withBinding({
        title = garage.label,
        description = ('%s | %s | %s'):format(
          garage.code,
          garage.kind == 'org' and ('org: ' .. tostring(garage.orgCode or '-')) or 'publica',
          garage.active == true and 'ativa' or 'arquivada'
        ),
        icon = garage.active == true and 'warehouse' or 'box-archive',
        arrow = true
      }, 'managedDetails', { code = garage.code })
    end
  end
  if #options == 0 then
    options[1] = {
      title = 'Nenhuma garagem persistente',
      description = 'As garagens estaticas continuam fora desta lista.',
      icon = 'warehouse',
      readOnly = true
    }
  end

  MZAdminUI.RegisterContext({
    id = LIST_ID,
    menu = GARAGE_ID,
    title = 'Garagens persistentes',
    subtitle = ('%d cadastrada(s)'):format(#garages),
    options = options
  })
  return MZAdminUI.ShowContext(LIST_ID)
end

local function showManagedDetails(code)
  local row = ManagedRowsByCode[tostring(code or '')]
  if type(row) ~= 'table' then return openManagedList() end
  local settings = type(row.settings) == 'table' and row.settings or {}
  local options = {
    { title = 'Codigo estrutural', description = row.code, icon = 'fingerprint', readOnly = true },
    {
      title = 'Tipo e vinculo',
      description = row.kind == 'org' and ('Organizacao: ' .. tostring(row.orgCode or '-')) or 'Garagem publica',
      icon = 'link',
      readOnly = true
    },
    {
      title = 'Regras',
      description = ('%s | %s | blip %s'):format(
        tostring(settings.categoryMode or 'car'),
        settings.strictGarage == true and 'estrita' or 'compartilhada',
        settings.blipEnabled == true and 'ativo' or 'inativo'
      ),
      icon = 'sliders',
      readOnly = true
    },
    { title = 'Entrada', description = formatCoordinate(row.entry), icon = 'door-open', readOnly = true },
    { title = 'Spawn', description = formatCoordinate(row.spawn, true), icon = 'car-side', readOnly = true },
    { title = 'Armazenamento', description = formatCoordinate(row.store), icon = 'square-parking', readOnly = true }
  }

  if CurrentActions.garageManage == true then
    options[#options + 1] = withBinding({
      title = 'Editar configuracao e pontos',
      description = 'Codigo, tipo e organizacao permanecem protegidos.',
      icon = 'pen-to-square'
    }, 'managedEdit', { code = row.code })
    options[#options + 1] = withBinding({
      title = row.active == true and 'Arquivar garagem' or 'Ativar garagem',
      description = row.active == true
        and 'Remove os pontos do runtime sem excluir o cadastro.'
        or 'Revalida a definicao e devolve os pontos ao runtime.',
      icon = row.active == true and 'box-archive' or 'circle-check'
    }, 'managedState', { code = row.code, active = row.active ~= true })
  end

  local contextId = ('mz_admin:garages:managed:%s'):format(row.code)
  MZAdminUI.RegisterContext({
    id = contextId,
    menu = LIST_ID,
    title = row.label,
    subtitle = row.active == true and 'Ativa' or 'Arquivada',
    options = options
  })
  return MZAdminUI.ShowContext(contextId)
end

local function changeManagedState(code, active)
  local row = ManagedRowsByCode[tostring(code or '')]
  if type(row) ~= 'table' or type(active) ~= 'boolean' then return end
  local action = active and 'Ativar' or 'Arquivar'
  if not MZAdminUI.Confirm(
    action .. ' garagem?',
    ('%s\nCodigo: %s\nNenhum cadastro sera excluido.'):format(row.label, row.code),
    { labels = { confirm = action, cancel = 'Cancelar' } }
  ) then return end
  local changed, err = MZAdminClient.SetManagedGarageActive(row.code, active)
  if not changed then
    notify(ERROR_MESSAGES[err] or ('Operacao recusada: ' .. tostring(err)), 'error')
    return
  end
  notify(active and 'Garagem ativada e sincronizada.' or 'Garagem arquivada e removida do runtime.', 'success')
  openManagedList()
end

local function draftPayload(draft)
  return {
    code = draft.code,
    label = draft.label,
    kind = draft.kind,
    orgCode = draft.orgCode,
    entry = draft.entry,
    spawn = draft.spawn,
    store = draft.store,
    settings = draft.settings
  }
end

local function submit()
  if not Draft or not Draft.entry or not Draft.spawn or not Draft.store then
    notify('Capture entrada, spawn e armazenamento antes de concluir.', 'error')
    return
  end

  local editing = Draft.operation == 'edit'
  local summary = ('Codigo: %s\nNome: %s\nTipo: %s%s\nEntrada: %s\nSpawn: %s\nArmazenamento: %s'):format(
    Draft.code,
    draftLabel(Draft),
    Draft.kind == 'public' and 'publica' or 'organizacional',
    Draft.orgCode and ('\nOrganizacao: ' .. Draft.orgCode) or '',
    formatCoordinate(Draft.entry),
    formatCoordinate(Draft.spawn, true),
    formatCoordinate(Draft.store)
  )
  if not MZAdminUI.Confirm(editing and 'Salvar garagem?' or 'Criar garagem persistente?', summary, {
    labels = { confirm = editing and 'Salvar' or 'Criar', cancel = 'Revisar' }
  }) then return end

  local saved, err
  if editing then
    saved, err = MZAdminClient.UpdateManagedGarage(Draft.originalCode, draftPayload(Draft))
  else
    saved, err = MZAdminClient.CreateManagedGarage(draftPayload(Draft))
  end
  if not saved then
    notify(ERROR_MESSAGES[err] or ('Operacao recusada: ' .. tostring(err or 'erro desconhecido')), 'error')
    return
  end

  local label = saved.label or draftLabel(Draft)
  Draft = nil
  notify(('Garagem "%s" %s e sincronizada.'):format(label, editing and 'atualizada' or 'criada'), 'success')
  MZAdminGarageWizard.Register(nil, CurrentActions)
  if editing and CurrentActions.garageView == true then openManagedList() else MZAdminUI.ShowContext(GARAGE_ID) end
end

function MZAdminGarageWizard.ShowDraft()
  if not Draft then return false end
  local complete = Draft.entry and Draft.spawn and Draft.store
  local options = {
    withBinding({
      title = 'Posicionar todos os pontos',
      description = 'Ande ou dirija; G trava/destrava e E captura cada ponto em sequencia.',
      icon = 'route'
    }, 'placementAll'),
    withBinding({
      title = Draft.entry and 'Reposicionar entrada' or 'Posicionar entrada',
      description = formatCoordinate(Draft.entry) .. ' | G trava, E captura e o menu volta',
      icon = 'door-open'
    }, 'placementOne', { point = 'entry' }),
    withBinding({
      title = Draft.spawn and 'Reposicionar spawn' or 'Posicionar spawn',
      description = formatCoordinate(Draft.spawn, true) .. ' | dirija, use G para travar e E para capturar',
      icon = 'car-side'
    }, 'placementOne', { point = 'spawn' }),
    withBinding({
      title = Draft.store and 'Reposicionar armazenamento' or 'Posicionar armazenamento',
      description = formatCoordinate(Draft.store) .. ' | G trava, E captura e o menu volta',
      icon = 'square-parking'
    }, 'placementOne', { point = 'store' })
  }

  if complete then
    options[#options + 1] = withBinding({
      title = Draft.operation == 'edit' and 'Revisar e salvar' or 'Revisar e criar',
      description = 'O servidor revalidara permissao, organizacao, codigo e coordenadas.',
      icon = 'floppy-disk'
    }, 'submit')
  else
    options[#options + 1] = {
      title = 'Criacao ainda incompleta',
      description = 'Os tres pontos sao obrigatorios.',
      icon = 'triangle-exclamation',
      readOnly = true,
      disabled = true
    }
  end

  MZAdminUI.RegisterContext({
    id = DRAFT_ID,
    menu = GARAGE_ID,
    title = draftLabel(Draft),
    subtitle = ('%s | %s'):format(Draft.kind, Draft.orgCode or 'publica'),
    options = options
  })
  return MZAdminUI.ShowContext(DRAFT_ID)
end

function MZAdminGarageWizard.Register(parentId, actions)
  CurrentActions = type(actions) == 'table' and actions or CurrentActions
  parentId = trim(parentId)
  if parentId ~= '' then CurrentParentId = parentId end
  local options = {}
  if CurrentActions.garageCreate == true then
    options[#options + 1] = withBinding({
      title = 'Criar garagem publica',
      description = 'Assistente em etapas com pontos de entrada, spawn e armazenamento.',
      icon = 'square-parking'
    }, 'startPublic')
    options[#options + 1] = withBinding({
      title = 'Criar garagem de organizacao',
      description = 'Seleciona uma organizacao ativa e configura regras de acesso.',
      icon = 'warehouse'
    }, 'startOrganization')
  end
  if CurrentActions.garageView == true then
    options[#options + 1] = withBinding({
      title = 'Garagens cadastradas',
      description = 'Lista, edita, posiciona e controla o ciclo de vida.',
      icon = 'list'
    }, 'managedList')
  end

  if Draft then
    options[#options + 1] = withBinding({
      title = 'Continuar rascunho',
      description = ('%s [%s]'):format(draftLabel(Draft), Draft.kind),
      icon = 'pen-ruler'
    }, 'showDraft')
    options[#options + 1] = withBinding({
      title = 'Descartar rascunho',
      description = 'Descarta apenas o rascunho local; nenhuma garagem sera removida.',
      icon = 'xmark'
    }, 'discard')
  end

  MZAdminUI.RegisterContext({
    id = GARAGE_ID,
    menu = CurrentParentId,
    title = 'Gerenciamento de garagens',
    subtitle = 'Publicas e organizacionais persistentes',
    options = options
  })
end

AddEventHandler(WIZARD_EVENT, function(payload)
  local selected = type(payload) == 'table' and tostring(payload.action or '') or ''
  if selected == 'startPublic' then
    startPublic()
  elseif selected == 'startOrganization' then
    startOrganization()
  elseif selected == 'showDraft' then
    MZAdminGarageWizard.ShowDraft()
  elseif selected == 'placementAll' then
    startPlacement({ 'entry', 'spawn', 'store' })
  elseif selected == 'placementOne' then
    local point = tostring(payload.point or '')
    if PLACEMENT_LABELS[point] then startPlacement({ point }) end
  elseif selected == 'submit' then
    submit()
  elseif selected == 'discard' and Draft then
    if MZAdminUI.Confirm('Descartar rascunho?', 'Nenhuma garagem ja criada sera alterada.') then
      Draft = nil
      MZAdminGarageWizard.Register(nil, CurrentActions)
      MZAdminUI.ShowContext(GARAGE_ID)
    end
  elseif selected == 'managedList' then
    openManagedList()
  elseif selected == 'managedDetails' then
    showManagedDetails(payload.code)
  elseif selected == 'managedEdit' then
    editManagedGarage(ManagedRowsByCode[tostring(payload.code or '')])
  elseif selected == 'managedState' then
    changeManagedState(payload.code, payload.active == true)
  end
end)

function MZAdminGarageWizard.GetMenuId()
  return GARAGE_ID
end

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  setPlacementLocked(false, true)
  PlacementActive = false
  hidePlacementHelp()
end)
