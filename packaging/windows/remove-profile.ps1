<#
    Удаление баннера, установленного из пакета (Scoop, Chocolatey, winget).
    Вырезает наш блок из профиля PowerShell, убирает автозапуск cmd и
    удаляет установленные файлы. Основной профиль не удаляется целиком -
    из него убирается только наш блок.
#>
[CmdletBinding()]
param(
    [switch]$KeepFiles
)

$ErrorActionPreference = 'Stop'

$psDir    = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell'
$psMain   = Join-Path $psDir 'profile.ps1'
$psBanner = Join-Path $psDir 'cowboy-profile.ps1'
$bak      = "$psMain.cowboy-banner.bak"
$cmdFile  = Join-Path (Join-Path $env:USERPROFILE 'bin') 'cowboy.cmd'

$beginMark = '# >>> cowboy-banner >>>'
$endMark   = '# <<< cowboy-banner <<<'

function Write-Step($m) { Write-Host "  $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "  $m" -ForegroundColor Green }

Write-Host ''
Write-Host 'Удаление cowboy-banner' -ForegroundColor White
Write-Host '========================' -ForegroundColor White

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

Write-Step 'Файлы'
if (-not $KeepFiles) {
    foreach ($f in @($psBanner, $cmdFile)) {
        if (Test-Path $f) { Remove-Item $f -Force; Write-Ok "  удалён $f" }
    }
} else {
    Write-Ok '  оставлены (был ключ -KeepFiles)'
}

if (Test-Path $bak) {
    Write-Host "  бэкап профиля остался: $bak" -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Готово. Откройте новое окно PowerShell или cmd.' -ForegroundColor Green
Write-Host ''
