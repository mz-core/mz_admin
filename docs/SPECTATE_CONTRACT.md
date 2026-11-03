# Contrato do spectate administrativo

## Autoridade

O spectate pertence ao `mz_admin` e exige a permissão global `staff.spectate`. Membership, grade, duty ou capability organizacional não concedem acesso.

O início exige:

1. ator e alvo online;
2. alvo diferente do próprio ator;
3. `HasGlobalPermission(source, 'staff.spectate')`;
4. aprovação de `mz_core:CanStaffActOnPlayer`;
5. peds do ator e alvo disponíveis;
6. auditoria persistida.

Player comum e Staff estritamente inferior podem ser observados. Owner e Staff de nível igual ou superior são protegidos.

## Estado oficial

O servidor mantém posição, heading e routing bucket originais, além do alvo atual. Exports:

```lua
exports['mz_admin']:IsPlayerSpectating(source)
exports['mz_admin']:GetSpectateTarget(source)
```

O client não informa coordenadas nem bucket. O servidor lê o ped oficial do alvo, move apenas o observador para o bucket necessário e envia sincronizações contextuais.

## Lifecycle

- `/spectate ID` inicia;
- repetir `/spectate` no mesmo alvo encerra;
- usar `/spectate OUTRO_ID` troca o alvo, preservando o retorno original;
- `/specoff` encerra mesmo se a permissão tiver sido revogada;
- drop do alvo encerra os observadores;
- morte ou troca de personagem do observador solicita encerramento;
- restart restaura o bucket e envia retorno antes do resource terminar.

Permissão e hierarquia são revalidadas durante a sessão. Qualquer falha encerra fail-closed e restaura o observador.

Noclip ativo bloqueia um novo spectate para evitar colisão entre dois controladores de posição.

## Estado local

Durante a sessão, o ped do observador fica invisível, invencível, congelado e sem colisão. O modo spectator usa somente o ped streamado do alvo.

No retorno, spectator mode é desligado, visibilidade, invencibilidade e colisão são restauradas e o servidor fornece posição e heading originais. A dimensão é restaurada server-side.

## Auditoria

Eventos:

```text
admin.spectate.started
admin.spectate.switched
admin.spectate.stopped
admin.spectate.denied
admin.spectate.revoked
admin.spectate.target_lost
```

Início e troca de alvo são cancelados se o log não puder ser persistido. Encerramento nunca é bloqueado por falha de log.

Coordenadas e routing buckets não são gravados nos logs.

## Limites

Intervalos são limitados no servidor:

- sincronização: 100 a 2000 ms;
- revalidação: 500 a 10000 ms.

O padrão atual usa 250 ms e 1500 ms. Spectate não concede wall, teleport, freeze, kick, ban ou inspeção de inventário.
