<#
    Загрузка файлов релиза на GitHub.

    Важно: эндпоинт загрузки ждёт СЫРОЙ бинарник в теле запроса, а не
    multipart-форму - иначе GitHub сохранит всю multipart-обёртку как файл.

    Токен берётся из того же хранилища, где git держит учётные данные
    (Git Credential Manager), - отдельно логиниться не нужно.

    powershell -File packaging\upload-assets.ps1 [-Tag v1.0.0]
#>
[CmdletBinding()]
param(
    [string]$Tag = 'v1.0.0',
    [string]$Repo = 'egot51/cowboy-banner',
    [string]$Dist = 'dist'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$distPath = if ([IO.Path]::IsPathRooted($Dist)) { $Dist } else { Join-Path $root $Dist }

# --- токен -----------------------------------------------------------------
$cred = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
$token = $null
foreach ($line in $cred) { if ($line -like 'password=*') { $token = $line.Substring(9) } }
if (-not $token) {
    Write-Host 'не найдены учётные данные для github.com - сначала сделайте git push' -ForegroundColor Red
    exit 1
}

$headers = @{
    Authorization = "Bearer $token"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'cowboy-banner-publisher'
}
$api = "https://api.github.com/repos/$Repo"

# --- файлы -----------------------------------------------------------------
$assets = Get-ChildItem $distPath -File | Where-Object { $_.Name -match '\.(deb|rpm|zip|sha256)$' }
if (-not $assets) { Write-Host "в $distPath нет артефактов" -ForegroundColor Red; exit 1 }

# --- релиз -----------------------------------------------------------------
$release = Invoke-RestMethod -Uri "$api/releases/tags/$Tag" -Headers $headers
Write-Host "релиз $Tag найден" -ForegroundColor Cyan

# Удаляем прежние версии файлов с теми же именами: GitHub не даёт загрузить
# файл, если имя уже занято, а перезаливка после правок нужна.
foreach ($a in @($release.assets)) {
    if ($assets.Name -contains $a.name) {
        Invoke-RestMethod -Uri "$api/releases/assets/$($a.id)" -Method Delete -Headers $headers
        Write-Host "  удалён прежний $($a.name)" -ForegroundColor Yellow
    }
}
if ($release.assets.Count) { Start-Sleep -Seconds 3 }

$upload = $release.upload_url -replace '\{.*\}$', ''
$curl = (Get-Command curl.exe -ErrorAction SilentlyContinue)
if (-not $curl) { Write-Host 'curl.exe не найден' -ForegroundColor Red; exit 1 }

foreach ($a in $assets) {
    Write-Host "  загружаю $($a.Name) ($([math]::Round($a.Length/1KB,1)) КБ) ..." -ForegroundColor Cyan
    $out = & $curl.Source -sS --fail-with-body -X POST `
        -H "Authorization: Bearer $token" `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        -H "User-Agent: cowboy-banner-publisher" `
        -H "Content-Type: application/octet-stream" `
        --data-binary "@$($a.FullName)" `
        "$upload`?name=$([uri]::EscapeDataString($a.Name))" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ОШИБКА: $out" -ForegroundColor Red
        exit 1
    }
    Write-Host '    готово' -ForegroundColor Green
}

# --- проверка: что скачивается то, что загрузили ---------------------------
Write-Host ''
Write-Host 'проверяю, что файлы скачиваются без изменений:' -ForegroundColor Cyan
$release = Invoke-RestMethod -Uri "$api/releases/tags/$Tag" -Headers $headers
$bad = 0
foreach ($a in @($release.assets)) {
    $local = Join-Path $distPath $a.name
    if (-not (Test-Path $local)) { continue }
    $tmp = Join-Path $env:TEMP ("dl-" + $a.name)
    & $curl.Source -sS -L -o $tmp "$($a.browser_download_url)?nocache=$([guid]::NewGuid().ToString('N'))"
    $h1 = (Get-FileHash $tmp -Algorithm SHA256).Hash
    $h2 = (Get-FileHash $local -Algorithm SHA256).Hash
    if ($h1 -eq $h2) {
        Write-Host "  OK   $($a.name) - совпадает побайтово" -ForegroundColor Green
    } else {
        Write-Host "  FAIL $($a.name) - отличается от локального" -ForegroundColor Red
        $bad++
    }
    Remove-Item $tmp -Force
}
if ($bad) { exit 1 }
Write-Host ''
Write-Host "релиз: $($release.html_url)" -ForegroundColor Green
