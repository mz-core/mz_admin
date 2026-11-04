local function expect(condition, message)
  if not condition then error(message, 2) end
end

local function read(path)
  local file, err = io.open(path, 'rb')
  if not file then error(err, 2) end
  local content = file:read('*a')
  file:close()
  return content
end

local menu = read('mz_admin/client/menu.lua')
local bans = read('mz_admin/client/bans.lua')
local logs = read('mz_admin/client/admin_logs.lua')
local en = read('mz_admin/locales/en-us.json')

for _, section in ipairs({
  { id = 'mz_admin:section:vehicles', title = 'Veículos e garagens' },
  { id = 'mz_admin:section:management', title = 'Organizações e equipe' },
  { id = 'mz_admin:section:moderation', title = 'Moderação e acesso' },
  { id = 'mz_admin:section:audit', title = 'Auditoria' }
}) do
  expect(menu:find(section.id, 1, true) ~= nil, 'id de secao ausente: ' .. section.id)
  local escaped = section.title:gsub('([^%w])', '%%%1')
  local key = menu:match("title%s*=%s*translate%('(menu%.s_[%da-f]+)',%s*'" .. escaped .. "'%)")
  if key then
    expect(en:find('"' .. key:sub(6) .. '"', 1, true) ~= nil, 'traducao ausente: ' .. key)
  else
    expect(menu:find(("title = '%s'"):format(section.title), 1, true) ~= nil, 'titulo de secao ausente: ' .. section.title)
  end
end

-- Hub e atalhos redundantes foram removidos da navegacao principal.
expect(menu:find('mz_admin:section:tools', 1, true) == nil, 'secao Ferramentas rapidas ainda existe')
expect(menu:find("title = 'Jogadores e movimento'", 1, true) == nil, 'pagina Jogadores e movimento ainda existe')
expect(menu:find('local function registerPlayerMenu', 1, true) == nil, 'segundo seletor de jogadores ainda e registrado')
expect(menu:find('local function registerSection', 1, true) ~= nil, 'builder compartilhado de secoes ausente')
expect(menu:find('MZAdminGarageWizard.Register(VEHICLE_SECTION_ID, actions)', 1, true) ~= nil,
  'garagens nao retornam para a secao de veiculos')
expect(
  menu:find('MZAdminStaffManagement.Register(MANAGEMENT_ID)', 1, true) ~= nil,
  'gestao Staff nao retorna para a secao de gestao'
)
expect(
  menu:find('MZAdminWhitelist.Register(MODERATION_ID, actions)', 1, true) ~= nil
    and menu:find('MZAdminWarnings.Register(MODERATION_ID, actions, true)', 1, true) ~= nil,
  'modulos de acesso nao retornam para moderacao'
)
expect(
  bans:find('CurrentParentId = parentId ~=', 1, true) ~= nil
    and bans:find('menu = CurrentParentId', 1, true) ~= nil,
  'banimentos nao preservam a secao pai'
)
expect(
  logs:find('if parentId ~=', 1, true) ~= nil
    and logs:find('menu = CurrentParentId', 1, true) ~= nil,
  'logs nao preservam a secao pai'
)
expect(menu:match("title%s*=%s*translate%('menu%.s_[%da-f]+',%s*'Nenhuma area autorizada'%)") ~= nil
  and menu:find('readOnly = true', 1, true) ~= nil, 'estado vazio fail-closed localizado ausente')
expect(menu:find('HasGlobalPermission', 1, true) == nil, 'menu passou a autorizar no client')
expect(menu:find('MySQL%.', 1) == nil, 'menu passou a acessar banco')

print('mz_admin menu sections contract harness: PASS')
