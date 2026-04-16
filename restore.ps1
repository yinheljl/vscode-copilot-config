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
    - 克隆/下载 qt-interactive-feedback-mcp 到用户级共享 MCP 目录并运行 uv sync

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
$feedbackMcpDir  = Join-Path (Join-Path $env:USERPROFILE "MCP") "Interactive-Feedback-MCP"

function Backup-File($path) {
    if (Test-Path $path) {
        $backup = $path + ".bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
        Copy-Item $path $backup
        Write-Host "  已备份: $backup" -ForegroundColor DarkGray
    }
}

function Write-Utf8NoBomFile($path, $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
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
    $json = $dstObj | ConvertTo-Json -Depth 10
    Write-Utf8NoBomFile $dstPath $json
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

function Get-FeedbackPythonPath($mcpDir) {
    $pythonPath = Join-Path $mcpDir ".venv\Scripts\python.exe"
    if (Test-Path $pythonPath) { return $pythonPath }
    return $null
}

function Escape-JsonString($value) {
    return $value.Replace('\', '\\')
}

function Install-McpJson($srcPath, $dstPath, $uvPath, $feedbackPythonPath, $mcpDir) {
    if (-not (Test-Path $srcPath)) { return }
    $content = Get-Content $srcPath -Raw
    $serverPath = Join-Path $mcpDir "server.py"
    $escapedUv = Escape-JsonString $uvPath
    $escapedPython = Escape-JsonString $feedbackPythonPath
    $escapedDir = Escape-JsonString $mcpDir
    $escapedServer = Escape-JsonString $serverPath
    $content = $content.Replace('__UV_PATH__', $escapedUv)
    $content = $content.Replace('__FEEDBACK_MCP_PYTHON__', $escapedPython)
    $content = $content.Replace('__FEEDBACK_MCP_DIR__', $escapedDir)
    $content = $content.Replace('__FEEDBACK_SERVER_PATH__', $escapedServer)
    $dstDir = Split-Path $dstPath -Parent
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    try {
        $null = $content | ConvertFrom-Json
    } catch {
        throw "生成的 mcp.json 不是合法 JSON: $($_.Exception.Message)"
    }
    Backup-File $dstPath
    Write-Utf8NoBomFile $dstPath $content
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
        Write-Host "  目录已存在，尝试更新..."
        if (Get-Command git -ErrorAction SilentlyContinue) {
            Push-Location $feedbackMcpDir
            try {
                git pull --ff-only 2>&1 | Out-Null
            } catch {
                Write-Warning "  更新反馈服务目录失败，继续使用本地已有版本: $($_.Exception.Message)"
            } finally {
                Pop-Location
            }
        } else {
            Write-Host "  未安装 git，跳过更新" -ForegroundColor Yellow
        }
    } else {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            Write-Host "  正在克隆（使用 git）..."
            git clone https://github.com/rooney2020/qt-interactive-feedback-mcp.git $feedbackMcpDir
        } else {
            Write-Host "  未安装 git，使用 ZIP 下载..." -ForegroundColor Yellow
            $zipUrl = "https://github.com/rooney2020/qt-interactive-feedback-mcp/archive/refs/heads/main.zip"
            $zipPath = Join-Path $env:TEMP "interactive-feedback-mcp.zip"
            $extractDir = Join-Path $env:TEMP "interactive-feedback-mcp-extract"
            try {
                Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
                if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
                Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
                $innerDir = Get-ChildItem $extractDir -Directory | Select-Object -First 1
                Move-Item $innerDir.FullName $feedbackMcpDir
                Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
                Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  + 已通过 ZIP 下载完成"
            } catch {
                Write-Warning "  ZIP 下载失败: $_"
                Write-Warning "  请手动下载: $zipUrl"
                Write-Warning "  解压到: $feedbackMcpDir"
            }
        }
    }

    $uvPath = Resolve-UvPath
    if ($uvPath) {
        Write-Host "  正在运行 uv sync..."
        Push-Location $feedbackMcpDir
        & $uvPath sync
        Pop-Location
        $feedbackPythonPath = Get-FeedbackPythonPath $feedbackMcpDir
        if ($feedbackPythonPath) {
            Write-Host "  + Interactive-Feedback-MCP 已就绪"

            $cursorMcpSrc = Join-Path $cursorSrc "mcp.json"
            Install-McpJson $cursorMcpSrc (Join-Path $cursorDst "mcp.json") $uvPath $feedbackPythonPath $feedbackMcpDir
            Install-McpJson $vscodeMcpSrc $vscodeMcpDst $uvPath $feedbackPythonPath $feedbackMcpDir
        } else {
            Write-Warning "  找不到反馈服务虚拟环境 Python: $feedbackMcpDir\.venv\Scripts\python.exe"
            Write-Warning "  请确认 uv sync 是否成功完成。"
        }
    } else {
        Write-Warning "  未找到 uv，请先安装: https://docs.astral.sh/uv/"
        Write-Warning "  然后手动执行: cd $feedbackMcpDir && uv sync"
        Write-Warning "  Cursor 模板需替换 __UV_PATH__ 和 __FEEDBACK_MCP_DIR__；VS Code 模板需替换 __FEEDBACK_MCP_PYTHON__ 和 __FEEDBACK_SERVER_PATH__"
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
