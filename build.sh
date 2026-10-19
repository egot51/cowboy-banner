#!/bin/sh
# Пересборка всех артефактов из исходников.
#   ./build.sh
#
# Нужен Node.js 18+. Порядок: сцены -> профиль PowerShell -> баннер cmd -> AUR-пакет.
set -e

ROOT=$(cd "$(dirname "$0")" && pwd)
command -v node >/dev/null 2>&1 || {
    echo "Node.js не найден: нужен для пересборки (https://nodejs.org)" >&2
    exit 1
}

cd "$ROOT/tools"

echo "1/4  рисуем сцены..."
node gen-scene.js

echo "2/4  профиль PowerShell..."
node gen-profile.js "$ROOT/windows/profile.ps1"

echo "3/4  баннер для cmd (cp866)..."
node gen-cmd.js "$ROOT/windows/cowboy.cmd"

echo "4/4  AUR-пакет..."
node gen-linux.js

echo ""
echo "Готово. Проверка: bash tests/test-linux.sh, bash tests/test-pkgbuild.sh"
