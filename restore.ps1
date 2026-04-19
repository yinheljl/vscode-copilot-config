<#
.SYNOPSIS
    还原 Cursor + VS Code GitHub Copilot + Codex 个人配置到当前机器

.DESCRIPTION
    自动检测已安装的 IDE（VS Code、Cursor、Codex），仅配置已安装的环境。
    默认使用增量模式：仅添加/更新配置，不删除用户已有的自定义内容。
    使用 -Force 参数可切换为完全覆盖模式。

    还原内容：
    - copilot (instructions, skills) → ~/.copilot/（VS Code）
    - cursor/rules/ → ~/.cursor/rules/（Cursor）
    - cursor/skills/ → ~/.cursor/skills/（Cursor）
    - cursor/settings.json → 合并到 Cursor settings.json（Cursor）
    - vscode/mcp.json → 合并到 VS Code mcp.json（VS Code）
    - vscode/settings.json → 合并到 VS Code settings.json（VS Code）
    - codex/AGENTS.md → ~/.codex/AGENTS.md（Codex）
    - codex/config.toml → 合并到 ~/.codex/config.toml（Codex）
    - codex/skills/ → ~/.codex/skills/（Codex 全局 Agent Skills，含安全护栏 skill）
    - codex/hooks/ → ~/.codex/hooks/（破坏性命令硬兜底 PreToolUse hook）
    - codex/hooks.json → 合并到 ~/.codex/hooks.json（注册 hook 到 Codex）
    - 克隆/下载 qt-interactive-feedback-mcp 到用户级共享 MCP 目录

.EXAMPLE
    .\restore.ps1                        # 增量模式（默认，不覆盖用户已有配置）
    .\restore.ps1 -Force                 # 完全覆盖模式
    .\restore.ps1 -DryRun                # 预览模式
    .\restore.ps1 -SkipFeedbackMCP       # 跳过 Interactive-Feedback-MCP
    .\restore.ps1 -Target Codex          # 仅配置 Codex
    .\restore.ps1 -Target VSCode,Cursor  # 仅配置 VS Code 和 Cursor
    .\restore.ps1 -Target Codex -Force   # 仅覆盖 Codex 配置
#>
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$SkipFeedbackMCP,
    [ValidateSet("All", "VSCode", "Cursor", "Codex")]
    [string[]]$Target = @("All")
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
$codexSrc        = Join-Path $scriptDir "codex"
$codexDst        = Join-Path $env:USERPROFILE ".codex"
$codexConfigSrc  = Join-Path $codexSrc "config.toml"
$codexConfigDst  = Join-Path $codexDst "config.toml"
$codexAgentsSrc  = Join-Path $codexSrc "AGENTS.md"
$codexAgentsDst  = Join-Path $codexDst "AGENTS.md"
$codexSkillsSrc  = Join-Path $codexSrc "skills"
$codexSkillsDst  = Join-Path $codexDst "skills"
$codexHooksSrc   = Join-Path $codexSrc "hooks"
$codexHooksDst   = Join-Path $codexDst "hooks"
$codexHooksJsonSrc = Join-Path $codexSrc "hooks.json"
$codexHooksJsonDst = Join-Path $codexDst "hooks.json"
$feedbackMcpDir  = Join-Path (Join-Path $env:USERPROFILE "MCP") "Interactive-Feedback-MCP"

# ============================
# IDE 自动检测
# ============================
$vscodeUserDir = Join-Path $env:APPDATA "Code\User"
$cursorUserDir = Join-Path $env:APPDATA "Cursor\User"
$hasVSCode = (Test-Path $vscodeUserDir) -or [bool](Get-Command code -ErrorAction SilentlyContinue)
$hasCursor = (Test-Path $cursorUserDir) -or (Test-Path $cursorDst) -or [bool](Get-Command cursor -ErrorAction SilentlyContinue)
$hasCodex  = (Test-Path $codexDst) -or [bool](Get-Command codex -ErrorAction SilentlyContinue)

# ============================
# -Target 参数过滤
# ============================
if ($Target -notcontains "All") {
    if ($Target -notcontains "VSCode") { $hasVSCode = $false }
    if ($Target -notcontains "Cursor") { $hasCursor = $false }
    if ($Target -notcontains "Codex")  { $hasCodex  = $false }
}

# 同名文件保留最近 N 份备份，避免无限累积
$BackupKeepCount = 5

function Backup-File($path) {
    if (Test-Path $path) {
        $backup = $path + ".bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
        Copy-Item $path $backup
        Write-Host "  已备份: $backup" -ForegroundColor DarkGray
        # 轮转：仅保留最新 $BackupKeepCount 份
        $dir = Split-Path $path -Parent
        $name = Split-Path $path -Leaf
        $old = Get-ChildItem -Path $dir -Filter ($name + ".bak_*") -File -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending |
               Select-Object -Skip $BackupKeepCount
        foreach ($f in $old) {
            try {
                Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
                Write-Host "  已清理旧备份: $($f.Name)" -ForegroundColor DarkGray
            } catch {}
        }
    }
}

function Write-Utf8NoBomFile($path, $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

# 把 PowerShell ConvertTo-Json 的"对齐式缩进"输出重新格式化为标准 2 空格缩进
function Format-Json([string]$json, [int]$indent = 2) {
    if ([string]::IsNullOrWhiteSpace($json)) { return $json }
    $indentStr = ' ' * $indent
    $sb = New-Object System.Text.StringBuilder
    $level = 0
    $inString = $false
    $escaped = $false
    for ($i = 0; $i -lt $json.Length; $i++) {
        $c = $json[$i]
        if ($inString) {
            [void]$sb.Append($c)
            if ($escaped) {
                $escaped = $false
            } elseif ($c -eq '\') {
                $escaped = $true
            } elseif ($c -eq '"') {
                $inString = $false
            }
            continue
        }
        switch ($c) {
            '"' { $inString = $true; [void]$sb.Append($c); break }
            '{' { [void]$sb.Append($c); $level++; [void]$sb.Append("`r`n" + ($indentStr * $level)); break }
            '[' { [void]$sb.Append($c); $level++; [void]$sb.Append("`r`n" + ($indentStr * $level)); break }
            '}' { $level--; [void]$sb.Append("`r`n" + ($indentStr * $level)); [void]$sb.Append($c); break }
            ']' { $level--; [void]$sb.Append("`r`n" + ($indentStr * $level)); [void]$sb.Append($c); break }
            ',' { [void]$sb.Append($c); [void]$sb.Append("`r`n" + ($indentStr * $level)); break }
            ':' { [void]$sb.Append(': '); break }
            default {
                if ($c -ne ' ' -and $c -ne "`n" -and $c -ne "`r" -and $c -ne "`t") {
                    [void]$sb.Append($c)
                }
            }
        }
    }
    return $sb.ToString()
}

function ConvertFrom-Jsonc([string]$raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) { return [PSCustomObject]@{} }
    # 保护字符串内的 // 和 /*：把所有字符串字面量先替换成占位符
    $strings = New-Object System.Collections.Generic.List[string]
    $stripped = [regex]::Replace($raw, '"(\\.|[^"\\])*"', {
        param($m)
        $i = $strings.Count
        [void]$strings.Add($m.Value)
        return "__JSONC_STR_${i}__"
    })
    # 删除单行注释 //...
    $stripped = [regex]::Replace($stripped, '(?m)//[^\r\n]*', '')
    # 删除多行注释 /* ... */
    $stripped = [regex]::Replace($stripped, '(?s)/\*.*?\*/', '')
    # 删除尾随逗号
    $stripped = [regex]::Replace($stripped, ',(\s*[}\]])', '$1')
    # 还原字符串
    for ($i = 0; $i -lt $strings.Count; $i++) {
        $stripped = $stripped.Replace("__JSONC_STR_${i}__", $strings[$i])
    }
    return $stripped | ConvertFrom-Json
}

function Merge-JsonSettings($srcPath, $dstPath) {
    if (-not (Test-Path $srcPath)) { return }
    # 显式 UTF8 读取，避免中文乱码
    $srcRaw = Get-Content $srcPath -Raw -Encoding UTF8
    try {
        $srcObj = ConvertFrom-Jsonc $srcRaw
    } catch {
        Write-Warning "  源 settings 解析失败，跳过: $srcPath"
        return
    }

    if (-not (Test-Path $dstPath)) {
        # 目标不存在：直接复制源（保留原始格式 + 注释）
        $dstDir = Split-Path $dstPath -Parent
        if (-not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }
        Write-Utf8NoBomFile $dstPath $srcRaw
        Write-Host "  + 已创建 $dstPath"
        return
    }

    # 目标存在：增量只补缺，最大限度保留原始 JSONC 注释和格式
    $dstRaw = Get-Content $dstPath -Raw -Encoding UTF8
    try {
        $dstObj = ConvertFrom-Jsonc $dstRaw
    } catch {
        Write-Warning "  现有 settings.json 解析失败（含语法错误），跳过合并: $dstPath"
        return
    }

    $existingKeys = @{}
    foreach ($p in $dstObj.PSObject.Properties) { $existingKeys[$p.Name] = $true }

    $missingProps = @()
    foreach ($prop in $srcObj.PSObject.Properties) {
        if (-not $existingKeys.ContainsKey($prop.Name)) {
            $missingProps += $prop
        }
    }

    if ($missingProps.Count -eq 0) {
        Write-Host "  + settings.json (所有键已存在，未修改，注释保留)"
        return
    }

    Backup-File $dstPath
    # 把缺失的键以 JSON 片段形式插入到结尾的 } 之前，原文其他部分保持不动
    $additions = @()
    foreach ($p in $missingProps) {
        $valueJson = ($p.Value | ConvertTo-Json -Depth 20 -Compress:$false)
        $additions += "  ""$($p.Name)"": $valueJson"
    }
    $insertion = ($additions -join ",`r`n")

    $trimmed = $dstRaw.TrimEnd()
    if ($trimmed.EndsWith('}')) {
        $body = $trimmed.Substring(0, $trimmed.Length - 1).TrimEnd()
        if ($body.EndsWith(',') -or $body.EndsWith('{')) {
            $newRaw = "$body`r`n$insertion`r`n}`r`n"
        } else {
            $newRaw = "$body,`r`n$insertion`r`n}`r`n"
        }
        Write-Utf8NoBomFile $dstPath $newRaw
        Write-Host "  + settings.json (追加 $($missingProps.Count) 个缺失键，原注释保留)"
    } else {
        Write-Warning "  目标 settings.json 不以 '}' 结尾，跳过追加"
    }
}

function Merge-McpJson($srcPath, $dstPath, $uvPath, $feedbackPythonPath, $mcpDir, $serverKey) {
    if (-not (Test-Path $srcPath)) { return }
    $content = Get-Content $srcPath -Raw -Encoding UTF8
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
            $dstObj = Get-Content $dstPath -Raw -Encoding UTF8 | ConvertFrom-Json
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
            $json = $dstObj | ConvertTo-Json -Depth 20 -Compress
            $json = Format-Json $json 2
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
    if ($null -eq $value) { return '' }
    # 使用 ConvertTo-Json 做完整转义（处理 \、"、控制字符等），再剥掉外层引号
    $json = ConvertTo-Json -InputObject ([string]$value) -Compress
    return $json.Substring(1, $json.Length - 2)
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

function Resolve-PythonForHooks {
    # 寻找一个可被 Codex hook 调用的 Python 解释器（优先 venv）
    $candidates = @(
        (Join-Path $env:USERPROFILE "MCP\Interactive-Feedback-MCP\.venv\Scripts\python.exe"),
        (Join-Path $env:USERPROFILE ".local\bin\python.exe")
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    foreach ($name in @("py", "python3", "python")) {
        $found = (Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1).Source
        if ($found) {
            # 排除 Microsoft Store 假 python
            if ($found -notmatch "WindowsApps\\python") { return $found }
        }
    }
    return $null
}

function Install-CodexHooks($srcDir, $dstDir, $jsonSrcPath, $jsonDstPath, $pythonPath, $configTomlPath) {
    if (-not (Test-Path $srcDir)) { return }

    if (-not $pythonPath) {
        Write-Warning "  未找到可用的 Python 解释器，跳过 Codex hook 硬兜底（软层 skill 仍有效）"
        Write-Warning "  → 安装 Python 后重跑 .\restore.ps1 -Target Codex 即可启用硬兜底"
        return
    }

    # 1) 部署 hook 脚本
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Copy-Item "$srcDir\*" $dstDir -Recurse -Force
    Write-Host "  + hooks/ (PreToolUse 守卫脚本)"

    # 2) 跑一次自检
    $testScript = Join-Path $dstDir "test_pre_tool_use_guard.py"
    if (Test-Path $testScript) {
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $testOutput = & $pythonPath $testScript 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "  hook 自检失败！输出："
                $testOutput | ForEach-Object { Write-Warning "    $_" }
            } else {
                Write-Host "  + hook 自检 26 个用例全部通过" -ForegroundColor DarkGreen
            }
        } finally {
            $ErrorActionPreference = $prevPref
        }
    }

    # 3) 渲染 hooks.json 模板（替换占位符）→ 部署到 ~/.codex/hooks.json
    if (Test-Path $jsonSrcPath) {
        $hookScriptPath = Join-Path $dstDir "pre_tool_use_guard.py"
        $content = Get-Content $jsonSrcPath -Raw -Encoding UTF8
        $content = $content.Replace('__GUARD_PYTHON__', (Escape-JsonString $pythonPath))
        $content = $content.Replace('__GUARD_SCRIPT__', (Escape-JsonString $hookScriptPath))

        if ((Test-Path $jsonDstPath) -and -not $Force) {
            # 增量：尝试合并 PreToolUse 数组
            Backup-File $jsonDstPath
            try {
                $existing = Get-Content $jsonDstPath -Raw -Encoding UTF8 | ConvertFrom-Json
                $newObj   = $content | ConvertFrom-Json
                if (-not ($existing.PSObject.Properties.Name -contains "hooks")) {
                    $existing | Add-Member -MemberType NoteProperty -Name "hooks" -Value ([PSCustomObject]@{}) -Force
                }
                if (-not ($existing.hooks.PSObject.Properties.Name -contains "PreToolUse")) {
                    $existing.hooks | Add-Member -MemberType NoteProperty -Name "PreToolUse" -Value @() -Force
                }
                # 用名字或 statusMessage 去重
                $newPre  = @($newObj.hooks.PreToolUse)
                $oldPre  = @($existing.hooks.PreToolUse)
                $marker  = "[destructive-command-guard]"
                $kept    = @($oldPre | Where-Object {
                    $g = $_
                    $hasGuard = $false
                    if ($g.PSObject.Properties.Name -contains "hooks") {
                        foreach ($h in $g.hooks) {
                            if ($h.PSObject.Properties.Name -contains "statusMessage" `
                                -and $h.statusMessage -like "*$marker*") {
                                $hasGuard = $true; break
                            }
                        }
                    }
                    -not $hasGuard
                })
                $existing.hooks.PreToolUse = @($kept + $newPre)
                $json = $existing | ConvertTo-Json -Depth 20 -Compress
                $json = Format-Json $json 2
                Write-Utf8NoBomFile $jsonDstPath $json
                Write-Host "  + hooks.json (增量合并 PreToolUse)"
            } catch {
                Write-Warning "  现有 hooks.json 解析失败，改为覆盖：$($_.Exception.Message)"
                Write-Utf8NoBomFile $jsonDstPath $content
                Write-Host "  + hooks.json (已覆盖)"
            }
        } else {
            if (Test-Path $jsonDstPath) { Backup-File $jsonDstPath }
            Write-Utf8NoBomFile $jsonDstPath $content
            Write-Host "  + hooks.json (新建)"
        }
    }

    # 4) 确保 config.toml 启用 codex_hooks
    if ($configTomlPath -and (Test-Path $configTomlPath)) {
        $cfg = Get-Content $configTomlPath -Raw -Encoding UTF8
        if ($cfg -notmatch '(?m)^\s*codex_hooks\s*=\s*true\b') {
            Backup-File $configTomlPath
            if ($cfg -match '(?m)^\[features\]') {
                # 已有 [features] 段，缺 key
                $cfg = [regex]::Replace($cfg, '(?m)^\[features\]\s*$', "[features]`r`ncodex_hooks = true")
            } else {
                # 追加新段
                $cfg = $cfg.TrimEnd() + "`r`n`r`n[features]`r`ncodex_hooks = true`r`n"
            }
            Write-Utf8NoBomFile $configTomlPath $cfg
            Write-Host "  + config.toml (追加 [features] codex_hooks = true)"
        }
    }
}

function Merge-CodexConfig($srcPath, $dstPath, $uvPath, $feedbackPythonPath, $mcpDir) {
    if (-not (Test-Path $srcPath)) { return }
    $content = Get-Content $srcPath -Raw -Encoding UTF8
    $serverPath = Join-Path $mcpDir "server.py"
    $content = $content.Replace('__UV_PATH__', (Escape-JsonString $uvPath))
    $content = $content.Replace('__FEEDBACK_MCP_PYTHON__', (Escape-JsonString $feedbackPythonPath))
    $content = $content.Replace('__FEEDBACK_SERVER_PATH__', (Escape-JsonString $serverPath))

    $dstDir = Split-Path $dstPath -Parent
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }

    if ((Test-Path $dstPath) -and -not $Force) {
        # 增量模式：检查已有配置，追加缺失的 MCP 服务器
        Backup-File $dstPath
        $existing = Get-Content $dstPath -Raw -Encoding UTF8
        $serversToAdd = @()

        # 提取模板中的 MCP 服务器段落
        $blocks = [regex]::Split($content, '(?m)(?=^\[mcp_servers\.\w+\])')
        foreach ($block in $blocks) {
            $block = $block.Trim()
            if ($block -match '^\[mcp_servers\.(\w+)\]') {
                $serverName = $Matches[1]
                if (-not $existing.Contains("[mcp_servers.$serverName]")) {
                    $serversToAdd += $block
                }
            }
        }

        if ($serversToAdd.Count -gt 0) {
            $appendContent = "`n`n" + ($serversToAdd -join "`n`n") + "`n"
            $result = $existing.TrimEnd() + $appendContent
            Write-Utf8NoBomFile $dstPath $result
            Write-Host "  + config.toml (增量合并，追加 MCP 服务器)"
        } else {
            Write-Host "  + config.toml (MCP 服务器已存在，无需修改)"
        }
    } else {
        # 覆盖模式或目标不存在
        Backup-File $dstPath
        Write-Utf8NoBomFile $dstPath $content
        Write-Host "  + config.toml (已替换路径)"
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Cursor + VS Code Copilot + Codex 配置还原" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 显示模式
if ($Force) {
    Write-Host "[模式] 完全覆盖（-Force）" -ForegroundColor Red
} else {
    Write-Host "[模式] 增量合并（保留用户已有配置）" -ForegroundColor Green
}
if ($Target -notcontains "All") {
    Write-Host "[目标] 仅配置: $($Target -join ', ')" -ForegroundColor Cyan
}

# 显示检测结果
Write-Host "[IDE 检测]" -ForegroundColor Cyan
if ($hasVSCode) { Write-Host "  + VS Code" -ForegroundColor Green }
if ($hasCursor) { Write-Host "  + Cursor" -ForegroundColor Green }
if ($hasCodex)  { Write-Host "  + Codex" -ForegroundColor Green }
if (-not $hasVSCode -and -not $hasCursor -and -not $hasCodex) {
    if ($Target -notcontains "All") {
        Write-Host "  指定的 IDE 未安装，仍将安装配置（IDE 安装后即可使用）。" -ForegroundColor Yellow
        if ($Target -contains "VSCode") { $hasVSCode = $true }
        if ($Target -contains "Cursor") { $hasCursor = $true }
        if ($Target -contains "Codex")  { $hasCodex  = $true }
    } else {
        Write-Host "  未检测到任何 IDE，将安装所有配置（IDE 安装后即可使用）。" -ForegroundColor Yellow
        $hasVSCode = $true
        $hasCursor = $true
        $hasCodex  = $true
    }
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
if ($hasCodex)  { $totalSteps++ }
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

        # settings.json (始终合并)
        if (Test-Path $cursorSettSrc) {
            Merge-JsonSettings $cursorSettSrc $cursorSettDst
        }
    }
}

# ============================
# 还原 Codex 配置
# ============================
if ($hasCodex) {
    $step++
    Write-Host "[$step/$totalSteps] 还原 Codex 配置（AGENTS.md + skills + hooks）..." -ForegroundColor Green
    if (-not (Test-Path $codexSrc)) {
        Write-Warning "找不到源目录: $codexSrc，跳过。"
    } elseif ($DryRun) {
        Write-Host "  [DryRun] $codexAgentsSrc -> $codexAgentsDst"
        Write-Host "  [DryRun] $codexSkillsSrc -> $codexSkillsDst"
        Write-Host "  [DryRun] $codexHooksSrc  -> $codexHooksDst"
        Write-Host "  [DryRun] $codexHooksJsonSrc -> $codexHooksJsonDst"
    } else {
        if (-not (Test-Path $codexDst)) {
            New-Item -ItemType Directory -Path $codexDst -Force | Out-Null
        }
        # AGENTS.md
        if (Test-Path $codexAgentsSrc) {
            Backup-File $codexAgentsDst
            Copy-Item $codexAgentsSrc $codexAgentsDst -Force
            Write-Host "  + AGENTS.md"
        }
        # skills/  ← 与 cursor/skills、copilot/skills 同源（含安全护栏 skill）
        if (Test-Path $codexSkillsSrc) {
            if ($Force) {
                Copy-DirReplace $codexSkillsSrc $codexSkillsDst
                Write-Host "  + skills/ (覆盖)"
            } else {
                Copy-DirMerge $codexSkillsSrc $codexSkillsDst
                Write-Host "  + skills/ (增量)"
            }
        }
        # hooks/ + hooks.json + config.toml feature flag （硬兜底）
        $hookPython = Resolve-PythonForHooks
        Install-CodexHooks $codexHooksSrc $codexHooksDst $codexHooksJsonSrc $codexHooksJsonDst $hookPython $codexConfigDst
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
                $prevPref = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                try {
                    & git pull --ff-only 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "  git pull 失败（退出码 $LASTEXITCODE），使用本地已有版本继续"
                    }
                } finally {
                    $ErrorActionPreference = $prevPref
                    Pop-Location
                }
            } else {
                Write-Host "  未安装 git，跳过更新" -ForegroundColor Yellow
            }
        } else {
            if (Get-Command git -ErrorAction SilentlyContinue) {
                Write-Host "  正在克隆（使用 git）..."
                $prevPref = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                try {
                    & git clone https://github.com/rooney2020/qt-interactive-feedback-mcp.git $feedbackMcpDir 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "  git clone 失败（退出码 $LASTEXITCODE），请检查网络后手动克隆"
                    }
                } finally {
                    $ErrorActionPreference = $prevPref
                }
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
        if (-not $uvPath) {
            Write-Host "  未找到 uv，正在自动安装..." -ForegroundColor Yellow
            try {
                $installScript = Invoke-RestMethod https://astral.sh/uv/install.ps1
                $installScript | Invoke-Expression
                # 刷新 PATH
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
                $uvPath = Resolve-UvPath
                if ($uvPath) {
                    Write-Host "  + uv 安装成功: $uvPath"
                } else {
                    Write-Warning "  uv 安装后仍未找到，请手动检查"
                }
            } catch {
                Write-Warning "  uv 自动安装失败: $_"
                Write-Warning "  请手动安装: https://docs.astral.sh/uv/"
            }
        }
        if ($uvPath) {
            Write-Host "  正在运行 uv sync..."
            Push-Location $feedbackMcpDir
            $prevPref = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                & $uvPath sync 2>&1 | ForEach-Object { Write-Host "    $_" }
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "  uv sync 失败（退出码 $LASTEXITCODE），mcp.json 仍按预期路径生成"
                }
            } finally {
                $ErrorActionPreference = $prevPref
                Pop-Location
            }
            $feedbackPythonPath = Get-FeedbackPythonPath $feedbackMcpDir
            if ($feedbackPythonPath) {
                Write-Host "  + Interactive-Feedback-MCP 已就绪"
            } else {
                Write-Warning "  找不到反馈服务虚拟环境 Python: $feedbackMcpDir\.venv\Scripts\python.exe"
                Write-Warning "  请确认 uv sync 是否成功完成。"
            }
        } else {
            Write-Warning "  未找到 uv，请先安装: https://docs.astral.sh/uv/"
            Write-Warning "  然后手动执行: cd $feedbackMcpDir && uv sync"
        }

        # 始终生成 mcp.json（即使 MCP 安装失败，也用预期路径生成配置）
        if (-not $uvPath) { $uvPath = Join-Path $env:USERPROFILE ".local\bin\uv.exe" }
        if (-not $feedbackPythonPath) { $feedbackPythonPath = Join-Path $feedbackMcpDir ".venv\Scripts\python.exe" }
        if ($hasCursor) {
            $cursorMcpSrc = Join-Path $cursorSrc "mcp.json"
            Merge-McpJson $cursorMcpSrc (Join-Path $cursorDst "mcp.json") $uvPath $feedbackPythonPath $feedbackMcpDir "mcpServers"
        }
        if ($hasVSCode) {
            Merge-McpJson $vscodeMcpSrc $vscodeMcpDst $uvPath $feedbackPythonPath $feedbackMcpDir "servers"
        }
        if ($hasCodex) {
            Merge-CodexConfig $codexConfigSrc $codexConfigDst $uvPath $feedbackPythonPath $feedbackMcpDir
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
        @{ Name = "~/.cursor/skills/"; Path = (Join-Path $cursorDst "skills") }
    ) + $checks
}
if ($hasCodex) {
    $checks = @(
        @{ Name = "~/.codex/AGENTS.md"; Path = $codexAgentsDst },
        @{ Name = "~/.codex/config.toml"; Path = $codexConfigDst },
        @{ Name = "~/.codex/skills/"; Path = $codexSkillsDst },
        @{ Name = "~/.codex/skills/safety/destructive-command-guard/"; Path = (Join-Path $codexSkillsDst "safety\destructive-command-guard") },
        @{ Name = "~/.codex/hooks/pre_tool_use_guard.py"; Path = (Join-Path $codexHooksDst "pre_tool_use_guard.py") },
        @{ Name = "~/.codex/hooks.json"; Path = $codexHooksJsonDst }
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
if ($hasCodex)  { Write-Host "  3. 重启 VS Code Codex 扩展，验证 MCP 工具是否正常加载" }
Write-Host "  4. 如需其他 MCP（GitHub、Context7 等），在扩展商城中安装"