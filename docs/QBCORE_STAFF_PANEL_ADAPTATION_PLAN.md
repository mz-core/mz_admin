# Plano de adaptação do painel Staff QBCore

## Referência analisada

O material em `ref/painelstaff` foi tratado como referência de produto. Seu código não deve ser copiado como uma segunda framework porque depende de:

- `qb-core`;
- `mz_perm`;
- callbacks e comandos QBCore;
- `qb-inventory`;
- `qb-clothing` e `qb-ambulancejob`;
- `QBCore.Shared.Vehicles`;
- tabelas próprias de ban, warn, logs, reports e duty;
- `player_vehicles` e campos específicos do ecossistema QB.

## Princípios da adaptação

1. `mz_core` continua autoridade de identidade, player, inventário, organização e veículos persistidos.
2. `mz_admin` coordena ferramentas Staff e permissões globais, sem virar uma segunda framework.
3. `mz_menu` permanece somente visual.
4. Banimentos pertencem ao BanGuard quando o resource for incorporado e possuir integração explícita.
5. Ações sobre Staff precisam conhecer hierarquia antes de permitir punições ou controle invasivo.
6. Toda ação client-originated é revalidada no servidor.
7. Nenhuma tabela da referência é criada automaticamente.

## Matriz

| Recurso da referência | Decisão MZ | Motivo |
| --- | --- | --- |
| lista de players online | adaptar agora | leitura mínima pode usar natives servidor e DTO sem dados sensíveis |
| goto, bring, heal e revive | reutilizar | já existem protegidos no `mz_admin` |
| noclip e coordenadas | reutilizar | já existem protegidos |
| spawn, repair e delete temporário | reutilizar | já existem; não persistem garagem/propriedade |
| spectate com retorno e bucket | adaptado | guard oficial, bucket server-side, retorno, cleanup e auditoria |
| freeze, kill e entrar no veículo | após hierarquia | ação invasiva sobre alvo |
| wall | adaptado | permissão própria, snapshot mínimo, auditoria e revalidação contínua |
| logs administrativos | adaptado | reutiliza `mz_core:ListGlobalLogsSecure`; nenhuma tabela QB foi copiada |
| names e blips | após hierarquia/duty | observabilidade invasiva e potencial custo de rede |
| dimensão/routing bucket | integrar com contrato próprio | buckets pertencem aos resources que criam instâncias |
| kick individual | adaptado | hierarquia, motivo, auditoria fail-closed e `DropPlayer` server-side |
| kickall | adiar | ação massiva exige confirmação e política própria |
| ban/unban | fluxo principal aprovado; negativos pendentes | tabelas ausentes autocriadas; schemas existentes nunca recebem `ALTER` automático |
| whitelist de entrada | fluxo principal aprovado em runtime | domínio próprio, hash de license, gate coordenado pelo BanGuard e gestão no `/admin`; falhas/concorrência pendentes |
| warns | projetar domínio próprio | não existe autoridade atual |
| reports/chat de suporte | projetar domínio próprio | exige persistência, concorrência, claim e retenção |
| staff chat/announce | lote separado | exige política de audiência, rate limit e auditoria |
| duty e estatísticas Staff | depois da hierarquia | não reutilizar duty organizacional |
| gestão de cargos Staff | domínio Staff próprio | permissões globais nunca vêm de membership organizacional |
| inventário de outro player | bloquear por enquanto | export visual atual não é contrato administrativo de inspeção |
| menu de roupa de outro player | bloquear por enquanto | `mz_clothing` não expõe contrato Staff equivalente |
| dar armas/setammo | rejeitar no fluxo nativo | deve respeitar inventário e ownership do `mz_core` |
| salvar veículo em `player_vehicles` | rejeitar | tabela e ownership QB não existem no MZ |
| maxmods/setmodel/setspeed/NUI focus | adiar | ferramentas dev invasivas, sem necessidade operacional atual |

## Primeiro lote aplicado

O `/admin` recebeu um diretório read-only de players online:

- exige `staff.players.list`;
- retorna somente `source`, nome de sessão, ping e marcador do próprio Staff;
- retorna CitizenID resolvido pelo `mz_core`, mas não retorna license, identifiers, telefone, dinheiro, inventário, coordenadas ou organizações;
- ordena por source;
- detalhes reutilizam somente goto, bring, heal e revive já existentes;
- o alvo é revalidado novamente no evento servidor da ação.

## Lote de garagens aplicado

A criacao persistente nao reutiliza `player_vehicles` nem contratos QBCore. O `mz_admin` oferece somente o assistente, enquanto `mz_garagem` possui a tabela, a validacao, o export, a auditoria e a sincronizacao. Garagens estaticas continuam preservadas.

## Próxima ordem

1. validar em staging os casos negativos de ban/unban, hierarquia e rollback transacional;
2. validar allowlists/limites dos exports de risco e os comandos históricos endurecidos;
3. validar a criação de banco vazio e a recusa segura de schema antigo incompleto;
4. validar runtime completo do módulo de logs no `/admin` e o isolamento do `/stafforg`;
5. conferir os logs ainda pendentes de bring/heal/revive e spectate;
6. decidir reports/warns/duty em lotes independentes.

Estado em 2026-07-28: diretório de players, garagem persistente, wall, hierarquia de bring/heal/revive, spectate e kick tiveram runtime principal informado como aprovado. Ban e unban principais também foram aprovados pelo usuário. Casos negativos, falhas transacionais e o novo endurecimento de exports/comandos históricos ainda aguardam runtime.
# Adaptação concluída: advertências

O conceito visual de advertências da referência foi adaptado para `mz_warns`, sem copiar o domínio QBCore. A implementação usa identidade e hierarquia do `mz_core`, Public ID estável, status ativo/revogado e auditoria por revisão.

Foram rejeitados explicitamente: license bruta, tabela `player_warns`, hard delete, remoção por índice visual e punição automática. Consulte `mz_warns/docs/ARCHITECTURE_IMPLEMENTATION_LOT_1.md`.
