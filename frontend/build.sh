#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js nao encontrado. Instale Node.js apenas no ambiente de desenvolvimento." >&2
  exit 1
fi

node scripts/build-and-package.mjs "$@"
