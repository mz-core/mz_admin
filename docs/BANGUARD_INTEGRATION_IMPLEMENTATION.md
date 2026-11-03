# Implementação da integração BanGuard

## Entrega local

Data: 2026-07-27.

O resource canônico `mz_banguard` 1.2 foi incorporado no diretório raiz a partir do pacote existente. O pacote histórico em `mz_banguard_complete` foi preservado.

Foram adicionados:

- API server-side protegida para prontidão, criação online, revogação, consulta e listagem;
- allowlist de resource chamador;
- revalidação de permissões `mz_core`;
- guard hierárquico para ban online;
- DTO público sem dados sensíveis;
- transações contendo persistência e auditoria;
- ponte opcional no `mz_admin`;
- `/ban`, `/unban` e menus compartilhados;
- permissões granulares e templates iniciais;
- documentação e checklists runtime.

Compatibilidade mantida:

- comandos históricos do BanGuard, agora com permissão global/hierarquia para jogadores e ACE adicional opcional;
- nomes e assinaturas de `FlagPlayer`, `RegisterTrustedAction` e `GetRiskScore`, agora com allowlist por operação;
- kick não persistente do `mz_admin`;
- cargos Staff já existentes não são sobrescritos pelo seed;
- `/admin` continua funcional sem BanGuard, apenas ocultando o módulo.

## Segurança

- `mz_admin` não acessa SQL do BanGuard;
- nenhuma integração usa `ExecuteCommand`;
- somente tabelas totalmente ausentes são criadas automaticamente;
- tabelas existentes nunca recebem `ALTER` com a configuração padrão;
- retenção, cloud, webhook e autoban não são habilitados automaticamente;
- sem schema, `IsReady` falha e novas conexões falham fechado;
- o alvo só é removido depois do commit de ban + auditoria;
- falha transacional de criação não chama `DropPlayer`;
- revogação exige permissão separada;
- identifiers, tokens e IP nunca entram nos DTOs do menu.
- resources não autorizados não conseguem criar flags, abrir janelas confiáveis ou ler score;
- limites server-side restringem pontos, duração e evidência;
- `/banlookup` com identifier bruto é exclusivo de console/Owner por padrão;
- `/ban`, `/unban`, `/baninfo`, `/banflags` e `/banlookup` usam nomes comunitários e são registrados somente pelo BanGuard;
- caminhos de console preservam persistência e auditoria na mesma transação.

## Validação estática executada

- `luac -p`: 25 arquivos Lua criados/alterados, aprovado;
- `node --check`: nenhum JavaScript existente nesses três resources;
- 19 harnesses de BanGuard, whitelist, admin, Staff, garagem e organizações, aprovados;
- trailing whitespace, aprovado;
- ausência de React/Vite/TS/TSX/JSX, aprovada;
- ausência de SQL do BanGuard em código runtime do `mz_admin`, aprovada.

O `luac` global do `mz_core` encontra sintaxe FiveM preexistente com backticks em `client/inventory.lua` e `server/vehicles/debug.lua`; esses arquivos não foram alterados. A validação obrigatória dos arquivos deste lote passou.

## Runtime pendente

O fluxo principal de ban e unban foi aprovado em runtime pelo usuário em 2026-07-28. Casos negativos, hierarquia, auditoria, falha de banco e o endurecimento dos exports/comandos históricos continuam pendentes e não podem ser marcados como aprovados.

Seguir, em staging descartável:

1. `mz_banguard/docs/RUNTIME_CHECKLIST.md`;
2. `mz_admin/docs/RUNTIME_CHECKLIST.md`;
3. registrar Public IDs e auditorias sem copiar identifiers/tokens para evidências.

## Comandos estáticos

```powershell
lua mz_banguard/tests/integration_contract_harness.lua
lua mz_banguard/tests/database_bootstrap_harness.lua
lua mz_banguard/tests/ban_state_contract_harness.lua
lua mz_banguard/tests/risk_export_access_harness.lua
lua mz_banguard/tests/legacy_commands_contract_harness.lua
lua mz_admin/tests/banguard_bridge_harness.lua
lua mz_admin/tests/security_contract_harness.lua
lua mz_core/tests/staff_default_roles_harness.lua
luac -p mz_banguard/server/api.lua
luac -p mz_admin/server/bans.lua
luac -p mz_admin/client/bans.lua
```
