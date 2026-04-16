<#
.SYNOPSIS
    还原 Cursor + VS Code GitHub Copilot 个人配置到当前机器

.DESCRIPTION
    将本仓库中的配置还原到当前用户的 Cursor 和 VS Code 配置目录：
    - copilot (instructions, skills) → ~/.copilot/
    - cursor/mcp.json → ~/.cursor/mcp.json（自动替换路径占位符）
    - cursor/rules/ → ~/.cursor/rules/
    - cursor/skills/ → ~/.cursor/skills/
    - cursor/skills-cursor/ → ~/.cursor/skills-cursor/
    - cursor/settings.json → 合并到 Cursor settings.json
    - vscode/mcp.json → %APPDATA%/Code/User/mcp.json（自动替换路径占位符）
    - vscode/settings.json → 合并到 VS Code settings.json
    - 克隆 qt-interactive-feedback-mcp 并运行 uv sync

.EXAMPLE
    .\restore.ps1
    .\restore.ps1 -DryRun
    .\restore.ps1 -SkipFeedbackMCP
#>
param(
    [switch]$DryRun,
    [switch]$SkipFeedbackMCP
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir       = $PSScriptRoot
$copilotSrc      = Join-Path $scriptDir "copilot"
$copilotDst      = Join-Path $env:USERPROFILE ".copilot"
$cursorSrc       = Join-Path $scriptDir "cursor"
$cursorDst       = Join-Path $env:USERPROFILE ".cursor"
$vscodeMcpSrc    = Join-Path $scriptDir "vscode\mcp.json"
$vscodeMcpDst    = Join-Path $env:APPDATA "Code\User\mcp.json"
$vscodeSettSrc   = Join-Path $scriptDir "vscode\settings.json"
$vscodeSettDst   = Join-Path $env:APPDATA "Code\User\settings.json"
$cursorSettSrc   = Join-Path $scriptDir "cursor\settings.json"
$cursorSettDst   = Join-Path $env:APPDATA "Cursor\User\settings.json"
$feedbackMcpDir  = Join-Path $cursorDst "Interactive-Feedback-MCP"

function Backup-File($path) {
    if (Test-Path $path) {
        $backup = $path + ".bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
        Copy-Item $path $backup
        Write-Host "  已备份: $backup" -ForegroundColor DarkGray
    }
}

function Merge-JsonSettings($srcPath, $dstPath) {
    if (-not (Test-Path $srcPath)) { return }
    $srcObj = Get-Content $srcPath -Raw | ConvertFrom-Json
    if (Test-Path $dstPath) {
        Backup-File $dstPath
        $dstObj = Get-Content $dstPath -Raw | ConvertFrom-Json
    } else {
        $dstObj = [PSCustomObject]@{}
    }
    foreach ($prop in $srcObj.PSObject.Properties) {
        $dstObj | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
    }
    $dstObj | ConvertTo-Json -Depth 10 | Set-Content $dstPath -Encoding UTF8
    Write-Host "  + 合并设置到 $dstPath"
}

function Resolve-UvPath {
    $candidates = @(
        (Join-Path $env:USERPROFILE ".local\bin\uv.exe"),
        (Join-Path $env:USERPROFILE ".cargo\bin\uv.exe")
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    $found = (Get-Command uv -ErrorAction SilentlyContinue).Source
    if ($found) { return $found }
    return $null
}

function Install-McpJson($srcPath, $dstPath, $uvPath, $mcpDir) {
    if (-not (Test-Path $srcPath)) { return }
    $content = Get-Content $srcPath -Raw
    $escapedUv  = $uvPath.Replace('\', '\\')
    $escapedDir = $mcpDir.Replace('\', '\\')
    $content = $content.Replace('__UV_PATH__', $escapedUv)
    $content = $content.Replace('__FEEDBACK_MCP_DIR__', $escapedDir)
    $dstDir = Split-Path $dstPath -Parent
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Backup-File $dstPath
    $content | Set-Content $dstPath -Encoding UTF8
    Write-Host "  + mcp.json (已替换路径)"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Cursor + VS Code Copilot 配置还原" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "[DryRun] 仅预览，不执行实际操作。" -ForegroundColor Yellow
    Write-Host ""
}

# ============================
# 1. 还原 copilot → ~/.copilot (VS Code Copilot instructions + skills)
# ============================
Write-Host "[1/5] 还原 Copilot 配置（instructions + skills）..." -ForegroundColor Green
if (-not (Test-Path $copilotSrc)) {
    Write-Warning "找不到源目录: $copilotSrc，跳过。"
} elseif ($DryRun) {
    Write-Host "  [DryRun] $copilotSrc -> $copilotDst"
} else {
    if (-not (Test-Path $copilotDst)) {
        New-Item -ItemType Directory -Path $copilotDst -Force | Out-Null
    }
    foreach ($subdir in @("instructions", "skills")) {
        $src = Join-Path $copilotSrc $subdir
        $dst = Join-Path $copilotDst $subdir
        if (Test-Path $src) {
            if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
            Copy-Item $src $dst -Recurse -Force
            Write-Host "  + $subdir"
        }
    }
}

# ============================
# 2. 还原 Cursor 配置
# ============================
Write-Host "[2/5] 还原 Cursor 配置..." -ForegroundColor Green
if (-not (Test-Path $cursorSrc)) {
    Write-Warning "找不到源目录: $cursorSrc，跳过。"
} elseif ($DryRun) {
    Write-Host "  [DryRun] $cursorSrc -> $cursorDst"
} else {
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

    # settings.json (合并)
    if (Test-Path $cursorSettSrc) {
        Merge-JsonSettings $cursorSettSrc $cursorSettDst
    }
}

# ============================
# 3. 还原 VS Code 配置
# ============================
Write-Host "[3/5] 还原 VS Code 配置..." -ForegroundColor Green
if ($DryRun) {
    Write-Host "  [DryRun] settings.json"
} else {
    if (Test-Path $vscodeSettSrc) {
        Merge-JsonSettings $vscodeSettSrc $vscodeSettDst
    }
}

# ============================
# 4. 克隆 Interactive-Feedback-MCP + 生成 mcp.json
# ============================
Write-Host "[4/5] 配置 Interactive-Feedback-MCP..." -ForegroundColor Green
if ($SkipFeedbackMCP) {
    Write-Host "  跳过（-SkipFeedbackMCP）" -ForegroundColor Yellow
} elseif ($DryRun) {
    Write-Host "  [DryRun] 将克隆到 $feedbackMcpDir 并运行 uv sync"
} else {
    if (Test-Path $feedbackMcpDir) {
        Write-Host "  目录已存在，执行 git pull..."
        Push-Location $feedbackMcpDir
        git pull --ff-only 2>&1 | Out-Null
        Pop-Location
    } else {
        Write-Host "  正在克隆..."
        git clone https://github.com/rooney2020/qt-interactive-feedback-mcp.git $feedbackMcpDir
    }

    $uvPath = Resolve-UvPath
    if ($uvPath) {
        Write-Host "  正在运行 uv sync..."
        Push-Location $feedbackMcpDir
        & $uvPath sync
        Pop-Location
        Write-Host "  + Interactive-Feedback-MCP 已就绪"

        # 用实际路径生成 Cursor 和 VS Code 的 mcp.json
        $cursorMcpSrc = Join-Path $cursorSrc "mcp.json"
        Install-McpJson $cursorMcpSrc (Join-Path $cursorDst "mcp.json") $uvPath $feedbackMcpDir
        Install-McpJson $vscodeMcpSrc $vscodeMcpDst $uvPath $feedbackMcpDir
    } else {
        Write-Warning "  未找到 uv，请先安装: https://docs.astral.sh/uv/"
        Write-Warning "  然后手动执行: cd $feedbackMcpDir && uv sync"
        Write-Warning "  安装完成后需手动编辑 mcp.json 替换 __UV_PATH__ 和 __FEEDBACK_MCP_DIR__"
    }
}

# ============================
# 5. 验证
# ============================
Write-Host "[5/5] 验证..." -ForegroundColor Green
$checks = @(
    @{ Name = "~/.copilot/instructions/"; Path = (Join-Path $copilotDst "instructions") },
    @{ Name = "~/.copilot/skills/"; Path = (Join-Path $copilotDst "skills") },
    @{ Name = "~/.cursor/mcp.json"; Path = (Join-Path $cursorDst "mcp.json") },
    @{ Name = "~/.cursor/rules/"; Path = (Join-Path $cursorDst "rules") },
    @{ Name = "~/.cursor/skills/"; Path = (Join-Path $cursorDst "skills") },
    @{ Name = "~/.cursor/skills-cursor/"; Path = (Join-Path $cursorDst "skills-cursor") },
    @{ Name = "VS Code mcp.json"; Path = $vscodeMcpDst },
    @{ Name = "Interactive-Feedback-MCP"; Path = $feedbackMcpDir }
)
foreach ($c in $checks) {
    if (Test-Path $c.Path) {
        Write-Host "  + $($c.Name)" -ForegroundColor Green
    } else {
        Write-Host "  - $($c.Name) (未找到)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  还原完成！" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "后续步骤：" -ForegroundColor Yellow
Write-Host "  1. 重启 Cursor 和 VS Code"
Write-Host "  2. 在 Cursor 中验证 MCP Server 是否正常加载"
Write-Host "  3. 如需其他 MCP（GitHub、Context7 等），在扩展商城中安装"
