<#
.SYNOPSIS
    从当前机器同步最新的 Cursor + VS Code Copilot + Codex 配置到本仓库并推送到 GitHub

.DESCRIPTION
    同步以下配置到本仓库目录：
    - ~/.copilot/instructions/ 和 ~/.copilot/skills/ → copilot/
    - ~/.cursor/rules/, skills/ → cursor/
    - Cursor settings.json (Copilot/MCP 相关) → cursor/settings.json
    - VS Code settings.json (Copilot 相关) → vscode/settings.json
    - ~/.codex/AGENTS.md → codex/AGENTS.md
    注意：mcp.json 和 config.toml 使用模板（含占位符），不从本机同步。
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
$copilotDst      = Join-Path $repoDir "copilot"
$cursorSrc       = Join-Path $env:USERPROFILE ".cursor"
$cursorDst       = Join-Path $repoDir "cursor"
$codexSrc        = Join-Path $env:USERPROFILE ".codex"
$codexDst        = Join-Path $repoDir "codex"
$vscodeSettSrc   = Join-Path $env:APPDATA "Code\User\settings.json"
$vscodeSettDst   = Join-Path $repoDir "vscode\settings.json"
$cursorSettSrc   = Join-Path $env:APPDATA "Cursor\User\settings.json"
$cursorSettDst   = Join-Path $repoDir "cursor\settings.json"

$copilotKeys = @("chat.", "github.copilot")
# 任何键名（不区分大小写）匹配下列任一片段，将被排除以避免泄露
$denyKeyParts = @("token", "apikey", "api_key", "secret", "password", "bearer", "credential")

function Test-IsSensitiveKey([string]$keyName) {
    $low = $keyName.ToLowerInvariant()
    foreach ($p in $denyKeyParts) {
        if ($low.Contains($p)) { return $true }
    }
    return $false
}

function Assert-GitReady($repoPath) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "未找到 git。sync.ps1 需要在已安装 git 的环境下运行。"
    }

    $gitDir = Join-Path $repoPath ".git"
    if (-not (Test-Path $gitDir)) {
        throw "当前目录不是 Git 仓库。若该目录来自 ZIP 解压，请先使用 git clone 获取完整仓库后再运行 sync.ps1。"
    }
}

function Extract-CopilotSettings($srcPath, $dstPath) {
    if (-not (Test-Path $srcPath)) { return }
    try {
        $srcObj = Get-Content $srcPath -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "  解析失败（可能含 // 注释），跳过: $srcPath"
        return
    }
    $filtered = [ordered]@{}
    $skipped = @()
    foreach ($prop in $srcObj.PSObject.Properties) {
        $matched = $false
        foreach ($prefix in $copilotKeys) {
            if ($prop.Name.StartsWith($prefix)) { $matched = $true; break }
        }
        if (-not $matched -and ($srcPath -like "*Cursor*")) {
            if ($prop.Name.StartsWith("cursor.") -or $prop.Name.StartsWith("mcp.")) {
                $matched = $true
            }
        }
        if ($matched) {
            if (Test-IsSensitiveKey $prop.Name) {
                $skipped += $prop.Name
                continue
            }
            $filtered[$prop.Name] = $prop.Value
        }
    }
    if ($skipped.Count -gt 0) {
        Write-Host ("  ! 跳过疑似敏感键: " + ($skipped -join ", ")) -ForegroundColor Yellow
    }
    if ($filtered.Count -gt 0) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $json = $filtered | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($dstPath, $json, $utf8NoBom)
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  同步 Cursor + VS Code + Codex 配置到仓库" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Assert-GitReady $repoDir

# ============================
# 1. 同步 copilot
# ============================
Write-Host "[1/5] 同步 Copilot..." -ForegroundColor Green
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
# 2. 同步 Cursor 配置（不含 mcp.json，使用模板）
# ============================
Write-Host "[2/5] 同步 Cursor 配置..." -ForegroundColor Green
if (-not (Test-Path $cursorDst)) {
    New-Item -ItemType Directory -Path $cursorDst -Force | Out-Null
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

# settings.json (提取 Copilot 相关)
Extract-CopilotSettings $cursorSettSrc $cursorSettDst
Write-Host "  + settings.json (Copilot/MCP 相关)"
Write-Host "  * mcp.json 使用模板，不从本机同步" -ForegroundColor DarkGray

# ============================
# 3. 同步 Codex 配置（只同步 AGENTS.md，config.toml 使用模板）
# ============================
Write-Host "[3/5] 同步 Codex 配置..." -ForegroundColor Green
$codexAgentsSrc = Join-Path $codexSrc "AGENTS.md"
if (Test-Path $codexAgentsSrc) {
    if (-not (Test-Path $codexDst)) {
        New-Item -ItemType Directory -Path $codexDst -Force | Out-Null
    }
    Copy-Item $codexAgentsSrc (Join-Path $codexDst "AGENTS.md") -Force
    Write-Host "  + AGENTS.md"
} else {
    Write-Host "  未找到 ~/.codex/AGENTS.md，跳过" -ForegroundColor Yellow
}
Write-Host "  * config.toml 使用模板，不从本机同步" -ForegroundColor DarkGray

# ============================
# 4. 同步 VS Code 配置（不含 mcp.json，使用模板）
# ============================
Write-Host "[4/5] 同步 VS Code 配置..." -ForegroundColor Green
if (-not (Test-Path (Join-Path $repoDir "vscode"))) {
    New-Item -ItemType Directory -Path (Join-Path $repoDir "vscode") -Force | Out-Null
}

Extract-CopilotSettings $vscodeSettSrc $vscodeSettDst
Write-Host "  + settings.json (Copilot 相关)"
Write-Host "  * mcp.json 使用模板，不从本机同步" -ForegroundColor DarkGray

# ============================
# 5. Git commit & push
# ============================
Write-Host "[5/5] 提交到 Git..." -ForegroundColor Green
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
