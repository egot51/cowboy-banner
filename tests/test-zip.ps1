<#
    Сквозной тест Windows-пакета: распаковываем zip, ставим из него,
    проверяем профиль, реестр и запуск баннера, затем удаляем.

    powershell -NoProfile -ExecutionPolicy Bypass -File tests\test-zip.ps1

    Кириллицу проверяем не через перехват вывода (там ломается кодировка),
    а через файл, который пишет сам дочерний процесс в UTF-8.
#>
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$zip  = Join-Path $root 'dist\cowboy-banner-1.0.0-windows.zip'
if (-not (Test-Path $zip)) {
    Write-Host "нет $zip - сначала: node packaging\build-zip.js" -ForegroundColor Red
    exit 1
}

$pass = 0; $fail = 0
function Ok($m) { $script:pass++; Write-Host "  OK   $m" -ForegroundColor Green }
function Bad($m) { $script:fail++; Write-Host "  FAIL $m" -ForegroundColor Red }
function Expect($m, $got, $want) {
    if ("$got" -eq "$want") { Ok $m } else { Bad "$m (получено '$got', ждали '$want')" }
}

Write-Host ''
Write-Host 'Windows-пакет: распаковка, установка, запуск, удаление' -ForegroundColor White

$work = Join-Path $env:TEMP ("cowboy-zip-test-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$sandbox = Join-Path $work 'home'
$app  = Join-Path $work 'app'
New-Item -ItemType Directory -Path $sandbox, $app -Force | Out-Null

# --- распаковка ---------------------------------------------------------
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $app)
$entries = Get-ChildItem $app -File | Select-Object -ExpandProperty Name
foreach ($f in 'cowboy.cmd', 'profile.ps1', 'cowboy-banner.ps1', 'install.ps1', 'uninstall.ps1', 'README.md', 'LICENSE') {
    if ($entries -contains $f) { Ok "в архиве $f" } else { Bad "в архиве нет $f" }
}

# --- установка -----------------------------------------------------------
$key = 'HKCU:\Software\Microsoft\Command Processor'
$oldAuto = (Get-ItemProperty -Path $key -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
try {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command "`$env:USERPROFILE='$sandbox'; & '$app\install.ps1' -NoPolicy" 2>&1 | Out-String
    $installed = 'нет'
    if ($out -match 'cowboy-banner') { $installed = 'да' }
    Expect 'установка отработала' $installed 'да'

    $prof   = Join-Path $sandbox 'Documents\WindowsPowerShell\profile.ps1'
    $banner = Join-Path $sandbox 'Documents\WindowsPowerShell\cowboy-profile.ps1'
    Expect 'основной профиль создан' (Test-Path $prof) 'True'
    Expect 'в профиле есть блок' ((Get-Content $prof -Raw) -match 'cowboy-banner') 'True'
    Expect 'профиль баннера на месте' (Test-Path $banner) 'True'
    Expect 'cowboy.cmd установлен' (Test-Path (Join-Path $sandbox 'bin\cowboy.cmd')) 'True'
    Expect 'AutoRun прописан' ((Get-ItemProperty -Path $key -Name AutoRun -ErrorAction SilentlyContinue).AutoRun -match 'cowboy\.cmd') 'True'

    # --- запуск баннера из пакета ---------------------------------------
    # Дочерний процесс пишет текст в файл сам: так кодировка не зависит от
    # того, как родитель перехватывает вывод.
    $textFile = Join-Path $work 'banner.txt'
    & powershell -NoProfile -ExecutionPolicy Bypass -Command @"
`$env:USERPROFILE='$sandbox'
. '$app\profile.ps1'
[IO.File]::WriteAllText('$textFile', (Get-CowboyBanner), (New-Object Text.UTF8Encoding `$false))
"@ | Out-Null
    $bannerText = [IO.File]::ReadAllText($textFile, [Text.Encoding]::UTF8)
    Expect 'баннер печатается (есть приветствие)' ($bannerText -match 'ДОБР') 'True'
    Expect 'баннер содержит подпись картинки' ($bannerText -match 'T H E|D E E P|N E O N|G H O S T') 'True'
    $esc = ([regex]::Matches($bannerText, "\x1b")).Count
    $seq = ([regex]::Matches($bannerText, "\x1b\[[0-9;]*m")).Count
    Expect 'битых ANSI-кодов нет' ($esc - $seq) 0

    # --- меню тем --------------------------------------------------------
    $menuFile = Join-Path $work 'menu.txt'
    & powershell -NoProfile -ExecutionPolicy Bypass -Command @"
`$env:USERPROFILE='$sandbox'
. '$app\profile.ps1'
[IO.File]::WriteAllText('$menuFile', (Get-CowboyMenu), (New-Object Text.UTF8Encoding `$false))
"@ | Out-Null
    $menuText = [IO.File]::ReadAllText($menuFile, [Text.Encoding]::UTF8)
    Expect 'меню тем работает' ($menuText -match 'COWBOY_THEME') 'True'
    Expect 'в меню есть темы' ($menuText -match 'wildwest') 'True'

    # --- удаление --------------------------------------------------------
    # USERPROFILE подменяем и здесь: иначе скрипт тронет настоящий профиль.
    $un = & powershell -NoProfile -ExecutionPolicy Bypass -Command "`$env:USERPROFILE='$sandbox'; & '$app\uninstall.ps1'" 2>&1 | Out-String
    Expect 'удаление прошло' ($un -match 'cowboy-banner') 'True'
    # Профиль в песочнице состоял только из нашего блока - после удаления он
    # пустой, поэтому читаем файл целиком, а не через -match по пустой строке.
    $after = if (Test-Path $prof) { [IO.File]::ReadAllText($prof) } else { '' }
    Expect 'блок вырезан из профиля' ($after -match 'cowboy-banner') 'False'
    $autoNow = (Get-ItemProperty -Path $key -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    Expect 'AutoRun удалён' $autoNow ''
    Expect 'профиль баннера удалён' (Test-Path $banner) 'False'
    Expect 'cowboy.cmd удалён' (Test-Path (Join-Path $sandbox 'bin\cowboy.cmd')) 'False'
}
finally {
    # Реестр глобальный: песочница его не изолирует, поэтому возвращаем
    # исходное значение AutoRun в любом случае.
    try {
        if ($oldAuto) {
            Set-ItemProperty -Path $key -Name AutoRun -Value $oldAuto -ErrorAction Stop
        } else {
            Remove-ItemProperty -Path $key -Name AutoRun -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "  (не удалось вернуть AutoRun: $($_.Exception.Message))" -ForegroundColor Red
    }
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "итого: $pass OK, $fail FAIL" -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
if ($fail) { exit 1 }
