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
    .\update.ps1 -Target Codex      # 仅更新 Codex 配置
    .\update.ps1 -Target Codex -Force  # 仅覆盖 Codex 配置
#>
param(
    [switch]$DryRun,
    [switch]$CheckOnly,
    [switch]$SkipFeedbackMCP,
    [switch]$Force,
    [ValidateSet("All", "VSCode", "Cursor", "Codex")]
    [string[]]$Target = @("All")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoName  = "vscode-copilot-config"

# 优先从 REPO_URL 文件读取仓库 URL（便于 fork 后只改一处）
$repoUrlFileLocal = if ($PSScriptRoot) { Join-Path $PSScriptRoot "REPO_URL" } else { $null }
if ($repoUrlFileLocal -and (Test-Path $repoUrlFileLocal)) {
    $repoUrl = (Get-Content $repoUrlFileLocal -Raw).Trim()
} else {
    $repoUrl = "https://github.com/yinheljl/vscode-copilot-config.git"
}

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
        # 从 $repoUrl 推导 raw URL：去掉 .git，把 github.com 换成 raw.githubusercontent.com
        $base = $repoUrl -replace '\.git$',''
        $base = $base -replace 'github\.com','raw.githubusercontent.com'
        $url  = "$base/main/VERSION"
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
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $pullOutput = & git pull --ff-only 2>&1
            Write-Host "  $pullOutput"
            if ($LASTEXITCODE -ne 0) {
                $statusOut = & git status --porcelain 2>&1
                $isDirty   = ($LASTEXITCODE -ne 0) -or [bool]($statusOut)

                Write-Warning "  git pull --ff-only 失败（退出码 $LASTEXITCODE）。为避免覆盖你的本地工作，update 不再自动执行 git reset --hard。"
                if ($isDirty) {
                    Write-Warning "  检测到当前仓库存在未提交修改。"
                } else {
                    Write-Warning "  当前仓库可能存在本地分叉、非跟踪分支状态，或远程访问异常。"
                }
                Write-Warning "  请手动处理本地状态后重试，例如："
                Write-Warning "    git status                # 查看本地修改"
                Write-Warning "    git stash                 # 暂存本地修改"
                Write-Warning "    git pull --rebase         # 在本地提交之上变基"
                Write-Warning "  确认要丢弃所有本地改动时，可手动执行：git fetch origin; git reset --hard origin/main"
                throw "更新中止：git pull 失败，需手动处理后重试"
            }
        } finally {
            $ErrorActionPreference = $prevPref
            Pop-Location
        }
    } else {
        Write-Host "  [DryRun] 将执行 git pull --ff-only（失败时停止并提示手动处理，不再自动 hard reset）"
    }
} else {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "  未安装 git，使用 ZIP 下载..." -ForegroundColor Yellow
        if (-not $DryRun) {
            $zipUrl = ($repoUrl -replace '\.git$','') + "/archive/refs/heads/main.zip"
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
            $prevPref = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                & git clone $repoUrl $repoDir 2>&1 | ForEach-Object { Write-Host "    $_" }
                if ($LASTEXITCODE -ne 0) { throw "git clone 失败（退出码 $LASTEXITCODE）" }
                Write-Host "  + 已克隆到 $repoDir"
            } finally {
                $ErrorActionPreference = $prevPref
            }
        } else {
            Write-Host "  [DryRun] 将克隆到 $repoDir"
        }
    }
}

# --- 执行 restore ---
Write-Host "[2/2] 执行配置还原..." -ForegroundColor Green
$restoreScript = Join-Path $repoDir "restore.ps1"
if (Test-Path $restoreScript) {
    $restoreArgs = @{}
    if ($DryRun) { $restoreArgs["DryRun"] = $true }
    if ($Force) { $restoreArgs["Force"] = $true }
    if ($SkipFeedbackMCP) { $restoreArgs["SkipFeedbackMCP"] = $true }
    if ($Target -notcontains "All") { $restoreArgs["Target"] = $Target }
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
