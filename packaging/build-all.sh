#!/bin/sh
# Сборка всех пакетов на Linux.
#   sh packaging/build-all.sh
#
# .deb и zip собираются на Node.js, .rpm - через rpmbuild.
# rpmbuild есть не везде: без него пакет просто пропускается.

set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

step() { printf '\n%s\n' "$1"; }
have() { command -v "$1" > /dev/null 2>&1; }

command -v node > /dev/null 2>&1 || {
    echo "Node.js не найден: нужен для сборки (https://nodejs.org)" >&2
    exit 1
}

step "1/5  пересобираем дерево пакета"
( cd tools && node gen-linux.js )

step "2/5  собираем .deb"
node packaging/build-deb.js

step "3/5  собираем .rpm"
# Два пути: nfpm (один конфиг на все форматы) или rpmbuild по spec-файлу.
if have nfpm; then
    node packaging/gen-nfpm.js
    nfpm pkg --packager rpm --config packaging/nfpm.yaml --target dist
elif have rpmbuild; then
    rm -rf dist/rpm
    mkdir -p dist/rpm/SOURCES
    # В архиве должно быть cowboy-banner-1.0.0/files/..., а не
    # cowboy-banner-1.0.0/linux/files/... - иначе %install не найдёт дерево.
    tar czf "dist/rpm/SOURCES/cowboy-banner-1.0.0.tar.gz" \
        --transform 's,^,cowboy-banner-1.0.0/,' -C linux files
    rpmbuild --define "_topdir $PWD/dist/rpm" \
             --define "_sourcedir $PWD/dist/rpm/SOURCES" \
             -ba packaging/rpm/cowboy-banner.spec
    ls -la dist/*.rpm
else
    echo "  nfpm и rpmbuild не найдены - .rpm пропущен" >&2
    echo "  nfpm: https://github.com/goreleaser/nfpm/releases" >&2
fi

step "4/5  собираем zip и обновляем манифесты"
node packaging/build-zip.js
node packaging/update-manifests.js

step "5/5  тесты"
node tests/test-deb.js
if [ -f tests/test-packages.js ]; then node tests/test-packages.js; fi

printf '\nГотово. Артефакты в dist/\n'
ls -la dist/ | tail -n +2
