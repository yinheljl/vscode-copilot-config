#!/usr/bin/env bash
# restore.sh — 还原 Cursor + VS Code GitHub Copilot 个人配置（Linux / macOS）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COPILOT_SRC="$SCRIPT_DIR/.copilot"
COPILOT_DST="$HOME/.copilot"
CURSOR_SRC="$SCRIPT_DIR/cursor"
CURSOR_DST="$HOME/.cursor"
FEEDBACK_MCP_DIR="$CURSOR_DST/Interactive-Feedback-MCP"

# VS Code 用户配置目录（macOS 和 Linux 路径不同）
if [[ "$OSTYPE" == "darwin"* ]]; then
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
else
    VSCODE_USER_DIR="$HOME/.config/Code/User"
fi

MCP_SRC="$SCRIPT_DIR/vscode/mcp.json"
MCP_DST="$VSCODE_USER_DIR/mcp.json"

echo "========================================"
echo "  Cursor + VS Code Copilot 配置还原"
echo "========================================"
echo ""

# --- 1. 还原 .copilot ---
echo "[1/4] 还原 .copilot 配置..."
if [ ! -d "$COPILOT_SRC" ]; then
    echo "  警告：找不到源目录: $COPILOT_SRC" >&2
else
    mkdir -p "$COPILOT_DST"
    for subdir in instructions skills; do
        if [ -d "$COPILOT_SRC/$subdir" ]; then
            rm -rf "$COPILOT_DST/$subdir"
            cp -rf "$COPILOT_SRC/$subdir" "$COPILOT_DST/"
            echo "  + $subdir"
        fi
    done
fi

# --- 2. 还原 Cursor 配置 ---
echo "[2/4] 还原 Cursor 配置..."
if [ ! -d "$CURSOR_SRC" ]; then
    echo "  警告：找不到源目录: $CURSOR_SRC" >&2
else
    mkdir -p "$CURSOR_DST"

    # mcp.json
    if [ -f "$CURSOR_SRC/mcp.json" ]; then
        [ -f "$CURSOR_DST/mcp.json" ] && cp "$CURSOR_DST/mcp.json" "$CURSOR_DST/mcp.json.bak_$(date +%Y%m%d_%H%M%S)"
        cp "$CURSOR_SRC/mcp.json" "$CURSOR_DST/mcp.json"
        echo "  + mcp.json"
    fi

    # rules/
    if [ -d "$CURSOR_SRC/rules" ]; then
        mkdir -p "$CURSOR_DST/rules"
        cp -rf "$CURSOR_SRC/rules/"* "$CURSOR_DST/rules/"
        echo "  + rules/"
    fi

    # skills/
    if [ -d "$CURSOR_SRC/skills" ]; then
        rm -rf "$CURSOR_DST/skills"
        cp -rf "$CURSOR_SRC/skills" "$CURSOR_DST/skills"
        echo "  + skills/"
    fi

    # skills-cursor/
    if [ -d "$CURSOR_SRC/skills-cursor" ]; then
        rm -rf "$CURSOR_DST/skills-cursor"
        cp -rf "$CURSOR_SRC/skills-cursor" "$CURSOR_DST/skills-cursor"
        echo "  + skills-cursor/"
    fi
fi

# --- 3. 还原 VS Code 配置 ---
echo "[3/4] 还原 VS Code 配置..."
if [ -f "$MCP_SRC" ]; then
    MCP_DIR="$(dirname "$MCP_DST")"
    mkdir -p "$MCP_DIR"
    [ -f "$MCP_DST" ] && cp "$MCP_DST" "${MCP_DST}.bak_$(date +%Y%m%d_%H%M%S)"
    cp "$MCP_SRC" "$MCP_DST"
    echo "  + mcp.json"
else
    echo "  警告：找不到 MCP 配置文件，跳过。"
fi

# --- 4. 克隆 Interactive-Feedback-MCP ---
echo "[4/4] 配置 Interactive-Feedback-MCP..."
if [ -d "$FEEDBACK_MCP_DIR" ]; then
    echo "  目录已存在，执行 git pull..."
    (cd "$FEEDBACK_MCP_DIR" && git pull --ff-only)
else
    echo "  正在克隆..."
    git clone https://github.com/rooney2020/qt-interactive-feedback-mcp.git "$FEEDBACK_MCP_DIR"
fi

if command -v uv &>/dev/null; then
    echo "  正在运行 uv sync..."
    (cd "$FEEDBACK_MCP_DIR" && uv sync)
    echo "  + Interactive-Feedback-MCP 已就绪"
else
    echo "  警告：未找到 uv，请先安装: https://docs.astral.sh/uv/"
    echo "  然后手动执行: cd $FEEDBACK_MCP_DIR && uv sync"
fi

echo ""
echo "========================================"
echo "  还原完成！"
echo "========================================"
echo ""
echo "后续步骤："
echo "  1. 重启 Cursor 和 VS Code"
echo "  2. 在 Cursor 中验证 MCP Server 是否正常加载"
echo "  3. 在 VS Code 中打开 Copilot Chat，输入 GITHUB_MCP_TOKEN"
echo "  4. 如使用飞书 MCP，需配置 LARK_APP_ID 和 LARK_APP_SECRET 环境变量"
