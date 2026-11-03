# Contrato de interação e movimento do contexto

## Objetivo

O painel unificado da NUI própria possui dois modos de entrada independentes da seção aberta:

- **movimento liberado**: o menu continua utilizável e o jogador pode andar ou dirigir;
- **movimento travado**: o menu continua utilizável, mas os controles do jogo não recebem input.

`F6` abre o painel no modo liberado e, enquanto ele estiver aberto, alterna somente entre
movimento livre e bloqueado sem alterar sua visibilidade. `TAB` e `/mztablet` abrem no modo
bloqueado; com o painel livre, mudam para bloqueado; com o painel já bloqueado, fecham.
`/admin` e os exports/eventos administrativos existentes abrem no modo bloqueado. Todas as
entradas convergem no mesmo `MZAdminRouter`; não há segunda NUI.

## Configuração

```lua
MZAdminUIConfig.EnableMovementWhileOpen = true
MZAdminUIConfig.MovementToggleKey = 'F6'
MZAdminUIConfig.MovementEnabledByDefault = false
```

`MovementToggleKey` aceita teclas de função de `F1` a `F12`. Uma alteração exige
restart do resource para atualizar o key mapping.

`EnableFocusToggle` e `FocusToggleKey` permanecem disponíveis como aliases legados.
Novos consumidores devem usar os nomes relacionados a movimento.

## Ownership dos atalhos

Com o painel fechado, `F6` (`mz_admin_ui_movement_toggle`) e `TAB`
(`mz_admin_tablet_toggle`) abrem pelo keymapping. Com o painel aberto, o keydown
da NUI é o único owner de `F6`, `TAB` e `ESC`
(`tabletFreeToggle`/`tabletBlockedToggle`/`tabletClose`); os comandos de
keymapping ignoram o evento para não executar o toggle duas vezes. `/mztablet` e
`/admin` continuam comandos explícitos e alternam normalmente.

## Regras

- o primeiro `OpenContext` ou `ShowContext` de uma sessão usa `MovementEnabledByDefault`;
- expandir/recolher, trocar seção, filtrar ou atualizar a lista preserva o modo de entrada;
- fechar o menu encerra a sessão; a próxima abertura aplica o modo da entrada usada (`F6` livre, demais bloqueadas);
- os exports de movimento podem trocar o modo sem fechar, recriar ou desfocar o contexto;
- mouse, busca e `Esc` continuam operando o menu nos dois estados;
- focar `input`, `textarea` ou `select` suspende `SetNuiFocusKeepInput`; sair do campo restaura o modo anterior;
- `InputDialog`, `AlertDialog` e `Confirm` travam temporariamente o movimento;
- ao encerrar um diálogo, o estado anterior de movimento é restaurado;
- ataques, mira, troca/recarregamento de arma e golpes são bloqueados enquanto o movimento é repassado;
- fechar o contexto ou parar `mz_admin` sempre remove foco e `keep input`;
- o modo não congela ped ou veículo;
- o modo não cria autorização, permissão ou regra de negócio.

## Exports de movimento

```lua
exports['mz_admin']:SetMovementEnabled(true)
exports['mz_admin']:SetMovementEnabled(false)
exports['mz_admin']:ToggleMovement()
exports['mz_admin']:IsMovementEnabled()
```

Os exports antigos, inclusive os exports de foco introduzidos anteriormente,
permanecem disponíveis. No backend `ox_lib`, a alternância de movimento retorna
`unsupported_backend`.

## Posicionamento de garagens

O `G` do assistente de garagens tem outra responsabilidade: congelar temporariamente
o ped ou veículo para capturar uma coordenada precisa. Ele não substitui o controle
global de movimento do `mz_admin`.

## Teste runtime

1. Reinicie `mz_admin`; abra com `F6` e confirme que `WASD` funciona, mas ataque, mira e golpes não.
2. Digite na busca e confirme que letras não chegam ao jogo; ao sair do campo, `WASD` volta a funcionar.
3. Pressione `F6` repetidamente e confirme alternância livre/bloqueado sem fechar ou reconstruir a NUI.
4. Abra com `TAB`, `/mztablet` e `/admin`; em cada entrada, confirme movimento e ações bloqueados.
5. Com o painel aberto por `F6`, pressione `TAB`; confirme que o painel fica aberto e passa ao modo bloqueado.
6. Com o painel aberto por `TAB`, pressione `F6`; confirme que fica aberto e passa ao modo livre.
7. No modo bloqueado, pressione `TAB` novamente e confirme que o painel fecha sem cursor preso.
8. Abra novamente, pressione `Esc` e confirme fechamento e cleanup de foco/controles.
9. Abra um input ou confirmação; feche-o e confirme que o modo anterior é restaurado.
10. Revogue a permissão, troque de personagem e pare `mz_admin`; confirme cleanup de foco e controles.
