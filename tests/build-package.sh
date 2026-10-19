#!/usr/bin/env bash
# Сборка пакета из общего дерева files/ - так же, как это делает makepkg.
# Используется для проверки, что все форматы пакетов получают одинаковый
# состав файлов.
#
#   bash tests/build-package.sh [каталог-пакета]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="${1:-$HERE/../linux}"
cd "$PKG" || exit 1
export startdir="$PWD"
pkgdir="${2:-/tmp/cowboy-pkg}"
rm -rf "$pkgdir"; mkdir -p "$pkgdir"

# shellcheck source=/dev/null
source ./PKGBUILD
if ! package; then
    echo "  package() ПРОВАЛ" >&2
    exit 1
fi

echo "  файлов в пакете: $(find "$pkgdir" -type f | wc -l)"
find "$pkgdir" -type f | sed "s|$pkgdir||" | sort | sed 's/^/    /'
