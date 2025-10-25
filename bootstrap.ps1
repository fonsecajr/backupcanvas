<# 
  backupcanvas / bootstrap.ps1
  - Login GitHub (gh auth login) se necessário
  - Cria/associa repositório remoto (public/private)
  - Inicializa Git local, .gitignore e branch main
  - Cria venv, instala deps (pip+uv) e roda o app
  - Faz commit e push (mensagem configurável)

  Uso:
    .\bootstrap.ps1 -RepoName backupcanvas -Visibility public -UserName "Seu Nome" -UserEmail "voce@exemplo.com" -CommitMessage "chore: initial import" -RunApp

  Requisitos:
    - Git for Windows (com Git Credential Manager)  https://git-scm.com/download/win
    - GitHub CLI (gh)                              https://cli.github.com/
    - Python 3.9+ no PATH
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$RepoName,
  [ValidateSet("public","private")][string]$Visibility = "public",
  [string]$UserName = "",
  [string]$UserEmail = "",
  [string]$CommitMessage = "chore: sync",
  [switch]$RunApp,
  [string]$Venv = ".venv"
)

function Fail($msg){ Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# -------- 0) Sanitizar nome (minúsculo) --------
$RepoName = ($RepoName.ToLower() -replace "[^a-z0-9._-]", "-")

# -------- 1) Checagens básicas --------
function Require-Cmd($name, $help){
  if(-not (Get-Command $name -ErrorAction SilentlyContinue)){
    Fail "$name não encontrado. $help"
  }
}
Require-Cmd git "Instale Git: https://git-scm.com/download/win"
Require-Cmd python "Instale Python: https://www.python.org/downloads/"
if(-not (Get-Command gh -ErrorAction SilentlyContinue)){
  Write-Host "GitHub CLI não encontrado. Tentando instalar via winget..." -ForegroundColor Yellow
  if(Get-Command winget -ErrorAction SilentlyContinue){
    winget install --id GitHub.cli -e --source winget | Out-Null
  }
}
Require-Cmd gh "Instale GitHub CLI: https://cli.github.com/"

# -------- 2) Login GitHub --------
$auth = (& gh auth status 2>$null)
if($LASTEXITCODE -ne 0){
  Write-Host "Autenticando no GitHub..." -ForegroundColor Cyan
  & gh auth login --web --scopes "repo" | Out-Null
  if($LASTEXITCODE -ne 0){ Fail "Falha no login do GitHub." }
}else{
  Write-Host "GitHub já autenticado." -ForegroundColor DarkGray
}

# -------- 3) Git local: init + identidade + .gitignore --------
if(-not (Test-Path .git)){
  Write-Host "Inicializando repositório Git local..." -ForegroundColor Cyan
  git init | Out-Null
}

# Config global opcional (só se fornecido)
if($UserName){ git config user.name $UserName | Out-Null }
if($UserEmail){ git config user.email $UserEmail | Out-Null }

# .gitignore mínimo se não existir
$gi = ".gitignore"
if(-not (Test-Path $gi)){
  @"
# venv
.venv/
env/
venv/
# python
__pycache__/
*.pyc
*.pyo
*.pyd
*.egg-info/
.dist-info/
# builds
build/
dist/
*.spec
# IDE/OS
.vscode/
.idea/
.DS_Store
Thumbs.db
"@ | Out-File -Encoding UTF8 $gi
}

# Nome do branch principal
git checkout -q -B main

# -------- 4) Criar/associar remoto no GitHub --------
# Tenta obter owner atual do gh
$ghUser = (& gh api user --jq ".login" 2>$null)
if(-not $ghUser){ Fail "Não consegui obter usuário do GitHub (gh api user)." }

# Verificar se remoto origin já existe
$hasOrigin = git remote get-url origin 2>$null
if($LASTEXITCODE -ne 0){
  # se repo remoto não existe, criar; senão, associar
  Write-Host "Verificando existência de https://github.com/$ghUser/$RepoName ..." -ForegroundColor DarkGray
  & gh repo view "$ghUser/$RepoName" 1>$null 2>$null
  if($LASTEXITCODE -ne 0){
    Write-Host "Criando repositório remoto $RepoName ($Visibility)..." -ForegroundColor Cyan
    & gh repo create "$RepoName" --$Visibility --source . --remote origin --push | Out-Null
    if($LASTEXITCODE -ne 0){ Fail "Falha ao criar o repositório remoto." }
  } else {
    Write-Host "Remoto já existe no GitHub. Associando origin..." -ForegroundColor DarkGray
    git remote add origin "https://github.com/$ghUser/$RepoName.git" | Out-Null
  }
}else{
  Write-Host "Remoto 'origin' já configurado." -ForegroundColor DarkGray
}

# -------- 5) Venv + deps + rodar app (opcional) --------
if(-not (Test-Path $Venv)){
  Write-Host "Criando venv em $Venv ..." -ForegroundColor Cyan
  python -m venv $Venv
}
$activate = Join-Path $Venv "Scripts\Activate.ps1"
. $activate

python -m pip install -U pip uv | Out-Null
# Instala dev (editable) se houver pyproject; caso contrário, só PySide6 p/ rodar o MVP
if(Test-Path "pyproject.toml"){
  uv pip install -e ".[dev]" | Out-Null
}else{
  python -m pip install PySide6 | Out-Null
}

if($RunApp){
  Write-Host "Iniciando BackupCanvas..." -ForegroundColor Green
  if(Get-Command backupcanvas -ErrorAction SilentlyContinue){
    backupcanvas
  } elseif (Test-Path ".\app.py"){
    python .\app.py
  } elseif (Test-Path ".\backupcanvas\app.py"){
    python .\backupcanvas\app.py
  } else {
    Write-Host "Não encontrei app.py nem entrypoint 'backupcanvas'." -ForegroundColor Yellow
  }
}

# -------- 6) Commit + push --------
git add -A

# cria commit se houver mudanças (ignora erro quando não há nada a commitar)
try { git commit -m $CommitMessage | Out-Null } catch {}

# push (ignora erro se já estiver em dia)
try { git push -u origin main | Out-Null } catch {}

# Mensagem final robusta (sem caracteres especiais)
$repoUrl = "https://github.com/$ghUser/$RepoName"
Write-Host ("Pronto. Repo: {0}" -f $repoUrl) -ForegroundColor Green
