<#
    Одноразовый запуск баннера. Ставится как команда `cowboy-banner`
    (Scoop делает из неё shim), чтобы посмотреть картинку не открывая новое окно.
#>
[CmdletBinding()]
param(
    [string]$Theme = '',
    [switch]$Plain,
    [switch]$Menu
)

$ErrorActionPreference = 'Stop'
$profile = Join-Path $PSScriptRoot 'profile.ps1'

if ($Theme) { $env:COWBOY_THEME = $Theme }
if ($Plain) { $env:COWBOY_BANNER = 'plain' }
if ($Menu)  { $env:COWBOY_BANNER = 'menu' }

. $profile

if ($Menu) {
    Show-CowboyMenu
} else {
    Show-CowboyBanner
}
