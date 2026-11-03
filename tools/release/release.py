#!/usr/bin/env python3
"""Build, validate, and package one MZ FiveM resource for a tagged release."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
TAG_PATTERN = re.compile(
    r"^(mz_[a-z0-9_]+)-v"
    r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?$"
)
STANDALONE_TAG_PATTERN = re.compile(
    r"^v"
    r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?$"
)
PACKAGE_MANAGER_PATTERN = re.compile(r"^(pnpm|npm)@(\d+\.\d+\.\d+)$")
SCALAR_FILE_FIELDS = {
    "client_script",
    "server_script",
    "shared_script",
    "loadscreen",
    "replace_level_meta",
}
SINGLE_PATH_FIELDS = {"ui_page"}
BLOCK_FILE_FIELDS = {
    "client_scripts",
    "server_scripts",
    "shared_scripts",
    "files",
    "escrow_ignore",
}
FORBIDDEN_DIRS = {
    ".git",
    ".github",
    ".idea",
    ".npm",
    ".pnpm-store",
    ".vscode",
    "__pycache__",
    ".cache",
    ".next",
    ".parcel-cache",
    ".pytest_cache",
    ".turbo",
    ".vite",
    "__tests__",
    "cache",
    "caches",
    "coverage",
    "graphify-out",
    "logs",
    "node_modules",
    "playwright-report",
    "secrets",
    "test",
    "test-results",
    "tests",
    "temp",
    "tmp",
}
FORBIDDEN_SUFFIXES = {
    ".bak",
    ".cert",
    ".crt",
    ".key",
    ".log",
    ".map",
    ".p12",
    ".pem",
    ".pfx",
    ".swp",
    ".temp",
    ".tmp",
    ".tsbuildinfo",
}
FORBIDDEN_FILES = {
    ".ds_store",
    "credentials.json",
    "id_rsa",
    "id_ed25519",
    "secrets.json",
    "thumbs.db",
}
FRONTEND_DIR_NAMES = {"frontend", "ui", "web"}
SUPPORTED_LOCKFILES = {"pnpm": "pnpm-lock.yaml", "npm": "package-lock.json"}


class ReleaseError(Exception):
    pass


def parse_tag(tag: str) -> dict[str, str | bool]:
    match = TAG_PATTERN.fullmatch(tag)
    if match:
        resource, major, minor, patch, prerelease = match.groups()
        return {
            "resource": resource,
            "version": f"{major}.{minor}.{patch}{prerelease or ''}",
            "prerelease": bool(prerelease),
            "standalone": False,
        }
    match = STANDALONE_TAG_PATTERN.fullmatch(tag)
    if match:
        major, minor, patch, prerelease = match.groups()
        return {
            "resource": "",
            "version": f"{major}.{minor}.{patch}{prerelease or ''}",
            "prerelease": bool(prerelease),
            "standalone": True,
        }
    raise ReleaseError(
        "Tag inválida. Use vX.Y.Z (ex.: v0.3.2) ou "
        "<resource>-vX.Y.Z (ex.: mz_lib-v0.1.0)."
    )


def _is_forbidden_path(
    path: PurePosixPath, *, exclude_frontend_sources: bool = True
) -> bool:
    lowered_parts = [part.lower() for part in path.parts]
    if any(part in FORBIDDEN_DIRS for part in lowered_parts):
        return True
    name = lowered_parts[-1] if lowered_parts else ""
    if name in FORBIDDEN_FILES or name.startswith(".env"):
        return True
    if exclude_frontend_sources:
        for index, part in enumerate(lowered_parts[:-1]):
            if part in FRONTEND_DIR_NAMES and "src" in lowered_parts[index + 1:]:
                return True
        if any(part in FRONTEND_DIR_NAMES for part in lowered_parts[:-1]) and name.endswith(
            (".map", ".ts", ".tsx", ".jsx", ".scss", ".sass", ".less", ".vue", ".svelte")
        ):
            return True
    return any(name.endswith(suffix) for suffix in FORBIDDEN_SUFFIXES)


def _lua_tokens(source: str) -> list[tuple[str, str]]:
    tokens: list[tuple[str, str]] = []
    i = 0
    length = len(source)

    while i < length:
        if source[i].isspace():
            i += 1
            continue
        if source.startswith("--", i):
            long_comment = re.match(r"--\[(=*)\[", source[i:])
            if long_comment:
                close = "]" + long_comment.group(1) + "]"
                end = source.find(close, i + long_comment.end())
                i = length if end < 0 else end + len(close)
            else:
                newline = source.find("\n", i)
                i = length if newline < 0 else newline + 1
            continue
        long_string = re.match(r"\[(=*)\[", source[i:])
        if long_string:
            close = "]" + long_string.group(1) + "]"
            end = source.find(close, i + long_string.end())
            if end < 0:
                raise ReleaseError("String longa sem fechamento em fxmanifest.lua.")
            value_start = i + long_string.end()
            tokens.append(("string", source[value_start:end]))
            i = end + len(close)
            continue
        if source[i] in {"'", '"'}:
            quote = source[i]
            i += 1
            value: list[str] = []
            while i < length:
                char = source[i]
                if char == "\\" and i + 1 < length:
                    value.append(source[i + 1])
                    i += 2
                elif char == quote:
                    i += 1
                    break
                else:
                    value.append(char)
                    i += 1
            else:
                raise ReleaseError("String sem fechamento em fxmanifest.lua.")
            tokens.append(("string", "".join(value)))
            continue
        identifier = re.match(r"[A-Za-z_][A-Za-z0-9_]*", source[i:])
        if identifier:
            tokens.append(("identifier", identifier.group(0)))
            i += identifier.end()
            continue
        tokens.append(("symbol", source[i]))
        i += 1
    return tokens


def _table_strings(tokens: list[tuple[str, str]], start: int) -> tuple[list[str], int]:
    depth = 0
    values: list[str] = []
    for index in range(start, len(tokens)):
        kind, value = tokens[index]
        if kind == "symbol" and value == "{":
            depth += 1
        elif kind == "symbol" and value == "}":
            depth -= 1
            if depth == 0:
                return values, index + 1
        elif kind == "string" and depth > 0:
            values.append(value)
    raise ReleaseError("Tabela Lua sem fechamento em fxmanifest.lua.")


def parse_manifest(manifest: Path) -> dict[str, list[str]]:
    tokens = _lua_tokens(manifest.read_text(encoding="utf-8-sig"))
    refs: list[str] = []
    ui_pages: list[str] = []
    dependencies: list[str] = []
    provides: list[str] = []

    for index, (kind, field) in enumerate(tokens):
        if kind != "identifier":
            continue
        cursor = index + 1
        while cursor < len(tokens) and tokens[cursor] == ("symbol", "("):
            cursor += 1

        if field in BLOCK_FILE_FIELDS or field in {"dependencies", "provide"}:
            if cursor >= len(tokens) or tokens[cursor] != ("symbol", "{"):
                continue
            values, end = _table_strings(tokens, cursor)
            if field in BLOCK_FILE_FIELDS | {"dependencies"} and any(
                token_kind == "identifier"
                for token_kind, _ in tokens[cursor + 1:end - 1]
            ):
                raise ReleaseError(
                    f"Lista dinâmica não suportada em fxmanifest.lua: {field}."
                )
            if field in BLOCK_FILE_FIELDS:
                refs.extend(values)
            elif field == "dependencies":
                dependencies.extend(values)
            else:
                provides.extend(values)
        elif field in SCALAR_FILE_FIELDS | SINGLE_PATH_FIELDS:
            if cursor < len(tokens) and tokens[cursor][0] == "string":
                value = tokens[cursor][1]
                refs.append(value)
                if field in SINGLE_PATH_FIELDS:
                    ui_pages.append(value)
            elif field in SINGLE_PATH_FIELDS | SCALAR_FILE_FIELDS:
                raise ReleaseError(
                    f"Referência dinâmica não suportada em fxmanifest.lua: {field}."
                )
        elif field == "data_file":
            if cursor + 1 < len(tokens) and tokens[cursor + 1][0] == "string":
                refs.append(tokens[cursor + 1][1])
            else:
                raise ReleaseError("data_file sem caminho literal em fxmanifest.lua.")
        elif field == "dependency":
            if cursor < len(tokens) and tokens[cursor][0] == "string":
                dependencies.append(tokens[cursor][1])
        elif field == "provide":
            if cursor < len(tokens) and tokens[cursor][0] == "string":
                provides.append(tokens[cursor][1])

    return {
        "files": refs,
        "ui_pages": ui_pages,
        "dependencies": dependencies,
        "provides": provides,
    }


def _resource_dir(resource: str) -> Path:
    if not re.fullmatch(r"mz_[a-z0-9_]+", resource):
        raise ReleaseError(f"Nome de resource inválido: {resource}")
    if ROOT.name == resource and (ROOT / "fxmanifest.lua").is_file():
        return ROOT
    path = ROOT / resource
    if path.parent != ROOT or not (path / "fxmanifest.lua").is_file():
        raise ReleaseError(f"Resource '{resource}' não existe na raiz ou não tem fxmanifest.lua.")
    return path


def _frontend_project(resource_dir: Path) -> tuple[Path, dict] | None:
    candidates: list[tuple[Path, dict]] = []
    dirs = [resource_dir]
    dirs.extend(resource_dir / name for name in sorted(FRONTEND_DIR_NAMES))
    for directory in dirs:
        package_file = directory / "package.json"
        if not package_file.is_file():
            continue
        try:
            package = json.loads(package_file.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            raise ReleaseError(f"package.json inválido: {package_file}: {exc}") from exc
        scripts = package.get("scripts", {})
        dependencies = {
            **package.get("dependencies", {}),
            **package.get("devDependencies", {}),
        }
        is_vite = "vite" in dependencies or any(directory.glob("vite.config.*"))
        if is_vite:
            if "build" not in scripts:
                raise ReleaseError(f"Projeto Vite sem script build: {package_file}")
            candidates.append((directory, package))
    if len(candidates) > 1:
        paths = ", ".join(str(path.relative_to(ROOT)) for path, _ in candidates)
        raise ReleaseError(f"Mais de um projeto Vite no resource; configure uma entrada única: {paths}")
    return candidates[0] if candidates else None


def _package_manager(project_dir: Path, package: dict) -> tuple[str, str]:
    declaration = package.get("packageManager", "")
    match = PACKAGE_MANAGER_PATTERN.fullmatch(declaration)
    if not match:
        raise ReleaseError(
            f"{project_dir / 'package.json'} precisa declarar packageManager "
            "com versão exata (ex.: pnpm@12.11.2 ou npm@10.9.2)."
        )
    manager, version = match.groups()
    lockfile = project_dir / SUPPORTED_LOCKFILES[manager]
    if not lockfile.is_file():
        raise ReleaseError(f"Lockfile obrigatório ausente: {lockfile}")
    node_version_file = ROOT / ".nvmrc"
    if not node_version_file.is_file():
        raise ReleaseError("Frontend release requer .nvmrc na raiz do monorepo.")
    node_version = node_version_file.read_text(encoding="utf-8").strip().removeprefix("v")
    if not re.fullmatch(r"\d+\.\d+\.\d+", node_version):
        raise ReleaseError(".nvmrc deve fixar uma versão exata X.Y.Z do Node.js.")
    return manager, version


def inspect_tag(tag: str) -> dict:
    parsed = parse_tag(tag)
    if parsed["standalone"]:
        resource = ROOT.name
        if not re.fullmatch(r"mz_[a-z0-9_]+", resource):
            raise ReleaseError("Tags vX.Y.Z só são válidas quando tools/release está dentro de um resource MZ.")
        parsed["resource"] = resource
    resource_dir = _resource_dir(str(parsed["resource"]))
    manifest = parse_manifest(resource_dir / "fxmanifest.lua")
    for dependency in manifest["dependencies"]:
        if not re.fullmatch(r"[A-Za-z0-9_-]+", dependency):
            raise ReleaseError(f"Nome de dependency inválido em fxmanifest.lua: {dependency!r}")
        if (
            not parsed["standalone"]
            and dependency.startswith("mz_")
            and not (ROOT / dependency / "fxmanifest.lua").is_file()
        ):
            raise ReleaseError(
                f"Dependency MZ declarada, mas sem fxmanifest.lua no monorepo: {dependency}"
            )
    frontend = _frontend_project(resource_dir)
    if frontend:
        manager, manager_version = _package_manager(*frontend)
        if not manifest["ui_pages"]:
            raise ReleaseError(
                f"{parsed['resource']} tem frontend Vite, mas não declara ui_page em fxmanifest.lua."
            )
    else:
        manager = ""
        manager_version = ""
    return {
        **parsed,
        "frontend": bool(frontend),
        "package_manager": manager,
        "package_manager_version": manager_version,
        "resource_dir": resource_dir,
        "frontend_dir": frontend[0] if frontend else None,
        "manifest": manifest,
    }


def _check_tag_commit(tag: str) -> None:
    expected = os.environ.get("GITHUB_SHA")
    if not expected:
        return
    try:
        actual = subprocess.run(
            ["git", "rev-parse", f"{tag}^{{commit}}"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError) as exc:
        raise ReleaseError(f"Não foi possível verificar o commit da tag {tag}: {exc}") from exc
    if actual != expected:
        raise ReleaseError(f"A tag {tag} não aponta para o commit deste evento GitHub Actions.")


def _run(command: list[str], cwd: Path, *, capture: bool = False) -> subprocess.CompletedProcess:
    print("> " + " ".join(command), flush=True)
    try:
        return subprocess.run(
            command,
            cwd=cwd,
            check=True,
            text=True,
            capture_output=capture,
            shell=os.name == "nt",
        )
    except FileNotFoundError as exc:
        raise ReleaseError(f"Comando necessário não encontrado: {command[0]}") from exc
    except subprocess.CalledProcessError as exc:
        if exc.stdout:
            print(exc.stdout, end="")
        if exc.stderr:
            print(exc.stderr, end="", file=sys.stderr)
        raise ReleaseError(f"Comando de build falhou ({exc.returncode}): {command[0]}") from exc


def _verify_tool_versions(info: dict, project_dir: Path) -> None:
    nvmrc = (ROOT / ".nvmrc").read_text(encoding="utf-8").strip().removeprefix("v")
    node = _run(["node", "--version"], project_dir, capture=True).stdout.strip().removeprefix("v")
    if node != nvmrc:
        raise ReleaseError(f"Node.js {node} ativo; o monorepo declara Node.js {nvmrc} em .nvmrc.")
    manager_version = _run([info["package_manager"], "--version"], project_dir, capture=True).stdout.strip()
    if manager_version != info["package_manager_version"]:
        raise ReleaseError(
            f"{info['package_manager']} {manager_version} ativo; "
            f"o projeto declara {info['package_manager_version']}."
        )


def _safe_copy_resource(source: Path, destination: Path) -> None:
    def ignore(directory: str, names: list[str]) -> set[str]:
        relative = Path(directory).relative_to(source)
        ignored: set[str] = set()
        for name in names:
            candidate = PurePosixPath((relative / name).as_posix())
            if _is_forbidden_path(candidate, exclude_frontend_sources=False):
                ignored.add(name)
        return ignored

    shutil.copytree(source, destination, ignore=ignore, symlinks=True)


def _clean_frontend_outputs(resource_dir: Path, frontend_dir: Path, ui_pages: list[str]) -> None:
    for page in ui_pages:
        if page.startswith(("http://", "https://", "//", "@")):
            continue
        page_path = PurePosixPath(page)
        if ".." in page_path.parts or page_path.is_absolute():
            raise ReleaseError(f"ui_page aponta para fora do resource: {page}")
        output_dir = resource_dir.joinpath(*page_path.parts).parent
        resolved_output = output_dir.resolve()
        resolved_resource = resource_dir.resolve()
        if resolved_output == resolved_resource or resolved_resource not in resolved_output.parents:
            raise ReleaseError(f"Saída de build insegura em ui_page: {page}")
        if resolved_output == frontend_dir.resolve() or frontend_dir.resolve() in resolved_output.parents:
            if resolved_output == frontend_dir.resolve():
                raise ReleaseError(
                    f"ui_page aponta para a raiz do projeto-fonte ({page}); "
                    "configure uma saída de build separada."
                )
        if output_dir.is_symlink():
            raise ReleaseError(f"Saída de build não pode ser symlink: {output_dir}")
        if output_dir.exists():
            if output_dir.is_dir():
                shutil.rmtree(output_dir)
            else:
                output_dir.unlink()


def _build_frontend(info: dict, resource_copy: Path) -> None:
    if not info["frontend"]:
        print("Resource sem projeto Vite: build frontend ignorado.")
        return
    source_frontend = info["frontend_dir"]
    frontend_dir = resource_copy / source_frontend.relative_to(info["resource_dir"])
    _verify_tool_versions(info, frontend_dir)
    _clean_frontend_outputs(resource_copy, frontend_dir, info["manifest"]["ui_pages"])

    manager = info["package_manager"]
    if manager == "pnpm":
        _run(["pnpm", "install", "--frozen-lockfile"], frontend_dir)
        _run(["pnpm", "run", "build"], frontend_dir)
    else:
        _run(["npm", "ci"], frontend_dir)
        _run(["npm", "run", "build"], frontend_dir)


def _normalise_reference(reference: str) -> str:
    value = reference.replace("\\", "/").strip()
    if value.startswith("@"):
        return value
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts:
        raise ReleaseError(f"Referência fora do resource recusada: {reference}")
    return path.as_posix()


def _expand_reference(resource_dir: Path, reference: str) -> list[Path]:
    normalized = _normalise_reference(reference)
    if normalized.startswith("@"):
        return []
    matches = sorted(resource_dir.glob(normalized), key=lambda path: path.as_posix())
    if not matches:
        raise ReleaseError(f"Referência ausente no resource: {reference}")
    resolved: list[Path] = []
    for match in matches:
        if match.is_symlink():
            raise ReleaseError(f"Symlink não pode ser incluído no ZIP: {match}")
        if match.is_dir():
            resolved.extend(sorted((item for item in match.rglob("*") if item.is_file()), key=lambda p: p.as_posix()))
        elif match.is_file():
            resolved.append(match)
    if not resolved:
        raise ReleaseError(f"Referência não contém arquivos: {reference}")
    return resolved


def _dynamic_load_references(resource_dir: Path, lua_files: set[Path], resource: str) -> list[str]:
    dynamic: list[str] = []
    resource_aliases = {"GetCurrentResourceName"}
    for lua_file in sorted(lua_files):
        source = lua_file.read_text(encoding="utf-8", errors="replace")
        for match in re.finditer(
            r"(?:local\s+)?([A-Za-z_][\w.]*)\s*=\s*GetCurrentResourceName\s*\(\s*\)",
            source,
        ):
            resource_aliases.add(match.group(1))

        call_pattern = re.compile(
            r"LoadResourceFile\s*\(\s*"
            r"(?P<resource>GetCurrentResourceName\s*\(\s*\)|[A-Za-z_][\w.]*|['\"][^'\"]+['\"])\s*,\s*"
            r"(?P<path>\(\s*(['\"])(?P<formatted>.*?)\3\s*\)\s*:\s*format\s*\([^)]*\)|(['\"])(?P<literal>.*?)\5)",
            re.DOTALL,
        )
        calls = list(call_pattern.finditer(source))
        for call in calls:
            target = call.group("resource").strip()
            is_local = target.startswith("GetCurrentResourceName") or target in resource_aliases
            if target[:1] in {"'", '"'}:
                is_local = target[1:-1] == resource
            if not is_local:
                continue
            path = call.group("formatted")
            if path is not None:
                path = re.sub(r"%[sdif]", "*", path)
            else:
                path = call.group("literal")
            if not path or "%" in path:
                raise ReleaseError(
                    f"LoadResourceFile local sem caminho estático validável em "
                    f"{lua_file.relative_to(resource_dir)}."
                )
            dynamic.append(path)
        recognised_starts = {call.start() for call in calls}
        for call in re.finditer(r"LoadResourceFile\s*\(\s*([^,]+)\s*,", source):
            target = call.group(1).strip()
            is_local = target.startswith("GetCurrentResourceName") or target in resource_aliases
            if target[:1] in {"'", '"'}:
                is_local = target[1:-1] == resource
            if is_local and call.start() not in recognised_starts:
                raise ReleaseError(
                    f"LoadResourceFile local com expressão de caminho não suportada em "
                    f"{lua_file.relative_to(resource_dir)}."
                )
    return dynamic


def _external_dependencies(files: list[str], dependencies: list[str]) -> list[str]:
    declared = set(dependencies)
    missing: set[str] = set()
    for reference in files:
        if not reference.startswith("@"):
            continue
        parts = reference[1:].replace("\\", "/").split("/")
        if parts[0] and parts[0] not in declared:
            missing.add(parts[0])
    if missing:
        raise ReleaseError(
            "Referências @resource no fxmanifest.lua sem dependency declarada: "
            + ", ".join(sorted(missing))
        )
    return sorted(declared)


def _validate_web_assets(resource_dir: Path, included: set[Path]) -> None:
    included_resolved = {path.resolve() for path in included}
    html_tag_pattern = re.compile(r"<([a-z][\w-]*)\b[^>]*>", re.I)
    html_asset_pattern = re.compile(
        r"""(?<![\w:-])(src|href|poster|data)\s*=\s*["']([^"']+)["']""", re.I
    )
    css_pattern = re.compile(r"""url\(\s*["']?([^)"']+)["']?\s*\)|@import\s+["']([^"']+)["']""", re.I)

    def check(reference: str, relative_to: Path) -> None:
        value = reference.strip()
        if not value or value.startswith(
            ("#", "data:", "http:", "https:", "//", "blob:", "javascript:", "var(", "env(")
        ):
            return
        value = value.split("#", 1)[0].split("?", 1)[0]
        if not value:
            return
        target = (relative_to / value.lstrip("/")).resolve()
        if resource_dir.resolve() not in target.parents:
            raise ReleaseError(f"Asset frontend fora do resource: {reference}")
        if not target.is_file() or target not in included_resolved:
            raise ReleaseError(f"Asset frontend não incluído ou ausente: {target.relative_to(resource_dir)}")

    for file in sorted(included):
        suffix = file.suffix.lower()
        if suffix not in {".html", ".css"}:
            continue
        text = file.read_text(encoding="utf-8", errors="replace")
        if suffix == ".html":
            for tag in html_tag_pattern.finditer(text):
                tag_name = tag.group(1).lower()
                for attribute in html_asset_pattern.finditer(tag.group(0)):
                    name, value = attribute.groups()
                    if name.lower() != "href" or tag_name == "link":
                        check(value, file.parent)
        else:
            for match in css_pattern.finditer(text):
                check(match.group(1) or match.group(2), file.parent)


def _collect_runtime_files(resource_dir: Path, manifest: dict, resource: str) -> tuple[set[Path], list[str], list[str]]:
    dependencies = _external_dependencies(manifest["files"], manifest["dependencies"])
    selected: set[Path] = set()
    pending = list(manifest["files"])
    dynamic_refs: list[str] = []

    stream_dir = resource_dir / "stream"
    if stream_dir.is_dir():
        pending.extend(
            path.relative_to(resource_dir).as_posix()
            for path in stream_dir.rglob("*")
            if path.is_file()
        )

    while pending:
        reference = pending.pop()
        if reference.startswith("@"):
            continue
        if _is_forbidden_path(PurePosixPath(_normalise_reference(reference))):
            raise ReleaseError(f"Manifest referencia fonte ou arquivo proibido: {reference}")
        included_from_reference = 0
        for path in _expand_reference(resource_dir, reference):
            relative = PurePosixPath(path.relative_to(resource_dir).as_posix())
            if _is_forbidden_path(relative):
                continue
            selected.add(path)
            included_from_reference += 1
        if included_from_reference == 0:
            raise ReleaseError(f"Referência contém somente arquivos excluídos: {reference}")

    manifest_path = resource_dir / "fxmanifest.lua"
    selected.add(manifest_path)
    lua_files = {path for path in selected if path.suffix.lower() == ".lua"}
    dynamic_refs = _dynamic_load_references(resource_dir, lua_files, resource)
    for reference in dynamic_refs:
        for path in _expand_reference(resource_dir, reference):
            relative = PurePosixPath(path.relative_to(resource_dir).as_posix())
            if _is_forbidden_path(relative):
                raise ReleaseError(f"Referência dinâmica aponta para arquivo proibido: {relative}")
            selected.add(path)

    _validate_web_assets(resource_dir, selected)
    return selected, dependencies, dynamic_refs


def _excluded_summary(
    resource_dir: Path, included_names: set[str]
) -> tuple[dict[str, int], list[str]]:
    categories: dict[str, int] = {}
    samples: list[str] = []
    for directory, dirs, files in os.walk(resource_dir, followlinks=False):
        current = Path(directory)
        relative_dir = PurePosixPath(current.relative_to(resource_dir).as_posix())
        allowed_dirs = []
        for name in dirs:
            candidate = relative_dir / name
            if _is_forbidden_path(candidate):
                categories["proibidos por política"] = categories.get("proibidos por política", 0) + 1
                if len(samples) < 30:
                    samples.append(candidate.as_posix() + "/")
            else:
                allowed_dirs.append(name)
        dirs[:] = allowed_dirs
        for name in files:
            candidate = relative_dir / name
            if candidate.as_posix() in included_names:
                continue
            if _is_forbidden_path(candidate):
                category = "proibidos por política"
            elif any(part in {"src", "tests", "examples", "docs"} for part in candidate.parts):
                category = "fontes, testes ou documentação"
            else:
                category = "fora da allowlist do fxmanifest/stream"
            categories[category] = categories.get(category, 0) + 1
            if len(samples) < 30:
                samples.append(candidate.as_posix())
    return categories, samples


def _verify_archive(archive: Path, expected: set[str], resource: str) -> list[str]:
    with zipfile.ZipFile(archive, "r") as zip_file:
        names = zip_file.namelist()
        if len(names) != len(set(names)):
            raise ReleaseError("ZIP contém caminhos duplicados.")
        for name in names:
            path = PurePosixPath(name)
            if len(path.parts) < 2 or path.parts[0] != resource:
                raise ReleaseError(f"Estrutura inesperada no ZIP: {name}")
            if _is_forbidden_path(path):
                raise ReleaseError(f"Arquivo proibido no ZIP: {name}")
        missing = expected - set(names)
        if missing:
            raise ReleaseError("Arquivos de runtime ausentes no ZIP: " + ", ".join(sorted(missing)))
        bad_member = zip_file.testzip()
        if bad_member:
            raise ReleaseError(f"CRC inválido no ZIP: {bad_member}")
        return sorted(names)


def package_tag(tag: str, output_dir: Path) -> Path:
    info = inspect_tag(tag)
    _check_tag_commit(tag)
    output_dir = output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    archive_path = output_dir / f"{info['resource']}-v{info['version']}.zip"
    if archive_path.exists():
        raise ReleaseError(f"Arquivo de saída já existe; não será sobrescrito: {archive_path}")

    with tempfile.TemporaryDirectory(prefix="mz-resource-release-") as temporary:
        temporary_root = Path(temporary)
        resource_copy = temporary_root / str(info["resource"])
        _safe_copy_resource(info["resource_dir"], resource_copy)
        _build_frontend(info, resource_copy)

        manifest_copy = parse_manifest(resource_copy / "fxmanifest.lua")
        files, dependencies, dynamic_refs = _collect_runtime_files(
            resource_copy, manifest_copy, str(info["resource"])
        )
        if not (resource_copy / "fxmanifest.lua").is_file():
            raise ReleaseError("fxmanifest.lua ausente no build.")

        included_relative_paths = {
            path.relative_to(resource_copy).as_posix() for path in files
        }
        excluded_counts, excluded_samples = _excluded_summary(
            info["resource_dir"], included_relative_paths
        )
        expected_names = {
            f"{info['resource']}/{path.relative_to(resource_copy).as_posix()}"
            for path in files
        }
        temporary_zip = output_dir / f".{archive_path.name}.{os.getpid()}.tmp"
        if temporary_zip.exists():
            raise ReleaseError(f"Arquivo temporário já existe; não será sobrescrito: {temporary_zip}")
        try:
            with zipfile.ZipFile(
                temporary_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
            ) as zip_file:
                for path in sorted(files, key=lambda item: item.relative_to(resource_copy).as_posix()):
                    relative = path.relative_to(resource_copy).as_posix()
                    archive_name = f"{info['resource']}/{relative}"
                    metadata = zipfile.ZipInfo(archive_name, date_time=(1980, 1, 1, 0, 0, 0))
                    metadata.compress_type = zipfile.ZIP_DEFLATED
                    metadata.external_attr = (stat.S_IFREG | 0o644) << 16
                    zip_file.writestr(metadata, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
            names = _verify_archive(temporary_zip, expected_names, str(info["resource"]))
            temporary_zip.rename(archive_path)
        finally:
            if temporary_zip.exists():
                temporary_zip.unlink()

    print(f"\nZIP: {archive_path}")
    print(f"Resource: {info['resource']} | versão: {info['version']}")
    print(f"Frontend: {'build concluído' if info['frontend'] else 'não aplicável'}")
    print(f"Dependencies declaradas (não empacotadas): {', '.join(dependencies) or '(nenhuma)'}")
    print(f"Referências LoadResourceFile locais: {', '.join(dynamic_refs) or '(nenhuma)'}")
    print(f"\nIncluídos ({len(names)} arquivos):")
    for name in names:
        print(f"  + {name}")
    print("\nExclusões:")
    if excluded_counts:
        for category, count in sorted(excluded_counts.items()):
            print(f"  - {category}: {count}")
        if excluded_samples:
            print("  Exemplos:")
            for name in excluded_samples:
                print(f"    - {name}")
    else:
        print("  - Nenhum arquivo adicional encontrado fora da allowlist.")

    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with Path(github_output).open("a", encoding="utf-8") as output:
            output.write(f"archive={archive_path}\n")
    return archive_path


def _semver_key(version: str) -> tuple:
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?", version)
    if not match:
        return (0, 0, 0, 0, ())
    major, minor, patch, prerelease = match.groups()
    if prerelease is None:
        return (int(major), int(minor), int(patch), 1, ())
    identifiers = tuple(
        (0, int(part)) if part.isdigit() else (1, part)
        for part in prerelease.split(".")
    )
    return (int(major), int(minor), int(patch), 0, identifiers)


def release_notes(tag: str) -> str:
    parsed = parse_tag(tag)
    standalone = bool(parsed["standalone"])
    resource = ROOT.name if standalone else str(parsed["resource"])
    if standalone and not (ROOT / "fxmanifest.lua").is_file():
        raise ReleaseError("Tags vX.Y.Z exigem tools/release dentro da raiz de um resource.")
    try:
        tag_names = subprocess.run(
            ["git", "tag", "--list", "v*" if standalone else f"{resource}-v*"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    except (OSError, subprocess.CalledProcessError) as exc:
        raise ReleaseError(f"Não foi possível listar tags para gerar release notes: {exc}") from exc

    previous: tuple[str, str] | None = None
    current_key = _semver_key(str(parsed["version"]))
    for candidate in tag_names:
        try:
            candidate_info = parse_tag(candidate)
        except ReleaseError:
            continue
        if bool(candidate_info["standalone"]) != standalone:
            continue
        version = str(candidate_info["version"])
        if version != parsed["version"] and _semver_key(version) < current_key:
            if previous is None or _semver_key(version) > _semver_key(previous[1]):
                previous = (candidate, version)

    revision = f"{previous[0]}..{tag}" if previous else tag
    log_command = ["git", "log", "--no-merges", "--format=%h%x09%s", revision]
    if not standalone:
        log_command.extend(["--", resource])
    try:
        changes = subprocess.run(
            log_command,
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    except (OSError, subprocess.CalledProcessError) as exc:
        raise ReleaseError(f"Não foi possível gerar notas a partir do histórico de {resource}: {exc}") from exc

    header = f"Mudanças em `{resource}` desde `{previous[0]}`:" if previous else f"Mudanças em `{resource}`:"
    if not changes:
        return f"{header}\n\n- Nenhum commit direto no resource neste intervalo.\n"
    bullets = []
    for change in changes:
        commit, separator, subject = change.partition("\t")
        if separator and subject.strip():
            bullets.append(f"- {subject.strip()} (`{commit}`)")
    return header + "\n\n" + ("\n".join(bullets) if bullets else "- Nenhuma alteração listada.\n") + "\n"


def _write_inspection_outputs(info: dict, path: Path) -> None:
    values = {
        "resource": info["resource"],
        "version": info["version"],
        "prerelease": str(info["prerelease"]).lower(),
        "frontend": str(info["frontend"]).lower(),
        "package_manager": info["package_manager"],
        "package_manager_version": info["package_manager_version"],
    }
    with path.open("a", encoding="utf-8") as output:
        for key, value in values.items():
            output.write(f"{key}={value}\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    inspect_parser = commands.add_parser("inspect", help="Validar tag e metadados para o workflow.")
    inspect_parser.add_argument("--tag", required=True)
    inspect_parser.add_argument("--github-output", type=Path)

    package_parser = commands.add_parser("package", help="Build, validar e criar um ZIP.")
    package_parser.add_argument("--tag", required=True)
    package_parser.add_argument("--output-dir", type=Path, required=True)

    notes_parser = commands.add_parser("notes", help="Gerar notas a partir de commits do resource.")
    notes_parser.add_argument("--tag", required=True)
    notes_parser.add_argument("--output-file", type=Path, required=True)

    args = parser.parse_args()
    try:
        if args.command == "inspect":
            info = inspect_tag(args.tag)
            _check_tag_commit(args.tag)
            if args.github_output:
                _write_inspection_outputs(info, args.github_output)
            print(
                f"Tag válida: {args.tag} | resource={info['resource']} | "
                f"frontend={'sim' if info['frontend'] else 'não'}"
            )
            if info["frontend"]:
                print(
                    f"Build: {info['package_manager']}@{info['package_manager_version']} "
                    f"em {info['frontend_dir'].relative_to(ROOT)}"
                )
        elif args.command == "package":
            package_tag(args.tag, args.output_dir)
        else:
            notes = release_notes(args.tag)
            args.output_file.parent.mkdir(parents=True, exist_ok=True)
            args.output_file.write_text(notes, encoding="utf-8")
            print(notes, end="")
    except (ReleaseError, OSError, json.JSONDecodeError) as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
