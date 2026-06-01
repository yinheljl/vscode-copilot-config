<#
.SYNOPSIS
    Sync local Codex user-authored configuration back into this repository.

.DESCRIPTION
    Copies:
    - ~/.codex/AGENTS.md -> codex/AGENTS.md
    - ~/.codex/skills/* -> codex/skills/*

    The script intentionally does not sync config.toml, hooks.json, or hooks/
    from the machine because those files are repository templates.
#>
param(
    [switch]$DryRun,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$codexSrc = Join-Path $env:USERPROFILE ".codex"
$codexDst = Join-Path $repoDir "codex"

function Copy-DirReplace([string]$Src, [string]$Dst) {
    if (Test-Path $Dst) {
        Remove-Item $Dst -Recurse -Force
    }
    Copy-Item $Src $Dst -Recurse -Force
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Sync Codex config into repository" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $codexSrc)) {
    throw "Local Codex directory not found: $codexSrc"
}

if ($DryRun) {
    Write-Host "  [DryRun] $codexSrc\AGENTS.md -> $codexDst\AGENTS.md"
    Write-Host "  [DryRun] $codexSrc\skills -> $codexDst\skills"
    exit 0
}

if (-not (Test-Path $codexDst)) {
    New-Item -ItemType Directory -Path $codexDst -Force | Out-Null
}

$agentsSrc = Join-Path $codexSrc "AGENTS.md"
if (Test-Path $agentsSrc) {
    Copy-Item $agentsSrc (Join-Path $codexDst "AGENTS.md") -Force
    Write-Host "  + codex/AGENTS.md"
} else {
    Write-Host "  - ~/.codex/AGENTS.md not found; skipped" -ForegroundColor Yellow
}

$skillsSrc = Join-Path $codexSrc "skills"
$skillsDst = Join-Path $codexDst "skills"
if (Test-Path $skillsSrc) {
    if (-not (Test-Path $skillsDst)) {
        New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null
    }

    $exclude = @(".system", "codex-primary-runtime")
    $synced = 0
    Get-ChildItem $skillsSrc -Directory | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
        $target = Join-Path $skillsDst $_.Name
        if ((Test-Path $target) -and $Force) {
            Remove-Item $target -Recurse -Force
        }
        if (-not (Test-Path $target)) {
            Copy-DirReplace $_.FullName $target
        } else {
            Copy-Item (Join-Path $_.FullName '*') $target -Recurse -Force
        }
        $synced++
    }
    Write-Host "  + codex/skills/ ($synced skills)"
} else {
    Write-Host "  - ~/.codex/skills not found; skipped" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Templates not synced: codex/config.toml, codex/hooks.json, codex/hooks/."
Write-Host "Review git diff before committing."
