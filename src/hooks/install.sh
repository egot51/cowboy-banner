#!/bin/sh
# Общий хук установки для Unix-пакетов (deb, rpm, AUR).
#
# Дописывает вызов баннера в rc-файлы и профиль PowerShell. Всё с метками,
# чтобы хук удаления мог вырезать блоки обратно. Бэкап делается только
# при первом изменении файла.
#
# Вызывается как: install.sh <каталог-дома>
# Без аргумента берётся домашний каталог того, кто ставил пакет.

set -e

BANNER=/usr/bin/cowboy-banner
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

block() {
    cat <<EOF
$MARK_BEGIN
# Баннер при старте терминала. Управление: export COWBOY_THEME=ocean
case \$- in
    *i*) [ -x $BANNER ] && $BANNER ;;
esac
$MARK_END
EOF
}

wire() {
    rc="$1"
    [ -n "$rc" ] || return 0
    if [ ! -e "$rc" ]; then
        mkdir -p "$(dirname "$rc")"
        block > "$rc"
        return 0
    fi
    if grep -qF "$MARK_BEGIN" "$rc"; then
        return 0
    fi
    [ -e "$rc.cowboy-banner.bak" ] || cp -p "$rc" "$rc.cowboy-banner.bak"
    printf '\n' >> "$rc"
    block >> "$rc"
}

wire "$home/.bashrc"
wire "$home/.zshrc"

psdir="$home/.config/powershell"
psprof="$psdir/Microsoft.PowerShell_profile.ps1"
if [ ! -e "$psprof" ]; then
    mkdir -p "$psdir"
    cat > "$psprof" <<EOF
$MARK_BEGIN
. /usr/share/cowboy-banner/profile.ps1
$MARK_END
EOF
else
    wire "$psprof"
fi

exit 0
