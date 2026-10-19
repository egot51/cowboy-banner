<#
    Удаление баннера cowboy-banner из Windows.

    Убирает блок из профиля PowerShell, автозапуск cmd и сами файлы.
    Основной профиль не удаляется - из него вырезается только наш блок.
    Если был бэкап (profile.ps1.cowboy-banner.bak) - предлагается вернуть его.

    Запуск:
      powershell -ExecutionPolicy Bypass -File windows\uninstall.ps1
#>
[CmdletBinding()]
param(
    [switch]$KeepFiles,
    [switch]$RestoreBackup
)

$ErrorActionPreference = 'Stop'

$psDir    = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell'
$psMain   = Join-Path $psDir 'profile.ps1'
$psBanner = Join-Path $psDir 'cowboy-profile.ps1'
$bak      = "$psMain.cowboy-banner.bak"
$binDir   = Join-Path $env:USERPROFILE 'bin'
$cmdFile  = Join-Path $binDir 'cowboy.cmd'

$beginMark = '# >>> cowboy-banner >>>'
$endMark   = '# <<< cowboy-banner <<<'

function Write-Step($msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  $msg" -ForegroundColor Green }

Write-Host ''
Write-Host 'Удаление cowboy-banner' -ForegroundColor White
Write-Host '========================' -ForegroundColor White

# --- 1. блок в профиле -----------------------------------------------------
Write-Step 'Профиль PowerShell'
if (Test-Path $psMain) {
    $lines = [IO.File]::ReadAllLines($psMain)
    $out = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($l in $lines) {
        if ($l.Trim() -eq $beginMark) { $skip = $true; continue }
        if ($l.Trim() -eq $endMark)   { $skip = $false; continue }
        if (-not $skip) { $out.Add($l) }
    }
    if ($out.Count -ne $lines.Count) {
        [IO.File]::WriteAllLines($psMain, $out, (New-Object Text.UTF8Encoding $true))
        Write-Ok '  наш блок вырезан'
    } else {
        Write-Ok '  блока не было'
    }
}

# --- 2. автозапуск cmd -----------------------------------------------------
Write-Step 'Автозапуск cmd'
$key = 'HKCU:\Software\Microsoft\Command Processor'
$cur = (Get-ItemProperty -Path $key -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
if ($cur -and $cur -match 'cowboy\.cmd') {
    Remove-ItemProperty -Path $key -Name AutoRun -ErrorAction SilentlyContinue
    Write-Ok '  ключ AutoRun удалён'
} elseif ($cur) {
    Write-Ok "  AutoRun чужой ($cur) - не трогаем"
} else {
    Write-Ok '  AutoRun не было'
}

# --- 3. файлы --------------------------------------------------------------
if (-not $KeepFiles) {
    Write-Step 'Файлы'
    foreach ($f in @($psBanner, $cmdFile)) {
        if (Test-Path $f) { Remove-Item $f -Force; Write-Ok "  удалён $f" }
    }
} else {
    Write-Step 'Файлы'
    Write-Ok '  оставлены (был ключ -KeepFiles)'
}

# --- 4. бэкап --------------------------------------------------------------
if ($RestoreBackup -and (Test-Path $bak)) {
    Copy-Item $bak $psMain -Force
    Write-Ok "  восстановлен $psMain из бэкапа"
} elseif (Test-Path $bak) {
    Write-Host "  бэкап профиля остался: $bak" -ForegroundColor Yellow
    Write-Host '  вернуть: powershell -File windows\uninstall.ps1 -RestoreBackup' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Готово. Откройте новое окно PowerShell или cmd.' -ForegroundColor Green
Write-Host ''
