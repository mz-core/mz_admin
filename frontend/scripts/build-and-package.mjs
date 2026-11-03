#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync } from "node:fs"
import { basename, dirname, join, relative, resolve, sep } from "node:path"
import { fileURLToPath } from "node:url"
import { execFileSync } from "node:child_process"

const appRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const adminRoot = resolve(appRoot, "..")
const repoRoot = resolve(adminRoot, "..")
const webRoot = join(adminRoot, "web")
const packageJson = JSON.parse(readFileSync(join(appRoot, "package.json"), "utf8"))
const packageName = `mz_admin-${packageJson.version}-mz-ui`
const releaseRoot = join(repoRoot, "release-artifacts", packageName)
const cleanDeps = process.argv.includes("--clean-deps")

const forbiddenNames = new Set([
  "node_modules",
  "package.json",
  "package-lock.json",
  "pnpm-lock.yaml",
  "yarn.lock",
  "vite.config.ts",
  "vite.config.js",
  "tsconfig.json",
  "tsconfig.app.json",
  "tsconfig.node.json",
])

function run(command, args, cwd = appRoot) {
  console.log(`> ${command} ${args.join(" ")}`)
  // No Windows os gerenciadores de pacote são .cmd; sem shell o spawn falha com ENOENT.
  execFileSync(command, args, {
    cwd,
    stdio: "inherit",
    env: process.env,
    shell: process.platform === "win32",
  })
}

function assertInside(target, parent) {
  const rel = relative(parent, target)
  if (rel === "" || rel.startsWith("..") || resolve(target) === resolve(parent)) {
    throw new Error(`Caminho de limpeza recusado: ${target}`)
  }
}

function safeRemove(target, parent) {
  if (!existsSync(target)) return
  assertInside(target, parent)
  rmSync(target, { recursive: true, force: true })
}

function walk(root) {
  if (!existsSync(root)) return []
  const files = []
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const full = join(root, entry.name)
    if (entry.isDirectory()) files.push(...walk(full))
    else files.push(full)
  }
  return files
}

function verifyRuntimeFolder(folder) {
  const problems = []
  for (const file of walk(folder)) {
    const name = basename(file)
    const rel = relative(folder, file).replaceAll(sep, "/")
    if (forbiddenNames.has(name)) problems.push(rel)
    if (/\.(ts|tsx|map)$/i.test(name)) problems.push(rel)
    if (rel.startsWith("node_modules/") || rel.startsWith("frontend/")) problems.push(rel)
  }
  if (problems.length) {
    throw new Error(`Arquivos de desenvolvimento encontrados no pacote:\n${problems.join("\n")}`)
  }
}

function verifyIndexReferences() {
  const html = readFileSync(join(webRoot, "index.html"), "utf8")
  const references = [...html.matchAll(/(?:src|href)="([^"]+)"/g)]
    .map((match) => match[1])
    .filter((value) => !/^(?:https?:|data:|#)/i.test(value))

  const missing = []
  for (const reference of references) {
    const normalized = reference.replace(/^\.\//, "")
    const target = join(webRoot, normalized)
    if (!existsSync(target) || !statSync(target).isFile()) missing.push(reference)
  }
  if (missing.length) {
    throw new Error(`index.html referencia arquivos ausentes: ${missing.join(", ")}`)
  }
  return references
}

function verifyManifest() {
  const manifest = readFileSync(join(adminRoot, "fxmanifest.lua"), "utf8")
  for (const required of [
    "ui_page 'web/index.html'",
    "'web/index.html'",
    "'web/app.js'",
    "'web/style.css'",
    "'web/logo_s.svg'",
  ]) {
    if (!manifest.includes(required)) {
      throw new Error(`fxmanifest.lua não referencia o build atual: ${required}`)
    }
  }
}

function copyRuntime() {
  safeRemove(releaseRoot, join(repoRoot, "release-artifacts"))
  const target = join(releaseRoot, "mz_admin")
  mkdirSync(target, { recursive: true })

  for (const name of ["fxmanifest.lua", "README.md", "client", "server", "shared", "docs", "examples", "web"]) {
    const source = join(adminRoot, name)
    if (!existsSync(source)) continue
    cpSync(source, join(target, name), { recursive: true })
  }

  verifyRuntimeFolder(join(target, "web"))
  return target
}

function createZip(target) {
  const zipPath = join(repoRoot, "release-artifacts", `${packageName}.zip`)
  rmSync(zipPath, { force: true })
  try {
    if (process.platform === "win32") {
      execFileSync("powershell.exe", [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        `Compress-Archive -Path '${target}' -DestinationPath '${zipPath}' -Force`,
      ], { stdio: "inherit" })
    } else {
      execFileSync("zip", ["-qr", zipPath, "mz_admin"], {
        cwd: releaseRoot,
        stdio: "inherit",
      })
    }
    return zipPath
  } catch (error) {
    console.warn(`Aviso: não foi possível gerar o ZIP (${error.message}). A pasta da release está pronta.`)
    return null
  }
}

try {
  if (!existsSync(join(appRoot, "node_modules"))) {
    const lockfile = join(appRoot, "pnpm-lock.yaml")
    run("pnpm", existsSync(lockfile) ? ["install", "--frozen-lockfile"] : ["install"])
  }

  run("pnpm", ["run", "build"])
  for (const required of ["index.html", "app.js", "style.css", "logo_s.svg"]) {
    if (!existsSync(join(webRoot, required))) {
      throw new Error(`Build incompleto: mz_admin/web/${required} ausente`)
    }
  }

  verifyRuntimeFolder(webRoot)
  const references = verifyIndexReferences()
  verifyManifest()

  const target = copyRuntime()
  verifyRuntimeFolder(target)
  const zipPath = createZip(target)

  console.log("")
  console.log("MZ Admin UI build concluído.")
  console.log(`Runtime: ${webRoot}`)
  console.log(`Pacote:  ${target}`)
  console.log(`ZIP:     ${zipPath || "(não gerado)"}`)
  console.log(`Assets:  ${references.join(", ")}`)
} finally {
  if (cleanDeps) {
    safeRemove(join(appRoot, "node_modules"), appRoot)
    safeRemove(join(appRoot, ".vite"), appRoot)
    console.log("Dependências locais removidas (--clean-deps).")
  }
}
