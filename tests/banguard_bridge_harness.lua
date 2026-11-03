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

local server = read('mz_admin/server/bans.lua')
local security = read('mz_admin/server/security.lua')
local client = read('mz_admin/client/bans.lua')
local menu = read('mz_admin/client/menu.lua')
local manifest = read('mz_admin/fxmanifest.lua')
local api = read('mz_banguard/server/api.lua')
local banRepository = read('mz_banguard/server/bans.lua')
local banCloud = read('mz_banguard/server/cloud.lua')
local banConfig = read('mz_banguard/config.lua')

expect(server:find("exports['mz_banguard']:CreateOnlineBan", 1, true) ~= nil, 'bridge nao usa export oficial de ban')
expect(server:find("exports['mz_banguard']:RevokeBan", 1, true) ~= nil, 'bridge nao usa export oficial de unban')
expect(server:find("exports['mz_banguard'][exportName]", 1, true) == nil, 'bridge usa export dinamico que desloca argumentos')
expect(server:find('MySQL%.', 1) == nil, 'mz_admin acessa SQL do BanGuard')
expect(server:find('ExecuteCommand', 1, true) == nil, 'bridge executa comando por string')
expect(server:find("MZAdminSecurity.Authorize(sourceId, 'ban')", 1, true) ~= nil, 'ban sem pre-autorizacao Staff')
expect(server:find("MZAdminSecurity.Authorize(sourceId, 'banRevoke')", 1, true) ~= nil, 'unban sem pre-autorizacao Staff')
expect(server:find('reason, expectedCitizenid', 1, true) ~= nil,
  'bridge nao encaminha identidade esperada ao BanGuard')
expect(security:find("GetResourceState('mz_banguard') == 'started'", 1, true) ~= nil, 'menu nao verifica estado do BanGuard')
expect(security:find("exports['mz_banguard']:IsReady()", 1, true) ~= nil, 'menu nao verifica prontidao do schema')
expect(client:find("RegisterCommand(Config.Commands.banPlayer or 'ban'", 1, true) == nil, 'mz_admin duplicou comando /ban')
expect(client:find("RegisterCommand(Config.Commands.unbanPlayer or 'unban'", 1, true) == nil, 'mz_admin duplicou comando /unban')
expect(client:find('function MZAdminBans.PromptRevoke', 1, true) ~= nil, 'prompt publico de unban ausente')
expect(menu:find('context.banModuleAvailable', 1, true) ~= nil, 'root nao oculta modulo indisponivel')
expect(menu:find("title = 'Desbanir por Public ID'", 1, true) ~= nil, 'atalho direto de unban ausente no /admin')
expect(menu:find("MZAdminBans.PromptRevoke()", 1, true) ~= nil, 'atalho de unban nao abre fluxo protegido')
expect(manifest:find("'client/bans.lua'", 1, true) ~= nil, 'client bans ausente no manifest')
expect(manifest:find("'server/bans.lua'", 1, true) ~= nil, 'server bans ausente no manifest')

expect(api:find("trusted%[invokingResource%] == true", 1) ~= nil, 'API nao restringe caller resource')
expect(api:find('CanStaffActOnPlayer', 1, true) ~= nil, 'API nao revalida hierarquia')
expect(api:find('HasGlobalPermission', 1, true) ~= nil, 'API nao revalida permissao global')
expect(api:find("exports('CreateOnlineBan'", 1, true) ~= nil, 'export CreateOnlineBan ausente')
expect(api:find("exports('RevokeBan'", 1, true) ~= nil, 'export RevokeBan ausente')
expect(api:find("exports('GetBan'", 1, true) ~= nil, 'export GetBan ausente')
expect(api:find("exports('ListBans'", 1, true) ~= nil, 'export ListBans ausente')
expect(api:find('pcall(DropPlayer, targetSource', 1, true) ~= nil,
  'BanGuard nao solicita remocao protegida apos persistencia')
expect(api:find('identityMatchesSnapshot', 1, true) ~= nil
  and api:find('identity_mismatch_after_persistence', 1, true) ~= nil,
  'BanGuard nao revalida identidade antes da desconexao')
expect(banRepository:find('MySQL.transaction.await', 1, true) ~= nil, 'persistencia de ban/revogacao nao e transacional')
local publicDto = banRepository:match('function MZBan%.Bans%.ToPublicDto.-\nend\n\nfunction MZBan%.Bans%.ListPublic')
expect(type(publicDto) == 'string', 'DTO publico nao localizado')
expect(publicDto:find('identifiers', 1, true) == nil, 'DTO publico expoe identifiers')
expect(publicDto:find('tokens', 1, true) == nil, 'DTO publico expoe tokens')
expect(publicDto:find('citizenId', 1, true) ~= nil, 'DTO Staff nao expoe CitizenID contextual')
expect(
  banCloud:find('cloudEvidence.target_citizenid = nil', 1, true) ~= nil,
  'integracao cloud nao remove CitizenID local da evidencia'
)
expect(banConfig:find('AutoCreateMissingTables = true', 1, true) ~= nil, 'criacao de tabelas ausentes deve estar ativa')
expect(banConfig:find('AutoMigrateExistingTables = false', 1, true) ~= nil, 'migration automatica deve permanecer desligada')
expect(banConfig:find('Retention%s*=%s*{%s*Enabled%s*=%s*false') ~= nil, 'retencao automatica deve permanecer desligada')
expect(banConfig:find("Ban = 'ban'", 1, true) ~= nil, 'BanGuard nao possui comando canonico /ban')
expect(banConfig:find("Unban = 'unban'", 1, true) ~= nil, 'BanGuard nao possui comando canonico /unban')
expect(banConfig:find("Info = 'baninfo'", 1, true) ~= nil, 'BanGuard nao possui comando canonico /baninfo')
expect(banConfig:find("Lookup = 'banlookup'", 1, true) ~= nil, 'BanGuard nao possui comando canonico /banlookup')
expect(banConfig:find("Flags = 'banflags'", 1, true) ~= nil, 'BanGuard nao possui comando canonico /banflags')

print('mz_admin banguard bridge harness: PASS')
