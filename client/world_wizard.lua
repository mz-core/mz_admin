MZAdminWorld = MZAdminWorld or {}

local ROOT_ID = 'mz_admin:world'
local DOORS_ID = 'mz_admin:world:doors'
local DRAFT_ID = 'mz_admin:world:doors:draft'
local LIST_ID = 'mz_admin:world:doors:list'
local DETAIL_ID = 'mz_admin:world:doors:detail'
local GROUPS_ID = 'mz_admin:world:doors:groups'
local GROUP_DETAIL_ID = 'mz_admin:world:doors:group:detail'
local ACTION_EVENT = 'mz_admin:client:worldAction'
local Draft
local CurrentActions = {}
local PendingSelection
local ListedDoors = {}
local ListedGroups = {}
local SelectedDoorId
local DoorDetailParent = LIST_ID

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

local function buildAccessPolicy(accessType)
  if accessType == 'public' then return { type = 'public' } end
  if accessType == 'staff' then
    local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('world.s_a7019c76c09f') or 'Acesso Staff'), {
      {
        type = 'input', label = (type(locale) == 'function' and locale('world.s_a8953d3d75ea') or 'Permissao Staff'), required = true,
        default = 'staff.world.doors.manage', description = (type(locale) == 'function' and locale('world.s_c341894ebcf5') or 'Exemplo: staff.world.doors.manage')
      }
    }, { allowCancel = true })
    if not values then return nil end
    return { type = 'staff', permission = tostring(values[1] or '') }
  end
  if accessType == 'organization' then
    local catalog = request('listWorldOrganizations')
    local organizations = catalog and catalog.organizations or {}
    if #organizations == 0 then
      notify((type(locale) == 'function' and locale('garage.s_eafdc0e5847c') or 'Nenhuma organizacao ativa foi encontrada.'), 'error')
      return nil
    end
    local organizationOptions = {}
    for _, organization in ipairs(organizations) do
      organizationOptions[#organizationOptions + 1] = {
        value = organization.code,
        label = organization.type ~= ''
          and ('%s [%s] - %s'):format(organization.name, organization.type, organization.code)
          or ('%s - %s'):format(organization.name, organization.code)
      }
    end
    local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('world.s_b8a1ce36b15f') or 'Acesso organizacional'), {
      {
        type = 'select',
        label = (type(locale) == 'function' and locale('garage.s_1dba7976c4cf') or 'Organizacao'),
        required = true,
        options = organizationOptions,
        default = organizationOptions[1].value
      },
      { type = 'number', label = (type(locale) == 'function' and locale('world.s_4f5567f54b6c') or 'Nivel minimo'), required = true, default = 0, min = 0, max = 1000 },
      {
        type = 'input', label = (type(locale) == 'function' and locale('world.s_5697d3d37c81') or 'Capability opcional'), required = false,
        placeholder = 'doors.armory', description = (type(locale) == 'function' and locale('world.s_87258d5e1647') or 'Vazio exige apenas organizacao e nivel.')
      }
    }, { allowCancel = true })
    if not values then return nil end
    local permission = tostring(values[3] or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return {
      type = 'organization',
      code = tostring(values[1] or ''):lower(),
      minGrade = tonumber(values[2]) or 0,
      permission = permission ~= '' and permission or nil
    }
  end
  return nil
end

local function groupPolicyLabel(group)
  local policy = type(group) == 'table' and group.access_policy or nil
  if type(policy) ~= 'table' then return (type(locale) == 'function' and locale('world.s_229111f0a8dc') or 'sem regra') end
  if policy.type == 'organization' then
    local suffix = policy.permission and policy.permission ~= '' and (' + ' .. policy.permission) or ''
    return ((type(locale) == 'function' and locale('world.s_31fb0f038854') or 'job/org %s (nivel %s)%s')):format(tostring(policy.code), tostring(policy.minGrade or 0), suffix)
  end
  if policy.type == 'staff' then return 'staff ' .. tostring(policy.permission or '') end
  return tostring(policy.type or 'public')
end

local function fetchGroups()
  local data = request('listWorldDoorGroups')
  ListedGroups = {}
  for _, group in ipairs(data and data.groups or {}) do
    ListedGroups[tonumber(group.id)] = group
    for _, door in ipairs(group.doors or {}) do ListedDoors[tonumber(door.id)] = door end
  end
  return data and data.groups or {}
end

local function averageInteraction(leaves)
  local x, y, z, count = 0.0, 0.0, 0.0, 0
  for _, leaf in ipairs(leaves or {}) do
    local coords = leaf.interaction_coords or leaf.coords
    if type(coords) == 'table' then
      local cx, cy, cz = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
      if cx and cy and cz then
        x, y, z, count = x + cx, y + cy, z + cz, count + 1
      end
    end
  end
  if count == 0 then return nil end
  return { x = x / count, y = y / count, z = z / count }
end

local function startSelection()
  if not Draft or #Draft.leaves >= Draft.requiredLeaves then return end
  if GetResourceState('mz_world_editor') ~= 'started' then
    notify((type(locale) == 'function' and locale('world.s_c7e1821b9acb') or 'mz_world_editor nao esta iniciado.'), 'error')
    return
  end
  local requestId = ('mz_admin:door:%s:%s'):format(GetGameTimer(), #Draft.leaves + 1)
  local excluded = {}
  for _, leaf in ipairs(Draft.leaves) do
    excluded[#excluded + 1] = {
      entity = leaf._entity,
      model_hash = leaf.model_hash,
      x = leaf.x, y = leaf.y, z = leaf.z
    }
  end
  PendingSelection = requestId
  MZAdminUI.CloseContext()
  local ok, err = exports['mz_world_editor']:StartEntitySelection({
    requestId = requestId,
    objectsOnly = true,
    title = ((type(locale) == 'function' and locale('world.s_c5b303fa3d12') or 'Selecionar folha %d/%d')):format(#Draft.leaves + 1, Draft.requiredLeaves),
    selectedCount = #Draft.leaves,
    requiredCount = Draft.requiredLeaves,
    excluded = excluded
  })
  if ok ~= true then
    PendingSelection = nil
    notify(((type(locale) == 'function' and locale('world.s_1f274d16af74') or 'Editor indisponivel: %s')):format(tostring(err)), 'error')
    MZAdminWorld.ShowDraft()
  end
end

local function configureDraft(kind)
  local groups = fetchGroups()
  if not groups then return end
  local groupOptions = { { value = 'none', label = (type(locale) == 'function' and locale('world.s_2fadd6d72e46') or 'Sem grupo (configurar acesso nesta porta)') } }
  for _, group in ipairs(groups) do
    if group.active == true then
      groupOptions[#groupOptions + 1] = {
        value = tostring(group.id),
        label = ('#%s %s - %s'):format(group.id, group.label, groupPolicyLabel(group))
      }
    end
  end
  local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('world.s_500d9ab04970') or 'Nova porta persistente'), {
    {
      type = 'input', label = (type(locale) == 'function' and locale('world.s_a053c73da298') or 'Nome personalizado'), required = false,
      placeholder = (type(locale) == 'function' and locale('world.s_215fc3c41985') or 'Vazio usa Porta #ID'), description = (type(locale) == 'function' and locale('world.s_695144d9f0c3') or 'O ID e o codigo estrutural sao gerados automaticamente.')
    },
    {
      type = 'select', label = (type(locale) == 'function' and locale('world.s_d2a2572bc9ef') or 'Grupo de portas'), required = true, default = 'none',
      options = groupOptions
    },
    {
      type = 'select', label = (type(locale) == 'function' and locale('world.s_de8568219f77') or 'Acesso sem grupo'), required = true, default = 'organization',
      options = {
        { value = 'organization', label = (type(locale) == 'function' and locale('garage.s_1dba7976c4cf') or 'Organizacao') },
        { value = 'staff', label = 'Staff' },
        { value = 'public', label = (type(locale) == 'function' and locale('world.s_b0e88810d98e') or 'Publico') }
      }
    },
    { type = 'number', label = (type(locale) == 'function' and locale('world.s_5f5f25b01c07') or 'Distancia de interacao'), required = true, default = 2.0, min = 0.5, max = 5.0 },
    { type = 'number', label = (type(locale) == 'function' and locale('world.s_4fb48e5a632f') or 'Auto-lock em segundos'), required = true, default = 0, min = 0, max = 3600 },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('world.s_d4535eb92bdd') or 'Iniciar trancada'), checked = true },
    {
      type = 'checkbox', label = (type(locale) == 'function' and locale('world.s_c5946d67ddff') or 'Exibir nome no texto 3D'), checked = true,
      description = (type(locale) == 'function' and locale('world.s_841de61a83df') or 'Desligado ainda mostra os comandos de trancar e bater, mas oculta o nome.')
    },
    {
      type = 'checkbox', label = (type(locale) == 'function' and locale('world.s_5c40f402ebf0') or 'Exibir icone 3D adicional'), checked = false,
      description = (type(locale) == 'function' and locale('world.s_c0ec2bce6ccc') or 'O texto contextual continua aparecendo mesmo com esta opcao desligada.')
    },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('world.s_39461d0c63f9') or 'Som habilitado'), checked = true }
  }, { allowCancel = true })
  if not values then return end
  local label = tostring(values[1] or '')
  local groupId = tonumber(values[2])
  local policy = groupId and { type = 'public' } or buildAccessPolicy(tostring(values[3] or ''))
  if not policy then return end
  local session = request('beginWorldDoorDraft')
  if not session or not session.sessionId then return end
  Draft = {
    sessionId = session.sessionId,
    kind = kind,
    requiredLeaves = kind == 'double' and 2 or 1,
    label = label,
    groupId = groupId,
    groupLabel = groupId and ListedGroups[groupId] and ListedGroups[groupId].label or nil,
    accessPolicy = policy,
    interactionDistance = tonumber(values[4]) or 2.0,
    autoLockSeconds = tonumber(values[5]) or 0,
    locked = values[6] == true,
    showLabel3d = values[7] == true,
    markerEnabled = values[8] == true,
    soundEnabled = values[9] == true,
    leaves = {}
  }
  startSelection()
end

function MZAdminWorld.ShowDraft()
  if not Draft then return false end
  local interaction = Draft.interaction or averageInteraction(Draft.leaves)
  Draft.interaction = interaction
  local options = {
    {
      title = ((type(locale) == 'function' and locale('world.s_89a4e5d3dbf5') or 'Folhas selecionadas: %d/%d')):format(#Draft.leaves, Draft.requiredLeaves),
      description = #Draft.leaves < Draft.requiredLeaves and (type(locale) == 'function' and locale('world.s_6334628922ed') or 'Selecione as folhas restantes.') or (type(locale) == 'function' and locale('world.s_22247846521f') or 'Selecao fisica completa.'),
      icon = 'door-open',
      readOnly = true
    }
  }
  if #Draft.leaves < Draft.requiredLeaves then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('world.s_c003f35d9876') or 'Selecionar proxima folha'),
      description = (type(locale) == 'function' and locale('world.s_559da0a1f90b') or 'Fecha o menu e abre o seletor visual.'),
      icon = 'crosshairs'
    }, 'selectLeaf')
  end
  if interaction then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('world.s_ec13b58cb9b7') or 'Ajustar ponto de interacao'),
      description = ('%.3f, %.3f, %.3f'):format(interaction.x, interaction.y, interaction.z),
      icon = 'location-dot'
    }, 'adjustInteraction')
  end
  if #Draft.leaves == Draft.requiredLeaves and interaction then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('garage.s_be02e142173d') or 'Revisar e criar'),
      description = ('%s | %s | %s'):format(
        Draft.label ~= '' and Draft.label or (type(locale) == 'function' and locale('world.s_a44b87aa3e33') or 'Porta #ID'), Draft.groupLabel or (type(locale) == 'function' and locale('world.s_ae200463988a') or 'sem grupo'), (Draft.kind == 'single' and (type(locale) == 'function' and locale('world.s_608542445531') or 'Simples') or (Draft.kind == 'double' and (type(locale) == 'function' and locale('world.s_e37830c42194') or 'Dupla') or tostring(Draft.kind)))
      ),
      icon = 'floppy-disk'
    }, 'submit')
  end
  options[#options + 1] = bind({
    title = (type(locale) == 'function' and locale('garage.s_aac64ed20751') or 'Descartar rascunho'),
    description = (type(locale) == 'function' and locale('world.s_3b4b096cd0ed') or 'Nenhuma porta persistente sera alterada.'),
    icon = 'xmark'
  }, 'discard')

  MZAdminUI.RegisterContext({
    id = DRAFT_ID,
    menu = DOORS_ID,
    title = Draft.label ~= '' and Draft.label or (type(locale) == 'function' and locale('world.s_97ca2366f4e6') or 'Porta #ID automatico'),
    subtitle = ('%s | %s'):format(Draft.groupLabel or (type(locale) == 'function' and locale('world.s_ae200463988a') or 'sem grupo'), (Draft.kind == 'single' and (type(locale) == 'function' and locale('world.s_608542445531') or 'Simples') or (Draft.kind == 'double' and (type(locale) == 'function' and locale('world.s_e37830c42194') or 'Dupla') or tostring(Draft.kind)))),
    options = options
  })
  return MZAdminUI.ShowContext(DRAFT_ID)
end

local function submit()
  if not Draft or #Draft.leaves ~= Draft.requiredLeaves or not Draft.interaction then return end
  local summary = ((type(locale) == 'function' and locale('world.s_98e9ae8a96dc') or 'Nome: %s\nID: automatico\nGrupo: %s\nTipo: %s\nFolhas: %d\nNome no 3D: %s\nInteracao: %.3f %.3f %.3f')):format(
    Draft.label ~= '' and Draft.label or (type(locale) == 'function' and locale('world.s_a44b87aa3e33') or 'Porta #ID'), Draft.groupLabel or (type(locale) == 'function' and locale('world.s_ae200463988a') or 'sem grupo'), (Draft.kind == 'single' and (type(locale) == 'function' and locale('world.s_608542445531') or 'Simples') or (Draft.kind == 'double' and (type(locale) == 'function' and locale('world.s_e37830c42194') or 'Dupla') or tostring(Draft.kind))), #Draft.leaves,
    Draft.showLabel3d and (type(locale) == 'function' and locale('security_alerts.s_813221ca5f14') or 'sim') or (type(locale) == 'function' and locale('security_alerts.s_21592d443e0a') or 'nao'),
    Draft.interaction.x, Draft.interaction.y, Draft.interaction.z
  )
  if not MZAdminUI.Confirm((type(locale) == 'function' and locale('world.s_b8017b1d0a1d') or 'Criar porta persistente?'), summary, {
    labels = { confirm = (type(locale) == 'function' and locale('garage.s_af3d3c69e687') or 'Criar'), cancel = (type(locale) == 'function' and locale('garage.s_dded1e28c28a') or 'Revisar') }
  }) then return end
  local leaves = {}
  for _, leaf in ipairs(Draft.leaves) do
    leaves[#leaves + 1] = {
      model_hash = leaf.model_hash,
      model_name = leaf.model_name,
      x = leaf.x, y = leaf.y, z = leaf.z,
      rx = leaf.rx, ry = leaf.ry, rz = leaf.rz,
      heading = leaf.heading
    }
  end
  local data = request('createWorldDoor', Draft.sessionId, {
    label = Draft.label,
    groupId = Draft.groupId,
    locked = Draft.locked,
    interaction = Draft.interaction,
    interactionDistance = Draft.interactionDistance,
    drawDistance = 8.0,
    accessPolicy = Draft.accessPolicy,
    autoLockSeconds = Draft.autoLockSeconds,
    markerEnabled = Draft.markerEnabled,
    showLabel3d = Draft.showLabel3d,
    soundEnabled = Draft.soundEnabled,
    leaves = leaves
  })
  if not data then return end
  notify(((type(locale) == 'function' and locale('world.s_70d0f3f419c2') or 'Porta #%s "%s" criada com sucesso.')):format(
    data.door and data.door.id or '?', data.door and data.door.label or Draft.label
  ), 'success')
  Draft = nil
  MZAdminUI.ShowContext(DOORS_ID)
end

local function createGroup()
  local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('world.s_68ddfa93e5dc') or 'Novo grupo de portas'), {
    {
      type = 'input', label = (type(locale) == 'function' and locale('world.s_3cd5f8e28f23') or 'Nome do grupo'), required = true,
      placeholder = (type(locale) == 'function' and locale('world.s_e121e327538c') or 'Delegacia'), description = (type(locale) == 'function' and locale('world.s_fa8342ea68a3') or 'O grupo recebe ID e codigo automaticos.')
    },
    {
      type = 'select', label = (type(locale) == 'function' and locale('world.s_26d6d9873c73') or 'Acesso padrao'), required = true, default = 'organization',
      options = {
        { value = 'organization', label = (type(locale) == 'function' and locale('world.s_7d206f9c99b5') or 'Job / organizacao') },
        { value = 'staff', label = 'Staff' },
        { value = 'public', label = (type(locale) == 'function' and locale('world.s_b0e88810d98e') or 'Publico') }
      }
    }
  }, { allowCancel = true })
  if not values then return end
  local policy = buildAccessPolicy(tostring(values[2] or ''))
  if not policy then return end
  local data = request('createWorldDoorGroup', {
    label = tostring(values[1] or ''),
    accessPolicy = policy
  })
  if not data or not data.group then return end
  notify(((type(locale) == 'function' and locale('world.s_08b125cac952') or 'Grupo #%s "%s" criado.')):format(data.group.id, data.group.label), 'success')
  ListedGroups[tonumber(data.group.id)] = data.group
end

local showGroupDetails

local function openGroups()
  local groups = fetchGroups()
  local options = {}
  for _, group in ipairs(groups or {}) do
    options[#options + 1] = bind({
      title = ('#%s %s'):format(group.id, group.label),
      description = ((type(locale) == 'function' and locale('world.s_a846c1875a9d') or '%s | %d porta(s)')):format(groupPolicyLabel(group), tonumber(group.door_count) or 0),
      icon = 'layer-group',
      readOnly = CurrentActions.worldDoorManage ~= true
    }, 'groupDetails', { groupId = tonumber(group.id) })
  end
  if #options == 0 then options[1] = { title = (type(locale) == 'function' and locale('world.s_ed9575dcc1d9') or 'Nenhum grupo de portas'), icon = 'layer-group', readOnly = true } end
  MZAdminUI.RegisterContext({
    id = GROUPS_ID,
    menu = DOORS_ID,
    title = (type(locale) == 'function' and locale('world.s_c54bbcfcfcf1') or 'Grupos de portas'),
    subtitle = ((type(locale) == 'function' and locale('world.s_d90265f5bf6b') or '%d grupo(s)')):format(#(groups or {})),
    options = options
  })
  MZAdminUI.ShowContext(GROUPS_ID)
end

showGroupDetails = function(groupId)
  local group = ListedGroups[tonumber(groupId)]
  if not group then return openGroups() end
  local options = {
    {
      title = groupPolicyLabel(group),
      description = ((type(locale) == 'function' and locale('world.s_3357c0bcf4f1') or 'ID #%s | codigo %s')):format(group.id, group.code),
      icon = 'shield-halved',
      readOnly = true
    }
  }
  if CurrentActions.worldDoorManage == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('world.s_12747e2aabf0') or 'Adicionar porta ao grupo'),
      description = (type(locale) == 'function' and locale('world.s_64036db028ce') or 'Seleciona uma porta cadastrada e passa a usar o acesso deste grupo.'),
      icon = 'plus'
    }, 'addDoorToGroup', { groupId = tonumber(group.id) })
  end
  for _, door in ipairs(group.doors or {}) do
    local option = {
      title = ('#%s %s'):format(door.id, door.label),
      description = CurrentActions.worldDoorManage == true
        and (type(locale) == 'function' and locale('world.s_f3ac8fe45861') or 'Abrir configuracoes da porta.') or tostring(door.code),
      icon = 'door-closed',
      readOnly = CurrentActions.worldDoorManage ~= true
    }
    if CurrentActions.worldDoorManage == true then
      bind(option, 'groupDoorDetails', { groupId = tonumber(group.id), doorId = tonumber(door.id) })
    end
    options[#options + 1] = option
  end
  MZAdminUI.RegisterContext({
    id = GROUP_DETAIL_ID,
    menu = GROUPS_ID,
    title = ('#%s %s'):format(group.id, group.label),
    subtitle = ((type(locale) == 'function' and locale('world.s_bd50cec19156') or '%d porta(s) herdando esta permissao')):format(#(group.doors or {})),
    options = options
  })
  MZAdminUI.ShowContext(GROUP_DETAIL_ID)
end

local function openList()
  local data = request('listWorldDoors')
  if not data then return end
  local options = {}
  ListedDoors = {}
  for _, door in ipairs(data.doors or {}) do
    ListedDoors[tonumber(door.id)] = door
    local option = {
      title = ('#%s %s'):format(door.id, tostring(door.label)),
      description = ((type(locale) == 'function' and locale('world.s_6aa21f1239fe') or '%s | %s | %d folha(s) | %s')):format(
        door.group and ((type(locale) == 'function' and locale('world.s_746d3f06609e') or 'grupo ') .. tostring(door.group.label)) or tostring(door.code), (door.kind == 'single' and (type(locale) == 'function' and locale('world.s_608542445531') or 'Simples') or (door.kind == 'double' and (type(locale) == 'function' and locale('world.s_e37830c42194') or 'Dupla') or tostring(door.kind))), #(door.leaves or {}),
        door.active == true and (door.locked == true and (type(locale) == 'function' and locale('world.s_2d528cca6225') or 'trancada') or (type(locale) == 'function' and locale('world.s_cac87d8d361b') or 'destrancada')) or (type(locale) == 'function' and locale('garage.s_e46e99168ad6') or 'arquivada')
      ),
      icon = door.locked == true and 'lock' or 'lock-open',
      readOnly = CurrentActions.worldDoorManage ~= true and CurrentActions.worldDoorArchive ~= true
    }
    if not option.readOnly then bind(option, 'doorDetails', { doorId = tonumber(door.id) }) end
    options[#options + 1] = option
  end
  if #options == 0 then options[1] = { title = (type(locale) == 'function' and locale('world.s_d8bcf8eb9730') or 'Nenhuma porta V2'), icon = 'door-closed', readOnly = true } end
  MZAdminUI.RegisterContext({
    id = LIST_ID,
    menu = DOORS_ID,
    title = (type(locale) == 'function' and locale('world.s_babf64a2144a') or 'Portas persistentes'),
    subtitle = ((type(locale) == 'function' and locale('garage.s_4abb390912f0') or '%d cadastrada(s)')):format(#(data.doors or {})),
    options = options
  })
  MZAdminUI.ShowContext(LIST_ID)
end

local function showDoorDetails(doorId, parentId)
  if parentId then DoorDetailParent = parentId end
  local door = ListedDoors[tonumber(doorId)]
  if not door then
    notify((type(locale) == 'function' and locale('world.s_9dbeb3a16387') or 'A definicao da porta ficou desatualizada. Reabrindo a lista.'), 'error')
    return openList()
  end
  SelectedDoorId = tonumber(door.id)
  local state = door.active == true and (door.locked == true and (type(locale) == 'function' and locale('world.s_674e845ec249') or 'Trancada') or (type(locale) == 'function' and locale('world.s_075ab41a008d') or 'Destrancada')) or (type(locale) == 'function' and locale('garage.s_692ec2b46d82') or 'Arquivada')
  local policy = type(door.access_policy) == 'table' and tostring(door.access_policy.type or 'public') or 'public'
  local options = {
    {
      title = state,
      description = ((type(locale) == 'function' and locale('world.s_2744d2988110') or 'Codigo: %s | acesso: %s | revisao: %s')):format(
        tostring(door.code), policy, tostring(door.revision or 1)
      ),
      icon = door.active == false and 'box-archive' or (door.locked == true and 'lock' or 'lock-open'),
      readOnly = true
    },
    {
      title = (type(locale) == 'function' and locale('world.s_9f0a33662839') or 'Ponto de interacao'),
      description = ((type(locale) == 'function' and locale('world.s_6aa35f6b9c02') or '%.3f, %.3f, %.3f | alcance %.1fm')):format(
        tonumber(door.interaction_x) or 0,
        tonumber(door.interaction_y) or 0,
        tonumber(door.interaction_z) or 0,
        tonumber(door.interaction_distance) or 0
      ),
      icon = 'location-dot',
      readOnly = true
    },
    {
      title = door.group and ((type(locale) == 'function' and locale('world.s_aeeeecc2afcc') or 'Grupo: #') .. tostring(door.group.id) .. ' ' .. tostring(door.group.label)) or (type(locale) == 'function' and locale('world.s_576edc5f8f0c') or 'Sem grupo'),
      description = door.group and ((type(locale) == 'function' and locale('world.s_4a9576a7f11e') or 'Acesso herdado: ') .. groupPolicyLabel(door.group)) or (type(locale) == 'function' and locale('world.s_c7b7e5e49914') or 'Usa a regra individual da porta.'),
      icon = 'layer-group',
      readOnly = true
    },
    {
      title = door.show_label_3d == false and (type(locale) == 'function' and locale('world.s_3be95bbe7501') or 'Nome oculto no 3D') or (type(locale) == 'function' and locale('world.s_4def75ff1d2e') or 'Nome visivel no 3D'),
      description = (type(locale) == 'function' and locale('world.s_802872b40aa6') or 'Os comandos de interacao continuam visiveis.'),
      icon = door.show_label_3d == false and 'eye-slash' or 'eye',
      readOnly = true
    }
  }
  if door.active == true and CurrentActions.worldDoorManage == true then
    options[#options + 1] = bind({
      title = (type(locale) == 'function' and locale('world.s_0b8b1de9803f') or 'Editar nome e exibicao 3D'),
      description = (type(locale) == 'function' and locale('world.s_1d4e613ed63c') or 'Personaliza o nome ou volta ao padrao Porta #ID.'),
      icon = 'pen'
    }, 'editDoorPresentation', { doorId = SelectedDoorId })
    options[#options + 1] = bind({
      title = door.locked == true and (type(locale) == 'function' and locale('world.s_219cb5b93154') or 'Destrancar agora') or (type(locale) == 'function' and locale('world.s_a5f45e9a0ddf') or 'Trancar agora'),
      description = (type(locale) == 'function' and locale('world.s_de459f943a86') or 'Persiste o estado e sincroniza todos os jogadores.'),
      icon = door.locked == true and 'lock-open' or 'lock'
    }, 'setDoorLocked', { doorId = SelectedDoorId, locked = door.locked ~= true })
    if door.group then
      options[#options + 1] = bind({
        title = (type(locale) == 'function' and locale('world.s_c28e06e63e77') or 'Remover deste grupo'),
        description = (type(locale) == 'function' and locale('world.s_7935c759cdc6') or 'A porta volta a usar sua regra de acesso individual.'),
        icon = 'link-slash'
      }, 'removeDoorFromGroup', { groupId = tonumber(door.group.id), doorId = SelectedDoorId })
    end
  end
  if CurrentActions.worldDoorArchive == true then
    options[#options + 1] = bind({
      title = door.active == true and (type(locale) == 'function' and locale('world.s_526bb232a191') or 'Arquivar porta') or (type(locale) == 'function' and locale('world.s_36f4217d3f03') or 'Restaurar porta'),
      description = door.active == true
        and (type(locale) == 'function' and locale('world.s_cb089329e2a2') or 'Remove a porta do runtime sem apagar seu historico.')
        or (type(locale) == 'function' and locale('world.s_7c8e1e915421') or 'Reativa a definicao e suas folhas fisicas.'),
      icon = door.active == true and 'box-archive' or 'rotate-left'
    }, 'setDoorActive', { doorId = SelectedDoorId, active = door.active ~= true })
  end
  MZAdminUI.RegisterContext({
    id = DETAIL_ID,
    menu = DoorDetailParent,
    title = tostring(door.label),
    subtitle = ((type(locale) == 'function' and locale('world.s_a3b030083728') or '%s | %d folha(s)')):format((door.kind == 'single' and (type(locale) == 'function' and locale('world.s_608542445531') or 'Simples') or (door.kind == 'double' and (type(locale) == 'function' and locale('world.s_e37830c42194') or 'Dupla') or tostring(door.kind))), #(door.leaves or {})),
    options = options
  })
  MZAdminUI.ShowContext(DETAIL_ID)
end

function MZAdminWorld.Register(parentId, actions, available, capabilities)
  CurrentActions = type(actions) == 'table' and actions or {}
  if available ~= true then return false end
  capabilities = type(capabilities) == 'table' and capabilities or {}
  local hasDoorActions = CurrentActions.worldView == true
    or CurrentActions.worldDoorCreate == true
    or CurrentActions.worldDoorManage == true
    or CurrentActions.worldDoorArchive == true
  local hasPropActions = CurrentActions.worldView == true
    or CurrentActions.worldPropCreate == true
    or CurrentActions.worldPropManage == true
    or CurrentActions.worldPropArchive == true
  local hasFurnitureActions = CurrentActions.furnitureView == true
    or CurrentActions.furnitureCreate == true
    or CurrentActions.furnitureManage == true
    or CurrentActions.furnitureArchive == true
    or CurrentActions.furnitureRecovery == true
  local doorOptions = {}
  if CurrentActions.worldDoorCreate == true then
    doorOptions[#doorOptions + 1] = bind({
      title = (type(locale) == 'function' and locale('world.s_e0484fc61904') or 'Criar porta simples'),
      description = (type(locale) == 'function' and locale('world.s_999b94996555') or 'Assistente visual com uma folha fisica.'),
      icon = 'door-closed'
    }, 'createSingle')
    doorOptions[#doorOptions + 1] = bind({
      title = (type(locale) == 'function' and locale('world.s_4d4458e60ef8') or 'Criar porta dupla'),
      description = (type(locale) == 'function' and locale('world.s_4e5136744ada') or 'Duas folhas, um unico estado e uma unica marcacao.'),
      icon = 'door-open'
    }, 'createDouble')
  end
  if CurrentActions.worldDoorManage == true then
    doorOptions[#doorOptions + 1] = bind({
      title = (type(locale) == 'function' and locale('world.s_0a66a810acd9') or 'Criar grupo de portas'),
      description = (type(locale) == 'function' and locale('world.s_8dcd77d847f0') or 'Define uma vez o job/organizacao e reaproveita em varias portas.'),
      icon = 'layer-group'
    }, 'createGroup')
  end
  if CurrentActions.worldView == true then
    doorOptions[#doorOptions + 1] = bind({
      title = (type(locale) == 'function' and locale('world.s_0009617e0909') or 'Portas cadastradas'),
      description = (type(locale) == 'function' and locale('world.s_1f405ffb0768') or 'Lista definicoes V2 ativas e arquivadas.'),
      icon = 'list'
    }, 'listDoors')
  end
  if CurrentActions.worldView == true or CurrentActions.worldDoorManage == true then
    doorOptions[#doorOptions + 1] = bind({
      title = (type(locale) == 'function' and locale('world.s_897b3f3b6096') or 'Grupos cadastrados'),
      description = (type(locale) == 'function' and locale('world.s_e98efa6a48eb') or 'Adicionar e remover portas dos grupos de acesso.'),
      icon = 'layer-group'
    }, 'listGroups')
  end
  if Draft then
    doorOptions[#doorOptions + 1] = bind({
      title = (type(locale) == 'function' and locale('garage.s_c2ef0b713d2e') or 'Continuar rascunho'),
      description = Draft.label,
      icon = 'pen-ruler'
    }, 'showDraft')
  end

  if capabilities.doorsReady == true and hasDoorActions then
    MZAdminUI.RegisterContext({
      id = DOORS_ID,
      menu = ROOT_ID,
      title = (type(locale) == 'function' and locale('world.s_895b05c84504') or 'Portas'),
      subtitle = capabilities.doorsRuntime == true and (type(locale) == 'function' and locale('world.s_3e6ae320fbbf') or 'Runtime V2 completo')
        or (capabilities.doorsNativeRuntime == true
          and (type(locale) == 'function' and locale('world.s_e38c02e22c8a') or 'Portas novas ativas; migradas continuam no legado')
          or (type(locale) == 'function' and locale('world.s_c8b8854f94ce') or 'V2 preparado; runtime ainda em modo seguro')),
      options = doorOptions
    })
  end
  local rootOptions = {}
  if capabilities.doorsReady == true and hasDoorActions then
    rootOptions[#rootOptions + 1] = {
      title = (type(locale) == 'function' and locale('world.s_babf64a2144a') or 'Portas persistentes'),
      description = capabilities.doorsRuntime == true
        and (type(locale) == 'function' and locale('world.s_cbce03ae720f') or 'Criar, consultar e administrar portas.')
        or (capabilities.doorsNativeRuntime == true
          and (type(locale) == 'function' and locale('world.s_db9b6f0aa90e') or 'Portas novas funcionam durante a migracao segura.')
          or (type(locale) == 'function' and locale('world.s_3dc009098cc6') or 'Cadastro disponivel; ative o runtime apos a migracao.')),
      icon = 'door-open',
      menu = DOORS_ID,
      arrow = true
    }
  end
  if capabilities.propsReady == true and hasPropActions and type(MZAdminProps) == 'table'
    and type(MZAdminProps.Register) == 'function' then
    MZAdminProps.Register(ROOT_ID, CurrentActions, true)
    rootOptions[#rootOptions + 1] = {
      title = (type(locale) == 'function' and locale('world.s_d2cbfda1a6fb') or 'Props persistentes'),
      description = (type(locale) == 'function' and locale('world.s_a62fb8746462') or 'Placement visual, streaming e ciclo de vida.'),
      icon = 'cubes',
      menu = MZAdminProps.GetMenuId(),
      arrow = true
    }
  end
  if capabilities.phoneChargingOutletsReady == true and hasPropActions
    and type(MZAdminChargingOutlets) == 'table'
    and type(MZAdminChargingOutlets.Register) == 'function'
    and MZAdminChargingOutlets.Register(ROOT_ID, CurrentActions, true) == true then
    rootOptions[#rootOptions + 1] = {
      title = (type(locale) == 'function' and locale('world.s_26ece3d0d2c1') or 'Tomadas de carregamento'),
      description = (type(locale) == 'function' and locale('world.s_a8d2daeae481') or 'Fallback persistente para superficies e MLOs.'),
      icon = 'plug',
      menu = MZAdminChargingOutlets.GetMenuId(),
      arrow = true
    }
  end
  if capabilities.furnitureReady == true and hasFurnitureActions
    and type(MZAdminFurniture) == 'table' and type(MZAdminFurniture.Register) == 'function'
    and MZAdminFurniture.Register(ROOT_ID, CurrentActions) == true then
    rootOptions[#rootOptions + 1] = {
      title = (type(locale) == 'function' and locale('world.s_bfa7c2c28780') or 'Moveis residenciais'),
      description = (type(locale) == 'function' and locale('world.s_b8a520c550c1') or 'Catalogo, precos e estado seguro do rollout.'),
      icon = 'couch',
      menu = MZAdminFurniture.GetMenuId(),
      arrow = true
    }
  end
  MZAdminUI.RegisterContext({
    id = ROOT_ID,
    menu = parentId,
    title = (type(locale) == 'function' and locale('world.s_f05831df0c1a') or 'Mundo e cenários'),
    subtitle = (type(locale) == 'function' and locale('world.s_1116355f9687') or 'Portas, props, tomadas, moveis e editor visual'),
    options = rootOptions
  })
  return true
end

function MZAdminWorld.GetMenuId()
  return ROOT_ID
end

AddEventHandler(ACTION_EVENT, function(payload)
  local action = type(payload) == 'table' and tostring(payload.action or '') or ''
  if action == 'createSingle' then configureDraft('single')
  elseif action == 'createDouble' then configureDraft('double')
  elseif action == 'selectLeaf' then startSelection()
  elseif action == 'showDraft' then MZAdminWorld.ShowDraft()
  elseif action == 'listDoors' then openList()
  elseif action == 'createGroup' then
    createGroup()
    openGroups()
  elseif action == 'listGroups' then openGroups()
  elseif action == 'groupDetails' then showGroupDetails(payload.groupId)
  elseif action == 'groupDoorDetails' then
    showDoorDetails(payload.doorId, GROUP_DETAIL_ID)
  elseif action == 'addDoorToGroup' then
    local doorsData = request('listWorldDoors')
    if not doorsData then return end
    local choices = {}
    for _, door in ipairs(doorsData.doors or {}) do
      if tonumber(door.group_id) ~= tonumber(payload.groupId) then
        choices[#choices + 1] = {
          value = tonumber(door.id),
          label = ('#%s %s%s'):format(
            door.id, door.label, door.group and ((type(locale) == 'function' and locale('world.s_6be4ad498739') or ' (atual: ') .. door.group.label .. ')') or ''
          )
        }
      end
    end
    if #choices == 0 then
      notify((type(locale) == 'function' and locale('world.s_da1e92b2e636') or 'Todas as portas cadastradas ja pertencem a este grupo.'), 'inform')
      return showGroupDetails(payload.groupId)
    end
    local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('world.s_12747e2aabf0') or 'Adicionar porta ao grupo'), {
      { type = 'select', label = (type(locale) == 'function' and locale('world.s_933d4f277e28') or 'Porta'), required = true, options = choices, default = choices[1].value }
    }, { allowCancel = true })
    if values then
      local changed = request('setWorldDoorGroup', tonumber(values[1]), tonumber(payload.groupId))
      if changed then notify((type(locale) == 'function' and locale('world.s_355de12aa922') or 'Porta adicionada ao grupo.'), 'success') end
    end
    fetchGroups()
    showGroupDetails(payload.groupId)
  elseif action == 'removeDoorFromGroup' then
    if MZAdminUI.Confirm((type(locale) == 'function' and locale('world.s_658fd8aa8c0d') or 'Remover porta do grupo?'), (type(locale) == 'function' and locale('world.s_3cc6324bf71a') or 'A porta voltara a usar sua regra de acesso individual.')) then
      local changed = request('setWorldDoorGroup', payload.doorId, false)
      if changed then notify((type(locale) == 'function' and locale('world.s_fc608b6b1948') or 'Porta removida do grupo.'), 'success') end
    end
    fetchGroups()
    showGroupDetails(payload.groupId)
  elseif action == 'doorDetails' then showDoorDetails(payload.doorId, LIST_ID)
  elseif action == 'editDoorPresentation' then
    local door = ListedDoors[tonumber(payload.doorId)]
    if not door then return openList() end
    local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('world.s_574ffe17949f') or 'Nome e texto 3D'), {
      {
        type = 'input', label = (type(locale) == 'function' and locale('world.s_a053c73da298') or 'Nome personalizado'), required = false,
        default = tostring(door.label or ''), placeholder = ((type(locale) == 'function' and locale('world.s_93f2ff9f2003') or 'Porta #%s')):format(door.id)
      },
      { type = 'checkbox', label = (type(locale) == 'function' and locale('world.s_c5946d67ddff') or 'Exibir nome no texto 3D'), checked = door.show_label_3d ~= false }
    }, { allowCancel = true })
    if values then
      local data = request('updateWorldDoorPresentation', door.id, {
        label = tostring(values[1] or ''),
        showLabel3d = values[2] == true
      })
      if data and data.door then
        ListedDoors[tonumber(data.door.id)] = data.door
        notify((type(locale) == 'function' and locale('world.s_30ec36344b21') or 'Nome e exibicao 3D atualizados.'), 'success')
        if DoorDetailParent == GROUP_DETAIL_ID and data.door.group then
          local groupId = tonumber(data.door.group.id)
          fetchGroups()
          showGroupDetails(groupId)
        end
        showDoorDetails(data.door.id, DoorDetailParent)
      end
    else
      showDoorDetails(door.id)
    end
  elseif action == 'setDoorLocked' then
    local data = request('setWorldDoorLocked', payload.doorId, payload.locked == true)
    if data and data.door then
      ListedDoors[tonumber(data.door.id)] = data.door
      notify(data.door.locked == true and (type(locale) == 'function' and locale('world.s_38423b3edb6f') or 'Porta trancada.') or (type(locale) == 'function' and locale('world.s_dbf422fe049b') or 'Porta destrancada.'), 'success')
      showDoorDetails(data.door.id)
    end
  elseif action == 'setDoorActive' then
    local verb = payload.active == true and (type(locale) == 'function' and locale('world.s_27985c84c2e0') or 'restaurar') or (type(locale) == 'function' and locale('world.s_6675573e1a64') or 'arquivar')
    if MZAdminUI.Confirm(((type(locale) == 'function' and locale('world.s_ed291ae3a990') or 'Deseja %s esta porta?')):format(verb), (type(locale) == 'function' and locale('world.s_607d32d14f66') or 'A definicao sera preservada no banco.')) then
      local data = request('setWorldDoorActive', payload.doorId, payload.active == true)
      if data and data.door then
        ListedDoors[tonumber(data.door.id)] = data.door
        notify(data.door.active == true and (type(locale) == 'function' and locale('world.s_072a6ee90c72') or 'Porta restaurada.') or (type(locale) == 'function' and locale('world.s_be02c71dfb1f') or 'Porta arquivada.'), 'success')
        showDoorDetails(data.door.id)
      end
    end
  elseif action == 'discard' then
    if Draft and MZAdminUI.Confirm((type(locale) == 'function' and locale('garage.s_0ee8d90b43ff') or 'Descartar rascunho?'), (type(locale) == 'function' and locale('world.s_6236903856c2') or 'Nenhuma porta sera alterada.')) then
      lib.callback.await('mz_admin:server:cancelWorldDoorDraft', false, Draft.sessionId)
      Draft = nil
      MZAdminUI.ShowContext(DOORS_ID)
    end
  elseif action == 'adjustInteraction' and Draft and Draft.interaction then
    local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('world.s_9f0a33662839') or 'Ponto de interacao'), {
      { type = 'number', label = 'X', required = true, default = Draft.interaction.x },
      { type = 'number', label = 'Y', required = true, default = Draft.interaction.y },
      { type = 'number', label = 'Z', required = true, default = Draft.interaction.z }
    }, { allowCancel = true })
    if values then
      Draft.interaction = { x = tonumber(values[1]), y = tonumber(values[2]), z = tonumber(values[3]) }
    end
    MZAdminWorld.ShowDraft()
  elseif action == 'submit' then submit()
  end
end)

AddEventHandler('mz_world_editor:client:selectionResult', function(requestId, data)
  if not PendingSelection or tostring(requestId) ~= tostring(PendingSelection) or not Draft then return end
  PendingSelection = nil
  for _, existing in ipairs(Draft.leaves) do
    local dx = tonumber(existing.x) - tonumber(data.coords.x)
    local dy = tonumber(existing.y) - tonumber(data.coords.y)
    local dz = tonumber(existing.z) - tonumber(data.coords.z)
    if tonumber(existing.model_hash) == tonumber(data.model_hash)
      and math.sqrt(dx * dx + dy * dy + dz * dz) < 0.05 then
      notify((type(locale) == 'function' and locale('world.s_0a2d423d0bd8') or 'Essa folha ja foi selecionada.'), 'error')
      SetTimeout(200, startSelection)
      return
    end
  end
  Draft.leaves[#Draft.leaves + 1] = {
    _entity = tonumber(data.entity),
    model_hash = data.model_hash,
    model_name = data.model_name,
    x = data.coords.x, y = data.coords.y, z = data.coords.z,
    rx = data.rotation.x, ry = data.rotation.y, rz = data.rotation.z,
    heading = data.heading,
    interaction_coords = data.interaction_coords
  }
  Draft.interaction = averageInteraction(Draft.leaves)
  if #Draft.leaves < Draft.requiredLeaves then
    notify(((type(locale) == 'function' and locale('world.s_e0afa13d9500') or 'Folha %d/%d registrada. Agora selecione a outra folha.')):format(
      #Draft.leaves, Draft.requiredLeaves
    ), 'success')
    SetTimeout(350, startSelection)
  else
    SetTimeout(150, MZAdminWorld.ShowDraft)
  end
end)

AddEventHandler('mz_world_editor:client:selectionCancelled', function(requestId)
  if not PendingSelection or tostring(requestId) ~= tostring(PendingSelection) then return end
  PendingSelection = nil
  if Draft then SetTimeout(100, MZAdminWorld.ShowDraft) end
end)
