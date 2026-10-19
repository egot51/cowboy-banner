#!/usr/bin/env bash
# Тесты bash-версии cowboy-banner. Запуск: bash test-linux.sh
ROOT="$(cd "$(dirname "$0")/../linux/files" && pwd)"
SCRIPT="$ROOT/bin/cowboy-banner"
STATE_DIR="$(mktemp -d)"
STATE="$STATE_DIR/cowboy-banner.state"
pass=0
fail=0

ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (получено '$2', ждали '$3')"; fi; }

# Переменные задаём через env, а не префиксом перед вызовом функции:
# в bash такие присваивания остаются в окружении после вызова и портят
# следующие проверки.
run()  { env COWBOY_ROOT="$ROOT" COWBOY_ALWAYS=1 XDG_RUNTIME_DIR="$STATE_DIR" bash "$SCRIPT"; }
runv() { env COWBOY_ROOT="$ROOT" COWBOY_ALWAYS=1 XDG_RUNTIME_DIR="$STATE_DIR" "$1" bash "$SCRIPT"; }
runq() { env COWBOY_ROOT="$ROOT" XDG_RUNTIME_DIR="$STATE_DIR" "$@" bash "$SCRIPT"; }

echo "== синтаксис =="
for f in "$SCRIPT" "$ROOT/../cowboy-banner.install" "$ROOT/../PKGBUILD"; do
    if bash -n "$f" 2>/dev/null; then ok "bash -n $(basename "$f")"; else bad "bash -n $(basename "$f")"; fi
done

echo "== базовый вывод =="
out=$(run)
lines=$(printf '%s\n' "$out" | wc -l)
check "картинка (24) + пусто + приветствие + поговорка = 27 строк" "$lines" "27"
printf '%s\n' "$out" | grep -q 'ДОБР' && ok "приветствие по времени суток" || bad "нет приветствия"
printf '%s\n' "$out" | grep -q '«' && ok "поговорка в кавычках" || bad "нет поговорки"
printf '%s\n' "$out" | grep -q $'\033\[' && ok "цветовые коды на месте" || bad "нет ANSI-цветов"

echo "== режимы =="
check "none = пусто" "$(runv COWBOY_BANNER=none | wc -c)" "0"
check "off = меню" "$(runv COWBOY_BANNER=off | grep -c 'любая тема')" "1"
check "menu = меню" "$(runv COWBOY_BANNER=menu | grep -c 'Т Е М Ы')" "1"
check "plain без цвета" "$(runv COWBOY_BANNER=plain | grep -c $'\033\[')" "0"
check "ascii без цвета" "$(runv COWBOY_BANNER=ascii | grep -c $'\033\[')" "0"
check "NO_COLOR убирает цвет" "$(runq NO_COLOR=1 COWBOY_ALWAYS=1 | grep -c $'\033\[')" "0"
check "COWBOY_CMD = синоним" "$(runq COWBOY_CMD=menu COWBOY_ALWAYS=1 | grep -c 'Т Е М Ы')" "1"
check "COWBOY_THEME=menu = меню" "$(runv COWBOY_THEME=menu | grep -c 'Т Е М Ы')" "1"
check "COWBOY_HINT=on = подсказка" "$(runv COWBOY_HINT=on | grep -c 'COWBOY_THEME=<тема>')" "1"
check "без HINT подсказки нет" "$(run | grep -c 'COWBOY_THEME=<тема>')" "0"
check "HINT=1 тоже работает" "$(runv COWBOY_HINT=1 | grep -c 'COWBOY_THEME=<тема>')" "1"
check "значение с пробелом обрезается" "$(runq COWBOY_BANNER='menu ' COWBOY_ALWAYS=1 | grep -c 'Т Е М Ы')" "1"
check "COWBOY_THEME=' ocean ' обрезается" "$(runq COWBOY_THEME=' ocean ' COWBOY_ALWAYS=1 | grep -c '«')" "1"

echo "== темы =="
for t in wildwest space cyber ocean; do
    n=$(wc -l < "$ROOT/data/$t.scenes")
    miss=""
    for s in $(cat "$ROOT/data/$t.scenes"); do
        [ -r "$ROOT/art/$s.txt" ] || miss="$miss $s"
    done
    [ -z "$miss" ] && ok "тема $t: $n картинки, арт на месте" || bad "тема $t: нет арта:$miss"
done
check "тема ocean рисуется" "$(runv COWBOY_THEME=ocean | grep -c '«')" "1"
check "любая тема (any)" "$(runv COWBOY_THEME=any | grep -c '«')" "1"
check "неизвестная тема -> wildwest" "$(runv COWBOY_THEME=bananas | grep -c 'ДОБР')" "1"

echo "== без повторов подряд =="
rm -f "$STATE"
rep=0
prev="___ничего___"
for i in $(seq 1 40); do
    runv COWBOY_THEME=wildwest > /dev/null
    cur=$(head -1 "$STATE" 2>/dev/null)
    [ "$cur" = "$prev" ] && rep=$((rep + 1))
    prev="$cur"
done
check "40 запусков wildwest без повтора подряд" "$rep" "0"
distinct=$(for i in $(seq 1 40); do runv COWBOY_THEME=cyber > /dev/null; head -1 "$STATE"; done | sort -u | wc -l)
check "за 40 запусков cyber показаны обе картинки" "$distinct" "2"

echo "== локали =="
check "LANG=C -> английская поговорка" "$(runq LANG=C LC_ALL=C COWBOY_ALWAYS=1 | tail -1 | grep -c '[A-Za-z]\{4,\}')" "1"
check "LANG=ru_RU.UTF-8 -> русская поговорка" "$(runq LANG=ru_RU.UTF-8 LC_ALL= COWBOY_ALWAYS=1 | tail -1 | grep -c '[А-Яа-я]')" "1"

echo "== молчание при перенаправлении =="
check "без COWBOY_ALWAYS в пайпе - тишина" "$(runq | wc -c)" "0"

echo
echo "итого: $pass OK, $fail FAIL"
[ "$fail" -eq 0 ]
