# Сборка всех пакетов на Windows.
#   .\packaging\build-all.ps1
#
# Что делает:
#   1. пересобирает дерево файлов пакета (нужны Node.js)
#   2. собирает .deb (свой сборщик, dpkg-deb не нужен)
#   3. собирает zip для Scoop, Chocolatey и winget
#   4. вписывает настоящий sha256 в манифесты
#   5. прогоняет тесты
#
# .deb и zip собираются везде, где есть Node.js. rpm требует rpmbuild
# (см. packaging/build-all.sh).

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Step($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'Node.js не найден: нужен для сборки (https://nodejs.org)'
}

Step '1/5  пересобираем дерево пакета'
Push-Location (Join-Path $root 'tools')
try { node gen-linux.js } finally { Pop-Location }

Step '2/5  собираем .deb'
node (Join-Path $root 'packaging\build-deb.js')

Step '3/5  собираем zip для Windows-пакетов'
node (Join-Path $root 'packaging\build-zip.js')

Step '4/5  собираем .rpm (nfpm)'
$nfpm = Get-Command nfpm -ErrorAction SilentlyContinue
if (-not $nfpm) {
    $local = Join-Path $root 'packaging\tools\nfpm.exe'
    if (Test-Path $local) { $nfpm = $local }
}
if ($nfpm) {
    node (Join-Path $root 'packaging\gen-nfpm.js')
    & $nfpm pkg --packager rpm --config (Join-Path $root 'packaging\nfpm.yaml') --target (Join-Path $root 'dist')
} else {
    Write-Host '  nfpm не найден - .rpm пропущен.' -ForegroundColor Yellow
    Write-Host '  Скачать: https://github.com/goreleaser/nfpm/releases (файл nfpm_<версия>_Windows_x86_64.zip)' -ForegroundColor Yellow
    Write-Host '  Положить бинарник в packaging\tools\ или в PATH.' -ForegroundColor Yellow
}

Step '5/5  обновляем манифесты (sha256) и прогоняем тесты'
node (Join-Path $root 'packaging\update-manifests.js')
node (Join-Path $root 'tests\test-deb.js')
if (Test-Path (Join-Path $root 'tests\test-packages.js')) {
    node (Join-Path $root 'tests\test-packages.js')
}
if (Test-Path (Join-Path $root 'tests\test-rpm.py')) {
    python (Join-Path $root 'tests\test-rpm.py')
}

Write-Host ''
Write-Host 'Готово. Артефакты в dist/' -ForegroundColor Green
Get-ChildItem (Join-Path $root 'dist') | ForEach-Object {
    Write-Host ("  {0,-46} {1,8:N0} байт" -f $_.Name, $_.Length)
}
Write-Host ''
Write-Host 'Осталось сделать руками:' -ForegroundColor Yellow
Write-Host '  - залить артефакты в Releases на GitHub (тег v1.0.0)'
Write-Host '  - собрать .rpm на машине с rpmbuild: sh packaging/build-all.sh'
Write-Host '  - залить манифест в репозиторий winget-pkgs'
