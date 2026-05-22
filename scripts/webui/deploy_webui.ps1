param()

# Deploy webui via docker compose (PowerShell)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Split-Path -Parent $scriptDir | Split-Path -Parent
$compose = Join-Path $repoRoot "services\webui\docker-compose.yml"

Write-Host "Using compose file: $compose"
docker compose -f $compose up -d --build

Write-Host "webui deployed"
