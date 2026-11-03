# Contrato dos logs administrativos

## Responsabilidades

- `mz_core`: armazenamento, sanitização, autorização e consulta estrutural;
- `mz_admin`: adaptador read-only, filtros, paginação e apresentação no `/admin`;
- `mz_org`: logs e auditoria associados a uma organização exata.

Não existe tabela, cache ou modelo de logs paralelo no `mz_admin`.

## Autorização

O módulo exige `staff.logs.view`. O fluxo possui duas validações:

1. `mz_admin` autoriza a ação interna `logsView`;
2. `mz_core:ListGlobalLogsSecure` revalida o source.

Falha, erro ou indisponibilidade em qualquer etapa resulta em negação. Membership organizacional não concede acesso.

## Escopo

O módulo chama exclusivamente:

```lua
exports['mz_core']:ListGlobalLogsSecure(source, filters)
```

O contrato oficial aplica `org_code IS NULL`. O adaptador do `mz_admin` não aceita `orgCode`; portanto não pode transformar a consulta global em consulta organizacional.

## Filtros

Campos aceitos:

- `search`, até 80 caracteres;
- `category`, até 32;
- `severity`, até 24;
- `action`, até 96;
- `actor`, até 96;
- `auditId`, até 96;
- `dateFrom` e `dateTo`, até 32;
- `auditOnly`, booleano;
- `offset`, entre 0 e 10000.

O tamanho de página é fixado pelo servidor em 25. Campos desconhecidos e limites enviados pelo client são ignorados.

## DTO

O `mz_core` devolve somente o DTO sanitizado de logs: ID, data, categoria, ação, severidade, escopo, Audit ID, nomes/CitizenIDs estruturais de ator e alvo, mensagem, motivo e metadados seguros.

Identifiers, tokens, IP, inventário, dinheiro e chaves sensíveis são removidos pelo serviço oficial antes de chegar ao `mz_admin`.

## Compatibilidade do `mz_org`

As opções `Logs globais` e `Auditoria global` não são mais montadas no root de `/stafforg`.

Permanecem preservados:

- `mz_org:server:staffListGlobalLogs`;
- `mz_org:server:staffListGlobalAudit`;
- callbacks de logs por organização;
- `MZOrgStaffLogs.OpenGlobal`;
- todos os dados em `mz_logs`.

Na inspeção de uma organização, `Logs` e `Auditoria` continuam filtrados por `org_code` exato.
