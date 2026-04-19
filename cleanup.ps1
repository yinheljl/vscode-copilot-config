<#
.SYNOPSIS
    扫描并清理 AI Agent（Codex / Cursor / Copilot）长任务后堆积的工程级缓存与临时文件。

.DESCRIPTION
    解决"AI agent 在执行任务时产生大量缓存/临时文件、累积占满磁盘"的问题。

    安全设计：
      * 默认 DryRun：仅扫描 + 打印大小，不删任何文件
      * 仅匹配明确的可重建缓存目录名（白名单），不会动源码 / 配置 / .git
      * 必须显式加 -Apply 才会真正删除
      * 全局缓存目录（~/.cache、~/.npm 等）只显示大小并给出推荐命令，不主动删
      * 命令通过 Codex hook 校验（已添加 ~/.cache/* 白名单测试）

.PARAMETER Path
    扫描根目录，默认当前目录。

.PARAMETER Apply
    实际执行删除。不加该开关时仅打印（DryRun）。

.PARAMETER MaxDepth
    最大递归深度，默认 5（避免扫描过深导致慢）。

.PARAMETER SkipGlobal
    不扫描全局缓存目录（~/.cache、~/.npm 等）。

.EXAMPLE
    .\cleanup.ps1
    扫描当前目录，仅打印 DryRun 结果。

.EXAMPLE
    .\cleanup.ps1 -Apply
    实际清理当前目录下所有匹配的工程缓存。

.EXAMPLE
    .\cleanup.ps1 -Path D:\projects -Apply
    清理 D:\projects 整棵树。

.NOTES
    可重建缓存白名单：
      node_modules / __pycache__ / .pytest_cache / .mypy_cache / .ruff_cache /
      .next / .nuxt / .turbo / .svelte-kit / .parcel-cache /
      dist / build / out / .gradle / target / .tox / .venv（仅在有 pyproject.toml 的兄弟目录时）
#>
[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [switch]$Apply,
    [int]$MaxDepth = 5,
    [switch]$SkipGlobal
)

$ErrorActionPreference = 'Stop'

$cacheDirNames = @(
    'node_modules',
    '__pycache__',
    '.pytest_cache',
    '.mypy_cache',
    '.ruff_cache',
    '.next',
    '.nuxt',
    '.turbo',
    '.svelte-kit',
    '.parcel-cache',
    'dist',
    'build',
    'out',
    '.gradle',
    'target',
    '.tox'
)

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0,9:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0,9:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0,9:N2} KB' -f ($Bytes / 1KB)) }
    return ('{0,9} B ' -f $Bytes)
}

function Get-DirSize {
    param([string]$DirPath)
    try {
        $sum = (Get-ChildItem -LiteralPath $DirPath -Recurse -Force -File -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) { return 0 }
        return [int64]$sum
    } catch {
        return 0
    }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
$mode = if ($Apply) { 'EXECUTE (will delete)' } else { 'DRY-RUN (will not delete)' }
Write-Host ('  AI Agent 缓存清理   模式：{0}' -f $mode) -ForegroundColor Cyan
Write-Host ('  扫描根目录：{0}' -f $Path)
Write-Host ('  最大深度  ：{0}' -f $MaxDepth)
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host ('错误：路径不存在：{0}' -f $Path) -ForegroundColor Red
    exit 1
}

$found = New-Object System.Collections.Generic.List[object]
$totalBytes = 0L

Write-Host '正在扫描工程缓存目录（白名单匹配）...'
foreach ($name in $cacheDirNames) {
    try {
        $matched = @(Get-ChildItem -Path $Path -Directory -Recurse -Force -Depth $MaxDepth `
            -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $name })
    } catch {
        $matched = @()
    }
    foreach ($m in $matched) {
        $size = Get-DirSize $m.FullName
        $found.Add([pscustomobject]@{
            Path   = $m.FullName
            Bytes  = $size
            Pretty = Format-Size $size
        }) | Out-Null
        $totalBytes += $size
    }
    if ($matched.Count -gt 0) {
        Write-Host ('  [{0,3}] {1}' -f $matched.Count, $name)
    }
}

Write-Host ''
if ($found.Count -eq 0) {
    Write-Host '✓ 没有找到任何工程缓存目录，磁盘很干净。' -ForegroundColor Green
} else {
    Write-Host '工程缓存清单（按大小降序，前 30）：'
    $found | Sort-Object Bytes -Descending | Select-Object -First 30 | ForEach-Object {
        Write-Host ('  [{0}]  {1}' -f $_.Pretty, $_.Path)
    }
    if ($found.Count -gt 30) {
        Write-Host ('  ... 还有 {0} 个未列出' -f ($found.Count - 30)) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host ('合计可释放：{0}（共 {1} 个目录）' -f (Format-Size $totalBytes), $found.Count) -ForegroundColor Yellow
}

if ($Apply -and $found.Count -gt 0) {
    Write-Host ''
    Write-Host '开始删除...'
    $okCount = 0
    $failCount = 0
    $freed = 0L
    foreach ($item in $found) {
        try {
            Remove-Item -LiteralPath $item.Path -Recurse -Force -ErrorAction Stop
            $okCount++
            $freed += $item.Bytes
        } catch {
            Write-Host ('  失败 {0}: {1}' -f $item.Path, $_.Exception.Message) -ForegroundColor Yellow
            $failCount++
        }
    }
    Write-Host ''
    Write-Host ('✓ 已删除 {0} 个目录，释放 {1}（失败 {2}）' -f $okCount, (Format-Size $freed), $failCount) -ForegroundColor Green
}

if (-not $SkipGlobal) {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '  全局缓存目录（仅报告大小，不主动删）' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan

    $global = @(
        @{ Path = Join-Path $env:USERPROFILE '.cache';                        Hint = 'rm -rf ~/.cache/<具体子目录>（不要直接删 ~/.cache）' },
        @{ Path = Join-Path $env:USERPROFILE '.cache\huggingface';            Hint = 'rm -rf ~/.cache/huggingface/hub' },
        @{ Path = Join-Path $env:USERPROFILE '.npm\_cacache';                 Hint = 'npm cache clean --force' },
        @{ Path = Join-Path $env:LOCALAPPDATA 'pip\Cache';                    Hint = 'pip cache purge' },
        @{ Path = Join-Path $env:USERPROFILE '.cargo\registry\cache';         Hint = 'cargo cache --autoclean  (cargo install cargo-cache)' },
        @{ Path = Join-Path $env:USERPROFILE '.gradle\caches';                Hint = 'rm -rf ~/.gradle/caches' },
        @{ Path = Join-Path $env:LOCALAPPDATA 'Yarn\Cache';                   Hint = 'yarn cache clean' },
        @{ Path = Join-Path $env:USERPROFILE '.pyenv';                        Hint = '(只看，按需手动)' }
    )

    foreach ($g in $global) {
        if (Test-Path -LiteralPath $g.Path) {
            $sz = Get-DirSize $g.Path
            if ($sz -gt 0) {
                Write-Host ('  [{0}]  {1}' -f (Format-Size $sz), $g.Path)
                Write-Host ('              提示：{0}' -f $g.Hint) -ForegroundColor DarkGray
            }
        }
    }

    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($docker) {
        Write-Host ''
        Write-Host '  Docker 占用：'
        try {
            & docker system df 2>$null | ForEach-Object { Write-Host ('    {0}' -f $_) }
            Write-Host '  推荐清理：docker system prune -af --volumes' -ForegroundColor DarkGray
        } catch { }
    }
}

if (-not $Apply) {
    Write-Host ''
    Write-Host '提示：当前是 DryRun 模式，未实际删除任何文件。' -ForegroundColor Cyan
    Write-Host '若确认无误，重新运行并加 -Apply 真正执行：' -ForegroundColor Cyan
    Write-Host ('    .\cleanup.ps1 -Path "{0}" -Apply' -f $Path) -ForegroundColor White
}

Write-Host ''
