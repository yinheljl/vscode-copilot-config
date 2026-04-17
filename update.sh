#!/usr/bin/env bash
# update.sh — 从 GitHub 拉取最新配置并自动还原（Linux / macOS）

set -euo pipefail

REPO_URL="https://github.com/yinheljl/vscode-copilot-config.git"

# 确定仓库目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
    curl -fsSL "https://raw.githubusercontent.com/yinheljl/vscode-copilot-config/main/VERSION" 2>/dev/null | tr -d '[:space:]' || echo ""
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
    git pull --ff-only || {
        echo "  git pull 失败，尝试强制同步..."
        git fetch origin
        git reset --hard origin/main
    }
else
    if command -v git &>/dev/null; then
        echo "  正在克隆仓库..."
        git clone "$REPO_URL" "$REPO_DIR"
        echo "  + 已克隆到 $REPO_DIR"
    else
        echo "  未安装 git，使用 ZIP 下载..."
        ZIP_URL="https://github.com/yinheljl/vscode-copilot-config/archive/refs/heads/main.zip"
        ZIP_PATH="/tmp/copilot-config.zip"
        EXTRACT_DIR="/tmp/copilot-config-extract"
        curl -fsSL "$ZIP_URL" -o "$ZIP_PATH"
        rm -rf "$EXTRACT_DIR"
        unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR"
        rm -rf "$REPO_DIR"
        mv "$EXTRACT_DIR"/vscode-copilot-config-main "$REPO_DIR"
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
