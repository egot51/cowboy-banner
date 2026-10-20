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
    [string]$Dist = 'dist',
    # Токен. Если не задан - берётся из хранилища учётных данных git
    # (в CI его нет, там токен передаётся явно).
    [string]$Token = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$distPath = if ([IO.Path]::IsPathRooted($Dist)) { $Dist } else { Join-Path $root $Dist }

# --- токен -----------------------------------------------------------------
if (-not $Token) {
    $cred = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
    foreach ($line in $cred) { if ($line -like 'password=*') { $Token = $line.Substring(9) } }
}
if (-not $Token) {
    Write-Host 'нет токена: задайте -Token или сделайте git push, чтобы git сохранил учётные данные' -ForegroundColor Red
    exit 1
}

$headers = @{
    Authorization = "Bearer $Token"
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

# Загрузка идёт через HttpClient, а не через curl: curl.exe есть только
# на Windows, а workflow публикации работает на Linux.
# В Windows PowerShell 5.1 сборку System.Net.Http надо подгрузить вручную.
try { Add-Type -AssemblyName System.Net.Http -ErrorAction Stop } catch { }
$client = [System.Net.Http.HttpClient]::new()
$client.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token)
$client.DefaultRequestHeaders.Add('Accept', 'application/vnd.github+json')
$client.DefaultRequestHeaders.Add('X-GitHub-Api-Version', '2022-11-28')
$client.DefaultRequestHeaders.Add('User-Agent', 'cowboy-banner-publisher')

foreach ($a in $assets) {
    Write-Host "  загружаю $($a.Name) ($([math]::Round($a.Length/1KB,1)) КБ) ..." -ForegroundColor Cyan
    $bytes = [IO.File]::ReadAllBytes($a.FullName)
    $content = [System.Net.Http.ByteArrayContent]::new($bytes)
    $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::new('application/octet-stream')
    try {
        $resp = $client.PostAsync("$upload`?name=$([uri]::EscapeDataString($a.Name))", $content).GetAwaiter().GetResult()
        if (-not $resp.IsSuccessStatusCode) {
            Write-Host "    ОШИБКА: $([int]$resp.StatusCode) $($resp.Content.ReadAsStringAsync().GetAwaiter().GetResult())" -ForegroundColor Red
            exit 1
        }
        Write-Host '    готово' -ForegroundColor Green
    } catch {
        Write-Host "    ОШИБКА: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
$client.Dispose()

# --- проверка: что скачивается то, что загрузили ---------------------------
Write-Host ''
Write-Host 'проверяю, что файлы скачиваются без изменений:' -ForegroundColor Cyan
$release = Invoke-RestMethod -Uri "$api/releases/tags/$Tag" -Headers $headers
$bad = 0
foreach ($a in @($release.assets)) {
    $local = Join-Path $distPath $a.name
    if (-not (Test-Path $local)) { continue }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("dl-" + $a.name)
    Invoke-WebRequest -Uri "$($a.browser_download_url)?nocache=$([guid]::NewGuid().ToString('N'))" -OutFile $tmp -UseBasicParsing
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
