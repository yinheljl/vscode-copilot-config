<#
.SYNOPSIS
    还原 Cursor + VS Code GitHub Copilot + Codex + Claude 个人配置到当前机器

.DESCRIPTION
    自动检测已安装的 IDE（VS Code、Cursor、Codex、Claude），仅配置已安装的环境。
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
    - codex/hooks.json → ~/.codex/hooks.json（注册低噪音 dcg PreToolUse hook 到 Codex）
    - codex/hooks/ → ~/.codex/hooks/（dcg 轻量过滤器）
    - claude/CLAUDE.md → ~/.claude/CLAUDE.md（Claude）
    - claude/skills/ → ~/.claude/skills/（Claude Skills，含安全护栏 skill）
    - claude/hooks/ → ~/.claude/hooks/（dcg 轻量过滤器，Claude Code 硬层）
    - claude/hooks → ~/.claude/settings.json（注册低噪音 dcg PreToolUse hook 到 Claude Code）

.EXAMPLE
    .\restore.ps1                        # 增量模式（默认，不覆盖用户已有配置）
    .\restore.ps1 -Force                 # 完全覆盖模式
    .\restore.ps1 -DryRun                # 预览模式
    .\restore.ps1 -Target Codex          # 仅配置 Codex
    .\restore.ps1 -Target Claude         # 仅配置 Claude
    .\restore.ps1 -Target VSCode,Cursor  # 仅配置 VS Code 和 Cursor
    .\restore.ps1 -Target Codex -Force   # 仅覆盖 Codex 配置
    .\restore.ps1 -AutoInstallDcg        # 未装 dcg 时自动下载并校验上游 release，不再交互询问
    .\restore.ps1 -DisableDcgHooks       # 安装/检测 dcg，但关闭 Codex PreToolUse hook
    .\restore.ps1 -SkipDcg               # 跳过 dcg 安装，并关闭 Codex PreToolUse hook
#>
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$AutoInstallDcg,
    [switch]$DisableDcgHooks,
    [switch]$SkipDcg,
    [ValidateSet("All", "VSCode", "Cursor", "Codex", "Claude")]
    [string[]]$Target = @("All")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir       = $PSScriptRoot
$copilotSrc      = Join-Path $scriptDir "copilot"
$copilotDst      = Join-Path $env:USERPROFILE ".copilot"
$cursorSrc       = Join-Path $scriptDir "cursor"
$cursorDst       = Join-Path $env:USERPROFILE ".cursor"
$claudeSrc       = Join-Path $scriptDir "claude"
$claudeDst       = Join-Path $env:USERPROFILE ".claude"
$claudeConfigSrc  = Join-Path $claudeSrc "CLAUDE.md"
$claudeConfigDst  = Join-Path $claudeDst "CLAUDE.md"
$claudeSkillsSrc  = Join-Path $claudeSrc "skills"
$claudeSkillsDst  = Join-Path $claudeDst "skills"
$claudeHooksSrc   = Join-Path $claudeSrc "hooks"
$claudeHooksDst   = Join-Path $claudeDst "hooks"
$claudeSettingsDst = Join-Path $claudeDst "settings.json"
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

# ============================
# IDE 自动检测
# ============================
$vscodeUserDir = Join-Path $env:APPDATA "Code\User"
$cursorUserDir = Join-Path $env:APPDATA "Cursor\User"
$hasVSCode = (Test-Path $vscodeUserDir) -or [bool](Get-Command code -ErrorAction SilentlyContinue)
$hasCursor = (Test-Path $cursorUserDir) -or (Test-Path $cursorDst) -or [bool](Get-Command cursor -ErrorAction SilentlyContinue)
$hasCodex  = (Test-Path $codexDst) -or [bool](Get-Command codex -ErrorAction SilentlyContinue)
$hasClaude = (Test-Path $claudeDst) -or [bool](Get-Command claude -ErrorAction SilentlyContinue)

# ============================
# -Target 参数过滤
# ============================
if ($Target -notcontains "All") {
    if ($Target -notcontains "VSCode") { $hasVSCode = $false }
    if ($Target -notcontains "Cursor") { $hasCursor = $false }
    if ($Target -notcontains "Codex")  { $hasCodex  = $false }
    if ($Target -notcontains "Claude") { $hasClaude = $false }
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

function Remove-LegacyFeedbackServers($serversObj) {
    if (-not $serversObj) { return $false }
    $changed = $false
    foreach ($name in @("interactiveFeedback", "interactive-feedback")) {
        if ($serversObj.PSObject.Properties.Name -contains $name) {
            $serversObj.PSObject.Properties.Remove($name)
            $changed = $true
        }
    }
    return $changed
}

function Remove-LegacyFeedbackCodexBlocks([string]$toml) {
    return [regex]::Replace(
        $toml,
        '(?ms)^\[mcp_servers\.(?:interactiveFeedback|interactive-feedback)(?:\.[^\]]+)?\]\s*.*?(?=^\[|\z)',
        ''
    )
}

function Merge-McpJson($srcPath, $dstPath, $uvPath, $serverKey) {
    if (-not (Test-Path $srcPath)) { return }
    $content = Get-Content $srcPath -Raw -Encoding UTF8
    $content = $content.Replace('__UV_PATH__', (Escape-JsonString $uvPath))
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
            $removedLegacy = Remove-LegacyFeedbackServers $dstObj.$serverKey
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
            if ($removedLegacy) {
                Write-Host "  + mcp.json (增量合并，已移除旧 interactive-feedback 服务器)"
            } else {
                Write-Host "  + mcp.json (增量合并，保留已有服务器)"
            }
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
    $cmd = Get-Command uv -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
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

function Set-CodexHooksFeature($configTomlPath, [bool]$enabled) {
    $value = if ($enabled) { "true" } else { "false" }
    if (-not (Test-Path $configTomlPath)) {
        $dir = Split-Path $configTomlPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Write-Utf8NoBomFile $configTomlPath "[features]`r`ncodex_hooks = $value`r`n"
        Write-Host "    + config.toml 设置 [features] codex_hooks = $value"
        return
    }
    $cfg = Get-Content $configTomlPath -Raw -Encoding UTF8
    $newCfg = $cfg

    $m = [regex]::Match($newCfg, '(?m)^(\s*codex_hooks\s*=\s*)(true|false)\b')
    if ($m.Success) {
        $newCfg = $newCfg.Substring(0, $m.Index) + $m.Groups[1].Value + $value + $newCfg.Substring($m.Index + $m.Length)
    } elseif ($newCfg -match '(?m)^\[features\]\s*$') {
        $newCfg = [regex]::Replace($newCfg, '(?m)^\[features\]\s*$', "[features]`r`ncodex_hooks = $value", 1)
    } else {
        $newCfg = $newCfg.TrimEnd() + "`r`n`r`n[features]`r`ncodex_hooks = $value`r`n"
    }

    if ($newCfg -ne $cfg) {
        Backup-File $configTomlPath
        Write-Utf8NoBomFile $configTomlPath $newCfg
        Write-Host "    + config.toml 设置 [features] codex_hooks = $value"
    }
}

function Install-CodexHooks($jsonSrcPath, $jsonDstPath, $configTomlPath) {
    # 硬层防护使用社区方案 dcg（Dicklesworthstone/destructive_command_guard）。
    # 设计原则：
    #   1) Windows 上复刻官方 install.ps1 的下载 + SHA256 校验流程，避免 PS 5.1 兼容问题
    #   2) 不默默 irm|iex；首次安装需用户交互式确认（Y/N），或通过 -AutoInstallDcg 旗标显式同意
    #   3) Codex PreToolUse matcher 当前按 Bash 工具名触发；默认使用轻量过滤器，只在疑似高危命令时调用 dcg

    Write-Host "  Codex 硬层（破坏性命令防护 dcg）：" -ForegroundColor DarkCyan

    if ($SkipDcg) {
        Write-Host "    → -SkipDcg 已启用，跳过 dcg 全部步骤，并关闭 Codex hooks。软层 SKILL 仍生效。" -ForegroundColor DarkGray
        if ($DryRun) {
            Write-Host "    [DryRun] 将在 $configTomlPath 设置 codex_hooks = false" -ForegroundColor Yellow
        } else {
            Set-CodexHooksFeature $configTomlPath $false
        }
        return
    }

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
            Write-Host "    [DryRun] 将下载并校验上游 release，把 dcg.exe 安装到 ~/.local/bin/" -ForegroundColor Yellow
        } elseif ($AutoInstallDcg) {
            $shouldInstall = $true
            Write-Host "    -AutoInstallDcg 已启用，自动安装。" -ForegroundColor Cyan
        } elseif ([Console]::IsInputRedirected) {
            # 与 restore.sh 的 `[ -t 0 ]` 检测对齐：非交互式 stdin（CI / 管道）下默认不安装。
            # 同时兑现 codex/hooks/README.md 的承诺："非交互式 stdin（CI、管道）默认不会安装 dcg"。
            Write-Host "    （非交互式 stdin，未安装 dcg。下次加 -AutoInstallDcg 自动安装。）" -ForegroundColor DarkGray
        } else {
            Write-Host ""
            Write-Host "    将下载并校验上游 release 安装 dcg：" -ForegroundColor Cyan
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

    # Step 2: 用户显式关闭时，仅保留 dcg 二进制。
    if ($DisableDcgHooks) {
        Write-Host "    → -DisableDcgHooks 已启用：保留 dcg 二进制，但关闭 Codex PreToolUse hook。" -ForegroundColor DarkGray
        if ($DryRun) {
            Write-Host "    [DryRun] 将在 $configTomlPath 设置 codex_hooks = false" -ForegroundColor Yellow
        } else {
            Set-CodexHooksFeature $configTomlPath $false
        }
        return
    }

    # Step 3: 默认启用低噪音 hook，部署 hooks.json + 过滤器 + config.toml feature flag
    if (-not $alreadyInstalled) {
        Write-Host "    → dcg 未安装，无法启用 hooks.json。" -ForegroundColor DarkGray
        if (-not $DryRun) { Set-CodexHooksFeature $configTomlPath $false }
        return
    }
    if ($DryRun) {
        Write-Host "    [DryRun] $jsonSrcPath -> $jsonDstPath" -ForegroundColor Yellow
        Write-Host "    [DryRun] $codexHooksSrc -> $codexHooksDst" -ForegroundColor Yellow
        Write-Host "    [DryRun] 在 $configTomlPath 设置 [features] codex_hooks = true" -ForegroundColor Yellow
        return
    }
    if (Test-Path $codexHooksSrc) {
        if ($Force) {
            Copy-DirReplace $codexHooksSrc $codexHooksDst
            Write-Host "    + ~/.codex/hooks/（覆盖，低噪音 dcg 过滤器）"
        } else {
            Copy-DirMerge $codexHooksSrc $codexHooksDst
            Write-Host "    + ~/.codex/hooks/（增量，低噪音 dcg 过滤器）"
        }
    }
    if (Test-Path $jsonSrcPath) {
        $dstDir = Split-Path $jsonDstPath -Parent
        if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
        if ((Test-Path $jsonDstPath) -and -not $Force) {
            Backup-File $jsonDstPath
        }
        $hookScript = Join-Path $codexHooksDst "dcg_filter.ps1"
        $hookCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File ""$hookScript"""
        $hookJson = Get-Content $jsonSrcPath -Raw -Encoding UTF8
        $hookJson = $hookJson.Replace('__DCG_HOOK_COMMAND__', (Escape-JsonString $hookCommand))
        Write-Utf8NoBomFile $jsonDstPath $hookJson
        Write-Host "    + ~/.codex/hooks.json（低噪音过滤器 → dcg）"
    }
    Set-CodexHooksFeature $configTomlPath $true
}

function Merge-CodexConfig($srcPath, $dstPath, $uvPath) {
    if (-not (Test-Path $srcPath)) { return }
    $content = Get-Content $srcPath -Raw -Encoding UTF8
    $content = $content.Replace('__UV_PATH__', (Escape-JsonString $uvPath))

    $dstDir = Split-Path $dstPath -Parent
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }

    if ((Test-Path $dstPath) -and -not $Force) {
        # 增量模式：检查已有配置，追加缺失的 MCP 服务器
        Backup-File $dstPath
        $existingOriginal = Get-Content $dstPath -Raw -Encoding UTF8
        $existing = Remove-LegacyFeedbackCodexBlocks $existingOriginal
        $removedLegacy = ($existing -ne $existingOriginal)
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

        if ($serversToAdd.Count -gt 0 -or $removedLegacy) {
            $result = $existing.TrimEnd()
            if ($serversToAdd.Count -gt 0) {
                $result = $result + "`n`n" + ($serversToAdd -join "`n`n")
            }
            $result = $result.TrimEnd() + "`n"
            Write-Utf8NoBomFile $dstPath $result
            if ($removedLegacy) {
                Write-Host "  + config.toml (增量合并，已移除旧 interactiveFeedback 服务器)"
            } else {
                Write-Host "  + config.toml (增量合并，追加 MCP 服务器)"
            }
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

function Install-ClaudeHooks($settingsDstPath) {
    if (-not (Test-DcgInstalled)) {
        Write-Host "    → dcg 未安装，跳过 Claude Code PreToolUse hook。" -ForegroundColor DarkGray
        return
    }

    if ($DryRun) {
        Write-Host "    [DryRun] $claudeHooksSrc -> $claudeHooksDst" -ForegroundColor Yellow
        Write-Host "    [DryRun] 向 $settingsDstPath 写入 dcg PreToolUse hook" -ForegroundColor Yellow
        return
    }

    # 1. 部署 claude/hooks/ → ~/.claude/hooks/
    if (Test-Path $claudeHooksSrc) {
        if ($Force) {
            Copy-DirReplace $claudeHooksSrc $claudeHooksDst
            Write-Host "    + ~/.claude/hooks/（覆盖，低噪音 dcg 过滤器）"
        } else {
            Copy-DirMerge $claudeHooksSrc $claudeHooksDst
            Write-Host "    + ~/.claude/hooks/（增量，低噪音 dcg 过滤器）"
        }
    }

    # 2. 合并 hooks.PreToolUse 条目到 ~/.claude/settings.json
    $dcgScriptPath = Join-Path $claudeHooksDst "dcg_filter.ps1"
    $hookCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$dcgScriptPath`""
    $newGroup = [PSCustomObject]@{
        matcher = "Bash"
        hooks   = @([PSCustomObject]@{
            type    = "command"
            command = $hookCmd
            timeout = 10
        })
    }

    if (-not (Test-Path $settingsDstPath)) {
        $obj = [PSCustomObject]@{
            hooks = [PSCustomObject]@{ PreToolUse = @($newGroup) }
        }
        $dstDir = Split-Path $settingsDstPath -Parent
        if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
        Write-Utf8NoBomFile $settingsDstPath (Format-Json ($obj | ConvertTo-Json -Depth 10) 2)
        Write-Host "    + ~/.claude/settings.json（新建，写入 dcg PreToolUse hook）"
        return
    }

    Backup-File $settingsDstPath
    $raw = Get-Content $settingsDstPath -Raw -Encoding UTF8
    try {
        $cfg = ConvertFrom-Jsonc $raw
    } catch {
        Write-Warning "  现有 settings.json 解析失败（含语法错误），跳过追加: $settingsDstPath"
        return
    }

    # 检查是否已存在 dcg hook
    $hasDcg = $false
    if ($cfg.PSObject.Properties.Name -contains "hooks") {
        if ($cfg.hooks -and ($cfg.hooks.PSObject.Properties.Name -contains "PreToolUse")) {
            foreach ($g in @($cfg.hooks.PreToolUse)) {
                if (-not $g.hooks) { continue }
                foreach ($h in @($g.hooks)) {
                    if ($h.command -like "*dcg_filter*") { $hasDcg = $true; break }
                }
                if ($hasDcg) { break }
            }
        }
    }

    if ($hasDcg -and -not $Force) {
        Write-Host "    + ~/.claude/settings.json（dcg hook 已存在，未修改）"
        return
    }

    if (-not ($cfg.PSObject.Properties.Name -contains "hooks")) {
        $cfg | Add-Member -MemberType NoteProperty -Name "hooks" -Value ([PSCustomObject]@{}) -Force
    }
    if (-not ($cfg.hooks.PSObject.Properties["PreToolUse"])) {
        $cfg.hooks | Add-Member -MemberType NoteProperty -Name "PreToolUse" -Value @() -Force
    }

    if ($Force -and $hasDcg) {
        # -Force 时替换旧 dcg 条目
        $kept = @($cfg.hooks.PreToolUse | Where-Object {
            $isDcg = $false
            foreach ($h in @($_.hooks)) { if ($h.command -like "*dcg_filter*") { $isDcg = $true; break } }
            -not $isDcg
        })
        $cfg.hooks.PreToolUse = $kept + @($newGroup)
    } else {
        $cfg.hooks.PreToolUse = @($cfg.hooks.PreToolUse) + @($newGroup)
    }

    Write-Utf8NoBomFile $settingsDstPath (Format-Json ($cfg | ConvertTo-Json -Depth 20) 2)
    Write-Host "    + ~/.claude/settings.json（已写入 dcg PreToolUse hook）"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Cursor + VS Code Copilot + Codex + Claude 配置还原" -ForegroundColor Cyan
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
if ($hasClaude) { Write-Host "  + Claude" -ForegroundColor Green }
if (-not $hasVSCode -and -not $hasCursor -and -not $hasCodex -and -not $hasClaude) {
    if ($Target -notcontains "All") {
        Write-Host "  指定的 IDE 未安装，仍将安装配置（IDE 安装后即可使用）。" -ForegroundColor Yellow
        if ($Target -contains "VSCode") { $hasVSCode = $true }
        if ($Target -contains "Cursor") { $hasCursor = $true }
        if ($Target -contains "Codex")  { $hasCodex  = $true }
        if ($Target -contains "Claude") { $hasClaude = $true }
    } else {
        Write-Host "  未检测到任何 IDE，将安装所有配置（IDE 安装后即可使用）。" -ForegroundColor Yellow
        $hasVSCode = $true
        $hasCursor = $true
        $hasCodex  = $true
        $hasClaude = $true
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
if ($hasClaude) { $totalSteps++ }
$hasMcpTargets = $hasVSCode -or $hasCursor -or $hasCodex
if ($hasMcpTargets) { $totalSteps++ }
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
    Write-Host "[$step/$totalSteps] 还原 Codex 配置（AGENTS.md + skills + 低噪音 hooks）..." -ForegroundColor Green
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
        # skills/  ← 与 cursor/skills、copilot/skills、claude/skills 技能内容同源（含安全护栏 skill）
        if (Test-Path $codexSkillsSrc) {
            if ($Force) {
                Copy-DirReplace $codexSkillsSrc $codexSkillsDst
                Write-Host "  + skills/ (覆盖)"
            } else {
                Copy-DirMerge $codexSkillsSrc $codexSkillsDst
                Write-Host "  + skills/ (增量)"
            }
        }
        # hooks.json（低噪音硬兜底，使用社区方案 dcg）
        Install-CodexHooks $codexHooksJsonSrc $codexHooksJsonDst $codexConfigDst
    }
}

# ============================
# 还原 Claude 配置
# ============================
if ($hasClaude) {
    $step++
    Write-Host "[$step/$totalSteps] 还原 Claude 配置（CLAUDE.md + skills + 低噪音 hooks）..." -ForegroundColor Green
    if (-not (Test-Path $claudeSrc)) {
        Write-Warning "找不到源目录: $claudeSrc，跳过。"
    } elseif ($DryRun) {
        Write-Host "  [DryRun] $claudeConfigSrc -> $claudeConfigDst"
        Write-Host "  [DryRun] $claudeSkillsSrc -> $claudeSkillsDst"
        Install-ClaudeHooks $claudeSettingsDst
    } else {
        if (-not (Test-Path $claudeDst)) {
            New-Item -ItemType Directory -Path $claudeDst -Force | Out-Null
        }
        if (Test-Path $claudeConfigSrc) {
            Backup-File $claudeConfigDst
            Copy-Item $claudeConfigSrc $claudeConfigDst -Force
            Write-Host "  + CLAUDE.md"
        }
        if (Test-Path $claudeSkillsSrc) {
            if ($Force) {
                Copy-DirReplace $claudeSkillsSrc $claudeSkillsDst
                Write-Host "  + skills/ (覆盖)"
            } else {
                Copy-DirMerge $claudeSkillsSrc $claudeSkillsDst
                Write-Host "  + skills/ (增量)"
            }
        }
        # hooks（低噪音硬兜底，使用社区方案 dcg）
        Install-ClaudeHooks $claudeSettingsDst
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
# 生成 MCP 配置
# ============================
if ($hasMcpTargets) {
    $step++
    Write-Host "[$step/$totalSteps] 配置 MCP 服务器..." -ForegroundColor Green
    if ($DryRun) {
        Write-Host "  [DryRun] 将生成 VS Code / Cursor / Codex MCP 配置"
    } else {
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
        if (-not $uvPath) {
            Write-Warning "  未找到 uv，请先安装: https://docs.astral.sh/uv/"
        }

        if (-not $uvPath) { $uvPath = Join-Path $env:USERPROFILE ".local\bin\uv.exe" }
        if ($hasCursor) {
            $cursorMcpSrc = Join-Path $cursorSrc "mcp.json"
            Merge-McpJson $cursorMcpSrc (Join-Path $cursorDst "mcp.json") $uvPath "mcpServers"
        }
        if ($hasVSCode) {
            Merge-McpJson $vscodeMcpSrc $vscodeMcpDst $uvPath "servers"
        }
        if ($hasCodex) {
            Merge-CodexConfig $codexConfigSrc $codexConfigDst $uvPath
        }
    }
}

# ============================
# 验证
# ============================
$step++
Write-Host "[$step/$totalSteps] 验证..." -ForegroundColor Green
$checks = @()
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
        @{ Name = "~/.codex/skills/destructive-command-guard/"; Path = (Join-Path $codexSkillsDst "destructive-command-guard") }
    ) + $checks
}
if ($hasClaude) {
    $checks = @(
        @{ Name = "~/.claude/CLAUDE.md"; Path = $claudeConfigDst },
        @{ Name = "~/.claude/skills/"; Path = $claudeSkillsDst },
        @{ Name = "~/.claude/skills/destructive-command-guard/"; Path = (Join-Path $claudeSkillsDst "destructive-command-guard") },
        @{ Name = "~/.claude/hooks/"; Path = $claudeHooksDst }
    ) + $checks
}
foreach ($c in $checks) {
    if (Test-Path $c.Path) {
        Write-Host "  + $($c.Name)" -ForegroundColor Green
    } else {
        Write-Host "  - $($c.Name) (未找到)" -ForegroundColor Red
    }
}

# dcg 二进制独立检查（未安装时软层 SKILL 仍生效）
if ($hasCodex -and -not $SkipDcg) {
    if (Test-DcgInstalled) {
        Write-Host "  + dcg 二进制（社区方案 destructive_command_guard）" -ForegroundColor Green
    } else {
        Write-Host "  ~ dcg 未安装（硬层未启用；软层 SKILL 仍生效）" -ForegroundColor Yellow
    }
    if ($DisableDcgHooks) {
        Write-Host "  + Codex dcg hook 已按参数关闭" -ForegroundColor Yellow
    } else {
        if (Test-Path $codexHooksJsonDst) {
            Write-Host "  + Codex dcg hook（默认启用，低噪音过滤器）" -ForegroundColor Green
        } else {
            Write-Host "  - Codex dcg hook（默认启用但 hooks.json 未找到）" -ForegroundColor Red
        }
    }
}
if ($hasClaude -and -not $SkipDcg) {
    if (Test-DcgInstalled) {
        Write-Host "  + dcg 二进制（Claude Code 硬层已启用）" -ForegroundColor Green
    } else {
        Write-Host "  ~ dcg 未安装（Claude Code 硬层未启用；软层 SKILL 仍生效）" -ForegroundColor Yellow
    }
    if (Test-Path $claudeHooksDst) {
        Write-Host "  + Claude Code dcg hook（低噪音过滤器）" -ForegroundColor Green
    } else {
        Write-Host "  ~ Claude Code dcg hook（hooks/ 未找到）" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  还原完成！" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "后续步骤：" -ForegroundColor Yellow
if ($hasVSCode) { Write-Host "  - 重启 VS Code" }
if ($hasCursor) { Write-Host "  - 重启 Cursor，验证 MCP Server 是否正常加载" }
if ($hasCodex)  { Write-Host "  - 重启 VS Code Codex 扩展，验证 MCP 工具是否正常加载" }
if ($hasClaude) { Write-Host "  - 重启 Claude Code" }
Write-Host "  - 如需其他 MCP（GitHub、Context7 等），在扩展商城中安装"
