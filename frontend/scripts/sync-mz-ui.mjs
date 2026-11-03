#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, readdirSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const appRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const repoRoot = resolve(appRoot, "..", "..")
const mzUiRoot = join(repoRoot, "mz_ui")
const sourceUi = join(mzUiRoot, "src", "components", "ui")
const targetUi = join(appRoot, "src", "components", "ui")

if (!existsSync(sourceUi)) {
  throw new Error(`Fonte mz_ui não encontrada: ${sourceUi}`)
}

mkdirSync(targetUi, { recursive: true })
for (const file of readdirSync(sourceUi)) {
  if (file.endsWith(".tsx")) {
    cpSync(join(sourceUi, file), join(targetUi, file))
  }
}
cpSync(join(mzUiRoot, "src", "lib", "utils.ts"), join(appRoot, "src", "lib", "utils.ts"))
console.log(`Componentes sincronizados de ${sourceUi}`)
