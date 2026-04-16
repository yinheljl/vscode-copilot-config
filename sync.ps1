<#
.SYNOPSIS
    从当前机器同步最新的 Cursor + VS Code Copilot 配置到本仓库并推送到 GitHub

.DESCRIPTION
    同步以下配置到本仓库目录：
    - ~/.copilot/instructions/ 和 ~/.copilot/skills/ → .copilot/
    - ~/.cursor/mcp.json, rules/, skills/, skills-cursor/ → cursor/
    - Cursor settings.json (Copilot 相关) → cursor/settings.json
    - VS Code mcp.json → vscode/mcp.json
    - VS Code settings.json (Copilot 相关) → vscode/settings.json
    然后 git commit 并 push。

.EXAMPLE
    .\sync.ps1
    .\sync.ps1 -Message "更新 feedback MCP 配置"
    .\sync.ps1 -NoPush
#>
param(
    [string]$Message = "chore: sync config from $(hostname)",
    [switch]$NoPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoDir         = $PSScriptRoot
$copilotSrc      = Join-Path $env:USERPROFILE ".copilot"
$copilotDst      = Join-Path $repoDir ".copilot"
$cursorSrc       = Join-Path $env:USERPROFILE ".cursor"
$cursorDst       = Join-Path $repoDir "cursor"
$vscodeMcpSrc    = Join-Path $env:APPDATA "Code\User\mcp.json"
$vscodeMcpDst    = Join-Path $repoDir "vscode\mcp.json"
$vscodeSettSrc   = Join-Path $env:APPDATA "Code\User\settings.json"
$vscodeSettDst   = Join-Path $repoDir "vscode\settings.json"
$cursorSettSrc   = Join-Path $env:APPDATA "Cursor\User\settings.json"
$cursorSettDst   = Join-Path $repoDir "cursor\settings.json"

# Copilot 相关的 settings.json 键名前缀
$copilotKeys = @("chat.", "github.copilot")

function Extract-CopilotSettings($srcPath, $dstPath) {
    if (-not (Test-Path $srcPath)) { return }
    $srcObj = Get-Content $srcPath -Raw | ConvertFrom-Json
    $filtered = [ordered]@{}
    foreach ($prop in $srcObj.PSObject.Properties) {
        foreach ($prefix in $copilotKeys) {
            if ($prop.Name.StartsWith($prefix)) {
                $filtered[$prop.Name] = $prop.Value
                break
            }
        }
    }
    # 对 Cursor settings 额外提取 cursor.* 和 mcp.* 键
    if ($srcPath -like "*Cursor*") {
        foreach ($prop in $srcObj.PSObject.Properties) {
            if ($prop.Name.StartsWith("cursor.") -or $prop.Name.StartsWith("mcp.")) {
                $filtered[$prop.Name] = $prop.Value
            }
        }
    }
    if ($filtered.Count -gt 0) {
        $filtered | ConvertTo-Json -Depth 10 | Set-Content $dstPath -Encoding UTF8
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  同步 Cursor + VS Code 配置到仓库" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================
# 1. 同步 .copilot
# ============================
Write-Host "[1/4] 同步 .copilot..." -ForegroundColor Green
foreach ($subdir in @("instructions", "skills")) {
    $src = Join-Path $copilotSrc $subdir
    $dst = Join-Path $copilotDst $subdir
    if (Test-Path $src) {
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
        Copy-Item $src $dst -Recurse -Force
        Write-Host "  + $subdir"
    }
}

# ============================
# 2. 同步 Cursor 配置
# ============================
Write-Host "[2/4] 同步 Cursor 配置..." -ForegroundColor Green
if (-not (Test-Path $cursorDst)) {
    New-Item -ItemType Directory -Path $cursorDst -Force | Out-Null
}

# mcp.json
$cursorMcpSrc = Join-Path $cursorSrc "mcp.json"
if (Test-Path $cursorMcpSrc) {
    Copy-Item $cursorMcpSrc (Join-Path $cursorDst "mcp.json") -Force
    Write-Host "  + mcp.json"
}

# rules/
$rulesSrc = Join-Path $cursorSrc "rules"
if (Test-Path $rulesSrc) {
    $rulesDst = Join-Path $cursorDst "rules"
    if (-not (Test-Path $rulesDst)) {
        New-Item -ItemType Directory -Path $rulesDst -Force | Out-Null
    }
    Copy-Item "$rulesSrc\*" $rulesDst -Recurse -Force
    Write-Host "  + rules/"
}

# skills/
$skillsSrc = Join-Path $cursorSrc "skills"
if (Test-Path $skillsSrc) {
    $skillsDst = Join-Path $cursorDst "skills"
    if (Test-Path $skillsDst) { Remove-Item $skillsDst -Recurse -Force }
    Copy-Item $skillsSrc $skillsDst -Recurse -Force
    Write-Host "  + skills/"
}

# skills-cursor/
$skillsCursorSrc = Join-Path $cursorSrc "skills-cursor"
if (Test-Path $skillsCursorSrc) {
    $skillsCursorDst = Join-Path $cursorDst "skills-cursor"
    if (Test-Path $skillsCursorDst) { Remove-Item $skillsCursorDst -Recurse -Force }
    Copy-Item $skillsCursorSrc $skillsCursorDst -Recurse -Force
    Write-Host "  + skills-cursor/"
}

# settings.json (提取 Copilot 相关)
Extract-CopilotSettings $cursorSettSrc $cursorSettDst
Write-Host "  + settings.json (Copilot/MCP 相关)"

# ============================
# 3. 同步 VS Code 配置
# ============================
Write-Host "[3/4] 同步 VS Code 配置..." -ForegroundColor Green
if (-not (Test-Path (Join-Path $repoDir "vscode"))) {
    New-Item -ItemType Directory -Path (Join-Path $repoDir "vscode") -Force | Out-Null
}

if (Test-Path $vscodeMcpSrc) {
    Copy-Item $vscodeMcpSrc $vscodeMcpDst -Force
    Write-Host "  + mcp.json"
}

Extract-CopilotSettings $vscodeSettSrc $vscodeSettDst
Write-Host "  + settings.json (Copilot 相关)"

# ============================
# 4. Git commit & push
# ============================
Write-Host "[4/4] 提交到 Git..." -ForegroundColor Green
Push-Location $repoDir
git add -A
$status = git status --porcelain
if ($status) {
    git commit -m $Message
    if (-not $NoPush) {
        git push
        Write-Host "  + 已推送到 GitHub" -ForegroundColor Green
    } else {
        Write-Host "  + 已提交（未推送，使用 -NoPush）" -ForegroundColor Yellow
    }
} else {
    Write-Host "  无变更，无需提交。" -ForegroundColor Yellow
}
Pop-Location

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  同步完成！" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
