# Пересборка всех артефактов из исходников.
#   .\build.ps1
#
# Нужен Node.js 18+. Порядок: сцены -> профиль PowerShell -> баннер cmd -> AUR-пакет.
$ErrorActionPreference = 'Stop'

$root  = Split-Path -Parent $MyInvocation.MyCommand.Path
$tools = Join-Path $root 'tools'

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'Node.js не найден: нужен для пересборки (https://nodejs.org)'
}

Push-Location $tools
try {
    Write-Host '1/4  рисуем сцены...' -ForegroundColor Cyan
    node gen-scene.js

    Write-Host '2/4  профиль PowerShell...' -ForegroundColor Cyan
    node gen-profile.js (Join-Path $root 'windows\profile.ps1')

    Write-Host '3/4  баннер для cmd (cp866)...' -ForegroundColor Cyan
    node gen-cmd.js (Join-Path $root 'windows\cowboy.cmd')

    Write-Host '4/4  AUR-пакет...' -ForegroundColor Cyan
    node (Join-Path $tools 'gen-linux.js')
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Готово. Проверка: bash tests/test-linux.sh, bash tests/test-pkgbuild.sh' -ForegroundColor Green
