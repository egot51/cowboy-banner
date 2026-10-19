#!/usr/bin/env powershell
# Установка пакета cowboy-banner (Chocolatey).
# Артефакт распакован в $env:ChocolateyInstallLocation\tools.

$ErrorActionPreference = 'Stop'

$tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$installer = Join-Path $tools 'install.ps1'

if (Test-Path $installer) {
    & $installer
} else {
    Write-Warning "не найден $installer - профиль PowerShell не подключён"
}
