# Checklist runtime do `mz_admin`

Testes não executados não podem ser marcados como aprovados.

## Preparação

- [ ] Usar staging descartável, sem produção ou VPS.
- [ ] Iniciar `ox_lib`, `mz_core`, `mz_status`, `mz_org`, `mz_garagem` e `mz_admin` nessa ordem.
- [ ] Manter `Config.Debug = false` e `Config.AllowNativeWeaponCommands = false`.
- [ ] Preparar um owner, um Staff granular e um player sem permissões.

## Negativos obrigatórios

- [ ] Player comum recebe negação em `/admin`.
- [ ] Player comum recebe negação em `/noclip`, `/wall`, `/tp`, `/tpm`, `/car`, `/dv`, `/fix`, `/heal`, `/revive`, `/armor` e `/godmode`.
- [ ] Chamada direta dos eventos `gotoPlayer`, `bringPlayer`, `healPlayer`, `revivePlayer` e `requestNoClip` é negada sem permissão.
- [ ] Indisponibilidade do `mz_core` nega todas as ações.
- [ ] Membership de uma organização com capability administrativa não concede nenhuma permissão `staff.*`.
- [ ] Staff com apenas `staff.panel.open` abre o shell, mas não vê módulos de players ou veículos.
- [ ] Staff sem `staff.players.list` não acessa a lista de players online por menu nem callback direto.

## Positivos por permissão

- [ ] `staff.noclip` permite alternar noclip e `IsPlayerInNoClip` acompanha o estado.
- [x] `staff.wall` permite alternar `/wall` e `IsPlayerUsingWall` acompanha o estado.
- [x] Wall mostra ID, nome, dimensão, distância e, para peds streamados, vida, colete, veículo e estado armado.
- [ ] Wall mostra o CitizenID correto e não expõe license, identifiers, dinheiro, inventário, organizações ou permissões.
- [x] Remover `staff.wall` durante o uso desativa o wall automaticamente.
- [x] Ativação, desativação, negação e revogação aparecem nos logs `admin.wall.*`.
- [x] Falha de auditoria impede a ativação do wall.
- [x] `staff.spectate` permite `/spectate ID` e `/specoff`.
- [ ] `IsPlayerSpectating` e `GetSpectateTarget` refletem a sessão ativa.
- [x] Spectate de player comum e Staff inferior inicia e move apenas o observador para o bucket do alvo.
- [x] Spectate de si mesmo, Owner, Staff igual e Staff superior é negado.
- [x] `/specoff` restaura posição, heading, visibilidade, colisão e bucket originais.
- [x] Trocar diretamente para outro alvo preserva o ponto de retorno original.
- [x] Revogar `staff.spectate` durante a sessão encerra e restaura o observador.
- [x] Drop do alvo, morte/troca de personagem do observador e restart encerram com cleanup.
- [x] Noclip ativo impede iniciar spectate.
- [ ] `admin.spectate.started|switched|stopped|denied|revoked|target_lost` aparecem nos logs.
- [ ] Falha de auditoria impede início e troca de alvo.
- [ ] Staff sem `staff.logs.view` não vê `Logs administrativos` e o callback direto é negado.
- [ ] `staff.logs.view` mostra `Auditoria` no root e `Logs administrativos` dentro da seção.
- [ ] A listagem retorna somente escopo global; eventos com `org_code` não aparecem.
- [ ] Busca, categoria, severidade, ação, ator, período, Audit ID e `auditOnly` filtram corretamente.
- [ ] Página anterior/próxima preserva os filtros e usa 25 itens.
- [ ] Campo `orgCode`, limite arbitrário e campos desconhecidos enviados diretamente são ignorados.
- [ ] `/stafforg` não mostra mais `Logs globais` ou `Auditoria global` no root.
- [ ] Inspeção de uma organização no `/stafforg` continua mostrando Logs/Auditoria daquela organização.
- [ ] `staff.teleport` permite `/tp` e `/tpm`, sem conceder ações sobre outros players.
- [ ] `staff.players.goto`, `bring`, `heal` e `revive` liberam somente suas ações correspondentes.
- [ ] `Players online` mostra somente ID, nome e ping, ordenados por ID.
- [ ] Selecionar player desconectado antes da ação falha fechado no servidor.
- [ ] `bring` usa a posição real do Staff mesmo se um cliente antigo enviar coordenadas extras.
- [x] Bring/heal/revive permitem player comum e Staff inferior.
- [x] Bring/heal/revive negam Staff igual, superior e Owner.
- [ ] Cada autorização/negação gera `admin.player.<acao>.authorized|denied`.
- [ ] Falha de auditoria cancela a ação autorizada.
- [ ] Staff sem `staff.players.kick` recebe negação em `/kick ID motivo`.
- [x] `staff.players.kick` remove player comum e Staff inferior com a mensagem informada.
- [ ] Kick de si mesmo é negado.
- [x] Kick de Staff igual/superior e Owner é negado.
- [x] Motivo vazio ou menor que 3 caracteres é recusado.
- [x] `admin.player.kick.authorized|denied` aparece nos logs com o motivo sanitizado.
- [ ] Falha de auditoria cancela o kick e mantém o alvo conectado.
- [ ] Sem `mz_banguard`, sem schema ou com `IsReady() = false`, opções de ban/unban não aparecem.
- [ ] Staff sem `staff.players.ban` não vê ban e chamada direta de `/ban` é negada.
- [ ] `staff.players.ban` bane player comum e Staff inferior online com duração e motivo.
- [ ] Ban de si mesmo, Owner, Staff igual e Staff superior é negado.
- [ ] Duração inválida/acima do limite, motivo curto, alvo offline e ban já ativo são negados.
- [ ] Falha transacional no BanGuard não remove o alvo nem deixa ban parcial.
- [ ] Staff sem `staff.bans.view` não lista/consulta por menu ou callback direto.
- [ ] Lista de bans filtra ativo/revogado, busca Public ID/nome e pagina em 25 itens.
- [ ] DTO de ban não expõe identifiers, tokens, IP, evidence ou IDs internos.
- [ ] Staff sem `staff.bans.revoke` não vê nem executa revogação.
- [ ] `Desbanir por Public ID` aparece em `Moderação e acesso` somente com `staff.bans.revoke`.
- [x] `Desbanir por Public ID` revoga um ban ativo com código e motivo válidos.
- [ ] `staff.bans.revoke` revoga Public ID válido com motivo; inválido/inexistente/já revogado falha fechado.
- [ ] `ban.created|revoked.integration` existe no BanGuard e `admin.ban.create|revoke.completed|denied` aparece nos logs administrativos.
- [ ] `staff.vehicles.spawn`, `repair`, `tune` e `delete` liberam somente suas ações correspondentes.
- [ ] `staff.garages.create` mostra o assistente somente quando o repositorio do `mz_garagem` esta pronto.
- [ ] `staff.garages.view` mostra a listagem sem conceder mutacoes.
- [ ] `staff.garages.manage` junto de `view` permite editar, reposicionar, arquivar e reativar.
- [ ] Sem `staff.garages.create`, callback e export de criacao falham fechados.
- [ ] O modo de posicionamento libera movimento/veiculo, alterna trava com `G`, captura com `E`, cancela com `X` e reabre o rascunho automaticamente.
- [ ] Captura, cancelamento e restart sempre removem a trava criada pelo assistente.
- [ ] Garagem publica criada aparece sem restart e reaparece depois de reiniciar `mz_garagem`.
- [ ] Garagem organizacional revalida organizacao ativa e membership no servidor.
- [ ] Nome vazio recebe label padrao e o mesmo texto no blip.
- [ ] `staff.roles.manage` mostra a gestao hierarquica.
- [ ] Owner encontra os quatro cargos padrão, personaliza permissões e atribui por CitizenID.
- [ ] Staff delegado administra somente niveis inferiores e nao concede permissoes que nao possui.
- [ ] `staff.orgs.view` junto de `staff.panel.open` mostra o atalho de organizações.
- [ ] O atalho abre o Staff Menu e o `mz_org` ainda nega qualquer módulo não concedido.

## Interface e regressão

- [ ] A rail mostra `INÍCIO`, `JOGADORES` e no máximo os domínios autorizados: mundo/cenários, veículos/garagens, organizações/equipe, moderação/acesso, auditoria e segurança.
- [ ] Não existe entrada `ADMIN` intermediária nem `Ferramentas rápidas` separada.
- [ ] Uma seção sem nenhuma opção autorizada não aparece.
- [ ] Staff apenas com `staff.panel.open` vê o estado vazio e não recebe ação operacional.
- [ ] Setas, Enter e Esc funcionam no INÍCIO, em JOGADORES e nos submenus de domínio.
- [ ] `INÍCIO` executa Noclip, Wall, coordenadas e teleporte uma única vez, sem duplicar cards.
- [ ] `JOGADORES` abre a lista canônica, busca/filtros e o modal de ações, sem abrir o seletor legado.
- [ ] Esc em banimentos, whitelist, advertências, garagens, equipe Staff e logs retorna à seção de domínio correta (não ao hub antigo).
- [x] Enter em `Wall` alterna o mesmo estado do comando `/wall`.
- [ ] Enter em `Espectar o player` inicia o mesmo fluxo protegido de `/spectate ID`.
- [ ] Tema e badge Staff são aplicados e restaurados ao fechar.
- [ ] Os comandos históricos continuam registrados.
- [ ] Comandos de armas continuam bloqueados com as flags seguras.
- [ ] Reinício/drop limpa o estado de noclip no servidor.
- [x] Reinício, troca de personagem, morte ou drop limpam o estado do wall.
- [ ] O shell nao escreve diretamente no banco, em organizacao, permissao ou ban; mutacoes sao delegadas aos contratos oficiais de `mz_garagem` e `mz_banguard`.

## Evidência

Registrar para cada caso: identidade, permissões atribuídas, comando/ação, resultado esperado, resultado observado e trecho relevante do console.

Wall aprovado em runtime em 2026-07-27, conforme execução e confirmação do usuário. Os demais itens permanecem independentes e não foram inferidos como aprovados.

Guard hierárquico de bring/heal/revive aprovado em runtime contra player comum, Staff inferior, Staff igual, Staff superior e Owner em 2026-07-27, conforme confirmação do usuário. A conferência dos registros em `mz_logs` permanece separada.

Fluxo runtime do spectate aprovado em 2026-07-27 para início, encerramento, hierarquia, troca de alvo, retorno visível, cleanup e bloqueio com noclip, conforme confirmação do usuário. Exports e evidência de auditoria permanecem testes separados.

Kick aprovado em runtime em 2026-07-27 contra player comum, Staff inferior, Staff igual, Staff superior e Owner, incluindo recusa de motivo inválido e conferência dos eventos `admin.player.kick.authorized|denied` nos logs administrativos. Auto-kick, ausência da permissão e falha de auditoria permanecem testes separados.

Fluxo principal de ban e unban aprovado em runtime em 2026-07-28, incluindo criação do ban, Public ID, remoção/bloqueio do alvo, revogação pelo `/admin` e reconexão após o unban. Hierarquia Staff, ausência de permissões, payloads inválidos e falhas transacionais permanecem testes independentes.

Os comandos canônicos `/ban` e `/unban` foram aprovados pelo operador em 2026-07-28 sem execução duplicada observada. O módulo de whitelist possui checklist próprio em `mz_whitelist/docs/RUNTIME_CHECKLIST_LOT_1.md` e ainda não está aprovado em runtime.

O carregamento e a abertura do módulo Whitelist no `/admin` foram aprovados pelo operador em 2026-07-28 após o guard de disponibilidade do builder client. Naquele aceite inicial, os fluxos funcionais ainda permaneciam separados.

O fluxo funcional principal da whitelist foi aprovado pelo operador em 2026-07-29, incluindo `observe`, aprovação, `enforce`, bloqueios por estado, reaprovação e bypass do Owner. Casos negativos de permissão/resource, concorrência e falhas de banco permanecem no checklist próprio.
# Advertências (`mz_warns`)

- [ ] Executar integralmente `mz_warns/docs/RUNTIME_CHECKLIST_LOT_1.md`.
- [ ] Confirmar que o `/admin` continua abrindo quando `mz_warns` estiver parado.
- [ ] Confirmar permissões independentes de consulta, emissão e revogação.
- [ ] Confirmar que advertências não executam kick ou ban automático.

- [ ] `/tuning` aplica upgrades de performance no máximo e randomiza apenas a parte visual do veículo atual/próximo.
