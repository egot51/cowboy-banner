// Сборка PowerShell-профиля с приветствием "Дикий Запад".
//
// Арт ПРЕ-РАСКРАШИВАЕТСЯ здесь, в генераторе: в профиле лежат готовые строки
// с ANSI-последовательностями. Иначе PowerShell 5.1 тратит ~200 мс на разбор
// сотен хештаблиц разметки при каждом старте.
const fs = require("fs");
const path = require("path");

// Раскраска и данные сцен живут в общем модуле: его же использует генератор
// AUR-пакета для Linux, поэтому обе версии баннера не могут разойтись.
const { data, paintArt } = require("./paint.js");
const sceneIds = Object.keys(data.scenes);

const painted = (id, setName) => {
  const s = data.scenes[id][setName];
  return paintArt(s.art, s.segments);
};

// Раньше здесь лежал свой список поговорок (20 штук). Он не использовался:
// тексты берутся из scenes.json по темам, см. THEMES в gen-scene.js.
// Удалён вместе с банановой шуткой.

const ps = String.raw`# ══════════════════════════════════════════════════════════════════════════
#  THE WILD WEST — приветствие при каждом запуске PowerShell.
#  Сцен: __LIST__. Каждый запуск - случайная, соседние не повторяются.
#
#    cowboy                 показать ещё одну картинку
#    Disable-CowboyBanner   не показывать (до конца сессии)
#    Enable-CowboyBanner    снова показывать
#    Переменная одна на cmd и PowerShell (работает и COWBOY_CMD, и COWBOY_BANNER):
#      setx COWBOY_BANNER off      выключить навсегда (нужно новое окно)
#      setx COWBOY_BANNER ascii    ASCII-версия (на случай старой кодировки)
#      setx COWBOY_BANNER plain    без цвета
#
#  Арт собран скриптами tools/gen-scene.js + tools/gen-profile.js
# ══════════════════════════════════════════════════════════════════════════

$global:CowboyArt = @{
__ART__
}

$global:CowboyThemeIds = @(__THEME_IDS__)

# id темы -> список сцен
$global:CowboyThemeScenes = @{
__THEME_SCENES__
}

# id темы -> заголовок для строки приветствия
$global:CowboyThemeTitles = @{
__THEME_TITLES__
}

# Приветствия и поговорки под каждую тему (латиница - одинаково везде)
$global:CowboySayings = @{
__SAYINGS__
}

$global:CowboySceneIds = @(__IDS__)

# Консоль должна уметь показать псевдографику и ANSI-последовательности,
# иначе включим UTF-8. Пробуем ВЕСЬ арт: в cp866, например, есть ─ и │,
# но нет ╱ ╲ ╭ ╮ — проверять один символ нельзя.
function Initialize-CowboyConsole {
    try {
        $probe = $global:CowboyArt.Values | Select-Object -First 1
        $enc = [Console]::OutputEncoding
        if ($enc.GetString($enc.GetBytes($probe)) -ne $probe) {
            [Console]::OutputEncoding = [Text.Encoding]::UTF8
        }
    } catch { }
}

# Какая тема активна. COWBOY_THEME: wildwest | space | cyber | ocean | any
function Get-CowboyTheme {
    $t = $env:COWBOY_THEME
    if ($t) { $t = $t.Trim().ToLower() }
    if (-not $t) { $t = 'wildwest' }
    if ($t -eq 'any') {
        $ids = $global:CowboyThemeIds
        return $ids[(Get-CowboyRng).Next($ids.Count)]
    }
    if ($global:CowboyThemeScenes.ContainsKey($t)) { return $t }
    return 'wildwest'
}

# Меню выбора темы - печатается, когда баннеры выключены (COWBOY_BANNER=off)
function Get-CowboyMenu {
    $E = [char]27
    $cur = if ($env:COWBOY_THEME) { $env:COWBOY_THEME.Trim().ToLower() } else { 'wildwest' }
    $inner = 60

    function Row($text, $color) {
        $t = $text
        if ($t.Length -gt $inner) { $t = $t.Substring(0, $inner) }
        return "  " + $E + $color + "║" + (" " + $t).PadRight($inner) + "║" + $E + "[0m"
    }

    $top    = "  " + $E + "[38;5;214m╔" + ("═" * $inner) + "╗" + $E + "[0m"
    $mid    = "  " + $E + "[38;5;214m╠" + ("═" * $inner) + "╣" + $E + "[0m"
    $bottom = "  " + $E + "[38;5;214m╚" + ("═" * $inner) + "╝" + $E + "[0m"

    $out = @()
    $out += $top
    $out += (Row "  Т Е М Ы   Б А Н Н Е Р О В   -   что рисовать?" "[38;5;231m")
    $out += $mid
    foreach ($t in $global:CowboyThemeIds) {
        $mark = if ($t -eq $cur) { '>' } else { ' ' }
        $name = $t.PadRight(9)
        $desc = $global:CowboyThemeTitles[$t].PadRight(14)
        $note = "$($global:CowboyThemeScenes[$t].Count) шт".PadLeft(6)
        $color = if ($t -eq $cur) { "[1;38;5;120m" } else { "[38;5;223m" }
        $out += (Row " $mark $name $desc $note " $color)
    }
    $mark = if ($cur -eq 'any') { '>' } else { ' ' }
    $out += (Row " $mark any       любая тема      (случайно) " ("[38;5;223m"))
    $out += $bottom
    $out += ""
    $out += "$E[1;38;5;84m  Сейчас активна тема: $cur$E[0m"
    $out += ""
    $out += "$E[38;5;223m  Переключить тему (работает и в PowerShell, и в cmd):$E[0m"
    foreach ($t in $global:CowboyThemeIds) {
        $out += "$E[38;5;242m      setx COWBOY_THEME $t$E[0m"
    }
    $out += "$E[38;5;242m      setx COWBOY_THEME any$E[0m   " + "$E[38;5;240m(каждая картинка случайная)$E[0m"
    $out += ""
    $out += "$E[38;5;223m  Только для текущего окна, без setx:$E[0m"
    $out += "$E[38;5;242m      " + '$env:COWBOY_THEME' + " = 'ocean'$E[0m   " + "$E[38;5;240m(PowerShell)$E[0m"
    $out += "$E[38;5;242m      set COWBOY_THEME=ocean$E[0m   " + "$E[38;5;240m(cmd)$E[0m"
    $out += ""
    $out += "$E[38;5;223m  Что бывает в COWBOY_BANNER:$E[0m"
    $out += "$E[38;5;242m" + '      (не задана)  рисовать картинку         setx COWBOY_BANNER ""' + "$E[0m"
    $out += "$E[38;5;242m      menu        показывать это меню       setx COWBOY_BANNER menu$E[0m"
    $out += "$E[38;5;242m      none        не выводить ничего         setx COWBOY_BANNER none$E[0m"
    $out += "$E[38;5;242m      ascii       без псевдографики           setx COWBOY_BANNER ascii$E[0m"
    $out += "$E[38;5;242m      plain       без цвета                  setx COWBOY_BANNER plain$E[0m"
    $out += "$E[38;5;242m      (off = menu, старое имя, работает так же)$E[0m"
    $out += ""
    $out += "$E[38;5;242m  Подсказки в баннере включаются отдельно:  setx COWBOY_HINT on$E[0m"
    return $out -join [Environment]::NewLine
}

# Следующая сцена всегда отличается от предыдущей - запоминаем выбор в TEMP.
# Get-Random в PowerShell 5.1 стоит ~4 мс на вызов, поэтому свой System.Random.
# Сид обязательно явный: [Random]::new() без аргументов сеется по Environment.TickCount
# с грубым разрешением, и два процесса подряд получают одну и ту же последовательность.
function Get-CowboyRng {
    if (-not $global:CowboyRng) { $global:CowboyRng = [System.Random]::new([Guid]::NewGuid().GetHashCode()) }
    return $global:CowboyRng
}

function Get-CowboySceneId {
    $ids = $global:CowboyThemeScenes[(Get-CowboyTheme)]
    $n = $ids.Count
    $i = (Get-CowboyRng).Next($n)
    $state = "$env:TEMP\cowboy-banner.state"
    # File::Exists, а не try/ReadAllText: исключение в PowerShell стоит ~10 мс
    $last = $null
    if ([IO.File]::Exists($state)) {
        try { $last = [IO.File]::ReadAllText($state).Trim() } catch { }
    }
    if ($last -and $n -gt 1 -and $ids[$i] -eq $last) { $i = ($i + 1) % $n }
    $id = $ids[$i]
    try { [IO.File]::WriteAllText($state, $id) } catch { }
    return $id
}

# Подсказки и метка темы - только если явно попросили: setx COWBOY_HINT on
function Test-CowboyHint {
    $h = $env:COWBOY_HINT
    if ($h) { $h = $h.Trim().ToLower() }
    return ($h -eq 'on' -or $h -eq '1' -or $h -eq 'yes' -or $h -eq 'true')
}

function Get-CowboyBanner {
    [CmdletBinding()]
    param([switch]$Plain)

    # Переключатель один на оба шелла: COWBOY_BANNER или COWBOY_CMD.
    # .Trim() страхует от значения с пробелом - в cmd это классическая ловушка
    # ("set X=off " даёт "off ", и сравнение не проходит).
    $flag = if ($env:COWBOY_BANNER) { $env:COWBOY_BANNER } else { $env:COWBOY_CMD }
    if ($flag) { $flag = $flag.Trim().ToLower() }

    $theme = Get-CowboyTheme
    $id = Get-CowboySceneId
    $scene = $global:CowboyArt[$id]

    $plain = $Plain -or $flag -eq 'plain'
    $art = $scene
    if ($plain -or $flag -eq 'ascii') {
        $art = $scene -replace "$([char]27)\[[0-9;]*m", ''
    }

    $E = [char]27
    $hour = (Get-Date).Hour
    if ($hour -lt 5) { $part = 'ДОБРАЯ НОЧЬ' }
    elseif ($hour -lt 12) { $part = 'ДОБРОЕ УТРО' }
    elseif ($hour -lt 18) { $part = 'ДОБРЫЙ ДЕНЬ' }
    else { $part = 'ДОБРЫЙ ВЕЧЕР' }
    $who = $env:USERNAME
    if ($who) { $who = $who.ToUpper() }

    # Приветствие и поговорка - из своей темы
    $say = $global:CowboySayings[$theme]
    $rng = Get-CowboyRng
    $hi = $say.Greet[$rng.Next($say.Greet.Count)]
    $pool = if ($plain) { $say.En } else { $say.Ru }
    $fortune = $pool[$rng.Next($pool.Count)]
    if ($fortune -eq $global:CowboyLastFortune) { $fortune = $pool[$rng.Next($pool.Count)] }
    $global:CowboyLastFortune = $fortune

    $NL = [char]10
    # Подсказка внизу и метка [тема] - только если явно попросили:
    # setx COWBOY_HINT on
    $hint = Test-CowboyHint
    if ($plain) {
        $line = "  $hi, $who!   $part"
        if ($hint) { $line += "   [$theme]" }
        return $art + $NL + $line + $NL + "  $fortune"
    }
    $tag = if ($hint) { " $E[38;5;245m[$theme]$E[0m" } else { '' }
    $tail = if ($hint) { $NL + "$E[38;5;242m  COWBOY_THEME=<theme> - сменить тему   |   COWBOY_BANNER=menu - меню тем$E[0m" } else { '' }
    return $art + $NL + "$E[1;38;5;84m  $hi,$E[0m $E[38;5;245m$who$E[0m $E[1;38;5;84m$part$E[0m$tag" +
        $NL + "$E[38;5;223m  «$fortune»$E[0m" + $tail
}

function Show-CowboyBanner { Write-Host (Get-CowboyBanner) }
function Show-CowboyMenu { Write-Host (Get-CowboyMenu) }
function Disable-CowboyBanner { $global:CowboyMuted = $true; Write-Host 'Шляпа отброшена. До связи, ковбой.' -ForegroundColor DarkGray }
function Enable-CowboyBanner  { Remove-Variable -Name CowboyMuted -Scope Global -ErrorAction SilentlyContinue }
Set-Alias -Name cowboy -Value Show-CowboyBanner -Scope Global -Force

Initialize-CowboyConsole
$__flag = if ($env:COWBOY_BANNER) { $env:COWBOY_BANNER } else { $env:COWBOY_CMD }
if ($__flag) { $__flag = $__flag.Trim().ToLower() }
$__th = if ($env:COWBOY_THEME) { $env:COWBOY_THEME.Trim().ToLower() } else { '' }
if ($global:CowboyMuted) {
    # тишина - Disable-CowboyBanner в этой сессии
} elseif ($__flag -eq 'none') {
    # совсем ничего
} elseif ($__flag -eq 'menu' -or $__flag -eq 'off' -or $__th -eq 'menu') {
    Show-CowboyMenu
} else {
    Show-CowboyBanner
}
`;

const artBlocks = sceneIds
  .map((id) => {
    const u = painted(id, "unicode");
    return `    ${id} = @'\n${u}\n'@`;
  })
  .join("\n");

const themes = data.themes;
const themeTitles = themes.map((t) => `    ${t.id} = '${t.ru}'`).join("\n");
const themeScenes = themes
  .map((t) => `    ${t.id} = @(${t.scenes.map((s) => `'${s}'`).join(", ")})`)
  .join("\n");

const psSayings = (list) =>
  list
    .map((t) => {
      const arr = (a) => a.map((s) => "'" + s.replace(/'/g, "''") + "'").join(", ");
      return `    ${t.id} = @{\n        Greet = @(${arr(t.greet)})\n        Ru = @(${arr(t.sayRu)})\n        En = @(${arr(t.sayEn)})\n    }`;
    })
    .join("\n");

let out = ps
  .replace("__LIST__", themes.map((t) => t.id).join(", "))
  .replace("__ART__", artBlocks)
  .replace("__THEME_IDS__", themes.map((t) => `'${t.id}'`).join(", "))
  .replace("__THEME_SCENES__", themeScenes)
  .replace("__THEME_TITLES__", themeTitles)
  .replace("__SAYINGS__", psSayings(themes))
  .replace("__IDS__", sceneIds.map((s) => `'${s}'`).join(", "));

const left = out.match(/__[A-Z][A-Z_]*__/g);
if (left) throw new Error("не подставлены плейсхолдеры: " + [...new Set(left)].join(", "));

const target = process.argv[2];
if (!target) {
  console.error("usage: node gen-profile.js <путь-к-profile.ps1>");
  process.exit(1);
}
fs.writeFileSync(target, "\uFEFF" + out, "utf8");
console.log(`профиль записан: ${target}`);
console.log(`сцен: ${sceneIds.length} (${sceneIds.join(", ")}) | ${Buffer.byteLength(out, "utf8")} байт + BOM`);
