<#
    Установка баннера cowboy-banner в Windows.

    Что делает:
      1. кладёт профиль в %USERPROFILE%\Documents\WindowsPowerShell\cowboy-profile.ps1
         и подключает его из основного профиля (существующий профиль не затирается)
      2. кладёт cowboy.cmd в %USERPROFILE%\bin и включает автозапуск cmd
      3. ставит политику выполнения RemoteSigned (область CurrentUser),
         иначе PowerShell не прочитает профиль

    Запуск:
      powershell -ExecutionPolicy Bypass -File windows\install.ps1
#>
[CmdletBinding()]
param(
    [switch]$NoCmd,
    [switch]$NoPolicy
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$psDir    = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell'
$psMain   = Join-Path $psDir 'profile.ps1'
$psBanner = Join-Path $psDir 'cowboy-profile.ps1'
$binDir   = Join-Path $env:USERPROFILE 'bin'
$cmdFile  = Join-Path $binDir 'cowboy.cmd'

$beginMark = '# >>> cowboy-banner >>>'
$endMark   = '# <<< cowboy-banner <<<'
$block     = @"
$beginMark
# Баннер при старте терминала. Управление: setx COWBOY_THEME=ocean
. "$psBanner"
$endMark
"@

function Write-Step($msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  $msg" -ForegroundColor Yellow }

Write-Host ''
Write-Host 'Установка cowboy-banner' -ForegroundColor White
Write-Host '=========================' -ForegroundColor White

# --- 1. профиль PowerShell -------------------------------------------------
Write-Step 'Профиль PowerShell'
New-Item -ItemType Directory -Path $psDir -Force | Out-Null
Copy-Item (Join-Path $here 'profile.ps1') $psBanner -Force
Write-Ok "  профиль: $psBanner"

if (Test-Path $psMain) {
    $text = [IO.File]::ReadAllText($psMain)
    if ($text -match [regex]::Escape($beginMark)) {
        Write-Ok '  основной профиль уже подключён - оставляем как есть'
    } else {
        $bak = "$psMain.cowboy-banner.bak"
        if (-not (Test-Path $bak)) { Copy-Item $psMain $bak }
        Add-Content -Path $psMain -Value "`r`n$block" -Encoding UTF8
        Write-Ok "  подключён из $psMain (бэкап: $bak)"
    }
} else {
    # Основного профиля не было - создаём короткий, который только подключает
    # наш. Так его потом можно править, не задев баннер.
    [IO.File]::WriteAllText($psMain, $block, (New-Object Text.UTF8Encoding $true))
    Write-Ok "  создан основной профиль $psMain (только подключение баннера)"
}

# --- 2. cmd ----------------------------------------------------------------
if (-not $NoCmd) {
    Write-Step 'Баннер для cmd'
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    Copy-Item (Join-Path $here 'cowboy.cmd') $cmdFile -Force
    Write-Ok "  $cmdFile"

    $key = 'HKCU:\Software\Microsoft\Command Processor'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    $prev = (Get-ItemProperty -Path $key -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    if ($prev -and $prev -notmatch 'cowboy\.cmd') {
        Write-Warn "  в AutoRun уже была строка: $prev"
        Write-Warn '  она сохранена, но баннер cmd переопределит её. Проверьте ключ:'
        Write-Warn "  reg query `"$key`" /v AutoRun"
    }
    Set-ItemProperty -Path $key -Name AutoRun -Value ('call "' + $cmdFile + '"')
    Write-Ok '  автозапуск cmd включён (HKCU\...\Command Processor\AutoRun)'
}

# --- 3. политика выполнения ------------------------------------------------
if (-not $NoPolicy) {
    Write-Step 'Политика выполнения'
    $cur = Get-ExecutionPolicy -Scope CurrentUser
    if ($cur -eq 'Restricted' -or $cur -eq 'Undefined') {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Write-Ok "  было $cur -> RemoteSigned"
    } else {
        Write-Ok "  уже $cur - не трогаем"
    }
}

Write-Host ''
Write-Host 'Готово. Откройте новое окно PowerShell или cmd.' -ForegroundColor Green
Write-Host ''
Write-Host '  Меню тем:        Show-CowboyMenu   (PowerShell)'
Write-Host '  Ещё картинка:    cowboy'
Write-Host '  Сменить тему:    setx COWBOY_THEME ocean'
Write-Host '  Выключить:       setx COWBOY_BANNER none'
Write-Host '  Подробности:     windows\README.md'
Write-Host ''
