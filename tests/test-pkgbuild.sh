#!/usr/bin/env bash
# Имитация makepkg и pacman: выполняем check(), package() и хуки .install
# из PKGBUILD в отдельном каталоге. Ловит опечатки в путях, глобах и
# идемпотентность подключения к rc-файлам.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
AUR="$HERE/../linux"
WORK="$(mktemp -d)"
pass=0
fail=0

ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }
expect(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (получено '$2', ждали '$3')"; fi; }

echo "== makepkg: check() =="
export startdir="$AUR"
pkgdir="$WORK/pkg"
mkdir -p "$pkgdir"
cd "$AUR" || exit 1
# shellcheck source=/dev/null
source ./PKGBUILD
if check > /dev/null 2>&1; then ok "check() прошёл"; else bad "check() провалился"; fi

echo "== makepkg: package() =="
if package > /dev/null 2>&1; then ok "package() отработал"; else bad "package() упал"; package; fi
for f in usr/bin/cowboy-banner usr/share/cowboy-banner/profile.ps1 \
         usr/share/cowboy-banner/data/themes.list usr/share/man/man1/cowboy-banner.1 \
         usr/share/doc/cowboy-banner/README.md usr/share/licenses/cowboy-banner/LICENSE \
         etc/skel/Default/.config/powershell/Microsoft.PowerShell_profile.ps1; do
    [ -f "$pkgdir/$f" ] && ok "$f" || bad "нет $f"
done
expect "картинок 10" "$(ls "$pkgdir/usr/share/cowboy-banner/art/" | wc -l)" "10"
expect "файлов данных 21 (4 темы x 5 + themes.list)" "$(ls "$pkgdir/usr/share/cowboy-banner/data/" | wc -l)" "21"
expect "скрипт исполняемый" "$([ -x "$pkgdir/usr/bin/cowboy-banner" ] && echo yes)" "yes"

echo "== установленный скрипт работает из pkgdir =="
if COWBOY_ROOT="$pkgdir/usr/share/cowboy-banner" COWBOY_ALWAYS=1 \
    "$pkgdir/usr/bin/cowboy-banner" | grep -q 'ДОБР'; then
    ok "баннер печатается из собранного пакета"
else
    bad "баннер не печатается из собранного пакета"
fi

echo "== хуки установки =="
export HOME="$WORK/home"
mkdir -p "$HOME/.config/powershell"
printf '# мой bashrc\nexport EDITOR=vi\n' > "$HOME/.bashrc"
printf '# мой профиль pwsh\n$OutputEncoding = [Console]::OutputEncoding\n' > \
    "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
# Путь к общим хукам задаём ДО подключения .install: он читается при загрузке
# файла, а пакет на этой машине не установлен.
export COWBOY_HOOK_DIR="$AUR/files/usr/lib/cowboy-banner"
# shellcheck source=/dev/null
source "$AUR/cowboy-banner.install"
# Подменяем путь к исходному профилю на файл из дерева пакета - функции
# читают переменные в момент вызова.
pwsh_source="$AUR/files/usr/share/cowboy-banner/profile.ps1"

post_install > "$WORK/post1.txt" 2>&1
expect "блок добавлен в .bashrc" "$(grep -c '>>> cowboy-banner >>>' "$HOME/.bashrc")" "1"
expect "исходные строки .bashrc целы" "$(grep -c 'export EDITOR=vi' "$HOME/.bashrc")" "1"
expect "бэкап .bashrc создан" "$([ -f "$HOME/.bashrc.cowboy-banner.bak" ] && echo yes)" "yes"
expect "блок добавлен в профиль pwsh" "$(grep -c '>>> cowboy-banner >>>' "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1")" "1"
expect "исходные строки профиля целы" "$(grep -c 'OutputEncoding' "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1")" "1"

post_install > "$WORK/post2.txt" 2>&1
expect "повторный post_install не дублирует" "$(grep -c '>>> cowboy-banner >>>' "$HOME/.bashrc")" "1"
expect "интерактивный guard в блоке" "$(grep -c 'case \$- in' "$HOME/.bashrc")" "1"

new_home="$WORK/home2"
mkdir -p "$new_home"
# Пути к профилю вычисляются при загрузке хука, поэтому под новый HOME
# их надо задать вручную - в pacman HOME не меняется, так что это только
# особенность теста.
HOME="$new_home"
pwsh_dir="$new_home/.config/powershell"
pwsh_profile="$pwsh_dir/Microsoft.PowerShell_profile.ps1"
post_install > /dev/null 2>&1
expect "профиль pwsh создан с нуля" "$([ -s "$pwsh_profile" ] && echo yes)" "yes"
expect "в новом профиле есть подключение баннера" "$(grep -c 'cowboy-banner/profile.ps1' "$pwsh_profile")" "1"

echo "== отключение =="
# HOME меняем именно export'ом: префиксное присваивание перед вызовом функции
# не действует на подстановки в следующих командах.
export HOME="$WORK/home"
pwsh_dir="$HOME/.config/powershell"
pwsh_profile="$pwsh_dir/Microsoft.PowerShell_profile.ps1"
pre_remove
expect "блок вырезан из .bashrc" "$(grep -c 'cowboy-banner' "$HOME/.bashrc")" "0"
expect "чужие строки .bashrc уцелели" "$(grep -c 'export EDITOR=vi' "$HOME/.bashrc")" "1"
expect "блок вырезан из профиля" "$(grep -c 'cowboy-banner' "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1")" "0"
expect "чужие строки профиля уцелели" "$(grep -c 'OutputEncoding' "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1")" "1"

echo
echo "итого: $pass OK, $fail FAIL"
rm -rf "$WORK"
[ "$fail" -eq 0 ]
