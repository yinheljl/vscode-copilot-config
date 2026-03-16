<#
.SYNOPSIS
    从当前机器同步最新的 Copilot 配置到本仓库并推送到 GitHub

.DESCRIPTION
    将 ~/.copilot 和 mcp.json 同步到本仓库目录，然后 git commit 并 push。

.EXAMPLE
    .\sync.ps1
    .\sync.ps1 -Message "更新 AUTOSAR instructions"
#>
param(
    [string]$Message = "chore: sync config from $(hostname)"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoDir     = $PSScriptRoot
$copilotSrc  = Join-Path $env:USERPROFILE ".copilot"
$copilotDst  = Join-Path $repoDir ".copilot"
$mcpSrc      = Join-Path $env:APPDATA "Code\User\mcp.json"
$mcpDst      = Join-Path $repoDir "vscode\mcp.json"

Write-Host "=== 同步 Copilot 配置到仓库 ===" -ForegroundColor Cyan

# --- 同步 .copilot ---
Write-Host "正在同步 .copilot..." -ForegroundColor Green
foreach ($subdir in @("instructions", "skills")) {
    $src = Join-Path $copilotSrc $subdir
    $dst = Join-Path $copilotDst $subdir
    if (Test-Path $src) {
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
        Copy-Item $src $dst -Recurse -Force
        Write-Host "  √ $subdir"
    }
}

# --- 同步 mcp.json ---
if (Test-Path $mcpSrc) {
    Write-Host "正在同步 mcp.json..." -ForegroundColor Green
    Copy-Item $mcpSrc $mcpDst -Force
    Write-Host "  √ mcp.json"
}

# --- git commit & push ---
Write-Host "正在提交并推送..." -ForegroundColor Green
Push-Location $repoDir
git add -A
$status = git status --porcelain
if ($status) {
    git commit -m $Message
    git push
    Write-Host "  √ 已推送到 GitHub" -ForegroundColor Green
} else {
    Write-Host "  无变更，无需提交。" -ForegroundColor Yellow
}
Pop-Location

Write-Host ""
Write-Host "=== 同步完成 ===" -ForegroundColor Cyan