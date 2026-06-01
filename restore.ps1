<#
.SYNOPSIS
    Restore Codex global configuration from this repository.

.DESCRIPTION
    Installs the Codex-only assets managed by this repository:
    - codex/AGENTS.md -> ~/.codex/AGENTS.md
    - codex/skills/ -> ~/.codex/skills/
    - codex/config.toml -> merged into ~/.codex/config.toml
    - codex/hooks.json and codex/hooks/ -> ~/.codex/ when dcg hooks are enabled

.EXAMPLE
    .\restore.ps1
    .\restore.ps1 -DryRun
    .\restore.ps1 -Force
    .\restore.ps1 -AutoInstallDcg
    .\restore.ps1 -SkipDcg
#>
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$AutoInstallDcg,
    [switch]$DisableDcgHooks,
    [switch]$SkipDcg
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$codexSrc = Join-Path $repoDir "codex"
$codexDst = Join-Path $env:USERPROFILE ".codex"

$agentsSrc = Join-Path $codexSrc "AGENTS.md"
$agentsDst = Join-Path $codexDst "AGENTS.md"
$skillsSrc = Join-Path $codexSrc "skills"
$skillsDst = Join-Path $codexDst "skills"
$configSrc = Join-Path $codexSrc "config.toml"
$configDst = Join-Path $codexDst "config.toml"
$hooksSrc = Join-Path $codexSrc "hooks"
$hooksDst = Join-Path $codexDst "hooks"
$hooksJsonSrc = Join-Path $codexSrc "hooks.json"
$hooksJsonDst = Join-Path $codexDst "hooks.json"

function Write-Utf8NoBomFile([string]$Path, [string]$Content) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Escape-TomlString([string]$Value) {
    return $Value.Replace('\', '\\').Replace('"', '\"')
}

function Escape-JsonString([string]$Value) {
    return $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n')
}

function Backup-File([string]$Path) {
    if ((Test-Path $Path) -and -not $Force) {
        $backup = "$Path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $Path $backup -Force
        Write-Host "  backup: $backup"
    }
}

function Copy-DirMerge([string]$Src, [string]$Dst) {
    if (-not (Test-Path $Dst)) {
        New-Item -ItemType Directory -Path $Dst -Force | Out-Null
    }
    Copy-Item (Join-Path $Src '*') $Dst -Recurse -Force
}

function Copy-DirReplace([string]$Src, [string]$Dst) {
    if (Test-Path $Dst) {
        Remove-Item $Dst -Recurse -Force
    }
    Copy-Item $Src $Dst -Recurse -Force
}

function Resolve-UvPath {
    $candidates = @(
        (Join-Path $env:USERPROFILE ".local\bin\uv.exe"),
        (Join-Path $env:USERPROFILE ".cargo\bin\uv.exe")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    $cmd = Get-Command uv -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Install-UvIfMissing {
    $uv = Resolve-UvPath
    if ($uv) { return $uv }

    Write-Host "  uv not found; installing uv for markitdown MCP..." -ForegroundColor Yellow
    if ($DryRun) {
        return (Join-Path $env:USERPROFILE ".local\bin\uv.exe")
    }

    try {
        $installScript = Invoke-RestMethod "https://astral.sh/uv/install.ps1"
        Invoke-Expression $installScript
    } catch {
        Write-Warning "uv install failed: $($_.Exception.Message)"
    }

    $uv = Resolve-UvPath
    if (-not $uv) {
        Write-Warning "uv is still unavailable. markitdown MCP will be configured with the default user path."
        $uv = Join-Path $env:USERPROFILE ".local\bin\uv.exe"
    }
    return $uv
}

function Resolve-DcgPath {
    $cmd = Get-Command dcg -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $cmd = Get-Command dcg.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidate = Join-Path $env:USERPROFILE ".local\bin\dcg.exe"
    if (Test-Path $candidate) { return $candidate }
    return $null
}

function Install-DcgIfRequested {
    if ($SkipDcg) {
        Write-Host "  dcg skipped; Codex hooks will be disabled."
        return $false
    }

    $dcg = Resolve-DcgPath
    if ($dcg) {
        Write-Host "  dcg found: $dcg"
        return $true
    }

    $shouldInstall = $false
    if ($AutoInstallDcg) {
        $shouldInstall = $true
    } elseif (-not $DryRun) {
        try {
            $answer = Read-Host "  dcg is not installed. Install it now? [y/N]"
            $shouldInstall = $answer -match '^(y|yes)$'
        } catch {
            $shouldInstall = $false
        }
    }

    if (-not $shouldInstall) {
        Write-Host "  dcg not installed; soft skill still applies, hard hook disabled."
        return $false
    }

    if ($DryRun) {
        Write-Host "  [DryRun] would install dcg from upstream installer."
        return $true
    }

    try {
        $url = "https://raw.githubusercontent.com/Dicklesworthstone/destructive_command_guard/main/install.ps1?$(Get-Date -Format yyyyMMddHHmmss)"
        $installScript = Invoke-RestMethod $url
        Invoke-Expression $installScript
    } catch {
        Write-Warning "dcg install failed: $($_.Exception.Message)"
    }

    return [bool](Resolve-DcgPath)
}

function Set-HooksFeature([string]$Content, [bool]$Enabled) {
    $value = if ($Enabled) { "true" } else { "false" }
    $pattern = '(?ms)^\[features\]\s*\r?\n.*?(?=^\[|\z)'
    $match = [regex]::Match($Content, $pattern)

    if ($match.Success) {
        $section = $match.Value
        if ($section -match '(?m)^\s*hooks\s*=') {
            $section = [regex]::Replace($section, '(?m)^(\s*hooks\s*=\s*)(true|false)', "`${1}$value", 1)
        } else {
            $section = $section.TrimEnd() + "`r`nhooks = $value`r`n"
        }
        return $Content.Remove($match.Index, $match.Length).Insert($match.Index, $section)
    }

    return $Content.TrimEnd() + "`r`n`r`n[features]`r`nhooks = $value`r`n"
}

function Upsert-MarkitdownMcp([string]$Content, [string]$UvPath) {
    $escapedUv = Escape-TomlString $UvPath
    $block = @"
[mcp_servers.markitdown]
command = "$escapedUv"
args = ["tool", "run", "markitdown-mcp"]
"@
    $withoutOld = [regex]::Replace($Content, '(?ms)^\[mcp_servers\.markitdown\]\s*\r?\n.*?(?=^\[|\z)', '').TrimEnd()
    return $withoutOld + "`r`n`r`n" + $block + "`r`n"
}

function Update-CodexConfig([string]$UvPath, [bool]$HooksEnabled) {
    if ($DryRun) {
        Write-Host "  [DryRun] would merge $configSrc -> $configDst"
        return
    }

    if (-not (Test-Path $codexDst)) {
        New-Item -ItemType Directory -Path $codexDst -Force | Out-Null
    }

    if ((Test-Path $configDst) -and -not $Force) {
        Backup-File $configDst
        $content = Get-Content $configDst -Raw -Encoding UTF8
    } else {
        $content = Get-Content $configSrc -Raw -Encoding UTF8
    }

    $content = $content.Replace('__UV_PATH__', (Escape-TomlString $UvPath))
    $content = Set-HooksFeature $content $HooksEnabled
    $content = Upsert-MarkitdownMcp $content $UvPath
    Write-Utf8NoBomFile $configDst $content
    Write-Host "  + ~/.codex/config.toml"
}

function Install-CodexHooks {
    if ($SkipDcg -or $DisableDcgHooks) {
        Write-Host "  Codex hard hooks disabled by option."
        return
    }

    if (-not (Resolve-DcgPath)) {
        Write-Host "  dcg unavailable; Codex hard hooks not installed."
        return
    }

    if ($DryRun) {
        Write-Host "  [DryRun] would install Codex hooks."
        return
    }

    if ($Force) {
        Copy-DirReplace $hooksSrc $hooksDst
    } else {
        Copy-DirMerge $hooksSrc $hooksDst
    }

    $hookScript = Join-Path $hooksDst "dcg_filter.ps1"
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$hookScript`""
    $hookJson = (Get-Content $hooksJsonSrc -Raw -Encoding UTF8).Replace('__DCG_HOOK_COMMAND__', (Escape-JsonString $command))
    Backup-File $hooksJsonDst
    Write-Utf8NoBomFile $hooksJsonDst $hookJson
    Write-Host "  + ~/.codex/hooks.json"
    Write-Host "  + ~/.codex/hooks/"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Codex configuration restore" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
if ($DryRun) { Write-Host "[DryRun] no files will be changed." -ForegroundColor Yellow }
if ($Force) { Write-Host "[Force] existing Codex managed files may be overwritten." -ForegroundColor Yellow }
Write-Host ""

if (-not (Test-Path $codexSrc)) {
    throw "Codex source directory not found: $codexSrc"
}

if ($DryRun) {
    Write-Host "  [DryRun] would ensure $codexDst"
} elseif (-not (Test-Path $codexDst)) {
    New-Item -ItemType Directory -Path $codexDst -Force | Out-Null
}

if ($DryRun) {
    Write-Host "  [DryRun] $agentsSrc -> $agentsDst"
} else {
    Backup-File $agentsDst
    Copy-Item $agentsSrc $agentsDst -Force
    Write-Host "  + ~/.codex/AGENTS.md"
}

if ($DryRun) {
    Write-Host "  [DryRun] $skillsSrc -> $skillsDst"
} else {
    if ($Force) {
        Copy-DirReplace $skillsSrc $skillsDst
    } else {
        Copy-DirMerge $skillsSrc $skillsDst
    }
    Write-Host "  + ~/.codex/skills/"
}

$uvPath = Install-UvIfMissing
$dcgAvailable = Install-DcgIfRequested
$hooksEnabled = $dcgAvailable -and -not $DisableDcgHooks -and -not $SkipDcg

Update-CodexConfig $uvPath $hooksEnabled
Install-CodexHooks

Write-Host ""
Write-Host "Done. Restart Codex to reload AGENTS.md, skills, MCP servers, and hooks." -ForegroundColor Green
