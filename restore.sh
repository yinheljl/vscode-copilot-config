#!/usr/bin/env bash
# restore.sh — 还原 VS Code GitHub Copilot 个人配置（Linux / macOS）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COPILOT_SRC="$SCRIPT_DIR/.copilot"
COPILOT_DST="$HOME/.copilot"
MCP_SRC="$SCRIPT_DIR/vscode/mcp.json"

# VS Code 用户配置目录（macOS 和 Linux 路径不同）
if [[ "$OSTYPE" == "darwin"* ]]; then
    MCP_DST="$HOME/Library/Application Support/Code/User/mcp.json"
else
    MCP_DST="$HOME/.config/Code/User/mcp.json"
fi

echo "=== VS Code Copilot 配置还原 ==="
echo ""

# --- 还原 .copilot ---
if [ ! -d "$COPILOT_SRC" ]; then
    echo "错误：找不到源目录: $COPILOT_SRC" >&2
    exit 1
fi

echo "正在还原 .copilot 配置..."
mkdir -p "$COPILOT_DST"
for subdir in instructions skills; do
    if [ -d "$COPILOT_SRC/$subdir" ]; then
        cp -rf "$COPILOT_SRC/$subdir" "$COPILOT_DST/"
        echo "  ✓ $subdir"
    fi
done

# --- 还原 mcp.json ---
if [ ! -f "$MCP_SRC" ]; then
    echo "警告：找不到 MCP 配置文件，跳过。"
else
    echo "正在还原 MCP 配置..."
    MCP_DIR="$(dirname "$MCP_DST")"

    # 备份现有 mcp.json
    if [ -f "$MCP_DST" ]; then
        BACKUP="${MCP_DST}.bak_$(date +%Y%m%d_%H%M%S)"
        cp "$MCP_DST" "$BACKUP"
        echo "  已备份原 mcp.json -> $BACKUP"
    fi

    mkdir -p "$MCP_DIR"
    cp "$MCP_SRC" "$MCP_DST"
    echo "  ✓ mcp.json"
fi

echo ""
echo "=== 还原完成 ==="
echo ""
echo "后续步骤："
echo "  1. 重启 VS Code"
echo "  2. 打开 Copilot Chat，系统会提示你输入 GITHUB_MCP_TOKEN"
echo "     (GitHub Personal Access Token，需要 repo 权限)"
echo "  3. 验证 MCP Server 和 instructions 是否正常加载"
