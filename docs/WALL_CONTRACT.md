# Contrato do wall administrativo

## Autoridade

O wall pertence ao `mz_admin` e exige a permissão global `staff.wall`. Membership, cargo, grade, duty ou capability de organização não concedem esse acesso.

O client nunca decide sozinho que está autorizado. `/wall` chama `mz_admin:server:toggleWall`; apenas `{ ok = true, enabled = true }` ativa a renderização.

## Estado e revalidação

O servidor mantém a lista oficial de observadores e expõe:

```lua
exports['mz_admin']:IsPlayerUsingWall(source)
```

Enquanto o wall estiver ativo, `HasGlobalPermission(source, 'staff.wall')` é consultado periodicamente. Revogação, indisponibilidade ou erro no `mz_core` encerram o estado fail-closed.

Drop e restart limpam o estado no servidor. Troca de personagem, morte e encerramento do resource solicitam cleanup pelo client.

## Dados

O snapshot servidor contém somente:

- source/ID da sessão;
- CitizenID do personagem, resolvido pelo `mz_core` e limitado a 64 caracteres;
- nome da sessão;
- coordenadas do ped;
- routing bucket;
- marcador genérico `STAFF` ou `OWNER`.

Não contém license, identifiers, tokens, IP, contas, dinheiro, inventário, organizações, cargo detalhado ou permissões. O CitizenID é enviado somente a observadores com `staff.wall`, enquanto o estado está ativo, e nunca é aceito de volta como autoridade de uma ação. `Config.Wall.citizenIdMaxLength` limita apenas a renderização para evitar sobreposição; o menu administrativo mantém o valor integral.

Vida, colete, veículo e estado armado são calculados localmente apenas para peds já streamados. Para entidades fora de stream, a interface exibe informação indisponível e não solicita dados adicionais.

`Config.Wall.showOtherBuckets` controla a visualização entre dimensões. Quando desativado, o servidor filtra o snapshot antes do envio; não é apenas um filtro visual do client.

## Auditoria

Eventos globais:

```text
admin.wall.enabled
admin.wall.disabled
admin.wall.denied
admin.wall.revoked
```

A ativação é fail-closed em relação ao log: se `admin.wall.enabled` não for persistido, o wall não inicia. Desativação nunca é bloqueada por falha de auditoria, pois reduzir observabilidade deve continuar possível.

Os logs não armazenam coordenadas nem o conteúdo do snapshot.

## Configuração segura

Intervalos são limitados no servidor:

- atualização: 100 a 2000 ms;
- revalidação de permissão: 500 a 10000 ms.

O padrão atual usa atualização a cada 250 ms e revalidação a cada 1500 ms. Ajustar distância, linhas e dimensões exige teste runtime com população representativa.

## Fora do escopo

O wall não concede spectate, teleporte, freeze, kick, ban, inventário, nomes no mapa ou blips. Ele não cria tabelas e não escreve dados de player.
