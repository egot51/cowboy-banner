#!/bin/sh
# Перегенерировать .SRCINFO так, как это сделает makepkg.
# Запускать на Arch: sh update-srcinfo.sh
set -e
command -v makepkg >/dev/null 2>&1 || {
    echo "makepkg не найден: этот скрипт нужен только на Arch" >&2
    exit 1
}
makepkg --printsrcinfo > .SRCINFO
echo ".SRCINFO обновлён"
