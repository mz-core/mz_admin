# Prontidão da integração com BanGuard

## Estado atual

O pacote histórico permanece em:

```text
mz_banguard_complete/fivem-resource/mz_banguard
```

Uma cópia explícita e evoluída foi incorporada como resource local canônico:

```text
mz_banguard
```

O resource 1.2 adiciona os exports oficiais:

```text
IsReady
CreateOnlineBan
RevokeBan
GetBan
ListBans
```

Os exports anteriores `FlagPlayer`, `RegisterTrustedAction` e `GetRiskScore`, assim como os comandos ACE históricos, foram preservados.

## Integração aplicada

O `mz_admin`:

- não chama comandos por string;
- não acessa globals internos;
- não escreve nas tabelas do BanGuard;
- só mostra ban/unban quando `mz_banguard:IsReady()` retorna `true`;
- pré-valida a permissão Staff e delega a revalidação definitiva ao BanGuard;
- usa `staff.players.ban`, `staff.bans.view` e `staff.bans.revoke`;
- recebe somente DTOs sem identifiers, tokens, IP, evidence ou IDs internos.

O BanGuard restringe callers por `Config.Integration.TrustedResources`, exige `mz_core`, revalida a permissão global e usa `CanStaffActOnPlayer` na criação online. O `mz_admin` encaminha `expectedCitizenid`; o BanGuard confere CitizenID e identifiers antes da transação e imediatamente antes de `DropPlayer`. Persistência e auditoria de criação/revogação são transacionais. Se o source for reutilizado após o commit, o ban permanece verdadeiro e a desconexão é cancelada/auditada.

O contrato completo está em `mz_banguard/docs/INTEGRATION_API_CONTRACT.md`.

## Bloqueio runtime real

A integração está concluída estaticamente, mas não está aprovada em runtime.

Antes de iniciar o resource:

1. revisar os SQLs em `mz_banguard/sql`;
2. usar somente staging descartável;
3. em banco vazio, observar a criação automática apenas das tabelas ausentes;
4. em schema existente incompleto, aplicar upgrade somente depois de revisão manual;
5. manter `AutoCreateMissingTables = true` e `AutoMigrateExistingTables = false`;
6. manter retenção, cloud, webhook e autoban desativados;
7. executar `mz_banguard/docs/RUNTIME_CHECKLIST.md`.

Nenhuma migration foi executada nesta implementação e nenhum `ensure` foi adicionado automaticamente.

## Ações proibidas

- copiar tabelas do BanGuard para `mz_core` ou `mz_admin`;
- executar comandos por string como integração em vez de usar os exports oficiais;
- assumir que ACE `mzban.*` equivale a permissões `staff.*`;
- habilitar `AutoMigrateExistingTables` sem revisão e backup;
- habilitar cloud, retenção ou autoban automaticamente;
- expor identifiers, tokens ou IP no menu Staff;
- marcar runtime como aprovado apenas pelos harnesses estáticos.
