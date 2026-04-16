#!/usr/bin/env bash
# restore.sh — 还原 Cursor + VS Code GitHub Copilot 个人配置（Linux / macOS）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COPILOT_SRC="$SCRIPT_DIR/copilot"
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

resolve_uv_path() {
    for p in "$HOME/.local/bin/uv" "$HOME/.cargo/bin/uv"; do
        [ -x "$p" ] && echo "$p" && return
    done
    command -v uv 2>/dev/null && return
    return 1
}

install_mcp_json() {
    local src="$1" dst="$2" uv_path="$3" mcp_dir="$4"
    [ ! -f "$src" ] && return
    local content
    content=$(cat "$src")
    content="${content//__UV_PATH__/$uv_path}"
    content="${content//__FEEDBACK_MCP_DIR__/$mcp_dir}"
    mkdir -p "$(dirname "$dst")"
    [ -f "$dst" ] && cp "$dst" "${dst}.bak_$(date +%Y%m%d_%H%M%S)"
    echo "$content" > "$dst"
    echo "  + mcp.json (已替换路径)"
}

echo "========================================"
echo "  Cursor + VS Code Copilot 配置还原"
echo "========================================"
echo ""

# --- 1. 还原 copilot → ~/.copilot ---
echo "[1/4] 还原 Copilot 配置（instructions + skills）..."
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

# --- 3. 克隆 Interactive-Feedback-MCP + 生成 mcp.json ---
echo "[3/4] 配置 Interactive-Feedback-MCP..."
if [ -d "$FEEDBACK_MCP_DIR" ]; then
    echo "  目录已存在，尝试更新..."
    if command -v git &>/dev/null; then
        (cd "$FEEDBACK_MCP_DIR" && git pull --ff-only)
    else
        echo "  未安装 git，跳过更新"
    fi
else
    if command -v git &>/dev/null; then
        echo "  正在克隆（使用 git）..."
        git clone https://github.com/rooney2020/qt-interactive-feedback-mcp.git "$FEEDBACK_MCP_DIR"
    else
        echo "  未安装 git，使用 ZIP 下载..."
        ZIP_URL="https://github.com/rooney2020/qt-interactive-feedback-mcp/archive/refs/heads/main.zip"
        ZIP_PATH="/tmp/interactive-feedback-mcp.zip"
        EXTRACT_DIR="/tmp/interactive-feedback-mcp-extract"
        if curl -fsSL "$ZIP_URL" -o "$ZIP_PATH"; then
            rm -rf "$EXTRACT_DIR"
            unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR"
            mv "$EXTRACT_DIR"/qt-interactive-feedback-mcp-main "$FEEDBACK_MCP_DIR"
            rm -f "$ZIP_PATH"
            rm -rf "$EXTRACT_DIR"
            echo "  + 已通过 ZIP 下载完成"
        else
            echo "  ZIP 下载失败，请手动下载: $ZIP_URL" >&2
            echo "  解压到: $FEEDBACK_MCP_DIR" >&2
        fi
    fi
fi

UV_PATH=$(resolve_uv_path || true)
if [ -n "$UV_PATH" ]; then
    echo "  正在运行 uv sync..."
    (cd "$FEEDBACK_MCP_DIR" && "$UV_PATH" sync)
    echo "  + Interactive-Feedback-MCP 已就绪"

    install_mcp_json "$CURSOR_SRC/mcp.json" "$CURSOR_DST/mcp.json" "$UV_PATH" "$FEEDBACK_MCP_DIR"
    install_mcp_json "$MCP_SRC" "$MCP_DST" "$UV_PATH" "$FEEDBACK_MCP_DIR"
else
    echo "  警告：未找到 uv，请先安装: https://docs.astral.sh/uv/"
    echo "  然后手动执行: cd $FEEDBACK_MCP_DIR && uv sync"
fi

# --- 4. 验证 ---
echo "[4/4] 验证..."
for item in \
    "~/.copilot/instructions/:$COPILOT_DST/instructions" \
    "~/.copilot/skills/:$COPILOT_DST/skills" \
    "~/.cursor/mcp.json:$CURSOR_DST/mcp.json" \
    "~/.cursor/rules/:$CURSOR_DST/rules" \
    "~/.cursor/skills/:$CURSOR_DST/skills" \
    "~/.cursor/skills-cursor/:$CURSOR_DST/skills-cursor" \
    "VS Code mcp.json:$MCP_DST" \
    "Interactive-Feedback-MCP:$FEEDBACK_MCP_DIR"
do
    name="${item%%:*}"
    path="${item#*:}"
    if [ -e "$path" ]; then
        echo "  + $name"
    else
        echo "  - $name (未找到)"
    fi
done

echo ""
echo "========================================"
echo "  还原完成！"
echo "========================================"
echo ""
echo "后续步骤："
echo "  1. 重启 Cursor 和 VS Code"
echo "  2. 在 Cursor 中验证 MCP Server 是否正常加载"
echo "  3. 如需其他 MCP（GitHub、Context7 等），在扩展商城中安装"
