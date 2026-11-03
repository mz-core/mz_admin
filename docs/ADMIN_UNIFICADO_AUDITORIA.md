# MZ Admin Unificado — Auditoria e Matriz de Cobertura

> **Atualização de navegação:** a rail não possui mais o hub `ADMIN` nem a seção
> independente `Ferramentas rápidas`. `INÍCIO` concentra as ferramentas únicas e
> `JOGADORES` é o caminho canônico de seleção/perfil. Este documento permanece
> como histórico da unificação; o contrato atual está em `ADMIN_NUI_CONTRACT.md`.

Autoridade funcional: `/admin` existente (`mz_admin/client/menu.lua` → `MZAdminMenu.RegisterModules`).
Apresentação atual: `mz_menu` oferece DUAS superfícies — contexto (`RegisterContext`/`ShowContext`) e tablet (`OpenTablet`/`SetTabletView`). `/admin` usa a primeira; TAB (`/mztablet`) usa a segunda. Esta duplicação de UI é o alvo da unificação.

## Estado dos repos (dirty, preservado — sem commits/checkout/reset)

- `mz_menu`: `M` README.md, client/main.lua, docs/CONTEXT_THEME_CONTRACT.md, fxmanifest.lua, shared/config.lua, web/* ; `??` docs/DASHBOARD_LAYOUT_CONTRACT.md, graphify-out/, mz_menu.rar, tests/player_selector_contract_harness.lua.
- `mz_admin`: `M` README.md, client/main.lua, fxmanifest.lua, server/main.lua, shared/config.lua, tests/server_debug_security_harness.lua, web/* ; `??` grande parte de client/, server/, shared/permissions.lua, tests/ (estado não commitado em massa).
- `mz_core`: refatoração ampla em andamento (deletions de orgs/inventory/vehicles/hud + `?? server/identity/`). **NÃO tocar.**

## Contratos de identidade (mz_core, SOMENTE LEITURA — autoridade canônica)

- `ResolvePlayerIdentity(source)` → `{ ok, citizenid, accountId, characterId, firstname, lastname }`.
- `SearchCharacters(search, page, pageSize)` → paginado, `search >= 2` chars, retorna `characterId/accountId/citizenid/firstname/lastname/characterStatus`.
- `GetCharactersForAccount(accountId)` → lista de personagens da conta (persistido).
- `GetCharacterByCitizenId(citizenid)` → ficha persistida (id/accountId/citizenid/nome/telefone/status).
- `GetSourceByCitizenId(citizenid)` → source se online.
- `GetStaffContext(source)` / `HasGlobalPermission(source, perm)` / `CanStaffActOnPlayer(actor, target)` — hierarquia/autorização.
- `CreateDetailedLog(scope, action, payload)` / `ListLogs(source, filters)` / `ListGlobalLogsSecure(source, filters)` — auditoria.

Invariantes: `source` é efêmero; `account_id` é persistente (conta); `character_id` interno; `citizenid` é o ID público do personagem. Nunca confundir source com identidade persistente.

## Matriz /admin → função → capability → owner/callback → novo destino → estado

Legenda estado: `PRESERVADA` (já funcional e roteada), `NOVA` (apresentação nova reusando contrato), `BLOQUEADA` (sem contrato seguro), `VERIFICADA RUNTIME` (só após FiveM).

### MAIN (Minha sessão + ferramentas rápidas)

| Ação | Capability | Owner/callback real | Destino | Estado |
|---|---|---|---|---|
| NoClip | `staff.noclip` | `mz_admin:server:toggleNoClip` + lease banguard | MAIN rápida | PRESERVADA |
| Ir ao waypoint (tpm) | `staff.teleport` | comando `/tpm` (`Authorize('tpm')`) | MAIN rápida | PRESERVADA |
| Copiar coordenadas (loc) | `staff.coords.copy` | comando `/loc` | MAIN rápida | PRESERVADA |
| Curar a si | `staff.players.heal` | `mz_admin:server:tabletHeal` (self) | MAIN rápida | PRESERVADA |
| Reviver a si | `staff.players.revive` | `mz_admin:server:tabletRevive` (self) | MAIN rápida | PRESERVADA |
| Colete 100 | `staff.players.armor` | `mz_admin:server:tabletArmor` | MAIN rápida | PRESERVADA |
| Godmode | `staff.players.godmode` | `mz_admin:server:toggleGodMode` | MAIN rápida | PRESERVADA |
| Wall | `staff.wall` | comando `/wall` | MAIN (ferramentas) | PRESERVADA |
| Encerrar spectate | `staff.spectate` | `mz_admin:server:tabletSpectateStop` | MAIN | PRESERVADA |

### JOGADORES (lista + modal)

| Ação | Capability | Owner/callback real | Destino | Estado |
|---|---|---|---|---|
| Lista online | `staff.players.list` | `mz_admin:server:listOnlinePlayers` | JOGADORES | PRESERVADA |
| Busca online/offline/todos | `staff.players.list` | `mz_admin:server:searchPlayers` → `mz_core:SearchCharacters` | JOGADORES (filtro/busca/paginação) | PRESERVADA (offline read) |
| Ir até | `staff.players.goto` | `mz_admin:server:tabletGoto` | modal Ações | PRESERVADA (online) |
| Trazer | `staff.players.bring` | `mz_admin:server:tabletBring` | modal Ações | PRESERVADA (online) |
| Espectar | `staff.spectate` | `mz_admin:server:tabletSpectateStart` | modal Ações | PRESERVADA (online) |
| Curar | `staff.players.heal` | `mz_admin:server:tabletHeal` | modal Ações | PRESERVADA (online) |
| Reviver | `staff.players.revive` | `mz_admin:server:tabletRevive` | modal Ações | PRESERVADA (online) |
| Advertir | `staff.warns.issue` | `mz_admin:server:issueWarning` | modal Ações | PRESERVADA (online) |
| Kick | `staff.players.kick` | `mz_admin:server:tabletKick` | modal Ações | PRESERVADA (online) |
| Banir | `staff.players.ban` | `mz_admin:server:createBan` | modal Ações/Punições | PRESERVADA (online) |
| Informações | `staff.players.list` | `ResolvePlayerIdentity` + `GetCharacterByCitizenId` | modal Informações | NOVA (read) |
| Personagens | `staff.players.list` | `mz_core:GetCharactersForAccount` | modal Personagens | NOVA (offline read) |
| Histórico | `staff.warns.view`/`staff.bans.view` | `listWarnings`/`listBans` (filtro citizenid) | modal Histórico | NOVA (read) |
| Segurança | `mz_banguard.alerts.view` | `securityIncidentList({player=})` | modal Segurança | NOVA (read) |
| Punições (revogar) | `staff.bans.revoke` | `revokeBan` (Public ID) | modal Punições | NOVA (read + revoke) |

### ADMIN (árvore canônica do `/admin`)

| Módulo | Capabilities | Owner/callback real | Destino | Estado |
|---|---|---|---|---|
| Veículos temporários (criar/reparar/tune/remover) | `staff.vehicles.*` | comandos `/car /fix /tuning /dv` | ADMIN | PRESERVADA |
| Garagens persistentes | `staff.garages.*` | `MZAdminGarageWizard` | ADMIN | PRESERVADA |
| Mundo e cenários (portas/props/móveis/tomadas) | `staff.world.*`,`staff.furniture.*` | `MZAdminWorld` | ADMIN | PRESERVADA |
| Organizações | `staff.orgs.*` | `/stafforg` | ADMIN | PRESERVADA |
| Equipe Staff | `staff.roles.manage` | `MZAdminStaffManagement` | ADMIN | PRESERVADA |
| Banimentos (view/revogar) | `staff.bans.view/revoke` | `MZAdminBans` | ADMIN | PRESERVADA |
| Desbanir por Public ID | `staff.bans.revoke` | `MZAdminBans.PromptRevoke` | ADMIN | PRESERVADA |
| Whitelist | `staff.whitelist.*` | `MZAdminWhitelist` | ADMIN | PRESERVADA |
| Advertências | `staff.warns.*` | `MZAdminWarnings` | ADMIN | PRESERVADA |
| Central de Alertas (Banguard) | `mz_banguard.alerts.*` | `MZAdminSecurityAlerts` | ADMIN | PRESERVADA |
| Logs administrativos | `staff.logs.view` | `MZAdminLogs` | ADMIN | PRESERVADA |
| Armas nativas | `staff.weapons.*` | comandos `/arma /armas /limpararmas` | (não exposto; nativo desligado por padrão `Debug=false`) | PRESERVADA como comando |

## Bloqueios / pendências identificadas

1. **Ações em tempo real para offline**: goto/bring/spectate/heal/revive/kick **proibidas** offline (source inexistente). Ban/warn/revoke offline somente via contrato canônico de alvo persistente (`revokeBan` por Public ID já existe; ban/warn offline NÃO têm endpoint — ficam desabilitados no modal, nunca mock).
2. **Personagens offline** dependem de `accountId` persistido; disponível quando o owner já fornece `accountId`/`characterId` e a capability de leitura. Usar `GetCharactersForAccount` (leitura) — NÃO criar SQL/facade em mz_core.
3. **Histórico/Segurança** são leitura via contratos existentes; sem dados = empty state explícito, sem fabricar.

## Riscos de regressão monitorados

- Foco NUI único; ESC fecha modal → página → interface; TAB alterna MAIN→JOGADORES→ADMIN quando aberto e abre quando fechado.
- Menus contextuais comuns de outros `mz_*` intactos (mz_menu continua expondo o mesmo contrato de contexto).
- `mz_core`, `mz_banguard`, canaries, schema: intocados.
