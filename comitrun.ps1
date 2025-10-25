# comitrun.ps1
[CmdletBinding()]
param(
  [string]$Message = "chore: sync",
  [switch]$NoPush
)

$ErrorActionPreference = "Stop"
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Error "git não encontrado no PATH"; exit 1
}

git add -A
try { git commit -m $Message | Out-Null } catch { Write-Host "Nada a commitar." -ForegroundColor Yellow }

if (-not $NoPush) {
  try { git push | Out-Null } catch { Write-Host "Nada para enviar ou remoto não configurado." -ForegroundColor Yellow }
}

Write-Host "OK: commit/push finalizado." -ForegroundColor Green
