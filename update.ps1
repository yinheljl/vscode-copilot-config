<#
.SYNOPSIS
    Pull the latest Codex-only configuration and restore it locally.

.EXAMPLE
    .\update.ps1
    .\update.ps1 -CheckOnly
    .\update.ps1 -AutoInstallDcg
#>
param(
    [switch]$DryRun,
    [switch]$CheckOnly,
    [switch]$Force,
    [switch]$AutoInstallDcg,
    [switch]$DisableDcgHooks,
    [switch]$SkipDcg
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoUrlFile = if ($PSScriptRoot) { Join-Path $PSScriptRoot "REPO_URL" } else { $null }
$repoBranch = "codex/codex-setup-doc"
if ($repoUrlFile -and (Test-Path $repoUrlFile)) {
    $repoUrl = (Get-Content $repoUrlFile -Raw -Encoding UTF8).Trim()
} else {
    $repoUrl = "https://github.com/yinheljl/ai-agent-config.git"
}

$scriptDir = $PSScriptRoot
if ($scriptDir -and (Test-Path (Join-Path $scriptDir "VERSION"))) {
    $repoDir = $scriptDir
} elseif (Test-Path (Join-Path (Get-Location) "VERSION")) {
    $repoDir = (Get-Location).Path
} else {
    $repoDir = Join-Path $env:USERPROFILE ".ai-agent-config"
}

function Get-LocalVersion([string]$Dir) {
    $versionFile = Join-Path $Dir "VERSION"
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw -Encoding UTF8).Trim()
    }
    return "0.0.0"
}

function Get-RemoteVersion {
    try {
        $base = $repoUrl -replace '\.git$', ''
        $base = $base -replace 'github\.com', 'raw.githubusercontent.com'
        $url = "$base/$repoBranch/VERSION"
        return (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10).Content.Trim()
    } catch {
        Write-Warning "Unable to fetch remote VERSION: $($_.Exception.Message)"
        return $null
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Codex configuration update" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$localVersion = Get-LocalVersion $repoDir
Write-Host "Local version:  $localVersion"
$remoteVersion = Get-RemoteVersion
if ($remoteVersion) {
    Write-Host "Remote version: $remoteVersion"
} else {
    Write-Host "Remote version: unknown"
}

if ($CheckOnly) {
    if ($remoteVersion -and $remoteVersion -ne $localVersion) {
        Write-Host "Update available: $localVersion -> $remoteVersion" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Already up to date."
    exit 0
}

Write-Host ""
Write-Host "[1/2] Sync repository"

if (Test-Path (Join-Path $repoDir ".git")) {
    Push-Location $repoDir
    try {
        if ($DryRun) {
            Write-Host "  [DryRun] git fetch origin $repoBranch"
            Write-Host "  [DryRun] git switch $repoBranch"
            Write-Host "  [DryRun] git pull --ff-only origin $repoBranch"
        } else {
            $currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
            if ($currentBranch -ne $repoBranch) {
                git fetch origin $repoBranch
                git show-ref --verify --quiet "refs/heads/$repoBranch"
                if ($LASTEXITCODE -eq 0) {
                    git switch $repoBranch
                } else {
                    git switch -c $repoBranch FETCH_HEAD
                }
            }
            git pull --ff-only origin $repoBranch
        }
    } finally {
        Pop-Location
    }
} else {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is required for first-time update. Install git or clone $repoUrl manually."
    }
    if ($DryRun) {
        Write-Host "  [DryRun] git clone --branch $repoBranch --single-branch $repoUrl $repoDir"
    } else {
        git clone --branch $repoBranch --single-branch $repoUrl $repoDir
    }
}

Write-Host ""
Write-Host "[2/2] Restore Codex configuration"
$restore = Join-Path $repoDir "restore.ps1"
if (-not (Test-Path $restore)) {
    throw "restore.ps1 not found: $restore"
}

& $restore `
    -DryRun:$DryRun `
    -Force:$Force `
    -AutoInstallDcg:$AutoInstallDcg `
    -DisableDcgHooks:$DisableDcgHooks `
    -SkipDcg:$SkipDcg
