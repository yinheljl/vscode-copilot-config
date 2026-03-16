<#
.SYNOPSIS
    还原 VS Code GitHub Copilot 个人配置到当前机器

.DESCRIPTION
    将本仓库中的 .copilot 配置（instructions、skills）和 MCP 服务器配置还原到
    当前用户的 VS Code 配置目录。

.EXAMPLE
    .\restore.ps1
    .\restore.ps1 -DryRun   # 只显示将要执行的操作，不实际复制
#>
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir   = $PSScriptRoot
$copilotSrc  = Join-Path $scriptDir ".copilot"
$copilotDst  = Join-Path $env:USERPROFILE ".copilot"
$mcpSrc      = Join-Path $scriptDir "vscode\mcp.json"
$mcpDst      = Join-Path $env:APPDATA "Code\User\mcp.json"

Write-Host "=== VS Code Copilot 配置还原 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "源目录  : $copilotSrc"
Write-Host "目标目录: $copilotDst"
Write-Host "MCP 源  : $mcpSrc"
Write-Host "MCP 目标: $mcpDst"
Write-Host ""

if ($DryRun) {
    Write-Host "[DryRun] 仅预览，不执行实际操作。" -ForegroundColor Yellow
    Write-Host ""
}

# --- 还原 .copilot ---
if (-not (Test-Path $copilotSrc)) {
    Write-Error "找不到源目录: $copilotSrc"
    exit 1
}

if ($DryRun) {
    Write-Host "[DryRun] 将复制: $copilotSrc  ->  $copilotDst" -ForegroundColor Yellow
} else {
    Write-Host "正在还原 .copilot 配置..." -ForegroundColor Green
    if (-not (Test-Path $copilotDst)) {
        New-Item -ItemType Directory -Path $copilotDst -Force | Out-Null
    }
    # 只复制 instructions 和 skills，不覆盖 ide 目录（包含运行时锁文件）
    foreach ($subdir in @("instructions", "skills")) {
        $src = Join-Path $copilotSrc $subdir
        $dst = Join-Path $copilotDst $subdir
        if (Test-Path $src) {
            Copy-Item $src $dst -Recurse -Force
            Write-Host "  ✓ $subdir"
        }
    }
}

# --- 还原 mcp.json ---
if (-not (Test-Path $mcpSrc)) {
    Write-Warning "找不到 MCP 配置文件: $mcpSrc，跳过。"
} else {
    $mcpDir = Split-Path $mcpDst -Parent
    if ($DryRun) {
        Write-Host "[DryRun] 将复制: $mcpSrc  ->  $mcpDst" -ForegroundColor Yellow
    } else {
        Write-Host "正在还原 MCP 配置..." -ForegroundColor Green

        # 如果目标 mcp.json 已存在，先备份
        if (Test-Path $mcpDst) {
            $backup = $mcpDst + ".bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
            Copy-Item $mcpDst $backup
            Write-Host "  已备份原 mcp.json -> $backup"
        }

        if (-not (Test-Path $mcpDir)) {
            New-Item -ItemType Directory -Path $mcpDir -Force | Out-Null
        }
        Copy-Item $mcpSrc $mcpDst -Force
        Write-Host "  ✓ mcp.json"
    }
}

Write-Host ""
Write-Host "=== 还原完成 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "后续步骤：" -ForegroundColor Yellow
Write-Host "  1. 重启 VS Code"
Write-Host "  2. 打开 Copilot Chat，系统会提示你输入 GITHUB_MCP_TOKEN"
Write-Host "     (GitHub Personal Access Token，需要 repo 权限)"
Write-Host "  3. 验证 MCP Server 和 instructions 是否正常加载"
