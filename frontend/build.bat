@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js nao encontrado. Instale Node.js apenas no ambiente de desenvolvimento.
  exit /b 1
)
node scripts\build-and-package.mjs %*
