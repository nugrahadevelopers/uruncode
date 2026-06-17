# uruncode installer for Windows (PowerShell).
# Usage:
#   irm https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$Repo = if ($env:URUNCODE_REPO_RAW) { $env:URUNCODE_REPO_RAW } else { 'https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main' }
$Dest = Join-Path $env:LOCALAPPDATA 'Programs\uruncode'

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

Write-Host "Installing uruncode to $Dest ..."
Invoke-WebRequest -UseBasicParsing "$Repo/uruncode.ps1" -OutFile (Join-Path $Dest 'uruncode.ps1')

$shim = @'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uruncode.ps1" %*
'@
Set-Content -Path (Join-Path $Dest 'uruncode.cmd') -Value $shim -Encoding ASCII

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $userPath) { $userPath = '' }
if ($userPath -notlike "*$Dest*") {
  $newPath = if ($userPath) { "$userPath;$Dest" } else { $Dest }
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  $env:Path = "$env:Path;$Dest"
  Write-Host "Added $Dest to your user PATH."
  Write-Host 'Open a NEW terminal for it to take effect.'
}

Write-Host 'Installed. Run: uruncode'
