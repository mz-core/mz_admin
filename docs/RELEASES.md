# Releases do mz_admin

O workflow `.github/workflows/release.yml` inicia somente com tags SemVer
`vX.Y.Z`; versões beta, como `v0.3.2-beta.1`, são publicadas como pre-release.
Um push comum de código não publica release.

## Pré-requisitos antes de integrar

O checkout `mz_admin` deve versionar o manifest, o frontend React/TypeScript,
o lockfile e o código compilado necessário para execução local. A sincronização
do workflow e do empacotador, sem esses arquivos, não basta para compilar a
NUI. O build da release faz `pnpm install --frozen-lockfile` em uma cópia
temporária, e não precisa nem modifica `node_modules` local.

Os componentes `mz_ui` usados pelo painel estão versionados como código-fonte
local em `frontend/src/components/ui/` e `frontend/src/lib/utils.ts`. O build
normal (`pnpm run build`) usa essas cópias diretamente; não executa
`sync:mz-ui`. O script de sincronização continua sendo uma ferramenta opcional
para o workspace completo e depende de `mz_ui` em um diretório irmão. Não é
necessário nem desejável baixar `mz_ui` no GitHub Actions.

## Publicar

Depois que a integração e todas as fontes necessárias estiverem no repositório
GitHub `mz-core/mz_admin`:

```sh
git tag -a v0.3.2 -m "mz_admin v0.3.2"
git push origin v0.3.2
```

O workflow valida que a tag aponta para o commit executado, roda os harnesses
Lua existentes, compila e valida o frontend, verifica o manifest e o ZIP e só
então publica. Cada release usa um asset `mz_admin-vX.Y.Z.zip`, cuja raiz
interna é `mz_admin/`. O release tem o título `MZ mz_admin vX.Y.Z — Release`;
tags beta criam pre-releases. O pacote contém os arquivos de runtime e a saída
compilada da NUI, não contém `frontend/`, dependências Node ou testes.

O job de build só tem permissão `contents: read`; `contents: write` existe
somente no job de publicação. Releases já existentes não são substituídos.
Não force nem mova tags publicadas.

## Reutilizar nos demais repositórios MZ

O empacotador em `tools/release/release.py` é a cópia standalone do
empacotador central já usado no workspace. Foi mantido igual, exceto pelo
reconhecimento de tags `vX.Y.Z`, descoberta da raiz do resource e geração de
notas para um repositório de resource independente.

Para cada resource independente:

1. Copie `tools/release/release.py` desta integração para
   `tools/release/release.py` na raiz do repositório do resource. Ela mantém a
   mesma allowlist, validações de manifest, assets, referências dinâmicas, ZIP
   e segurança, e descobre o resource pela raiz local. Não crie outro
   empacotador.
2. Adicione `.nvmrc` somente se o frontend do resource usar Node/Vite e fixe a
   versão Node validada pelo projeto. O `package.json` deve declarar a versão
   exata do package manager e o lockfile correspondente.
3. Adapte uma cópia de `.github/workflows/release.yml` para os scripts e testes
   reais do resource. Preserve jobs separados de build read-only e publicação
   com `contents: write`.
4. Documente os comandos de tag/build, verifique o conteúdo do ZIP e confirme
   que o runtime não depende de Node.js.

Não reutilize nomes de repositório, managers, testes ou caminhos do `mz_admin`
sem conferir os arquivos reais de cada resource. O workflow não publica em
pushes de branch.
