# MZ Admin — NUI própria e contratos públicos

## Ownership

`mz_admin` é o único owner da interface administrativa, dos comandos de Staff e da
orquestração das ações. A NUI é declarada em `fxmanifest.lua` e não depende de
`mz_menu`. `mz_core` continua owner de identidade, sessão, autorização global e
auditoria; `mz_banguard` continua owner de incidentes, políticas e banimentos; cada
resource de domínio continua owner de seus dados e mutações.

A interface só abre depois de `mz_admin:server:getMenuContext` confirmar
`staff.panel.open`. Enquanto aberta, a autorização é revalidada; revogação, sessão
inválida ou indisponibilidade do Core fecham a NUI e liberam o foco. Toda ação mutável
continua passando por callback/evento server-side específico e por sua capability.

## Entrada

- Comando: `/admin`.
- Atalho/comando legado controlado: `/mztablet` e keymapping configurável em
  `Config.Tablet.OpenKey`.
- Todos os entrypoints chegam ao mesmo `MZAdminRouter`; não existe fallback para
  `mz_menu`.

## Exports client

```lua
exports['mz_admin']:OpenAdminMenu()
exports['mz_admin']:CloseAdminMenu()
exports['mz_admin']:ToggleAdminMenu()
local open = exports['mz_admin']:IsAdminMenuOpen()
```

`OpenAdminMenu` não contorna autorização: ele solicita o contexto ao servidor antes
de abrir a NUI.

## Eventos client

```lua
TriggerEvent('mz_admin:client:openAdmin')
TriggerEvent('mz_admin:client:closeAdmin')
TriggerEvent('mz_admin:client:toggleAdmin')
```

Os eventos são apenas entrypoints locais. O evento de abertura passa pelo mesmo gate
server-side do comando e do export.

## Fluxo

```text
comando/export/evento
  -> MZAdminRouter
  -> mz_admin:server:getMenuContext
  -> MZAdminUI (NUI própria)
  -> callback tipado da ação
  -> autorização/hierarquia/identidade no servidor
  -> owner canônico
  -> auditoria e resposta
```

## Direção visual

A NUI adapta a anatomia pública do Flight Admin: shell de `600x775`, header de
`50px`, sidebar de `80px`, navegação por ícones, cartões densos e ações em grade.
A identidade exibida é MZ Admin e somente módulos realmente registrados/autorizados
entram na sidebar. `INÍCIO` e `JOGADORES` são entradas estáveis; as demais
categorias vêm da árvore canônica registrada por `MZAdminMenu.RegisterModules`.
Não existe uma entrada intermediária `ADMIN`: cada domínio autorizado possui uma
única entrada direta na rail.

A referência local `D:\Mara\server\extras\flight_admin-main` declara LGPL-3.0.
O frontend MZ permanece uma implementação vanilla independente: não importa o
backend, eventos ou lógica administrativa da referência.

O idioma do documento herda o convar replicado `ox:locale`, com fallback `pt-br`.
Os aliases `pt` e `en` são normalizados para `pt-br` e `en-us`. A NUI recebe
esse valor no modelo; os textos funcionais ainda dependem dos módulos que montam
cada view e não estão todos traduzidos.

### Catálogo de permissões Staff

O callback `mz_admin:server:listStaffManagement` consulta o export server-side
`mz_core:ListStaffManagement`. O campo `catalog` devolve entradas com `code`,
`label` e `group`; `code` é o identificador estável usado nas decisões e
alterações de permissões. Os rótulos `label` e grupos `group` atuais vêm do
catálogo do Core e podem chegar em português independentemente do idioma do
Admin. Nomes de cargos e outros valores administrados são dados e também não
devem ser traduzidos automaticamente.

Uma evolução no Core poderia fornecer rótulos localizados pelo `ox:locale`, ou
chaves estáveis de tradução junto com o catálogo, preservando `code`, `group`
e os contratos de autorização. O Admin não replica o catálogo de permissões.

### Textos dinâmicos e rótulos técnicos

Identificadores e exemplos estruturais mantêm sua forma original: `Citizen ID`,
`Account ID`, `Audit ID`, `Whitelist`, `Spawn`, `Staff`, `Status`,
`Online`/`Offline`, nomes de modelos, coordenadas e valores como `recepcao_01`.
São identificadores, termos técnicos ou exemplos de dados. Marcas como
`MZ Admin` também permanecem iguais nos dois idiomas.

O Admin preserva dados fornecidos por outros owners: os campos humanos dos
incidentes do `mz_banguard`, nomes e categorias do catálogo do `mz_furniture`,
nomes de organizações e outros dados de `mz_org`, `mz_doors`, `mz_props` e
`mz_phone`. Motivos históricos, nomes de jogadores e conteúdo inserido por
usuários permanecem como recebidos. Para localizar esses campos, o respectivo
owner pode fornecer textos no idioma global ou chaves estáveis, sem duplicar
seus catálogos no Admin.

## Homologação FiveM pendente

1. Inicie `mz_admin` com `mz_menu` parado e valide `/admin`, `/mztablet`, TAB,
   ESC e o botão de fechar.
2. Inicie `mz_menu` com `mz_admin` parado e valide menus comuns.
3. Tente abrir sem `staff.panel.open` e forje callbacks NUI/eventos administrativos.
4. Revogue a permissão com o painel aberto; ele deve fechar em até 3 segundos.
5. Percorra INÍCIO, JOGADORES e cada domínio autorizado (Mundo, Veículos,
   Organizações, Moderação, Auditoria, Segurança), modais e wizards;
   reinicie `mz_admin` com a NUI
   aberta e confirme que foco e `SetNuiFocusKeepInput` foram limpos.
6. Valide cada ação mutável e seu registro de auditoria no owner correspondente.

Browser/CEF isolado não comprova esses itens; o aceite final exige runtime FiveM.

