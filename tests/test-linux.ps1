# Тест Linux-профиля cowboy-banner на Windows PowerShell.
# Логика та же, отличаются только пути и переменные окружения.
$ErrorActionPreference = 'Stop'
$root    = "$PSScriptRoot\..\linux\files"
$stateD  = Join-Path $env:TEMP ('cowboy-test-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $stateD -Force | Out-Null

$env:COWBOY_ROOT          = $root
$env:XDG_RUNTIME_DIR      = $stateD
$env:COWBOY_ALWAYS        = '1'
$env:COWBOY_BANNER        = ''
$env:COWBOY_THEME         = ''
$env:COWBOY_HINT          = ''

$script:pass = 0; $script:fail = 0
function Check($name, $got, $want) {
    if ("$got" -eq "$want") { $script:pass++; Write-Host "  OK   $name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  FAIL $name (получено '$got', ждали '$want')" -ForegroundColor Red }
}
function CheckLike($name, $got, $pattern) {
    if ("$got" -match $pattern) { $script:pass++; Write-Host "  OK   $name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  FAIL $name (не совпало с /$pattern/)" -ForegroundColor Red }
}
function CheckUnlike($name, $got, $pattern) {
    if ("$got" -notmatch $pattern) { $script:pass++; Write-Host "  OK   $name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  FAIL $name (совпало с /$pattern/, а не должно)" -ForegroundColor Red }
}

Write-Host '== загрузка профиля ==' -ForegroundColor Cyan
. "$root\profile.ps1"
CheckLike 'профиль загрузился, картинка напечатана' "$($global:CowboyThemes.Count)" '^4$'
Check 'функции на месте' (@(Get-Command Show-CowboyBanner, Show-CowboyMenu, Get-CowboyBanner, cowboy -EA SilentlyContinue).Count) 4

Write-Host '== баннер ==' -ForegroundColor Cyan
$b = Get-CowboyBanner
Check '27 строк' ((@($b -split "`n")).Count) 27
CheckLike 'приветствие' $b 'ДОБР\w+ '
CheckLike 'поговорка в кавычках' $b '«.+»'
CheckLike 'есть ANSI-цвета' $b "\e\[38;5;"
CheckUnlike 'подсказки нет по умолчанию' $b 'COWBOY_THEME=<тема>'
Check 'plain без цвета' ((Get-CowboyBanner -Plain) -match "\e\[") 'False'

Write-Host '== режимы ==' -ForegroundColor Cyan
$env:COWBOY_HINT = 'on'
CheckLike 'HINT=on добавляет подсказку' (Get-CowboyBanner) 'COWBOY_THEME=<тема>'
CheckLike 'HINT=on добавляет метку [тему]' (Get-CowboyBanner) "\[wildwest\]"
$env:COWBOY_HINT = ''
$env:COWBOY_THEME = ' space '
CheckLike 'пробелы в теме обрезаются' (Get-CowboyTheme) '^space$'
CheckLike 'в меню есть активная тема' (Get-CowboyMenu) '\* space'
$env:COWBOY_THEME = 'bananas'
CheckLike 'неизвестная тема -> wildwest' (Get-CowboyTheme) '^wildwest$'
$env:COWBOY_THEME = 'any'
$t = Get-CowboyTheme
CheckLike 'any -> одна из четырёх тем' $t '^(wildwest|space|cyber|ocean)$'
$env:COWBOY_THEME = ''

Write-Host '== без повторов подряд ==' -ForegroundColor Cyan
$env:COWBOY_THEME = 'cyber'
$seen = @{}
$repeat = 0
$prev = '___ничего___'
for ($i = 0; $i -lt 30; $i++) {
    $id = Get-CowboySceneId
    if ($id -eq $prev) { $repeat++ }
    if (-not $seen.ContainsKey($id)) { $seen[$id] = 1 }
    $prev = $id
}
Check '30 запусков cyber: оба кадра показаны' $seen.Count 2
Check 'ни одного повтора подряд' $repeat 0
$env:COWBOY_THEME = ''

Write-Host '== содержимое данных ==' -ForegroundColor Cyan
$themes = Get-CowboyThemes
Check '4 темы' ($themes.Count) 4
Check 'у wildwest 4 картинки' ($themes['wildwest'].Scenes.Count) 4
Check 'у cyber 2 картинки' ($themes['cyber'].Scenes.Count) 2
Check 'арт читается с диска' ([IO.File]::Exists((Join-Path (Get-CowboyArtPath) 'wagon.txt'))) 'True'
CheckLike 'приветствие темы' (Get-CowboyGreeting) '^\S.*\S$'
CheckLike 'поговорка непустая' (Get-CowboyFortune) '.+'
CheckLike 'время суток' (Get-CowboyPartOfDay) '^ДОБР'

Write-Host ''
Write-Host "итого: $script:pass OK, $script:fail FAIL" -ForegroundColor $(if ($script:fail) { 'Red' } else { 'Green' })
Remove-Item -Recurse -Force $stateD -EA SilentlyContinue
if ($script:fail) { exit 1 }
