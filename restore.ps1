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
    .\restore.ps1 -AutoInstallDcg        # 未装 dcg 时直接调用官方 install.ps1，不再交互询问
    .\restore.ps1 -SkipDcg               # 跳过 dcg 安装与硬层 hook 部署
#>
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$SkipFeedbackMCP,
    [switch]$AutoInstallDcg,
    [switch]$SkipDcg,
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

function Test-DcgInstalled {
    if (Get-Command dcg -ErrorAction SilentlyContinue) { return $true }
    if (Get-Command dcg.exe -ErrorAction SilentlyContinue) { return $true }
    $defaultBin = Join-Path $env:USERPROFILE ".local\bin\dcg.exe"
    if (Test-Path $defaultBin) { return $true }
    return $false
}

function Test-WindowsHost {
    # 兼容 PS 5.1（无 $IsWindows 自动变量）和 PS 7+
    if ($env:OS -eq 'Windows_NT') { return $true }
    $v = Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $v -and $v) { return $true }
    return $false
}

function Get-WebString([string]$url) {
    # PS 5.1 与 PS 7 兼容：拉远端文本。-UseBasicParsing 在 PS 5.1 下 .Content 可能是 byte[]。
    $wr = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
    $content = $wr.Content
    if ($content -is [byte[]]) {
        return [System.Text.Encoding]::UTF8.GetString($content)
    }
    return [string]$content
}

function Invoke-DcgInstaller {
    # 复刻 dcg 官方 install.ps1 的核心步骤（PS 5.1 兼容）：
    #   1. GitHub API 解析最新 release tag
    #   2. 下载 dcg-x86_64-pc-windows-msvc.zip
    #   3. 用上游 .sha256 文件校验（信任链与官方一致）
    #   4. 解压 → 复制到 ~/.local/bin/dcg.exe
    #   5. 把 ~/.local/bin 加到用户 PATH
    # 之所以不直接调用上游 install.ps1：在 Windows PowerShell 5.1 下 -UseBasicParsing 返回 byte[]
    # 导致上游 .Content.Trim() 抛 "Checksum file not found"。本仓库只是"复刻流程"，
    # 真正的信任锚点（GitHub release zip 与上游 .sha256）完全没变。
    $owner = "Dicklesworthstone"
    $repo  = "destructive_command_guard"
    $target = "x86_64-pc-windows-msvc"
    $userBin = Join-Path $env:USERPROFILE ".local\bin"

    if (-not [Environment]::Is64BitOperatingSystem) {
        Write-Warning "    当前不是 64-bit Windows，dcg 不支持。"
        return $false
    }

    # Step 1: 解析最新版本
    Write-Host "    → 查询最新 release..." -ForegroundColor DarkGray
    $version = $null
    try {
        $json = Get-WebString "https://api.github.com/repos/$owner/$repo/releases/latest"
        $rel = $json | ConvertFrom-Json
        $version = $rel.tag_name
    } catch {
        Write-Warning "    GitHub API 调用失败: $_"
        return $false
    }
    if (-not $version) {
        Write-Warning "    无法解析最新 release tag。"
        return $false
    }
    Write-Host "    → 最新版本: $version" -ForegroundColor DarkGray

    $zipName = "dcg-$target.zip"
    $zipUrl  = "https://github.com/$owner/$repo/releases/download/$version/$zipName"
    $shaUrl  = "$zipUrl.sha256"

    $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) "dcg_install_$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
    $zipPath = Join-Path $tmpRoot $zipName

    try {
        # Step 2: 下载 zip
        Write-Host "    → 下载: $zipUrl" -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop

        # Step 3: 校验 SHA256
        Write-Host "    → 拉取上游 .sha256 并校验..." -ForegroundColor DarkGray
        $shaText = Get-WebString $shaUrl
        $expected = ($shaText -split '\s+')[0].Trim().ToLower()
        if (-not $expected -or $expected.Length -ne 64) {
            Write-Warning "    上游 .sha256 内容异常: '$shaText'"
            return $false
        }
        $actual = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
        if ($actual -ne $expected) {
            Write-Warning "    SHA256 不匹配！expected=$expected actual=$actual"
            return $false
        }
        Write-Host "    ✓ SHA256 校验通过 ($expected)" -ForegroundColor Green

        # Step 4: 解压并安装
        Write-Host "    → 解压并复制到 $userBin\dcg.exe" -ForegroundColor DarkGray
        $extractDir = Join-Path $tmpRoot "extract"
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractDir)
        $bin = Get-ChildItem -Path $extractDir -Recurse -Filter "dcg.exe" | Select-Object -First 1
        if (-not $bin) {
            Write-Warning "    zip 内未找到 dcg.exe"
            return $false
        }
        if (-not (Test-Path $userBin)) { New-Item -ItemType Directory -Path $userBin -Force | Out-Null }
        Copy-Item $bin.FullName (Join-Path $userBin "dcg.exe") -Force

        # Step 5: 加 PATH（持久化到 User scope）
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if (-not $userPath) { $userPath = "" }
        if ($userPath -notlike "*$userBin*") {
            $newPath = if ($userPath) { "$userPath;$userBin" } else { $userBin }
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            Write-Host "    ✓ 已把 $userBin 加入用户 PATH" -ForegroundColor Green
        }
        # 当前 session 也立即可用
        if ($env:PATH -notlike "*$userBin*") { $env:PATH = "$env:PATH;$userBin" }
        return $true
    } catch {
        Write-Warning "    安装失败: $_"
        return $false
    } finally {
        Remove-Item $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-CodexHooks($jsonSrcPath, $jsonDstPath, $configTomlPath) {
    # 硬层防护使用社区方案 dcg（Dicklesworthstone/destructive_command_guard）。
    # 设计原则：
    #   1) 调用官方 install.ps1，不自己实现下载/SHA256/cosign 校验逻辑（责任清晰：出问题归上游）
    #   2) 不默默 irm|iex；首次安装需用户交互式确认（Y/N），或通过 -AutoInstallDcg 旗标显式同意
    #   3) Codex 官方文档当前明确："Hooks are currently disabled on Windows"
    #      （https://developers.openai.com/codex/hooks）—— 但 dcg.exe 仍然有用：
    #         · 命令行工具：dcg test "rm -rf /"
    #         · 同时被 Cursor / Claude Code / Copilot CLI 等其他 agent 调用
    #         · 未来 Codex 在 Windows 解禁时立即生效
    #      所以本函数在 Windows 上仍然装 dcg.exe，只跳过 ~/.codex/hooks.json 的部署

    Write-Host "  Codex 硬层（破坏性命令防护 dcg）：" -ForegroundColor DarkCyan

    if ($SkipDcg) {
        Write-Host "    → -SkipDcg 已启用，跳过 dcg 全部步骤。软层 SKILL 仍生效。" -ForegroundColor DarkGray
        return
    }

    $isWindowsHost = Test-WindowsHost

    # Step 1: 检测 dcg
    $alreadyInstalled = Test-DcgInstalled
    if ($alreadyInstalled) {
        $verLine = ""
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        try {
            $rawOut = (& dcg --version 2>&1 | Out-String)
            $m = [regex]::Match($rawOut, 'v\d+\.\d+\.\d+(?:[-+][\w\.\-]+)?')
            if ($m.Success) { $verLine = $m.Value }
        } catch {} finally {
            $ErrorActionPreference = $prevPref
        }
        if (-not $verLine) { $verLine = "(已安装)" }
        Write-Host "    ✓ 已检测到 dcg：$verLine" -ForegroundColor Green
    } else {
        Write-Host "    × 未检测到 dcg（社区方案 destructive_command_guard）" -ForegroundColor Yellow

        $shouldInstall = $false
        if ($DryRun) {
            Write-Host "    [DryRun] 将调用官方 install.ps1 下载 dcg.exe 到 ~/.local/bin/" -ForegroundColor Yellow
        } elseif ($AutoInstallDcg) {
            $shouldInstall = $true
            Write-Host "    -AutoInstallDcg 已启用，自动安装。" -ForegroundColor Cyan
        } else {
            Write-Host ""
            Write-Host "    将通过官方 install.ps1 安装 dcg：" -ForegroundColor Cyan
            Write-Host "      源:    https://github.com/Dicklesworthstone/destructive_command_guard"
            Write-Host "      安装到: $env:USERPROFILE\.local\bin\dcg.exe"
            Write-Host "      校验:   官方安装器内置 SHA256（强制） + cosign（如果你装了）"
            $resp = Read-Host "    是否安装 dcg？[y/N]"
            if ($resp -match '^(y|Y|yes|YES)$') { $shouldInstall = $true }
        }

        if ($shouldInstall) {
            if (Invoke-DcgInstaller) {
                Start-Sleep -Milliseconds 200
                $alreadyInstalled = Test-DcgInstalled
                if ($alreadyInstalled) {
                    Write-Host "    ✓ dcg 安装成功" -ForegroundColor Green
                } else {
                    Write-Warning "    安装脚本结束但仍找不到 dcg，请手动确认 PATH 是否包含 $env:USERPROFILE\.local\bin"
                }
            }
        } elseif (-not $DryRun) {
            Write-Host "    → 跳过 dcg 安装。软层 SKILL 仍生效；如需启用硬层，重跑 -AutoInstallDcg。" -ForegroundColor DarkGray
        }
    }

    # Step 2: Windows 上跳过 hooks.json 部署
    if ($isWindowsHost) {
        Write-Host ""
        Write-Warning "    ⚠ Codex 官方文档：'Hooks are currently disabled on Windows'（https://developers.openai.com/codex/hooks）"
        Write-Warning "      → 不部署 ~/.codex/hooks.json（避免误导你以为有保护）。"
        if ($alreadyInstalled) {
            Write-Host "      但 dcg.exe 仍可独立使用：" -ForegroundColor DarkGray
            Write-Host "        · 命令行测试：dcg test ""rm -rf /""" -ForegroundColor DarkGray
            Write-Host "        · Cursor / Claude Code / Copilot CLI 等其他 agent 仍可调用" -ForegroundColor DarkGray
            Write-Host "        · OpenAI 解禁 Windows hook 后将自动生效" -ForegroundColor DarkGray
        }
        return
    }

    # Step 3: 非 Windows，部署 hooks.json + config.toml feature flag
    if (-not $alreadyInstalled) {
        Write-Host "    → dcg 未安装，跳过 hooks.json 部署。" -ForegroundColor DarkGray
        return
    }
    if ($DryRun) {
        Write-Host "    [DryRun] $jsonSrcPath -> $jsonDstPath" -ForegroundColor Yellow
        Write-Host "    [DryRun] 在 $configTomlPath 追加 [features] codex_hooks = true" -ForegroundColor Yellow
        return
    }
    if (Test-Path $jsonSrcPath) {
        $dstDir = Split-Path $jsonDstPath -Parent
        if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
        if ((Test-Path $jsonDstPath) -and -not $Force) {
            Backup-File $jsonDstPath
        }
        Copy-Item $jsonSrcPath $jsonDstPath -Force
        Write-Host "    + ~/.codex/hooks.json（指向 dcg）"
    }
    if (Test-Path $configTomlPath) {
        $cfg = Get-Content $configTomlPath -Raw -Encoding UTF8
        if ($cfg -notmatch '(?m)^\s*codex_hooks\s*=\s*true\b') {
            Backup-File $configTomlPath
            if ($cfg -match '(?m)^\[features\]\s*$') {
                $cfg = [regex]::Replace($cfg, '(?m)^\[features\]\s*$', "[features]`r`ncodex_hooks = true", 1)
            } else {
                $cfg = $cfg.TrimEnd() + "`r`n`r`n[features]`r`ncodex_hooks = true`r`n"
            }
            Write-Utf8NoBomFile $configTomlPath $cfg
            Write-Host "    + config.toml 启用 [features] codex_hooks = true"
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
        # Install-CodexHooks 在 DryRun 下也会被调用，由它自己打印更精确的预览
        Install-CodexHooks $codexHooksJsonSrc $codexHooksJsonDst $codexConfigDst
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
        # hooks.json（硬兜底，使用社区方案 dcg；Windows 上自动跳过）
        Install-CodexHooks $codexHooksJsonSrc $codexHooksJsonDst $codexConfigDst
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
        @{ Name = "~/.codex/skills/safety/destructive-command-guard/"; Path = (Join-Path $codexSkillsDst "safety\destructive-command-guard") }
    ) + $checks
}
foreach ($c in $checks) {
    if (Test-Path $c.Path) {
        Write-Host "  + $($c.Name)" -ForegroundColor Green
    } else {
        Write-Host "  - $($c.Name) (未找到)" -ForegroundColor Red
    }
}

# dcg 二进制独立检查（不强制要求；Windows 上 Codex 暂不调用 hook，但 dcg.exe 作为 CLI 工具仍可用）
if ($hasCodex -and -not $SkipDcg) {
    if (Test-DcgInstalled) {
        Write-Host "  + dcg 二进制（社区方案 destructive_command_guard）" -ForegroundColor Green
    } else {
        Write-Host "  ~ dcg 未安装（硬层未启用；软层 SKILL 仍生效）" -ForegroundColor Yellow
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