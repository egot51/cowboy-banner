#!/usr/bin/env powershell
# Удаление пакета cowboy-banner (Chocolatey).

$ErrorActionPreference = 'Stop'

$tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$uninstaller = Join-Path $tools 'uninstall.ps1'

if (Test-Path $uninstaller) {
    & $uninstaller
}
