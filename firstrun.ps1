# firstrun.ps1  (coloque isso e salve em UTF-8 com CRLF)
param(
  [string]$RepoName = "backupcanvas",
  [ValidateSet("public","private")] [string]$Visibility = "public",
  [string]$UserName = "",
  [string]$UserEmail = "",
  [string]$CommitMessage = "chore: initial import",
  [switch]$RunApp = $true,
  [string]$Venv = ".venv"
)

# garante que roda a partir da pasta do script
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)

# chama o bootstrap no MESMO processo
& .\bootstrap.ps1 `
  -RepoName $RepoName `
  -Visibility $Visibility `
  -UserName $UserName `
  -UserEmail $UserEmail `
  -CommitMessage $CommitMessage `
  -RunApp:$RunApp `
  -Venv $Venv
