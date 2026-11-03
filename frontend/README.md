# mz_admin/frontend — frontend do painel administrativo

Fonte React + TypeScript + Vite do NUI do `mz_admin`, usando componentes copiados da
biblioteca oficial `mz_ui` (source-owned, mantidos sincronizados via `sync:mz-ui`).
**Node/pnpm são necessários apenas em desenvolvimento**: o resource `mz_admin` em
produção é estático e não executa build.

## Pré-requisitos (somente desenvolvimento)

- Node.js 22+
- pnpm 12+ (`corepack enable` ou `npm i -g pnpm`)

```bat
cd mz_admin\frontend
pnpm install
```

## Rotina de recompilação

```bat
:: opção recomendada (build + verificação de pacote + release)
build.bat

:: ou via pnpm
pnpm run build:package
```

O que o script faz:

1. `pnpm run build` → `tsc -b` (typecheck) + `vite build`.
2. Gera o runtime em `../web/` (`index.html`, `app.js`, `style.css`, `logo_s.svg`).
3. Verifica que não há `node_modules`, lockfiles, `tsconfig*`, `vite.config*`, `.ts/.tsx`,
   source maps nem `frontend/` no runtime gerado.
4. Confere as referências do `index.html` e o `fxmanifest.lua`.
5. Copia somente os arquivos de runtime do resource para
   `../../release-artifacts/mz_admin-0.3.1-mz-ui/mz_admin/` e gera o `.zip`
   (a pasta `frontend/` não entra no pacote).

Build rápido sem empacotar: `pnpm run build` (ou `pnpm run dev` para desenvolvimento
com hot reload — servir a pasta não é preciso, o Vite sobe um servidor local).

> **Importante:** `mz_admin/web/` é gerado. Não edite os arquivos lá por dentro; altere a
> fonte em `src/` e recompile. `base: './'` no `vite.config.ts` mantém caminhos relativos
> exigidos pelo `ui_page` do FiveM.

## Estrutura

```txt
mz_admin/frontend/
├─ src/
│  ├─ components/ui/        # componentes mz_ui copiados (source-owned)
│  ├─ components/           # ContextPanel, TabletSurface, DialogLayer, ToastStack...
│  ├─ hooks/useAdminNui.ts  # contrato Lua↔NUI (mensagens, teclado, post)
│  ├─ lib/                  # state, nui, types, format
│  └─ styles/admin.css      # CSS legado preservado byte-a-byte
├─ scripts/build-and-package.mjs
├─ scripts/sync-mz-ui.mjs   # ressincroniza componentes do mz_ui
├─ vite.config.ts
└─ build.bat / build.sh
```

Para atualizar os componentes copiados do `mz_ui` após mudança na biblioteca:

```bat
pnpm run sync:mz-ui
```

O script lê `../../mz_ui/src/components/ui` e `../../mz_ui/src/lib/utils.ts` na raiz do
repositório e sobrescreve as cópias locais — não crie componentes alternativos.

## Testes (mz_testkit)

```bat
cd ..\..\mz_testkit
npm run test:mz_admin          # contratos de superfície/roteador/NUI (node --test)
npm run test:mz_admin:visual   # Playwright visual (serve mz_admin/web em :4174)
```

Harnesses Lua (cwd = raiz do repositório):

```bat
lua mz_admin\tests\tablet_contract_harness.lua
lua mz_admin\tests\focus_toggle_contract_harness.lua
```

## Contratos

O frontend não altera eventos, `RegisterNUICallback`, permissões, comandos F6/TAB/ESC
nem semântica de foco — tudo permanece definido em `mz_admin/client/*.lua`. Ver
`mz_admin/docs/ADMIN_NUI_CONTRACT.md` e `mz_admin/docs/RUNTIME_CHECKLIST.md`.
