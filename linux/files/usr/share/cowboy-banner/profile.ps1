# cowboy-banner — баннер при старте PowerShell на Linux (Arch / AUR).
#
# В отличие от версии для Windows арт не вписан в профиль, а читается из
# /usr/share/cowboy-banner/art: профиль весит килограммы вместо десятков.
#
# Переменные окружения (те же, что и в bash-версии):
#   COWBOY_THEME   wildwest | space | cyber | ocean | any | menu
#   COWBOY_BANNER  не задана - картинка; menu - меню тем; none - молчать;
#                  plain/ascii - без цвета; off = menu
#   COWBOY_HINT    on - подсказка и метка [тема] под картинкой
#   COWBOY_ALWAYS  1 - печатать и при перенаправлении вывода
#   COWBOY_ROOT    где лежит арт (по умолчанию /usr/share/cowboy-banner)

$global:CowboyRoot = if ($env:COWBOY_ROOT) { $env:COWBOY_ROOT } else { '/usr/share/cowboy-banner' }

function Get-CowboyDataPath { Join-Path $global:CowboyRoot 'data' }
function Get-CowboyArtPath  { Join-Path $global:CowboyRoot 'art' }

# Строки файла данных. Пустой массив, если файла нет - пакет мог быть удалён.
function Get-CowboyLines {
    param([string]$Name)
    $path = Join-Path (Get-CowboyDataPath) $Name
    if ([IO.File]::Exists($path)) { return @(Get-Content -LiteralPath $path -Encoding UTF8) }
    return @()
}

function Get-CowboyThemes {
    if ($global:CowboyThemes) { return $global:CowboyThemes }
    $map = [ordered]@{}
    foreach ($line in (Get-CowboyLines 'themes.list')) {
        if (-not $line.Trim()) { continue }
        $f = $line -split "`t"
        if ($f.Count -lt 2) { continue }
        $map[$f[0]] = @{
            Id     = $f[0]
            Ru     = $f[1]
            Count  = if ($f.Count -gt 2) { [int]$f[2] } else { 0 }
            Scenes = @(Get-CowboyLines "$($f[0]).scenes")
        }
    }
    $global:CowboyThemes = $map
    return $map
}

function Get-CowboyTheme {
    $themes = Get-CowboyThemes
    $t = if ($env:COWBOY_THEME) { $env:COWBOY_THEME.Trim().ToLower() } else { '' }
    if ($t -eq 'any') {
        $ids = @($themes.Keys)
        if ($ids.Count -eq 0) { return 'wildwest' }
        return $ids[(Get-CowboyRng).Next($ids.Count)]
    }
    # Пусто - обычная тема по умолчанию (не случайная), как в bash-версии.
    if (-not $t) { $t = 'wildwest' }
    if ($themes.Contains($t)) { return $t }
    return 'wildwest'
}

# Случайность с явным сидом: [Random]::new() без сида в .NET Framework сеется по
# Environment.TickCount с грубым разрешением, и соседние процессы получают одну
# последовательность.
function Get-CowboyRng {
    if (-not $global:CowboyRng) {
        $global:CowboyRng = [System.Random]::new([Guid]::NewGuid().GetHashCode())
    }
    return $global:CowboyRng
}

# Следующая картинка всегда отличается от предыдущей.
function Get-CowboySceneId {
    $theme = Get-CowboyTheme
    $ids = @((Get-CowboyThemes)[$theme].Scenes)
    if ($ids.Count -eq 0) { return $null }
    $rng = Get-CowboyRng
    $i = $rng.Next($ids.Count)
    $dir = if ($env:XDG_RUNTIME_DIR) { $env:XDG_RUNTIME_DIR } else { '/tmp' }
    $state = Join-Path $dir 'cowboy-banner.state'
    $last = $null
    if ([IO.File]::Exists($state)) {
        try { $last = [IO.File]::ReadAllText($state).Trim() } catch { }
    }
    if ($last -and $ids.Count -gt 1 -and $ids[$i] -eq $last) { $i = ($i + 1) % $ids.Count }
    $id = $ids[$i]
    try { [IO.File]::WriteAllText($state, $id) } catch { }
    return $id
}

function Test-CowboyHint {
    $h = $env:COWBOY_HINT
    if ($h) { $h = $h.Trim().ToLower() }
    return ($h -eq 'on' -or $h -eq '1' -or $h -eq 'yes' -or $h -eq 'true')
}

function Get-CowboyFlag {
    $flag = if ($env:COWBOY_BANNER) { $env:COWBOY_BANNER } else { $env:COWBOY_CMD }
    if ($flag) { $flag = $flag.Trim().ToLower() }
    return $flag
}

function Get-CowboyGreeting {
    $theme = Get-CowboyTheme
    $greet = @(Get-CowboyLines "$theme.greet")
    if ($greet.Count -eq 0) { return 'H O W D Y' }
    return $greet[(Get-CowboyRng).Next($greet.Count)]
}

# Английская поговорка - если культура терминала английская, иначе кириллица.
function Get-CowboyEnglish {
    if ($null -ne $global:CowboyEnglish) { return $global:CowboyEnglish }
    $name = ''
    try { $name = [System.Globalization.CultureInfo]::CurrentCulture.Name } catch { $name = '' }
    $global:CowboyEnglish = [bool]($name -like 'en*')
    return $global:CowboyEnglish
}

function Get-CowboyFortune {
    param([switch]$English)
    if (-not $English) { $English = Get-CowboyEnglish }
    $theme = Get-CowboyTheme
    $file = if ($English) { "$theme.sayen" } else { "$theme.say" }
    $pool = @(Get-CowboyLines $file)
    if ($pool.Count -eq 0) { $pool = @(Get-CowboyLines "$theme.sayen") }
    if ($pool.Count -eq 0) { return '' }
    $rng = Get-CowboyRng
    $i = $rng.Next($pool.Count)
    if ($pool.Count -gt 1 -and $pool[$i] -eq $global:CowboyLastFortune) {
        $i = ($i + 1) % $pool.Count
    }
    $global:CowboyLastFortune = $pool[$i]
    return $pool[$i]
}

function Get-CowboyPartOfDay {
    $hour = (Get-Date).Hour
    if ($hour -lt 5) { return 'ДОБРАЯ НОЧЬ' }
    elseif ($hour -lt 12) { return 'ДОБРОЕ УТРО' }
    elseif ($hour -lt 18) { return 'ДОБРЫЙ ДЕНЬ' }
    else { return 'ДОБРЫЙ ВЕЧЕР' }
}

function Get-CowboyUserName {
    $who = if ($env:USER) { $env:USER } elseif ($env:USERNAME) { $env:USERNAME } elseif ($env:LOGNAME) { $env:LOGNAME } else { 'КОВБОЙ' }
    return $who.ToUpper()
}

function Get-CowboyBanner {
    [CmdletBinding()]
    param([switch]$Plain)

    $flag = Get-CowboyFlag
    $theme = Get-CowboyTheme
    $id = Get-CowboySceneId
    if (-not $id) { return '' }

    $artPath = Join-Path (Get-CowboyArtPath) "$id.txt"
    if (-not [IO.File]::Exists($artPath)) { return '' }
    $art = [IO.File]::ReadAllText($artPath)

    $plain = $Plain -or $flag -eq 'plain' -or $flag -eq 'ascii' -or [bool]$env:NO_COLOR
    if ($plain) { $art = $art -replace "$([char]27)\[[0-9;]*m", '' }

    $E = [char]27
    $hi = Get-CowboyGreeting
    $who = Get-CowboyUserName
    $part = Get-CowboyPartOfDay
    $fortune = Get-CowboyFortune
    $NL = [char]10

    if ($plain) {
        $line = "  $hi, $who!   $part"
        if (Test-CowboyHint) { $line += "   [$theme]" }
        $out = $art + $NL + $line + $NL + "  $fortune"
        if (Test-CowboyHint) { $out += $NL + '  COWBOY_THEME=<тема> - сменить тему   |   COWBOY_BANNER=menu - меню тем' }
        return $out
    }

    $tag = if (Test-CowboyHint) { " $E[38;5;245m[$theme]$E[0m" } else { '' }
    $tail = if (Test-CowboyHint) {
        $NL + "$E[38;5;242m  COWBOY_THEME=<тема> - сменить тему   |   COWBOY_BANNER=menu - меню тем$E[0m"
    } else { '' }
    return $art + $NL + "$E[1;38;5;84m  $hi,$E[0m $E[38;5;245m$who$E[0m $E[1;38;5;84m$part$E[0m$tag" +
        $NL + "$E[38;5;223m  «$fortune»$E[0m" + $tail
}

function Get-CowboyMenu {
    $E = [char]27
    $cur = if ($env:COWBOY_THEME) { $env:COWBOY_THEME.Trim().ToLower() } else { '' }
    if (-not $cur) { $cur = 'wildwest' }

    $out = @()
    $out += ''
    $out += "$E[1;38;5;84m  Т Е М Ы   Б А Н Н Е Р О В$E[0m   $E[38;5;242m- что рисовать?$E[0m"
    foreach ($key in (Get-CowboyThemes).Keys) {
        $t = (Get-CowboyThemes)[$key]
        $mark = if ($key -eq $cur) { '*' } else { ' ' }
        $color = if ($key -eq $cur) { "$E[1;38;5;120m" } else { "$E[38;5;223m" }
        $note = if ($key -eq $cur) { 'сейчас' } else { "$($t.Count) картинок" }
        $out += "  $color$mark $($key.PadRight(10)) $($t.Ru.PadRight(15)) $note$E[0m"
    }
    $mark = if ($cur -eq 'any') { '*' } else { ' ' }
    $out += "  $E[38;5;223m$mark any        любая тема     (случайно)$E[0m"
    $out += ''
    $out += "$E[1;38;5;84m  Сейчас активна тема: $cur$E[0m"
    $out += ''
    $out += "$E[38;5;223m  Переключить тему (PowerShell):$E[0m"
    foreach ($key in (Get-CowboyThemes).Keys) {
        $out += "$E[38;5;242m      " + '$env:COWBOY_THEME' + " = '$key'$E[0m"
    }
    $out += "$E[38;5;242m      " + '$env:COWBOY_THEME' + " = 'any'$E[0m   $E[38;5;240m(каждая картинка случайная)$E[0m"
    $out += ''
    $out += "$E[38;5;223m  Что бывает в COWBOY_BANNER:$E[0m"
    $out += "$E[38;5;242m      (не задана)  рисовать картинку         " + '$env:COWBOY_BANNER' + " = ''$E[0m"
    $out += "$E[38;5;242m      menu        показывать это меню       " + '$env:COWBOY_BANNER' + " = 'menu'$E[0m"
    $out += "$E[38;5;242m      none        не выводить ничего         " + '$env:COWBOY_BANNER' + " = 'none'$E[0m"
    $out += "$E[38;5;242m      plain       без цвета                  " + '$env:COWBOY_BANNER' + " = 'plain'$E[0m"
    $out += ''
    $out += "$E[38;5;242m  Подсказки в баннере включаются отдельно:  " + '$env:COWBOY_HINT' + " = 'on'$E[0m"
    return $out -join [Environment]::NewLine
}

function Show-CowboyBanner { Write-Host (Get-CowboyBanner) }
function Show-CowboyMenu   { Write-Host (Get-CowboyMenu) }
function Disable-CowboyBanner { $global:CowboyMuted = $true; Write-Host 'Шляпа отброшена. До связи, ковбой.' -ForegroundColor DarkGray }
function Enable-CowboyBanner  { Remove-Variable -Name CowboyMuted -Scope Global -ErrorAction SilentlyContinue }
Set-Alias -Name cowboy -Value Show-CowboyBanner -Scope Global -Force

# Автозапуск. Молчим при перенаправлении вывода и в неинтерактивных сессиях,
# иначе баннер попадёт в вывод скриптов (COWBOY_ALWAYS=1 включает его обратно).
$__flag = Get-CowboyFlag
$__th = if ($env:COWBOY_THEME) { $env:COWBOY_THEME.Trim().ToLower() } else { '' }
$__always = ($env:COWBOY_ALWAYS -eq '1')
if ($global:CowboyMuted) {
    # тишина - Disable-CowboyBanner в этой сессии
} elseif ($__flag -eq 'none') {
    # совсем ничего
} elseif (-not $__always -and (-not [Environment]::UserInteractive -or [Console]::IsOutputRedirected)) {
    # перенаправленный вывод или -NonInteractive
} elseif ($__flag -eq 'menu' -or $__flag -eq 'off' -or $__th -eq 'menu') {
    Show-CowboyMenu
} else {
    Show-CowboyBanner
}
