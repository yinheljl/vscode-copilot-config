<#
.SYNOPSIS
    还原 Cursor + VS Code GitHub Copilot 个人配置到当前机器

.DESCRIPTION
    自动检测已安装的 IDE（VS Code、Cursor），仅配置已安装的环境。
    默认使用增量模式：仅添加/更新配置，不删除用户已有的自定义内容。
    使用 -Force 参数可切换为完全覆盖模式。

    还原内容：
    - copilot (instructions, skills) → ~/.copilot/（VS Code）
    - cursor/rules/ → ~/.cursor/rules/（Cursor）
    - cursor/skills/ → ~/.cursor/skills/（Cursor）
    - cursor/skills-cursor/ → ~/.cursor/skills-cursor/（Cursor）
    - cursor/settings.json → 合并到 Cursor settings.json（Cursor）
    - vscode/mcp.json → 合并到 VS Code mcp.json（VS Code）
    - vscode/settings.json → 合并到 VS Code settings.json（VS Code）
    - 克隆/下载 qt-interactive-feedback-mcp 到用户级共享 MCP 目录

.EXAMPLE
    .\restore.ps1                   # 增量模式（默认，不覆盖用户已有配置）
    .\restore.ps1 -Force            # 完全覆盖模式
    .\restore.ps1 -DryRun           # 预览模式
    .\restore.ps1 -SkipFeedbackMCP  # 跳过 Interactive-Feedback-MCP
#>
param(
    [switch]$DryRun,
    [switch]$Force,
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

# ============================
# IDE 自动检测
# ============================
$vscodeUserDir = Join-Path $env:APPDATA "Code\User"
$cursorUserDir = Join-Path $env:APPDATA "Cursor\User"
$hasVSCode = (Test-Path $vscodeUserDir) -or [bool](Get-Command code -ErrorAction SilentlyContinue)
$hasCursor = (Test-Path $cursorUserDir) -or (Test-Path $cursorDst) -or [bool](Get-Command cursor -ErrorAction SilentlyContinue)

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

function Merge-McpJson($srcPath, $dstPath, $uvPath, $feedbackPythonPath, $mcpDir, $serverKey) {
    if (-not (Test-Path $srcPath)) { return }
    $content = Get-Content $srcPath -Raw
    $serverPath = Join-Path $mcpDir "server.py"
    $content = $content.Replace('__UV_PATH__', (Escape-JsonString $uvPath))
    $content = $content.Replace('__FEEDBACK_MCP_PYTHON__', (Escape-JsonString $feedbackPythonPath))
    $content = $content.Replace('__FEEDBACK_MCP_DIR__', (Escape-JsonString $mcpDir))
    $content = $content.Replace('__FEEDBACK_SERVER_PATH__', (Escape-JsonString $serverPath))
    try {
        $srcObj = $content | ConvertFrom-Json
    } catch {
        throw "模板 mcp.json 不是合法 JSON: $($_.Exception.Message)"
    }
    $dstDir = Split-Path $dstPath -Parent
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    if ((Test-Path $dstPath) -and -not $Force) {
        # 增量模式：合并 MCP 服务器配置
        Backup-File $dstPath
        try {
            $dstObj = Get-Content $dstPath -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "  现有 mcp.json 格式错误，将使用新配置覆盖"
            $dstObj = $null
        }
        if ($dstObj) {
            # 确保目标有 servers/mcpServers 键
            if (-not ($dstObj.PSObject.Properties.Name -contains $serverKey)) {
                $dstObj | Add-Member -MemberType NoteProperty -Name $serverKey -Value ([PSCustomObject]@{}) -Force
            }
            # 从源中合并每个 server 到目标
            $srcServers = $srcObj.$serverKey
            if ($srcServers) {
                foreach ($prop in $srcServers.PSObject.Properties) {
                    $dstObj.$serverKey | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
                }
            }
            $json = $dstObj | ConvertTo-Json -Depth 10
            Write-Utf8NoBomFile $dstPath $json
            Write-Host "  + mcp.json (增量合并，保留已有服务器)"
            return
        }
    }
    # 覆盖模式或目标不存在
    Backup-File $dstPath
    Write-Utf8NoBomFile $dstPath $content
    Write-Host "  + mcp.json (已替换路径)"
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

function Copy-DirMerge($src, $dst) {
    # 增量复制：只添加/更新文件，不删除目标中已有的其他文件
    if (-not (Test-Path $dst)) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
    }
    Copy-Item "$src\*" $dst -Recurse -Force
}

function Copy-DirReplace($src, $dst) {
    # 完全覆盖：先删除目标目录再复制
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    Copy-Item $src $dst -Recurse -Force
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Cursor + VS Code Copilot 配置还原" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 显示模式
if ($Force) {
    Write-Host "[模式] 完全覆盖（-Force）" -ForegroundColor Red
} else {
    Write-Host "[模式] 增量合并（保留用户已有配置）" -ForegroundColor Green
}

# 显示检测结果
Write-Host "[IDE 检测]" -ForegroundColor Cyan
if ($hasVSCode) { Write-Host "  + VS Code" -ForegroundColor Green }
if ($hasCursor) { Write-Host "  + Cursor" -ForegroundColor Green }
if (-not $hasVSCode -and -not $hasCursor) {
    Write-Host "  未检测到任何 IDE，将安装所有配置（IDE 安装后即可使用）。" -ForegroundColor Yellow
    $hasVSCode = $true
    $hasCursor = $true
}
Write-Host ""

if ($DryRun) {
    Write-Host "[DryRun] 仅预览，不执行实际操作。" -ForegroundColor Yellow
    Write-Host ""
}

# 计算总步骤数
$totalSteps = 1  # 验证
if ($hasVSCode) { $totalSteps += 2 }
if ($hasCursor) { $totalSteps++ }
if (-not $SkipFeedbackMCP) { $totalSteps++ }
$step = 0

# ============================
# 还原 copilot → ~/.copilot (VS Code Copilot instructions + skills)
# ============================
if ($hasVSCode) {
    $step++
    Write-Host "[$step/$totalSteps] 还原 VS Code Copilot 配置（instructions + skills）..." -ForegroundColor Green
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
                if ($Force) {
                    Copy-DirReplace $src $dst
                    Write-Host "  + $subdir (覆盖)"
                } else {
                    Copy-DirMerge $src $dst
                    Write-Host "  + $subdir (增量)"
                }
            }
        }
    }
}

# ============================
# 还原 Cursor 配置
# ============================
if ($hasCursor) {
    $step++
    Write-Host "[$step/$totalSteps] 还原 Cursor 配置..." -ForegroundColor Green
    if (-not (Test-Path $cursorSrc)) {
        Write-Warning "找不到源目录: $cursorSrc，跳过。"
    } elseif ($DryRun) {
        Write-Host "  [DryRun] $cursorSrc -> $cursorDst"
    } else {
        # rules/
        $rulesSrc = Join-Path $cursorSrc "rules"
        if (Test-Path $rulesSrc) {
            $rulesDst = Join-Path $cursorDst "rules"
            if ($Force) {
                Copy-DirReplace $rulesSrc $rulesDst
                Write-Host "  + rules/ (覆盖)"
            } else {
                Copy-DirMerge $rulesSrc $rulesDst
                Write-Host "  + rules/ (增量)"
            }
        }

        # skills/
        $skillsSrc = Join-Path $cursorSrc "skills"
        if (Test-Path $skillsSrc) {
            $skillsDst = Join-Path $cursorDst "skills"
            if ($Force) {
                Copy-DirReplace $skillsSrc $skillsDst
                Write-Host "  + skills/ (覆盖)"
            } else {
                Copy-DirMerge $skillsSrc $skillsDst
                Write-Host "  + skills/ (增量)"
            }
        }

        # skills-cursor/
        $skillsCursorSrc = Join-Path $cursorSrc "skills-cursor"
        if (Test-Path $skillsCursorSrc) {
            $skillsCursorDst = Join-Path $cursorDst "skills-cursor"
            if ($Force) {
                Copy-DirReplace $skillsCursorSrc $skillsCursorDst
                Write-Host "  + skills-cursor/ (覆盖)"
            } else {
                Copy-DirMerge $skillsCursorSrc $skillsCursorDst
                Write-Host "  + skills-cursor/ (增量)"
            }
        }

        # settings.json (始终合并)
        if (Test-Path $cursorSettSrc) {
            Merge-JsonSettings $cursorSettSrc $cursorSettDst
        }
    }
}

# ============================
# 还原 VS Code 配置
# ============================
if ($hasVSCode) {
    $step++
    Write-Host "[$step/$totalSteps] 还原 VS Code 配置..." -ForegroundColor Green
    if ($DryRun) {
        Write-Host "  [DryRun] settings.json"
    } else {
        if (Test-Path $vscodeSettSrc) {
            Merge-JsonSettings $vscodeSettSrc $vscodeSettDst
        }
    }
}

# ============================
# 克隆 Interactive-Feedback-MCP + 生成 mcp.json
# ============================
if (-not $SkipFeedbackMCP) {
    $step++
    Write-Host "[$step/$totalSteps] 配置 Interactive-Feedback-MCP..." -ForegroundColor Green
    if ($DryRun) {
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

                # 生成/合并 mcp.json
                if ($hasCursor) {
                    $cursorMcpSrc = Join-Path $cursorSrc "mcp.json"
                    Merge-McpJson $cursorMcpSrc (Join-Path $cursorDst "mcp.json") $uvPath $feedbackPythonPath $feedbackMcpDir "mcpServers"
                }
                if ($hasVSCode) {
                    Merge-McpJson $vscodeMcpSrc $vscodeMcpDst $uvPath $feedbackPythonPath $feedbackMcpDir "servers"
                }
            } else {
                Write-Warning "  找不到反馈服务虚拟环境 Python: $feedbackMcpDir\.venv\Scripts\python.exe"
                Write-Warning "  请确认 uv sync 是否成功完成。"
            }
        } else {
            Write-Warning "  未找到 uv，请先安装: https://docs.astral.sh/uv/"
            Write-Warning "  然后手动执行: cd $feedbackMcpDir && uv sync"
        }
    }
}

# ============================
# 验证
# ============================
$step++
Write-Host "[$step/$totalSteps] 验证..." -ForegroundColor Green
$checks = @(
    @{ Name = "Interactive-Feedback-MCP"; Path = $feedbackMcpDir }
)
if ($hasVSCode) {
    $checks = @(
        @{ Name = "~/.copilot/instructions/"; Path = (Join-Path $copilotDst "instructions") },
        @{ Name = "~/.copilot/skills/"; Path = (Join-Path $copilotDst "skills") },
        @{ Name = "VS Code mcp.json"; Path = $vscodeMcpDst }
    ) + $checks
}
if ($hasCursor) {
    $checks = @(
        @{ Name = "~/.cursor/mcp.json"; Path = (Join-Path $cursorDst "mcp.json") },
        @{ Name = "~/.cursor/rules/"; Path = (Join-Path $cursorDst "rules") },
        @{ Name = "~/.cursor/skills/"; Path = (Join-Path $cursorDst "skills") },
        @{ Name = "~/.cursor/skills-cursor/"; Path = (Join-Path $cursorDst "skills-cursor") }
    ) + $checks
}
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
if ($hasVSCode) { Write-Host "  1. 重启 VS Code" }
if ($hasCursor) { Write-Host "  2. 重启 Cursor，验证 MCP Server 是否正常加载" }
Write-Host "  3. 如需其他 MCP（GitHub、Context7 等），在扩展商城中安装"