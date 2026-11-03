# Contrato de segurança e menu do `mz_admin`

## Autoridade

Toda autorização administrativa vem de:

```lua
exports['mz_core']:HasGlobalPermission(source, permission)
```

Falha do resource, erro no export, ação desconhecida ou resposta diferente de `true` resultam em negação. `HasPermission` organizacional não é usado. Membership, grade, duty e capability de organização não concedem acesso ao `mz_admin`.

## Matriz de ações

| Ação interna | Permissão global |
| --- | --- |
| `menu` | `staff.panel.open` |
| `loc` | `staff.coords.copy` |
| `noclip` | `staff.noclip` |
| `wall` | `staff.wall` |
| `spectate` | `staff.spectate` |
| `tp`, `tpm` | `staff.teleport` |
| `playersList` | `staff.players.list` |
| `gotoPlayer` | `staff.players.goto` |
| `bringPlayer` | `staff.players.bring` |
| `kick` | `staff.players.kick` |
| `ban` | `staff.players.ban` |
| `banView` | `staff.bans.view` |
| `banRevoke` | `staff.bans.revoke` |
| `heal` | `staff.players.heal` |
| `revive` | `staff.players.revive` |
| `armor` | `staff.players.armor` |
| `godMode` | `staff.players.godmode` |
| `deleteVehicle` | `staff.vehicles.delete` |
| `spawnVehicle` | `staff.vehicles.spawn` |
| `fixVehicle` | `staff.vehicles.repair` |
| `tuneVehicle` | `staff.vehicles.tune` |
| `garageView` | `staff.garages.view` |
| `garageCreate` | `staff.garages.create` |
| `garageManage` | `staff.garages.manage` |
| `staffManage` | `staff.roles.manage` |
| `logsView` | `staff.logs.view` |
| `weapon` | `staff.weapons.give` |
| `weaponKit` | `staff.weapons.kit` |
| `clearWeapons` | `staff.weapons.clear` |

O mapa canônico está em `shared/permissions.lua`. Essas permissões são contratos globais do `mz_admin`; podem ser atribuídas por ACE explícito, override global oficial ou cargo Staff persistente do `mz_core`. Um override `deny` continua prevalecendo sobre o cargo.

## Fluxos

### Ação local

1. o client solicita `mz_admin:server:authorizeAction`;
2. o servidor valida a ação contra allowlist fixa;
3. o servidor consulta `HasGlobalPermission`;
4. apenas uma resposta `ok = true` permite executar a ação local.

Não existe fallback permissivo quando callback, `ox_lib` ou `mz_core` estiver indisponível.

### Ação sobre outro player

`gotoPlayer`, `bringPlayer`, `kickPlayer`, `healPlayer` e `revivePlayer` são autorizados novamente dentro do evento servidor. IDs são normalizados e o alvo deve estar online.

Em `bringPlayer`, posição e heading são obtidos pelo servidor com o ped do Staff. Parâmetros antigos de coordenadas enviados por clientes são ignorados.

Bring, kick, heal e revive consultam `mz_core:CanStaffActOnPlayer`. Player comum pode ser alvo; Staff exige nível estritamente inferior; Owner é protegido; contexto ausente falha fechado. Goto não usa o guard porque movimenta apenas o ator.

Cada tentativa gera log `admin.player.<ação>.authorized|denied`. Uma autorização não é despachada se `CreateDetailedLog` falhar. Heal/revive em si também passam pelo servidor e pela auditoria.

Kick exige motivo entre 3 e 256 caracteres, nega self-target e só executa `DropPlayer` depois de persistir `admin.player.kick.authorized`. O motivo sanitizado fica no campo `message` do log.

Ban online exige `staff.players.ban` e usa o guard hierárquico novamente dentro do `mz_banguard`. O `mz_admin` não persiste punições nem chama comandos por string. O BanGuard grava ban, identifiers, tokens e auditoria na mesma transação e só então remove o alvo.

### Noclip

O servidor mantém o estado oficial usado por `IsPlayerInNoClip`. O callback de alternância exige `staff.noclip`. O evento legado `mz_admin:server:requestNoClip` foi preservado, mas agora segue a mesma validação fail-closed.

### Wall

O callback `mz_admin:server:toggleWall` exige `staff.wall`. A ativação só ocorre depois que `admin.wall.enabled` é persistido; falha de auditoria cancela o fluxo. Desativação, negação e revogação geram `admin.wall.disabled`, `admin.wall.denied` e `admin.wall.revoked`.

Enquanto ativo, o servidor revalida a permissão periodicamente e interrompe o envio quando ela é revogada. O snapshot contém ID de sessão, CitizenID resolvido pelo `mz_core`, nome de sessão, coordenadas, routing bucket e marcador Staff genérico. License, identifiers, dinheiro, inventário, organizações e permissões não pertencem ao DTO.

Dados de vida, colete, veículo e estado armado são lidos pelo próprio client somente quando o ped já está streamado. O contrato completo está em `WALL_CONTRACT.md`.

### Spectate

`/spectate ID` exige `staff.spectate`, alvo online e aprovação de `CanStaffActOnPlayer`. O próprio ator, Owner e Staff de nível igual ou superior são negados. `/specoff` sempre pode encerrar uma sessão pertencente ao solicitante, mesmo depois de revogar a permissão.

O servidor captura posição, heading e routing bucket originais, move somente o observador para o bucket do alvo e envia as coordenadas oficiais do ped observado. O client não escolhe buckets. Permissão e hierarquia são revalidadas periodicamente.

Início e troca de alvo são fail-closed em relação à auditoria. Encerramento, revogação e perda do alvo sempre priorizam restaurar o observador. O contrato completo está em `SPECTATE_CONTRACT.md`.

## Shell `/admin`

O `mz_admin` possui NUI própria e não depende de `mz_menu`. A sidebar mostra apenas módulos concedidos no contexto retornado pelo servidor. `INÍCIO` concentra as ferramentas pessoais e de acesso rápido; `JOGADORES` é o caminho canônico para busca, perfil e ações individuais; cada domínio autorizado (`Mundo e cenários`, `Veículos e garagens`, `Organizações e equipe`, `Moderação e acesso`, `Auditoria`, `Segurança - Central de Alertas`) possui uma única entrada direta na rail. Se uma seção não possui opção autorizada, ela não é registrada nem exibida.

As opções atravessam a fronteira Lua/NUI somente com payload serializável (`event`, `args` e `menu`). Funções Lua em `onSelect` não chegam ao browser. O evento local `mz_admin:client:menuAction` aceita apenas uma allowlist fixa; cada comando selecionado continua passando pela autorização oficial.

O atalho de organizações executa o comando configurado em `Config.StaffOrganizationCommand`. Isso não delega autoridade: `mz_org` abre uma sessão própria e revalida as permissões globais.

### Logs administrativos

`Logs administrativos` aparece somente com `staff.logs.view`. O callback do `mz_admin` normaliza uma allowlist fixa de filtros e delega a leitura a `mz_core:ListGlobalLogsSecure`, que revalida a mesma permissão e aplica `org_code IS NULL`.

O módulo é read-only, usa páginas de 25 itens e aceita busca, categoria, severidade, ação, ator, período, Audit ID e modo `auditOnly`. `orgCode`, campos desconhecidos e limites escolhidos pelo client são descartados.

Logs por organização continuam no contexto da organização em `/stafforg` e `/org`. O contrato completo está em `ADMIN_LOGS_CONTRACT.md`.

### Banimentos

O módulo aparece somente quando `mz_banguard` está iniciado, `IsReady()` confirma schema e core, e o ator possui a permissão da ação. Criar, consultar e revogar usam exports server-side explícitos.

`staff.players.ban` bane somente player online elegível pela hierarquia. `staff.bans.view` retorna DTO sanitizado. `staff.bans.revoke` é independente e exige Public ID e motivo. O menu nunca recebe identifiers, tokens, IP, evidence, identificador do Staff ou IDs internos.

A seção `Moderação e acesso` oferece `Desbanir por Public ID` para quem possui `staff.bans.revoke`. A mesma ação permanece disponível nos detalhes de um ban ativo em `Banimentos`; ambos os caminhos usam o mesmo callback protegido.

O BanGuard é a autoridade de persistência, auditoria, enforcement, webhook e cloud. `mz_admin` acrescenta logs globais `admin.ban.create|revoke.completed|denied`, mas a auditoria transacional do BanGuard é a evidência autoritativa. Veja `mz_banguard/docs/INTEGRATION_API_CONTRACT.md`.

### Criacao de garagens

O modulo aparece quando existe permissao de visualizar ou criar e `mz_garagem:IsManagedGarageReady()` retorna `true`. `staff.garages.manage` nao implica `view`; um gestor de interface deve receber ambos explicitamente.

O assistente cria ou edita um rascunho local em etapas, captura entrada, spawn e armazenamento e delega a mutacao aos exports oficiais do `mz_garagem`. `mz_admin` nao escreve no banco nem em configuracao organizacional. A permissao global e todos os campos sao revalidados pelo resource de destino.

A listagem inclui somente garagens persistentes; definicoes estaticas permanecem protegidas. Arquivar e reativar nao excluem linhas.

O seletor organizacional vem do contrato oficial `mz_core:ListOrgs()` e expoe somente codigo, nome e tipo de organizacoes ativas. O `mz_garagem` consulta novamente `GetOrgByCode` no momento da gravacao.

O contrato persistente completo esta em `mz_garagem/docs/MANAGED_GARAGE_CONTRACT.md`.

### Hierarquia Staff

`Gerenciar equipe Staff` consome somente os exports oficiais do `mz_core`. O shell nao grava cargos, permissoes ou atribuicoes diretamente.

Owner e o bootstrap. Gestores delegados so recebem cargos e alvos inferiores, nao podem gerenciar a si mesmos nem conceder permissoes ausentes no proprio contexto. O contrato completo esta em `mz_core/docs/STAFF_HIERARCHY_CONTRACT.md`.

Os cargos `suporte`, `moderador`, `administrador` e `gerente_staff` são criados pelo `mz_core` somente quando ausentes. Nenhuma atribuição é automática e o Staff Supremo permanece exclusivamente no ACE de owner.

A fundação protege o próprio domínio Staff, bring/heal/revive, wall, spectate, kick e ban online. Ban depende de instalação manual e validação runtime do `mz_banguard`; validação estática não autoriza uso em produção.

### Diretório de players

`mz_admin:server:listOnlinePlayers` retorna source, CitizenID resolvido pelo `mz_core`, nome de sessão, ping e indicador do próprio solicitante. License, identifiers, telefone, contas, coordenadas, inventário e memberships não fazem parte desse DTO.

Selecionar um player apenas cria atalhos para ações já existentes. O diretório não concede autoridade adicional, e cada ação revalida permissão e presença online no servidor.

## Compatibilidade

- comandos existentes preservados;
- comandos `/ban` e `/unban` registrados somente pelo BanGuard; o menu do `mz_admin` usa a API oficial sem handler concorrente;
- export servidor `IsPlayerInNoClip` preservado;
- novo export servidor `IsPlayerUsingWall`;
- novos exports servidor `IsPlayerSpectating` e `GetSpectateTarget`;
- eventos globais antigos de logs do `mz_org` preservados para compatibilidade, sem entrada no root `/stafforg`;
- evento servidor `mz_admin:server:requestNoClip` preservado;
- eventos client existentes de teleporte, cura, revive e autorização de noclip preservados;
- comandos nativos de arma continuam desligados por padrão.

O novo export client `OpenAdminMenu` abre o mesmo fluxo protegido de `/admin`.

### Whitelist de entrada

O módulo opcional usa `mz_whitelist` como autoridade. `mz_admin` não acessa suas tabelas nem controla `playerConnecting`; ele apenas lista DTOs sanitizados e encaminha decisões pelos exports `ListEntries` e `Decide`.

O root mostra Whitelist somente quando o resource está pronto e o ator possui `staff.whitelist.view`. Aprovar, recusar ou revogar exige `staff.whitelist.manage` no `mz_admin` e nova validação dentro do `mz_whitelist`. A lista é paginada e não contém license ou hash.
# Integração de advertências

O módulo opcional `mz_warns` é descoberto pelo contexto do menu por `IsReady`. O `mz_admin` não consulta suas tabelas e não replica suas regras.

- `staff.warns.view`: lista global ou contextual;
- `staff.warns.issue`: emissão contra player online, sujeita a hierarquia;
- `staff.warns.revoke`: revogação com motivo e revisão persistente.

O bridge revalida a ação no `mz_admin` e a API de `mz_warns` revalida novamente a permissão, o alvo e o payload. Advertências não causam kick ou ban automático.
