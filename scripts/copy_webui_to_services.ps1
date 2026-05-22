param(
    [string]$SourcePath = "D:\Code_write_d\VScodeNewDay\WebKu\OCS_LocalLLM_UI",
    [string]$TargetPath = "services/webui"
)

Write-Host "Source: $SourcePath"
Write-Host "Target (relative to repo): $TargetPath"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition | Split-Path -Parent
$absTarget = Join-Path $repoRoot $TargetPath

if (-not (Test-Path $SourcePath)) {
    Write-Error "Source path does not exist: $SourcePath"
    exit 1
}

Write-Host "Creating target: $absTarget"
New-Item -ItemType Directory -Force -Path $absTarget | Out-Null

# Use robocopy to copy recursively but exclude node_modules and .git
$excludeDirs = @("node_modules",".git")

# Build robocopy exclude args
$xd = $excludeDirs -join ' '

Write-Host "Copying files (excluding: $xd). This may take a while..."

# robocopy mirrors source to target; /MIR keeps target in sync. /R:2 /W:2 reduce retries/wait.
robocopy $SourcePath $absTarget /MIR /XD $excludeDirs /R:2 /W:2 | Out-Null

if ($LASTEXITCODE -ge 8) {
    Write-Error "robocopy failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "Copy complete. Next steps: see services/webui/README.md"
