#!/usr/bin/env bash
# update.sh — 从 GitHub 拉取最新配置并自动还原（Linux / macOS）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 优先从 REPO_URL 文件读取（便于 fork 后只改一处）
if [ -f "$SCRIPT_DIR/REPO_URL" ]; then
    REPO_URL=$(tr -d '[:space:]' < "$SCRIPT_DIR/REPO_URL")
else
    REPO_URL="https://github.com/yinheljl/vscode-copilot-config.git"
fi

if [ -f "$SCRIPT_DIR/VERSION" ]; then
    REPO_DIR="$SCRIPT_DIR"
elif [ -f "$PWD/VERSION" ]; then
    REPO_DIR="$PWD"
else
    REPO_DIR="$HOME/.copilot-config"
fi

get_local_version() {
    if [ -f "$1/VERSION" ]; then
        cat "$1/VERSION" | tr -d '[:space:]'
    else
        echo "0.0.0"
    fi
}

get_remote_version() {
    # 从 REPO_URL 推导 raw URL（去掉 .git 后缀，把 github.com 换成 raw.githubusercontent.com）
    local raw_url="${REPO_URL%.git}"
    raw_url="${raw_url//github.com/raw.githubusercontent.com}/main/VERSION"
    curl -fsSL "$raw_url" 2>/dev/null | tr -d '[:space:]' || echo ""
}

echo "========================================"
echo "  Copilot 配置更新工具"
echo "========================================"
echo ""

# --- 版本检查 ---
LOCAL_VER=$(get_local_version "$REPO_DIR")
echo "本地版本: $LOCAL_VER"

REMOTE_VER=$(get_remote_version)
if [ -n "$REMOTE_VER" ]; then
    echo "远程版本: $REMOTE_VER"
    if [ "$LOCAL_VER" = "$REMOTE_VER" ]; then
        echo "已是最新版本。"
        echo "继续执行还原以确保配置一致..."
    else
        echo "发现新版本！ $LOCAL_VER -> $REMOTE_VER"
    fi
else
    echo "无法检查远程版本，继续执行..."
fi

# --- 拉取/克隆仓库 ---
echo ""
echo "[1/2] 同步仓库代码..."

if [ -d "$REPO_DIR/.git" ]; then
    echo "  仓库已存在: $REPO_DIR"
    cd "$REPO_DIR"
    if ! git pull --ff-only; then
        # git pull --ff-only 失败说明本地与 origin/main 已分叉，或有阻塞 ff 的本地修改。
        # 仅在「自管理目录 + 工作区干净」时才允许强制同步，避免覆盖用户本地工作。
        MANAGED_DIR="$HOME/.copilot-config"
        REPO_DIR_NORM="${REPO_DIR%/}"
        MANAGED_DIR_NORM="${MANAGED_DIR%/}"
        IS_MANAGED_DIR=false
        if [ "$REPO_DIR_NORM" = "$MANAGED_DIR_NORM" ]; then
            IS_MANAGED_DIR=true
        fi

        IS_DIRTY=false
        if ! STATUS_OUT=$(git status --porcelain 2>&1); then
            IS_DIRTY=true
        elif [ -n "$STATUS_OUT" ]; then
            IS_DIRTY=true
        fi

        if [ "$IS_MANAGED_DIR" = true ] && [ "$IS_DIRTY" = false ]; then
            echo "  git pull 失败，自管理目录无本地改动，强制同步到 origin/main..."
            git fetch origin
            git reset --hard origin/main
        else
            echo "  git pull --ff-only 失败。" >&2
            if [ "$IS_DIRTY" = true ]; then
                echo "  当前仓库存在未提交修改或本地提交，已停止以避免覆盖你的本地工作。" >&2
            else
                echo "  当前仓库与 origin/main 已分叉。" >&2
            fi
            echo "  请手动处理本地状态后重试，例如：" >&2
            echo "    git status                # 查看本地修改" >&2
            echo "    git stash                 # 暂存本地修改" >&2
            echo "    git pull --rebase         # 在本地提交之上变基" >&2
            echo "  确认要丢弃所有本地改动时，可手动执行：git fetch origin && git reset --hard origin/main" >&2
            exit 1
        fi
    fi
else
    if command -v git &>/dev/null; then
        echo "  正在克隆仓库..."
        git clone "$REPO_URL" "$REPO_DIR"
        echo "  + 已克隆到 $REPO_DIR"
    else
        echo "  未安装 git，使用 ZIP 下载..."
        ZIP_URL="${REPO_URL%.git}/archive/refs/heads/main.zip"
        ZIP_PATH="/tmp/copilot-config.zip"
        EXTRACT_DIR="/tmp/copilot-config-extract"
        curl -fsSL "$ZIP_URL" -o "$ZIP_PATH"
        rm -rf "$EXTRACT_DIR"
        unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR"
        inner_dir=$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
        if [ -z "$inner_dir" ]; then
            echo "  ZIP 解压结构异常，终止" >&2
            rm -f "$ZIP_PATH"
            rm -rf "$EXTRACT_DIR"
            exit 1
        fi
        rm -rf "$REPO_DIR"
        mv "$inner_dir" "$REPO_DIR"
        rm -f "$ZIP_PATH"
        rm -rf "$EXTRACT_DIR"
        echo "  + 已通过 ZIP 下载到 $REPO_DIR"
    fi
fi

# --- 执行 restore ---
echo "[2/2] 执行配置还原..."
RESTORE_SCRIPT="$REPO_DIR/restore.sh"
if [ -f "$RESTORE_SCRIPT" ]; then
    chmod +x "$RESTORE_SCRIPT"
    # 透传所有参数给 restore.sh
    bash "$RESTORE_SCRIPT" "$@"
else
    echo "  警告：找不到 restore.sh: $RESTORE_SCRIPT" >&2
    echo "  请确认仓库完整性" >&2
fi

# --- 显示更新后的版本 ---
NEW_VER=$(get_local_version "$REPO_DIR")
echo ""
echo "========================================"
echo "  更新完成！当前版本: $NEW_VER"
echo "========================================"
