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
    labels = { confirm = label or 'Confirmar', cancel = 'Cancelar' }
  })
end

local function request(name, ...)
  local data, err = MZAdminClient.StaffRequest(name, ...)
  if not data then notify('Operacao Staff recusada: ' .. tostring(err or 'erro desconhecido'), 'error') end
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
    { title = 'Nivel hierarquico', description = tostring(role.level), icon = 'ranking-star', readOnly = true },
    { title = 'Estado', description = role.active and 'Ativo' or 'Inativo', icon = 'power-off', readOnly = true },
    bind({ title = 'Editar cargo', description = 'Nome, nivel e estado.', icon = 'pen-to-square' }, 'editRole', { code = code })
  }
  for _, permission in ipairs(State.catalog or {}) do
    local selected = permissionSelected(role, permission.code)
    options[#options + 1] = bind({
      title = permission.label,
      description = permission.code .. ' | ' .. (selected and 'concedida' or 'nao concedida'),
      icon = selected and 'square-check' or 'square',
      metadata = { group = permission.group }
    }, 'togglePermission', { code = code, permission = permission.code, selected = not selected })
  end
  local id = ROOT_ID .. ':role:' .. code
  MZAdminUI.RegisterContext({
    id = id, menu = ROLES_ID, title = role.name,
    subtitle = ('%s | nivel %d'):format(role.code, role.level), options = options
  })
  MZAdminUI.ShowContext(id)
end

local function openRoles()
  if not refresh() then return end
  local options = {
    bind({ title = 'Criar cargo Staff', description = 'O nivel precisa ser inferior ao seu.', icon = 'plus' }, 'createRole')
  }
  for _, role in ipairs(State.roles or {}) do
    options[#options + 1] = bind({
      title = role.name,
      description = ('%s | nivel %d | %d permissoes | %s'):format(
        role.code, role.level, #(role.permissions or {}), role.active and 'ativo' or 'inativo'
      ),
      icon = role.active and 'user-shield' or 'user-lock',
      arrow = true
    }, 'openRole', { code = role.code })
  end
  MZAdminUI.RegisterContext({
    id = ROLES_ID, menu = ROOT_ID, title = 'Cargos Staff',
    subtitle = ('Seu nivel: %s'):format(State.actor and State.actor.level or 0), options = options
  })
  MZAdminUI.ShowContext(ROLES_ID)
end

local function openAssignments()
  if not refresh() then return end
  local options = {
    bind({ title = 'Atribuir cargo', description = 'Selecione um Character; a conta canonica sera usada.', icon = 'user-plus' }, 'assignRole')
  }
  for _, assignment in ipairs(State.assignments or {}) do
    options[#options + 1] = bind({
      title = assignment.name,
      description = ('%s | %s [%d] | %s'):format(
        ('Conta #%s'):format(assignment.accountId), assignment.roleName, assignment.roleLevel,
        assignment.active and 'ativo' or 'revogado'
      ),
      icon = assignment.active and 'user-check' or 'user-xmark'
    }, 'assignmentDetails', { accountId = assignment.accountId })
  end
  MZAdminUI.RegisterContext({
    id = ASSIGNMENTS_ID, menu = ROOT_ID, title = 'Equipe Staff',
    subtitle = ('%d atribuicao(oes) visiveis'):format(#(State.assignments or {})), options = options
  })
  MZAdminUI.ShowContext(ASSIGNMENTS_ID)
end

local function createRole()
  local values = input('Criar cargo Staff', {
    { type = 'input', label = 'Codigo', required = true, placeholder = 'moderador' },
    { type = 'input', label = 'Nome', required = true, placeholder = 'Moderador' },
    { type = 'number', label = 'Nivel', required = true, min = 1, max = 9999 },
    { type = 'textarea', label = 'Motivo', required = true }
  }, 'Criar')
  if not values then return end
  local result = request('createStaffRole', {
    code = values[1], name = values[2], level = values[3], reason = values[4]
  })
  if result then notify('Cargo Staff criado.', 'success') openRoles() end
end

local function editRole(code)
  local role = roleByCode(code)
  if not role then return end
  local values = input('Editar cargo Staff', {
    { type = 'input', label = 'Nome', required = true, default = role.name },
    { type = 'number', label = 'Nivel', required = true, default = role.level, min = 1, max = 9999 },
    { type = 'checkbox', label = 'Ativo', checked = role.active == true },
    { type = 'textarea', label = 'Motivo', required = true }
  }, 'Salvar')
  if not values then return end
  local result = request('updateStaffRole', code, {
    name = values[1], level = values[2], active = values[3] == true, reason = values[4]
  })
  if result then notify('Cargo Staff atualizado.', 'success') openRoles() end
end

local function togglePermission(code, permission, selected)
  local role = roleByCode(code)
  if not role then return end
  local permissions = {}
  for _, current in ipairs(role.permissions or {}) do
    if current ~= permission then permissions[#permissions + 1] = current end
  end
  if selected then permissions[#permissions + 1] = permission end
  local values = input(selected and 'Conceder permissao' or 'Remover permissao', {
    { type = 'textarea', label = 'Motivo', required = true }
  }, selected and 'Conceder' or 'Remover')
  if not values then return end
  local result = request('setStaffRolePermissions', code, permissions, values[1])
  if result then notify('Permissoes do cargo atualizadas.', 'success') openRoles() end
end

local function assignRole()
  if #State.roles == 0 then notify('Crie um cargo ativo primeiro.', 'error') return end
  local selected = MZAdminPlayerSelector.Select({
    title = 'Selecionar Character para Staff',
    subtitle = 'O cargo sera vinculado a Account canonica.',
    allowOffline = true
  })
  local accountId = selected and tonumber(selected.accountId)
  if not accountId then
    notify('O Character selecionado nao possui Account valida.', 'error')
    return
  end
  local roleOptions = {}
  for _, role in ipairs(State.roles) do
    if role.active then roleOptions[#roleOptions + 1] = { value = role.code, label = ('%s [%d]'):format(role.name, role.level) } end
  end
  local values = input('Atribuir cargo Staff', {
    { type = 'select', label = 'Cargo', required = true, options = roleOptions },
    { type = 'textarea', label = 'Motivo', required = true }
  }, 'Atribuir')
  if not values then return end
  local result = request('assignStaffRole', accountId, values[1], values[2])
  if result then notify('Cargo Staff atribuido.', 'success') openAssignments() end
end

local function assignmentDetails(accountId)
  local assignment
  for _, row in ipairs(State.assignments or {}) do if tonumber(row.accountId) == tonumber(accountId) then assignment = row break end end
  if not assignment then return end
  local options = {
    { title = 'Account ID', description = tostring(assignment.accountId), icon = 'id-card', readOnly = true },
    { title = 'Cargo', description = ('%s [%d]'):format(assignment.roleName, assignment.roleLevel), icon = 'user-shield', readOnly = true }
  }
  if assignment.active then
    options[#options + 1] = bind({ title = 'Revogar Staff', description = 'Remove as permissoes do cargo sem excluir historico.', icon = 'user-xmark' }, 'revokeRole', { accountId = accountId })
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
    local values = input('Revogar Staff', { { type = 'textarea', label = 'Motivo', required = true } }, 'Revogar')
    if values and request('revokeStaffRole', payload.accountId, values[1]) then
      notify('Atribuicao Staff revogada.', 'success')
      openAssignments()
    end
  end
end)

function MZAdminStaffManagement.Register(parentId)
  MZAdminUI.RegisterContext({
    id = ROOT_ID, menu = parentId, title = 'Equipe Staff',
    subtitle = 'Hierarquia global persistente',
    options = {
      bind({ title = 'Cargos Staff', description = 'Niveis e permissoes globais.', icon = 'ranking-star' }, 'roles'),
      bind({ title = 'Atribuicoes Staff', description = 'Definir ou revogar cargos pela Account canonica.', icon = 'users-gear' }, 'assignments')
    }
  })
end

function MZAdminStaffManagement.GetMenuId()
  return ROOT_ID
end
