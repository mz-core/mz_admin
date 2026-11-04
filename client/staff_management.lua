MZAdminStaffManagement = MZAdminStaffManagement or {}

local ROOT_ID = 'mz_admin:staff'
local ROLES_ID = 'mz_admin:staff:roles'
local ASSIGNMENTS_ID = 'mz_admin:staff:assignments'
local EVENT = 'mz_admin:client:staffManagementAction'
local State = { roles = {}, assignments = {}, catalog = {}, actor = {} }

local function notify(message, kind)
  MZAdminUI.Notify(message, kind or 'inform')
end

local function bind(option, action, args)
  args = type(args) == 'table' and args or {}
  args.action = action
  option.event = EVENT
  option.args = args
  return option
end

local function input(title, rows, label)
  return MZAdminUI.InputDialog(title, rows, {
    allowCancel = true,
    labels = { confirm = label or (type(locale) == 'function' and locale('ui.confirm') or 'Confirmar'), cancel = (type(locale) == 'function' and locale('garage.s_c111e0ab9ddb') or 'Cancelar') }
  })
end

local function request(name, ...)
  local data, err = MZAdminClient.StaffRequest(name, ...)
  if not data then notify((type(locale) == 'function' and locale('staff.s_d285024af23d') or 'Operacao Staff recusada: ') .. tostring(err or (type(locale) == 'function' and locale('garage.s_d7cff8e730ea') or 'erro desconhecido')), 'error') end
  return data
end

local function refresh()
  local data = request('listStaffManagement')
  if not data then return false end
  State = data
  return true
end

local function roleByCode(code)
  for _, role in ipairs(State.roles or {}) do
    if role.code == code then return role end
  end
end

local function permissionSelected(role, permission)
  for _, current in ipairs(role.permissions or {}) do
    if current == permission then return true end
  end
  return false
end

local function openRole(code)
  local role = roleByCode(code)
  if not role then return end
  local options = {
    { title = (type(locale) == 'function' and locale('staff.s_2c56cbf68e28') or 'Nivel hierarquico'), description = tostring(role.level), icon = 'ranking-star', readOnly = true },
    { title = (type(locale) == 'function' and locale('staff.s_87cf2a843e2e') or 'Estado'), description = role.active and (type(locale) == 'function' and locale('router.s_8263fde6ccc4') or 'Ativo') or (type(locale) == 'function' and locale('staff.s_2b1f189dff58') or 'Inativo'), icon = 'power-off', readOnly = true },
    bind({ title = (type(locale) == 'function' and locale('staff.s_41a4f0a1fc96') or 'Editar cargo'), description = (type(locale) == 'function' and locale('staff.s_f45c3f967eae') or 'Nome, nivel e estado.'), icon = 'pen-to-square' }, 'editRole', { code = code })
  }
  for _, permission in ipairs(State.catalog or {}) do
    local selected = permissionSelected(role, permission.code)
    options[#options + 1] = bind({
      title = permission.label,
      description = permission.code .. ' | ' .. (selected and (type(locale) == 'function' and locale('staff.s_8acdf5560142') or 'concedida') or (type(locale) == 'function' and locale('staff.s_4b02c22bfea7') or 'nao concedida')),
      icon = selected and 'square-check' or 'square',
      metadata = { group = permission.group }
    }, 'togglePermission', { code = code, permission = permission.code, selected = not selected })
  end
  local id = ROOT_ID .. ':role:' .. code
  MZAdminUI.RegisterContext({
    id = id, menu = ROLES_ID, title = role.name,
    subtitle = ((type(locale) == 'function' and locale('staff.s_7dec7667cbc9') or '%s | nivel %d')):format(role.code, role.level), options = options
  })
  MZAdminUI.ShowContext(id)
end

local function openRoles()
  if not refresh() then return end
  local options = {
    bind({ title = (type(locale) == 'function' and locale('staff.s_2dc3455fd774') or 'Criar cargo Staff'), description = (type(locale) == 'function' and locale('staff.s_cb4bcffa625a') or 'O nivel precisa ser inferior ao seu.'), icon = 'plus' }, 'createRole')
  }
  for _, role in ipairs(State.roles or {}) do
    options[#options + 1] = bind({
      title = role.name,
      description = ((type(locale) == 'function' and locale('staff.s_1588d8b5318f') or '%s | nivel %d | %d permissoes | %s')):format(
        role.code, role.level, #(role.permissions or {}), role.active and (type(locale) == 'function' and locale('garage.s_4d53355a2818') or 'ativo') or (type(locale) == 'function' and locale('garage.s_dfefd0d3541c') or 'inativo')
      ),
      icon = role.active and 'user-shield' or 'user-lock',
      arrow = true
    }, 'openRole', { code = role.code })
  end
  MZAdminUI.RegisterContext({
    id = ROLES_ID, menu = ROOT_ID, title = (type(locale) == 'function' and locale('staff.s_c253bc0e364a') or 'Cargos Staff'),
    subtitle = ((type(locale) == 'function' and locale('staff.s_539638b01452') or 'Seu nivel: %s')):format(State.actor and State.actor.level or 0), options = options
  })
  MZAdminUI.ShowContext(ROLES_ID)
end

local function openAssignments()
  if not refresh() then return end
  local options = {
    bind({ title = (type(locale) == 'function' and locale('staff.s_9aefc1445595') or 'Atribuir cargo'), description = (type(locale) == 'function' and locale('staff.s_72729712637d') or 'Selecione um Character; a conta canonica sera usada.'), icon = 'user-plus' }, 'assignRole')
  }
  for _, assignment in ipairs(State.assignments or {}) do
    options[#options + 1] = bind({
      title = assignment.name,
      description = ('%s | %s [%d] | %s'):format(
        ((type(locale) == 'function' and locale('staff.s_33e7e9e32537') or 'Conta #%s')):format(assignment.accountId), assignment.roleName, assignment.roleLevel,
        assignment.active and (type(locale) == 'function' and locale('garage.s_4d53355a2818') or 'ativo') or (type(locale) == 'function' and locale('staff.s_a0a8e3fd8567') or 'revogado')
      ),
      icon = assignment.active and 'user-check' or 'user-xmark'
    }, 'assignmentDetails', { accountId = assignment.accountId })
  end
  MZAdminUI.RegisterContext({
    id = ASSIGNMENTS_ID, menu = ROOT_ID, title = (type(locale) == 'function' and locale('staff.s_cec13ac495c6') or 'Equipe Staff'),
    subtitle = ((type(locale) == 'function' and locale('staff.s_a3a3a1c9f437') or '%d atribuicao(oes) visiveis')):format(#(State.assignments or {})), options = options
  })
  MZAdminUI.ShowContext(ASSIGNMENTS_ID)
end

local function createRole()
  local values = input((type(locale) == 'function' and locale('staff.s_2dc3455fd774') or 'Criar cargo Staff'), {
    { type = 'input', label = (type(locale) == 'function' and locale('staff.s_b77b7ce64ab6') or 'Codigo'), required = true, placeholder = 'moderador' },
    { type = 'input', label = (type(locale) == 'function' and locale('router.s_13030dd962f4') or 'Nome'), required = true, placeholder = (type(locale) == 'function' and locale('staff.s_82dc2f90b138') or 'Moderador') },
    { type = 'number', label = (type(locale) == 'function' and locale('staff.s_ada9db57a4b1') or 'Nivel'), required = true, min = 1, max = 9999 },
    { type = 'textarea', label = (type(locale) == 'function' and locale('menu.s_cbeec536b2f8') or 'Motivo'), required = true }
  }, (type(locale) == 'function' and locale('garage.s_af3d3c69e687') or 'Criar'))
  if not values then return end
  local result = request('createStaffRole', {
    code = values[1], name = values[2], level = values[3], reason = values[4]
  })
  if result then notify((type(locale) == 'function' and locale('staff.s_3a92704c3887') or 'Cargo Staff criado.'), 'success') openRoles() end
end

local function editRole(code)
  local role = roleByCode(code)
  if not role then return end
  local values = input((type(locale) == 'function' and locale('staff.s_2c365bb4037e') or 'Editar cargo Staff'), {
    { type = 'input', label = (type(locale) == 'function' and locale('router.s_13030dd962f4') or 'Nome'), required = true, default = role.name },
    { type = 'number', label = (type(locale) == 'function' and locale('staff.s_ada9db57a4b1') or 'Nivel'), required = true, default = role.level, min = 1, max = 9999 },
    { type = 'checkbox', label = (type(locale) == 'function' and locale('router.s_8263fde6ccc4') or 'Ativo'), checked = role.active == true },
    { type = 'textarea', label = (type(locale) == 'function' and locale('menu.s_cbeec536b2f8') or 'Motivo'), required = true }
  }, (type(locale) == 'function' and locale('garage.s_93bf2d32ec33') or 'Salvar'))
  if not values then return end
  local result = request('updateStaffRole', code, {
    name = values[1], level = values[2], active = values[3] == true, reason = values[4]
  })
  if result then notify((type(locale) == 'function' and locale('staff.s_545f3db2bcd5') or 'Cargo Staff atualizado.'), 'success') openRoles() end
end

local function togglePermission(code, permission, selected)
  local role = roleByCode(code)
  if not role then return end
  local permissions = {}
  for _, current in ipairs(role.permissions or {}) do
    if current ~= permission then permissions[#permissions + 1] = current end
  end
  if selected then permissions[#permissions + 1] = permission end
  local values = input(selected and (type(locale) == 'function' and locale('staff.s_c840b4a9eb59') or 'Conceder permissao') or (type(locale) == 'function' and locale('staff.s_97f59506fc1e') or 'Remover permissao'), {
    { type = 'textarea', label = (type(locale) == 'function' and locale('menu.s_cbeec536b2f8') or 'Motivo'), required = true }
  }, selected and (type(locale) == 'function' and locale('staff.s_f0cf8c597330') or 'Conceder') or (type(locale) == 'function' and locale('staff.s_4bd4ea834263') or 'Remover'))
  if not values then return end
  local result = request('setStaffRolePermissions', code, permissions, values[1])
  if result then notify((type(locale) == 'function' and locale('staff.s_f066a8b448e5') or 'Permissoes do cargo atualizadas.'), 'success') openRoles() end
end

local function assignRole()
  if #State.roles == 0 then notify((type(locale) == 'function' and locale('staff.s_7ae7c34fba3d') or 'Crie um cargo ativo primeiro.'), 'error') return end
  local selected = MZAdminPlayerSelector.Select({
    title = (type(locale) == 'function' and locale('staff.s_8711c536d3c9') or 'Selecionar Character para Staff'),
    subtitle = (type(locale) == 'function' and locale('staff.s_d7edb9349be4') or 'O cargo sera vinculado a Account canonica.'),
    allowOffline = true
  })
  local accountId = selected and tonumber(selected.accountId)
  if not accountId then
    notify((type(locale) == 'function' and locale('staff.s_cff0379e80d2') or 'O Character selecionado nao possui Account valida.'), 'error')
    return
  end
  local roleOptions = {}
  for _, role in ipairs(State.roles) do
    if role.active then roleOptions[#roleOptions + 1] = { value = role.code, label = ('%s [%d]'):format(role.name, role.level) } end
  end
  local values = input((type(locale) == 'function' and locale('staff.s_9c3ea937dc7b') or 'Atribuir cargo Staff'), {
    { type = 'select', label = (type(locale) == 'function' and locale('ui.role') or 'Cargo'), required = true, options = roleOptions },
    { type = 'textarea', label = (type(locale) == 'function' and locale('menu.s_cbeec536b2f8') or 'Motivo'), required = true }
  }, (type(locale) == 'function' and locale('staff.s_2ca9b02c3610') or 'Atribuir'))
  if not values then return end
  local result = request('assignStaffRole', accountId, values[1], values[2])
  if result then notify((type(locale) == 'function' and locale('staff.s_25bb8c3bdf6a') or 'Cargo Staff atribuido.'), 'success') openAssignments() end
end

local function assignmentDetails(accountId)
  local assignment
  for _, row in ipairs(State.assignments or {}) do if tonumber(row.accountId) == tonumber(accountId) then assignment = row break end end
  if not assignment then return end
  local options = {
    { title = 'Account ID', description = tostring(assignment.accountId), icon = 'id-card', readOnly = true },
    { title = (type(locale) == 'function' and locale('ui.role') or 'Cargo'), description = ('%s [%d]'):format(assignment.roleName, assignment.roleLevel), icon = 'user-shield', readOnly = true }
  }
  if assignment.active then
    options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('staff.s_576064057e09') or 'Revogar Staff'), description = (type(locale) == 'function' and locale('staff.s_33a0a04146e8') or 'Remove as permissoes do cargo sem excluir historico.'), icon = 'user-xmark' }, 'revokeRole', { accountId = accountId })
  end
  local id = ROOT_ID .. ':assignment:' .. tostring(accountId)
  MZAdminUI.RegisterContext({ id = id, menu = ASSIGNMENTS_ID, title = assignment.name, options = options })
  MZAdminUI.ShowContext(id)
end

AddEventHandler(EVENT, function(payload)
  local action = type(payload) == 'table' and tostring(payload.action or '') or ''
  if action == 'roles' then openRoles()
  elseif action == 'assignments' then openAssignments()
  elseif action == 'createRole' then createRole()
  elseif action == 'openRole' then openRole(payload.code)
  elseif action == 'editRole' then editRole(payload.code)
  elseif action == 'togglePermission' then togglePermission(payload.code, payload.permission, payload.selected == true)
  elseif action == 'assignRole' then assignRole()
  elseif action == 'assignmentDetails' then assignmentDetails(payload.accountId)
  elseif action == 'revokeRole' then
    local values = input((type(locale) == 'function' and locale('staff.s_576064057e09') or 'Revogar Staff'), { { type = 'textarea', label = (type(locale) == 'function' and locale('menu.s_cbeec536b2f8') or 'Motivo'), required = true } }, (type(locale) == 'function' and locale('router.s_d4ec79be0fea') or 'Revogar'))
    if values and request('revokeStaffRole', payload.accountId, values[1]) then
      notify((type(locale) == 'function' and locale('staff.s_c095374ab047') or 'Atribuicao Staff revogada.'), 'success')
      openAssignments()
    end
  end
end)

function MZAdminStaffManagement.Register(parentId)
  MZAdminUI.RegisterContext({
    id = ROOT_ID, menu = parentId, title = (type(locale) == 'function' and locale('staff.s_cec13ac495c6') or 'Equipe Staff'),
    subtitle = (type(locale) == 'function' and locale('staff.s_341400f9de31') or 'Hierarquia global persistente'),
    options = {
      bind({ title = (type(locale) == 'function' and locale('staff.s_c253bc0e364a') or 'Cargos Staff'), description = (type(locale) == 'function' and locale('staff.s_96b49d50f2d7') or 'Niveis e permissoes globais.'), icon = 'ranking-star' }, 'roles'),
      bind({ title = (type(locale) == 'function' and locale('staff.s_24b1a009b030') or 'Atribuicoes Staff'), description = (type(locale) == 'function' and locale('staff.s_79656bc311cf') or 'Definir ou revogar cargos pela Account canonica.'), icon = 'users-gear' }, 'assignments')
    }
  })
end

function MZAdminStaffManagement.GetMenuId()
  return ROOT_ID
end
