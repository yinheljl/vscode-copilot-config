<#
.SYNOPSIS
    从 GitHub 拉取最新配置并自动还原到本机

.DESCRIPTION
    自动完成以下操作：
    1. 如果本地没有仓库，自动 clone
    2. 如果已有仓库，git pull 拉取最新代码
    3. 执行 restore.ps1 还原配置
    支持版本检查和增量更新。

.EXAMPLE
    .\update.ps1                    # 拉取更新并还原
    .\update.ps1 -DryRun            # 预览模式
    .\update.ps1 -CheckOnly         # 仅检查更新，不执行
    .\update.ps1 -SkipFeedbackMCP   # 跳过反馈 MCP 更新
#>
param(
    [switch]$DryRun,
    [switch]$CheckOnly,
    [switch]$SkipFeedbackMCP
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoUrl   = "https://github.com/yinheljl/vscode-copilot-config.git"
$repoName  = "vscode-copilot-config"

# 确定仓库目录：如果当前目录就是仓库，就用当前目录；否则用临时目录
$scriptDir = $PSScriptRoot
if ($scriptDir -and (Test-Path (Join-Path $scriptDir "VERSION"))) {
    $repoDir = $scriptDir
} elseif (Test-Path (Join-Path $PWD "VERSION")) {
    $repoDir = $PWD.Path
} else {
    $repoDir = Join-Path $env:USERPROFILE ".copilot-config"
}

function Get-LocalVersion($dir) {
    $versionFile = Join-Path $dir "VERSION"
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw).Trim()
    }
    return "0.0.0"
}

function Get-RemoteVersion {
    try {
        $url = "https://raw.githubusercontent.com/yinheljl/vscode-copilot-config/main/VERSION"
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
        return $response.Content.Trim()
    } catch {
        Write-Warning "无法获取远程版本号: $($_.Exception.Message)"
        return $null
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Copilot 配置更新工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- 版本检查 ---
$localVersion = Get-LocalVersion $repoDir
Write-Host "本地版本: $localVersion"

$remoteVersion = Get-RemoteVersion
if ($remoteVersion) {
    Write-Host "远程版本: $remoteVersion"
    if ($localVersion -eq $remoteVersion) {
        Write-Host "已是最新版本。" -ForegroundColor Green
        if ($CheckOnly) { exit 0 }
        Write-Host "继续执行还原以确保配置一致..." -ForegroundColor Yellow
    } else {
        Write-Host "发现新版本！ $localVersion -> $remoteVersion" -ForegroundColor Yellow
    }
} else {
    Write-Host "无法检查远程版本，继续执行..." -ForegroundColor Yellow
}

if ($CheckOnly) {
    Write-Host ""
    Write-Host "仅检查模式，不执行更新。" -ForegroundColor Yellow
    exit 0
}

if ($DryRun) {
    Write-Host "[DryRun] 仅预览，不执行实际操作。" -ForegroundColor Yellow
    Write-Host ""
}

# --- 拉取/克隆仓库 ---
Write-Host ""
Write-Host "[1/2] 同步仓库代码..." -ForegroundColor Green

if (Test-Path (Join-Path $repoDir ".git")) {
    Write-Host "  仓库已存在: $repoDir"
    if (-not $DryRun) {
        Push-Location $repoDir
        try {
            $pullOutput = git pull --ff-only 2>&1
            Write-Host "  $pullOutput"
        } catch {
            Write-Warning "  git pull 失败: $($_.Exception.Message)"
            Write-Warning "  尝试强制同步..."
            git fetch origin
            git reset --hard origin/main
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "  [DryRun] 将执行 git pull"
    }
} else {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "  未安装 git，使用 ZIP 下载..." -ForegroundColor Yellow
        if (-not $DryRun) {
            $zipUrl = "https://github.com/yinheljl/vscode-copilot-config/archive/refs/heads/main.zip"
            $zipPath = Join-Path $env:TEMP "copilot-config.zip"
            $extractDir = Join-Path $env:TEMP "copilot-config-extract"
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
            if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
            Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
            $innerDir = Get-ChildItem $extractDir -Directory | Select-Object -First 1
            if (Test-Path $repoDir) { Remove-Item $repoDir -Recurse -Force }
            Move-Item $innerDir.FullName $repoDir
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  + 已通过 ZIP 下载到 $repoDir"
        } else {
            Write-Host "  [DryRun] 将下载 ZIP 到 $repoDir"
        }
    } else {
        Write-Host "  正在克隆仓库..."
        if (-not $DryRun) {
            git clone $repoUrl $repoDir
            Write-Host "  + 已克隆到 $repoDir"
        } else {
            Write-Host "  [DryRun] 将克隆到 $repoDir"
        }
    }
}

# --- 执行 restore ---
Write-Host "[2/2] 执行配置还原..." -ForegroundColor Green
$restoreScript = Join-Path $repoDir "restore.ps1"
if (Test-Path $restoreScript) {
    $restoreArgs = @()
    if ($DryRun) { $restoreArgs += "-DryRun" }
    if ($SkipFeedbackMCP) { $restoreArgs += "-SkipFeedbackMCP" }
    & $restoreScript @restoreArgs
} else {
    Write-Warning "找不到 restore.ps1: $restoreScript"
    Write-Warning "请确认仓库完整性"
}

# --- 显示更新后的版本 ---
$newVersion = Get-LocalVersion $repoDir
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  更新完成！当前版本: $newVersion" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
