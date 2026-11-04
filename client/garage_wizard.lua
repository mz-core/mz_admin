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
  { value = 'car', label = (type(locale) == 'function' and locale('garage.cars') or 'Carros') },
  { value = 'bike', label = (type(locale) == 'function' and locale('garage.bikes') or 'Motos') },
  { value = 'car_bike', label = (type(locale) == 'function' and locale('garage.cars_bikes') or 'Carros e motos') },
  { value = 'boat', label = (type(locale) == 'function' and locale('garage.boats') or 'Barcos') },
  { value = 'plane', label = (type(locale) == 'function' and locale('garage.aircraft') or 'Aeronaves') }
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
  if type(value) ~= 'table' then return (type(locale) == 'function' and locale('garage.s_568be0555136') or 'nao capturado') end
  local base = ('%.2f, %.2f, %.2f'):format(value.x or 0, value.y or 0, value.z or 0)
  return heading and (base .. (' | h %.1f'):format(value.w or 0)) or base
end

local function input(title, rows, confirmLabel)
  return MZAdminUI.InputDialog(title, rows, {
    allowCancel = true,
    labels = { confirm = confirmLabel or (type(locale) == 'function' and locale('garage.s_b8cb6f8bec0b') or 'Continuar'), cancel = (type(locale) == 'function' and locale('garage.s_c111e0ab9ddb') or 'Cancelar') }
  })
end

local function confirmOverwrite()
  if not Draft then return true end
  return MZAdminUI.Confirm(
    (type(locale) == 'function' and locale('garage.s_a7a575bf945b') or 'Substituir rascunho?'),
    ((type(locale) == 'function' and locale('garage.s_329ca33a8f2f') or 'O rascunho atual de "%s" sera descartado.')):format(Draft.label or Draft.code or (type(locale) == 'function' and locale('garage.s_d7f7f011c91f') or 'garagem')),
    { labels = { confirm = (type(locale) == 'function' and locale('garage.s_2b7c46de1394') or 'Substituir'), cancel = (type(locale) == 'function' and locale('garage.s_b812baab74f4') or 'Manter') } }
  )
end

local function identityStep(kind, step)
  local values = input(
    ((type(locale) == 'function' and locale('garage.s_c8269baa9bdc') or 'Nova garagem %s - %s')):format(kind == 'public' and (type(locale) == 'function' and locale('garage.s_a20021495a80') or 'publica') or (type(locale) == 'function' and locale('garage.s_c0b70fc21819') or 'organizacional'), step or '1/2'),
    {
      {
        type = 'input',
        label = (type(locale) == 'function' and locale('garage.s_ba53a1f3589a') or 'Codigo estrutural'),
        required = true,
        placeholder = kind == 'public' and 'praca_central' or 'mafia_sede',
        description = (type(locale) == 'function' and locale('garage.s_f3971fdcbec2') or 'Unico, em minusculas; aceita letras, numeros, _ e -.')
      },
      {
        type = 'input',
        label = (type(locale) == 'function' and locale('garage.s_6f4b8c6403f4') or 'Nome de exibicao'),
        required = false,
        placeholder = kind == 'public' and (type(locale) == 'function' and locale('garage.s_35f5803d62c1') or 'Garagem Pública') or (type(locale) == 'function' and locale('garage.s_513f7c9e1b32') or 'Garagem - nome da organizacao'),
        description = (type(locale) == 'function' and locale('garage.s_a4764842e06c') or 'Opcional. Vazio usa o nome padrao tambem no blip.')
      }
    },
    (type(locale) == 'function' and locale('garage.s_3b19c6319db6') or 'Proximo')
  )
  if type(values) ~= 'table' then return nil end
  return { code = trim(values[1]):lower(), label = trim(values[2]) }
end

local function startPublic()
  if not confirmOverwrite() then return end
  local identity = identityStep('public', '1/2')
  if not identity then return end
  local settings = input((type(locale) == 'function' and locale('garage.s_9d10976e27fa') or 'Garagem publica - 2/2'), {
    {
      type = 'select', label = (type(locale) == 'function' and locale('garage.s_8d7c061562b8') or 'Veiculos aceitos'), required = true,
      default = 'car', options = CATEGORY_OPTIONS
    },
    {
      type = 'select', label = (type(locale) == 'function' and locale('garage.s_ef66c52a22f6') or 'Vinculo das vagas'), required = true, default = 'strict',
      options = {
        { value = 'strict', label = (type(locale) == 'function' and locale('garage.s_8faf5ba755e7') or 'Somente esta garagem') },
        { value = 'shared', label = (type(locale) == 'function' and locale('garage.s_e3e7d078b211') or 'Pool publico compartilhado') }
      },
      description = (type(locale) == 'function' and locale('garage.s_1d0aec707167') or 'No modo estrito, o veiculo volta somente para esta garagem.')
    },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('garage.s_42dbb410e40a') or 'Exibir blip no mapa'), checked = true },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('garage.s_73e478f943ab') or 'Permitir retirada de apreendidos'), checked = true }
  }, (type(locale) == 'function' and locale('garage.s_abe8ccda8287') or 'Criar rascunho'))
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
    notify((type(locale) == 'function' and locale('garage.s_eafdc0e5847c') or 'Nenhuma organizacao ativa foi encontrada.'), 'error')
    return
  end

  local orgOptions = {}
  for _, org in ipairs(organizations) do
    orgOptions[#orgOptions + 1] = {
      value = org.code,
      label = ('%s [%s]'):format(org.name or org.code, org.type or '')
    }
  end

  local selected = input((type(locale) == 'function' and locale('garage.s_9218ebe396ec') or 'Garagem organizacional - 1/3'), {
    {
      type = 'select', label = (type(locale) == 'function' and locale('garage.s_1dba7976c4cf') or 'Organizacao'), required = true,
      options = orgOptions, default = orgOptions[1].value
    }
  }, (type(locale) == 'function' and locale('garage.s_3b19c6319db6') or 'Proximo'))
  if type(selected) ~= 'table' then return end

  local identity = identityStep('org', '2/3')
  if not identity then return end
  local access = input((type(locale) == 'function' and locale('garage.s_87c1e1be1dd5') or 'Garagem organizacional - 3/3'), {
    {
      type = 'select', label = (type(locale) == 'function' and locale('garage.s_8d7c061562b8') or 'Veiculos aceitos'), required = true,
      default = 'car', options = CATEGORY_OPTIONS
    },
    {
      type = 'select', label = (type(locale) == 'function' and locale('garage.s_ef66c52a22f6') or 'Vinculo das vagas'), required = true, default = 'strict',
      options = {
        { value = 'strict', label = (type(locale) == 'function' and locale('garage.s_8faf5ba755e7') or 'Somente esta garagem') },
        { value = 'shared', label = (type(locale) == 'function' and locale('garage.s_101568de39e7') or 'Pool da organizacao') }
      }
    },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('garage.s_6c8877183015') or 'Exigir duty ativo'), checked = false },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('garage.s_4e7cc7e3a181') or 'Exigir organizacao primaria'), checked = false },
    {
      type = 'number', label = (type(locale) == 'function' and locale('garage.s_a377d7d092e6') or 'Nivel minimo do cargo'), required = true,
      default = 0, min = 0, max = 1000
    },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('garage.s_42dbb410e40a') or 'Exibir blip no mapa'), checked = false }
  }, (type(locale) == 'function' and locale('garage.s_abe8ccda8287') or 'Criar rascunho'))
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
  entry = (type(locale) == 'function' and locale('garage.s_09a2f4eb2cf3') or 'entrada da garagem'),
  spawn = (type(locale) == 'function' and locale('garage.s_7e0e66264a1f') or 'ponto de spawn'),
  store = (type(locale) == 'function' and locale('garage.s_a09b7a68e0cb') or 'ponto de armazenamento')
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
    if wasLocked and silent ~= true then notify((type(locale) == 'function' and locale('garage.s_d6307d861043') or 'Movimento destravado.'), 'inform') end
    return true
  end

  if PlacementLocked then return true end
  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)
  local entity = ped
  if vehicle ~= 0 then
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
      if silent ~= true then
        notify((type(locale) == 'function' and locale('garage.s_29ede85f206c') or 'Para travar um veiculo, ocupe o banco do motorista.'), 'error')
      end
      return false
    end
    entity = vehicle
  end
  if not entity or entity == 0 or not DoesEntityExist(entity) then
    if silent ~= true then notify((type(locale) == 'function' and locale('garage.s_11f6262a8452') or 'Entidade de posicionamento indisponivel.'), 'error') end
    return false
  end

  PlacementEntityWasFrozen = type(IsEntityPositionFrozen) == 'function'
    and IsEntityPositionFrozen(entity) == true
    or false
  FreezeEntityPosition(entity, true)
  PlacementLocked = true
  PlacementFrozenEntity = entity
  if silent ~= true then
    notify(vehicle ~= 0 and (type(locale) == 'function' and locale('garage.s_bf10384ef7a9') or 'Veiculo travado para posicionamento.') or (type(locale) == 'function' and locale('garage.s_dfcbb04f7ef4') or 'Movimento travado para posicionamento.'), 'success')
  end
  return true
end

local function showPlacementHelp(point, current, total)
  local label = PLACEMENT_LABELS[point] or point
  local vehicleHint = point == 'spawn' and (type(locale) == 'function' and locale('garage.s_b10d8168fee9') or ' Entre em um veiculo para usar sua posicao e heading.') or ''
  local lockHint = PlacementLocked and (type(locale) == 'function' and locale('garage.s_f2c794b3dfb2') or '[G] Destravar movimento') or (type(locale) == 'function' and locale('garage.s_2d7260e88876') or '[G] Travar movimento')
  if lib and type(lib.showTextUI) == 'function' then
    pcall(lib.showTextUI, (
      (type(locale) == 'function' and locale('garage.s_bdf3a32aee86') or '[E] Capturar %s (%d/%d)  |  %s  |  [X] Cancelar.%s')
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
          notify(((type(locale) == 'function' and locale('garage.s_5a77ba9e5eb0') or '%s capturado.')):format(PLACEMENT_LABELS[point] or point), 'success')
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
    if cancelled then notify((type(locale) == 'function' and locale('garage.s_88670334a152') or 'Posicionamento cancelado; capturas anteriores foram mantidas.'), 'warning') end
    if Draft then
      Wait(100)
      MZAdminGarageWizard.ShowDraft()
    end
  end)
end

local ERROR_MESSAGES = {
  invalid_code = (type(locale) == 'function' and locale('garage.s_84a3c7f6ddbe') or 'Codigo invalido ou fora do padrao.'),
  invalid_label = (type(locale) == 'function' and locale('garage.s_1e5b68c92ca8') or 'Nome de exibicao invalido.'),
  invalid_coordinates = (type(locale) == 'function' and locale('garage.s_9e29d6937c8c') or 'Uma das coordenadas capturadas e invalida.'),
  coordinates_too_far = (type(locale) == 'function' and locale('garage.s_007202b352a2') or 'Os pontos devem ficar a no maximo 250 metros da entrada.'),
  invalid_org = (type(locale) == 'function' and locale('garage.s_6c40a25d9d3a') or 'A organizacao nao existe mais.'),
  org_archived = (type(locale) == 'function' and locale('garage.s_f1b0082e5f9b') or 'A organizacao foi arquivada.'),
  garage_code_exists = (type(locale) == 'function' and locale('garage.s_259e5e783ea9') or 'Ja existe uma garagem com este codigo.'),
  garage_code_immutable = (type(locale) == 'function' and locale('garage.s_f4c0f9127300') or 'O codigo estrutural nao pode ser alterado.'),
  garage_kind_immutable = (type(locale) == 'function' and locale('garage.s_efc39dce454c') or 'O tipo da garagem nao pode ser alterado.'),
  garage_org_immutable = (type(locale) == 'function' and locale('garage.s_b296cbb48a34') or 'A organizacao vinculada nao pode ser alterada.'),
  garage_not_found = (type(locale) == 'function' and locale('garage.s_6ffcf5ad5016') or 'A garagem nao existe mais.'),
  managed_repository_unavailable = (type(locale) == 'function' and locale('garage.s_2cb11ccfb57d') or 'O repositorio persistente de garagens esta indisponivel.'),
  permission_denied = (type(locale) == 'function' and locale('garage.s_ba9ef310633c') or 'Sua permissao para criar garagens foi revogada.'),
  database_error = (type(locale) == 'function' and locale('garage.s_3709d9e7f8ff') or 'O banco recusou a criacao da garagem.')
}

local function draftLabel(draft)
  if trim(draft and draft.label) ~= '' then return trim(draft.label) end
  return draft and draft.kind == 'org' and (type(locale) == 'function' and locale('garage.s_ef367479fd5d') or 'Nome padrao da organizacao') or (type(locale) == 'function' and locale('garage.s_35f5803d62c1') or 'Garagem Pública')
end

local function editManagedGarage(row)
  if CurrentActions.garageManage ~= true or type(row) ~= 'table' then return end
  local settings = type(row.settings) == 'table' and row.settings or {}
  local rows = {
    {
      type = 'input',
      label = (type(locale) == 'function' and locale('garage.s_6f4b8c6403f4') or 'Nome de exibicao'),
      required = false,
      default = row.label,
      description = (type(locale) == 'function' and locale('garage.s_de52a7b79fdf') or 'Pode ficar vazio para restaurar o nome padrao.')
    },
    {
      type = 'select', label = (type(locale) == 'function' and locale('garage.s_8d7c061562b8') or 'Veiculos aceitos'), required = true,
      default = settings.categoryMode or 'car', options = CATEGORY_OPTIONS
    },
    {
      type = 'select', label = (type(locale) == 'function' and locale('garage.s_ef66c52a22f6') or 'Vinculo das vagas'), required = true,
      default = settings.strictGarage == true and 'strict' or 'shared',
      options = {
        { value = 'strict', label = (type(locale) == 'function' and locale('garage.s_8faf5ba755e7') or 'Somente esta garagem') },
        { value = 'shared', label = row.kind == 'org' and (type(locale) == 'function' and locale('garage.s_101568de39e7') or 'Pool da organizacao') or (type(locale) == 'function' and locale('garage.s_e3e7d078b211') or 'Pool publico compartilhado') }
      }
    },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('garage.s_42dbb410e40a') or 'Exibir blip no mapa'), checked = settings.blipEnabled == true }
  }
  if row.kind == 'public' then
    rows[#rows + 1] = {
      type = 'checkbox', label = (type(locale) == 'function' and locale('garage.s_73e478f943ab') or 'Permitir retirada de apreendidos'),
      checked = settings.allowImpounded == true
    }
  else
    rows[#rows + 1] = { type = 'checkbox', label = (type(locale) == 'function' and locale('garage.s_6c8877183015') or 'Exigir duty ativo'), checked = settings.requireDuty == true }
    rows[#rows + 1] = { type = 'checkbox', label = (type(locale) == 'function' and locale('garage.s_4e7cc7e3a181') or 'Exigir organizacao primaria'), checked = settings.primaryOnly == true }
    rows[#rows + 1] = {
      type = 'number', label = (type(locale) == 'function' and locale('garage.s_a377d7d092e6') or 'Nivel minimo do cargo'), required = true,
      default = tonumber(settings.minGradeLevel) or 0, min = 0, max = 1000
    }
  end

  local values = input(((type(locale) == 'function' and locale('garage.s_b1e37d242103') or 'Editar %s')):format(row.code), rows, (type(locale) == 'function' and locale('garage.s_2f754ea9fa32') or 'Abrir rascunho'))
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
          garage.kind == 'org' and ('org: ' .. tostring(garage.orgCode or '-')) or (type(locale) == 'function' and locale('garage.s_a20021495a80') or 'publica'),
          garage.active == true and (type(locale) == 'function' and locale('garage.s_1b9e540e4a17') or 'ativa') or (type(locale) == 'function' and locale('garage.s_e46e99168ad6') or 'arquivada')
        ),
        icon = garage.active == true and 'warehouse' or 'box-archive',
        arrow = true
      }, 'managedDetails', { code = garage.code })
    end
  end
  if #options == 0 then
    options[1] = {
      title = (type(locale) == 'function' and locale('garage.s_9359db29d558') or 'Nenhuma garagem persistente'),
      description = (type(locale) == 'function' and locale('garage.s_1e9640c985f8') or 'As garagens estaticas continuam fora desta lista.'),
      icon = 'warehouse',
      readOnly = true
    }
  end

  MZAdminUI.RegisterContext({
    id = LIST_ID,
    menu = GARAGE_ID,
    title = (type(locale) == 'function' and locale('garage.s_10b6ecd9dc64') or 'Garagens persistentes'),
    subtitle = ((type(locale) == 'function' and locale('garage.s_4abb390912f0') or '%d cadastrada(s)')):format(#garages),
    options = options
  })
  return MZAdminUI.ShowContext(LIST_ID)
end

local function showManagedDetails(code)
  local row = ManagedRowsByCode[tostring(code or '')]
  if type(row) ~= 'table' then return openManagedList() end
  local settings = type(row.settings) == 'table' and row.settings or {}
  local categoryLabel = tostring(settings.categoryMode or 'car')
  for _, category in ipairs(CATEGORY_OPTIONS) do
    if category.value == categoryLabel then categoryLabel = category.label break end
  end
  local options = {
    { title = (type(locale) == 'function' and locale('garage.s_ba53a1f3589a') or 'Codigo estrutural'), description = row.code, icon = 'fingerprint', readOnly = true },
    {
      title = (type(locale) == 'function' and locale('garage.s_6d6ae1fa81ab') or 'Tipo e vinculo'),
      description = row.kind == 'org' and ((type(locale) == 'function' and locale('garage.s_7619a2d3f451') or 'Organizacao: ') .. tostring(row.orgCode or '-')) or (type(locale) == 'function' and locale('garage.s_4d2e36773b5a') or 'Garagem publica'),
      icon = 'link',
      readOnly = true
    },
    {
      title = (type(locale) == 'function' and locale('garage.s_c3aec15974ad') or 'Regras'),
      description = ('%s | %s | blip %s'):format(
        categoryLabel,
        settings.strictGarage == true and (type(locale) == 'function' and locale('garage.s_2c372709ecaf') or 'estrita') or (type(locale) == 'function' and locale('garage.s_67f6050e20c1') or 'compartilhada'),
        settings.blipEnabled == true and (type(locale) == 'function' and locale('garage.s_4d53355a2818') or 'ativo') or (type(locale) == 'function' and locale('garage.s_dfefd0d3541c') or 'inativo')
      ),
      icon = 'sliders',
      readOnly = true
    },
    { title = (type(locale) == 'function' and locale('garage.s_73f83108cf33') or 'Entrada'), description = formatCoordinate(row.entry), icon = 'door-open', readOnly = true },
    { title = 'Spawn', description = formatCoordinate(row.spawn, true), icon = 'car-side', readOnly = true },
    { title = (type(locale) == 'function' and locale('garage.s_b598522ea0a0') or 'Armazenamento'), description = formatCoordinate(row.store), icon = 'square-parking', readOnly = true }
  }

  if CurrentActions.garageManage == true then
    options[#options + 1] = withBinding({
      title = (type(locale) == 'function' and locale('garage.s_a3f3459d0425') or 'Editar configuracao e pontos'),
      description = (type(locale) == 'function' and locale('garage.s_55e6ceb7cca2') or 'Codigo, tipo e organizacao permanecem protegidos.'),
      icon = 'pen-to-square'
    }, 'managedEdit', { code = row.code })
    options[#options + 1] = withBinding({
      title = row.active == true and (type(locale) == 'function' and locale('garage.s_5d5417fb2c9c') or 'Arquivar garagem') or (type(locale) == 'function' and locale('garage.s_9948c8ce7dd1') or 'Ativar garagem'),
      description = row.active == true
        and (type(locale) == 'function' and locale('garage.s_d6debaa57175') or 'Remove os pontos do runtime sem excluir o cadastro.')
        or (type(locale) == 'function' and locale('garage.s_aa0b4843431e') or 'Revalida a definicao e devolve os pontos ao runtime.'),
      icon = row.active == true and 'box-archive' or 'circle-check'
    }, 'managedState', { code = row.code, active = row.active ~= true })
  end

  local contextId = ('mz_admin:garages:managed:%s'):format(row.code)
  MZAdminUI.RegisterContext({
    id = contextId,
    menu = LIST_ID,
    title = row.label,
    subtitle = row.active == true and (type(locale) == 'function' and locale('garage.s_f21c4ff2bbb3') or 'Ativa') or (type(locale) == 'function' and locale('garage.s_692ec2b46d82') or 'Arquivada'),
    options = options
  })
  return MZAdminUI.ShowContext(contextId)
end

local function changeManagedState(code, active)
  local row = ManagedRowsByCode[tostring(code or '')]
  if type(row) ~= 'table' or type(active) ~= 'boolean' then return end
  local action = active and (type(locale) == 'function' and locale('garage.s_dbb3d05dcf77') or 'Ativar') or (type(locale) == 'function' and locale('garage.s_127ed55d7c5f') or 'Arquivar')
  if not MZAdminUI.Confirm(
    action .. (type(locale) == 'function' and locale('garage.s_2927d3b4f793') or ' garagem?'),
    ((type(locale) == 'function' and locale('garage.s_b6bb5c545c20') or '%s\nCodigo: %s\nNenhum cadastro sera excluido.')):format(row.label, row.code),
    { labels = { confirm = action, cancel = (type(locale) == 'function' and locale('garage.s_c111e0ab9ddb') or 'Cancelar') } }
  ) then return end
  local changed, err = MZAdminClient.SetManagedGarageActive(row.code, active)
  if not changed then
    notify(ERROR_MESSAGES[err] or ((type(locale) == 'function' and locale('garage.s_e4c83ada54a5') or 'Operacao recusada: ') .. tostring(err)), 'error')
    return
  end
  notify(active and (type(locale) == 'function' and locale('garage.s_2e0c5d9ae8eb') or 'Garagem ativada e sincronizada.') or (type(locale) == 'function' and locale('garage.s_ffa16010e934') or 'Garagem arquivada e removida do runtime.'), 'success')
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
    notify((type(locale) == 'function' and locale('garage.s_dc7ff82604f4') or 'Capture entrada, spawn e armazenamento antes de concluir.'), 'error')
    return
  end

  local editing = Draft.operation == 'edit'
  local summary = ((type(locale) == 'function' and locale('garage.s_4a8e4bc44fe6') or 'Codigo: %s\nNome: %s\nTipo: %s%s\nEntrada: %s\nSpawn: %s\nArmazenamento: %s')):format(
    Draft.code,
    draftLabel(Draft),
    Draft.kind == 'public' and (type(locale) == 'function' and locale('garage.s_a20021495a80') or 'publica') or (type(locale) == 'function' and locale('garage.s_c0b70fc21819') or 'organizacional'),
    Draft.orgCode and ((type(locale) == 'function' and locale('garage.s_e9c9ebc0f542') or '\nOrganizacao: ') .. Draft.orgCode) or '',
    formatCoordinate(Draft.entry),
    formatCoordinate(Draft.spawn, true),
    formatCoordinate(Draft.store)
  )
  if not MZAdminUI.Confirm(editing and (type(locale) == 'function' and locale('garage.s_b04f8eb2926f') or 'Salvar garagem?') or (type(locale) == 'function' and locale('garage.s_4953aeae6bde') or 'Criar garagem persistente?'), summary, {
    labels = { confirm = editing and (type(locale) == 'function' and locale('garage.s_93bf2d32ec33') or 'Salvar') or (type(locale) == 'function' and locale('garage.s_af3d3c69e687') or 'Criar'), cancel = (type(locale) == 'function' and locale('garage.s_dded1e28c28a') or 'Revisar') }
  }) then return end

  local saved, err
  if editing then
    saved, err = MZAdminClient.UpdateManagedGarage(Draft.originalCode, draftPayload(Draft))
  else
    saved, err = MZAdminClient.CreateManagedGarage(draftPayload(Draft))
  end
  if not saved then
    notify(ERROR_MESSAGES[err] or ((type(locale) == 'function' and locale('garage.s_e4c83ada54a5') or 'Operacao recusada: ') .. tostring(err or (type(locale) == 'function' and locale('garage.s_d7cff8e730ea') or 'erro desconhecido'))), 'error')
    return
  end

  local label = saved.label or draftLabel(Draft)
  Draft = nil
  notify(((type(locale) == 'function' and locale('garage.s_27f47242f8ae') or 'Garagem "%s" %s e sincronizada.')):format(label, editing and (type(locale) == 'function' and locale('garage.s_b6086da02e22') or 'atualizada') or (type(locale) == 'function' and locale('garage.s_05fe29ab3f44') or 'criada')), 'success')
  MZAdminGarageWizard.Register(nil, CurrentActions)
  if editing and CurrentActions.garageView == true then openManagedList() else MZAdminUI.ShowContext(GARAGE_ID) end
end

function MZAdminGarageWizard.ShowDraft()
  if not Draft then return false end
  local complete = Draft.entry and Draft.spawn and Draft.store
  local options = {
    withBinding({
      title = (type(locale) == 'function' and locale('garage.s_ce7bfd739552') or 'Posicionar todos os pontos'),
      description = (type(locale) == 'function' and locale('garage.s_e135c80c742a') or 'Ande ou dirija; G trava/destrava e E captura cada ponto em sequencia.'),
      icon = 'route'
    }, 'placementAll'),
    withBinding({
      title = Draft.entry and (type(locale) == 'function' and locale('garage.s_27206c00196e') or 'Reposicionar entrada') or (type(locale) == 'function' and locale('garage.s_31e856e00978') or 'Posicionar entrada'),
      description = formatCoordinate(Draft.entry) .. (type(locale) == 'function' and locale('garage.s_3ef0baa93647') or ' | G trava, E captura e o menu volta'),
      icon = 'door-open'
    }, 'placementOne', { point = 'entry' }),
    withBinding({
      title = Draft.spawn and (type(locale) == 'function' and locale('garage.s_e459218c268c') or 'Reposicionar spawn') or (type(locale) == 'function' and locale('garage.s_a1cc1e9779d1') or 'Posicionar spawn'),
      description = formatCoordinate(Draft.spawn, true) .. (type(locale) == 'function' and locale('garage.s_8fad56751181') or ' | dirija, use G para travar e E para capturar'),
      icon = 'car-side'
    }, 'placementOne', { point = 'spawn' }),
    withBinding({
      title = Draft.store and (type(locale) == 'function' and locale('garage.s_1d949e7acbf6') or 'Reposicionar armazenamento') or (type(locale) == 'function' and locale('garage.s_ca6ce3b12209') or 'Posicionar armazenamento'),
      description = formatCoordinate(Draft.store) .. (type(locale) == 'function' and locale('garage.s_3ef0baa93647') or ' | G trava, E captura e o menu volta'),
      icon = 'square-parking'
    }, 'placementOne', { point = 'store' })
  }

  if complete then
    options[#options + 1] = withBinding({
      title = Draft.operation == 'edit' and (type(locale) == 'function' and locale('garage.s_4ff6e03689f6') or 'Revisar e salvar') or (type(locale) == 'function' and locale('garage.s_be02e142173d') or 'Revisar e criar'),
      description = (type(locale) == 'function' and locale('garage.s_fe42a9e5a610') or 'O servidor revalidara permissao, organizacao, codigo e coordenadas.'),
      icon = 'floppy-disk'
    }, 'submit')
  else
    options[#options + 1] = {
      title = (type(locale) == 'function' and locale('garage.s_b7ed7fe4789f') or 'Criacao ainda incompleta'),
      description = (type(locale) == 'function' and locale('garage.s_cac2d64af446') or 'Os tres pontos sao obrigatorios.'),
      icon = 'triangle-exclamation',
      readOnly = true,
      disabled = true
    }
  end

  MZAdminUI.RegisterContext({
    id = DRAFT_ID,
    menu = GARAGE_ID,
    title = draftLabel(Draft),
    subtitle = ('%s | %s'):format(
      Draft.kind == 'public' and (type(locale) == 'function' and locale('garage.s_a20021495a80') or 'publica')
        or (type(locale) == 'function' and locale('garage.s_c0b70fc21819') or 'organizacional'),
      Draft.orgCode or (type(locale) == 'function' and locale('garage.s_a20021495a80') or 'publica')
    ),
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
      title = (type(locale) == 'function' and locale('garage.s_aaefa4fd90e1') or 'Criar garagem publica'),
      description = (type(locale) == 'function' and locale('garage.s_0558a9ca3e29') or 'Assistente em etapas com pontos de entrada, spawn e armazenamento.'),
      icon = 'square-parking'
    }, 'startPublic')
    options[#options + 1] = withBinding({
      title = (type(locale) == 'function' and locale('garage.s_03e7ffbea662') or 'Criar garagem de organizacao'),
      description = (type(locale) == 'function' and locale('garage.s_198a268c63cf') or 'Seleciona uma organizacao ativa e configura regras de acesso.'),
      icon = 'warehouse'
    }, 'startOrganization')
  end
  if CurrentActions.garageView == true then
    options[#options + 1] = withBinding({
      title = (type(locale) == 'function' and locale('garage.s_67ea604258b9') or 'Garagens cadastradas'),
      description = (type(locale) == 'function' and locale('garage.s_5e9e82864898') or 'Lista, edita, posiciona e controla o ciclo de vida.'),
      icon = 'list'
    }, 'managedList')
  end

  if Draft then
    options[#options + 1] = withBinding({
      title = (type(locale) == 'function' and locale('garage.s_c2ef0b713d2e') or 'Continuar rascunho'),
      description = ('%s [%s]'):format(draftLabel(Draft),
        Draft.kind == 'public' and (type(locale) == 'function' and locale('garage.s_a20021495a80') or 'publica')
          or (type(locale) == 'function' and locale('garage.s_c0b70fc21819') or 'organizacional')),
      icon = 'pen-ruler'
    }, 'showDraft')
    options[#options + 1] = withBinding({
      title = (type(locale) == 'function' and locale('garage.s_aac64ed20751') or 'Descartar rascunho'),
      description = (type(locale) == 'function' and locale('garage.s_f0eb6636bdc4') or 'Descarta apenas o rascunho local; nenhuma garagem sera removida.'),
      icon = 'xmark'
    }, 'discard')
  end

  MZAdminUI.RegisterContext({
    id = GARAGE_ID,
    menu = CurrentParentId,
    title = (type(locale) == 'function' and locale('garage.s_78448eba425c') or 'Gerenciamento de garagens'),
    subtitle = (type(locale) == 'function' and locale('garage.s_71d0ce015928') or 'Publicas e organizacionais persistentes'),
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
    if MZAdminUI.Confirm((type(locale) == 'function' and locale('garage.s_0ee8d90b43ff') or 'Descartar rascunho?'), (type(locale) == 'function' and locale('garage.s_e8358a4af64c') or 'Nenhuma garagem ja criada sera alterada.')) then
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
