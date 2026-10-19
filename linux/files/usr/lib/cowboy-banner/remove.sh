#!/bin/sh
# Общий хук удаления для Unix-пакетов (deb, rpm, AUR).
# Вырезает блоки с метками из rc-файлов и профиля PowerShell.
#
# Вызывается как: remove.sh <каталог-дома>

set -e

MARK_BEGIN="# >>> cowboy-banner >>>"
MARK_END="# <<< cowboy-banner <<<"

home="${1:-}"
if [ -z "$home" ]; then
    if [ -n "${SUDO_USER:-}" ] && [ -d "/home/$SUDO_USER" ]; then
        home="/home/$SUDO_USER"
    else
        home="${HOME:-/root}"
    fi
fi

strip() {
    rc="$1"
    [ -e "$rc" ] || return 0
    grep -qF "$MARK_BEGIN" "$rc" || return 0
    tmp=$(mktemp)
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
        $0 == b  { skip = 1; next }
        $0 == e  { skip = 0; next }
        !skip    { print }
    ' "$rc" > "$tmp"
    cat "$tmp" > "$rc"
    rm -f "$tmp"
}

strip "$home/.bashrc"
strip "$home/.zshrc"
strip "$home/.config/powershell/Microsoft.PowerShell_profile.ps1"

exit 0
