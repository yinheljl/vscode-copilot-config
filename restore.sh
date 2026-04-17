#!/usr/bin/env bash
# restore.sh — 还原 Cursor + VS Code GitHub Copilot + Codex 个人配置（Linux / macOS）
# 自动检测已安装的 IDE，仅配置已安装的环境。
# 默认增量模式（不覆盖用户已有配置），使用 --force 切换为覆盖模式。

set -euo pipefail

# 参数解析
FORCE=false
TARGET_ALL=true
TARGET_VSCODE=false
TARGET_CURSOR=false
TARGET_CODEX=false
for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=true ;;
        --target=*)
            TARGET_ALL=false
            IFS=',' read -ra TARGETS <<< "${arg#--target=}"
            for t in "${TARGETS[@]}"; do
                case "$(echo "$t" | tr '[:upper:]' '[:lower:]')" in
                    vscode) TARGET_VSCODE=true ;;
                    cursor) TARGET_CURSOR=true ;;
                    codex)  TARGET_CODEX=true ;;
                    all)    TARGET_ALL=true ;;
                esac
            done
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COPILOT_SRC="$SCRIPT_DIR/copilot"
COPILOT_DST="$HOME/.copilot"
CURSOR_SRC="$SCRIPT_DIR/cursor"
CURSOR_DST="$HOME/.cursor"
CODEX_SRC="$SCRIPT_DIR/codex"
CODEX_DST="$HOME/.codex"
FEEDBACK_MCP_DIR="$HOME/MCP/Interactive-Feedback-MCP"

# VS Code 用户配置目录（macOS 和 Linux 路径不同）
if [[ "$OSTYPE" == "darwin"* ]]; then
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
else
    VSCODE_USER_DIR="$HOME/.config/Code/User"
fi

MCP_SRC="$SCRIPT_DIR/vscode/mcp.json"
MCP_DST="$VSCODE_USER_DIR/mcp.json"

# ============================
# IDE 自动检测
# ============================
HAS_VSCODE=false
HAS_CURSOR=false
HAS_CODEX=false

if [ -d "$VSCODE_USER_DIR" ] || command -v code &>/dev/null; then
    HAS_VSCODE=true
fi

if [ -d "$CURSOR_DST" ] || command -v cursor &>/dev/null; then
    HAS_CURSOR=true
fi

if [ -d "$CODEX_DST" ] || command -v codex &>/dev/null; then
    HAS_CODEX=true
fi

# ============================
# --target 参数过滤
# ============================
if [ "$TARGET_ALL" = false ]; then
    [ "$TARGET_VSCODE" = false ] && HAS_VSCODE=false
    [ "$TARGET_CURSOR" = false ] && HAS_CURSOR=false
    [ "$TARGET_CODEX"  = false ] && HAS_CODEX=false
fi

resolve_uv_path() {
    for p in "$HOME/.local/bin/uv" "$HOME/.cargo/bin/uv"; do
        [ -x "$p" ] && echo "$p" && return
    done
    command -v uv 2>/dev/null && return
    return 1
}

copy_dir_merge() {
    local src="$1" dst="$2"
    mkdir -p "$dst"
    cp -rf "$src/"* "$dst/"
}

copy_dir_replace() {
    local src="$1" dst="$2"
    rm -rf "$dst"
    cp -rf "$src" "$dst"
}

install_mcp_json() {
    local src="$1" dst="$2" uv_path="$3" feedback_python="$4" mcp_dir="$5"
    [ ! -f "$src" ] && return
    local content
    content=$(cat "$src")
    content="${content//__UV_PATH__/$uv_path}"
    content="${content//__FEEDBACK_MCP_PYTHON__/$feedback_python}"
    content="${content//__FEEDBACK_MCP_DIR__/$mcp_dir}"
    content="${content//__FEEDBACK_SERVER_PATH__/$mcp_dir/server.py}"
    mkdir -p "$(dirname "$dst")"

    if [ -f "$dst" ] && [ "$FORCE" = false ]; then
        # 增量模式：备份并保留已有内容（简单合并）
        cp "$dst" "${dst}.bak_$(date +%Y%m%d_%H%M%S)"
        # 使用 python 进行 JSON 合并（如果可用）
        if command -v python3 &>/dev/null; then
            python3 -c "
import json, sys
with open('$dst') as f:
    existing = json.load(f)
new_data = json.loads('''$content''')
# 合并 servers 或 mcpServers
for key in ['servers', 'mcpServers']:
    if key in new_data:
        if key not in existing:
            existing[key] = {}
        existing[key].update(new_data[key])
with open('$dst', 'w') as f:
    json.dump(existing, f, indent=2)
" 2>/dev/null && echo "  + mcp.json (增量合并，保留已有服务器)" && return
        fi
        # python 不可用则回退到覆盖
        echo "$content" > "$dst"
        echo "  + mcp.json (已替换路径)"
    else
        [ -f "$dst" ] && cp "$dst" "${dst}.bak_$(date +%Y%m%d_%H%M%S)"
        echo "$content" > "$dst"
        echo "  + mcp.json (已替换路径)"
    fi
}

echo "========================================"
echo "  Cursor + VS Code Copilot + Codex 配置还原"
echo "========================================"
echo ""

# 显示模式
if [ "$FORCE" = true ]; then
    echo "[模式] 完全覆盖（--force）"
else
    echo "[模式] 增量合并（保留用户已有配置）"
fi
if [ "$TARGET_ALL" = false ]; then
    active_targets=()
    [ "$TARGET_VSCODE" = true ] && active_targets+=("VSCode")
    [ "$TARGET_CURSOR" = true ] && active_targets+=("Cursor")
    [ "$TARGET_CODEX"  = true ] && active_targets+=("Codex")
    echo "[目标] 仅配置: $(IFS=', '; echo "${active_targets[*]}")"
fi

# 显示检测结果
echo "[IDE 检测]"
if [ "$HAS_VSCODE" = true ]; then echo "  + VS Code"; fi
if [ "$HAS_CURSOR" = true ]; then echo "  + Cursor"; fi
if [ "$HAS_CODEX" = true ]; then echo "  + Codex"; fi
if [ "$HAS_VSCODE" = false ] && [ "$HAS_CURSOR" = false ] && [ "$HAS_CODEX" = false ]; then
    if [ "$TARGET_ALL" = false ]; then
        echo "  指定的 IDE 未安装，仍将安装配置（IDE 安装后即可使用）。"
        [ "$TARGET_VSCODE" = true ] && HAS_VSCODE=true
        [ "$TARGET_CURSOR" = true ] && HAS_CURSOR=true
        [ "$TARGET_CODEX"  = true ] && HAS_CODEX=true
    else
        echo "  未检测到任何 IDE，将安装所有配置（IDE 安装后即可使用）。"
        HAS_VSCODE=true
        HAS_CURSOR=true
        HAS_CODEX=true
    fi
fi
echo ""

# --- 1. 还原 copilot → ~/.copilot (VS Code) ---
if [ "$HAS_VSCODE" = true ]; then
    echo "[1] 还原 VS Code Copilot 配置（instructions + skills）..."
    if [ ! -d "$COPILOT_SRC" ]; then
        echo "  警告：找不到源目录: $COPILOT_SRC" >&2
    else
        for subdir in instructions skills; do
            if [ -d "$COPILOT_SRC/$subdir" ]; then
                if [ "$FORCE" = true ]; then
                    copy_dir_replace "$COPILOT_SRC/$subdir" "$COPILOT_DST/$subdir"
                    echo "  + $subdir (覆盖)"
                else
                    copy_dir_merge "$COPILOT_SRC/$subdir" "$COPILOT_DST/$subdir"
                    echo "  + $subdir (增量)"
                fi
            fi
        done
    fi
fi

# --- 2. 还原 Cursor 配置 ---
if [ "$HAS_CURSOR" = true ]; then
    echo "[2] 还原 Cursor 配置..."
    if [ ! -d "$CURSOR_SRC" ]; then
        echo "  警告：找不到源目录: $CURSOR_SRC" >&2
    else
        mkdir -p "$CURSOR_DST"

        for subdir in rules skills skills-cursor; do
            if [ -d "$CURSOR_SRC/$subdir" ]; then
                if [ "$FORCE" = true ]; then
                    copy_dir_replace "$CURSOR_SRC/$subdir" "$CURSOR_DST/$subdir"
                    echo "  + $subdir/ (覆盖)"
                else
                    copy_dir_merge "$CURSOR_SRC/$subdir" "$CURSOR_DST/$subdir"
                    echo "  + $subdir/ (增量)"
                fi
            fi
        done
    fi
fi

# --- 3. 还原 Codex 配置 ---
if [ "$HAS_CODEX" = true ]; then
    echo "[3] 还原 Codex 配置（AGENTS.md）..."
    if [ ! -d "$CODEX_SRC" ]; then
        echo "  警告：找不到源目录: $CODEX_SRC" >&2
    else
        mkdir -p "$CODEX_DST"
        AGENTS_SRC="$CODEX_SRC/AGENTS.md"
        AGENTS_DST="$CODEX_DST/AGENTS.md"
        if [ -f "$AGENTS_SRC" ]; then
            if [ "$FORCE" = true ] || [ ! -f "$AGENTS_DST" ]; then
                [ -f "$AGENTS_DST" ] && cp "$AGENTS_DST" "${AGENTS_DST}.bak_$(date +%Y%m%d_%H%M%S)"
                cp "$AGENTS_SRC" "$AGENTS_DST"
                echo "  + AGENTS.md"
            else
                echo "  + AGENTS.md (已存在，增量模式跳过。使用 --force 覆盖)"
            fi
        fi
    fi
fi

# --- 4. 克隆 Interactive-Feedback-MCP + 生成 mcp.json ---
echo "[4] 配置 Interactive-Feedback-MCP..."
if [ -d "$FEEDBACK_MCP_DIR" ]; then
    echo "  目录已存在，尝试更新..."
    if command -v git &>/dev/null; then
        (cd "$FEEDBACK_MCP_DIR" && git pull --ff-only) || echo "  更新失败，使用已有版本"
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

    FEEDBACK_PYTHON="$FEEDBACK_MCP_DIR/.venv/bin/python"
    if [ -x "$FEEDBACK_PYTHON" ]; then
        if [ "$HAS_CURSOR" = true ]; then
            install_mcp_json "$CURSOR_SRC/mcp.json" "$CURSOR_DST/mcp.json" "$UV_PATH" "$FEEDBACK_PYTHON" "$FEEDBACK_MCP_DIR"
        fi
        if [ "$HAS_VSCODE" = true ]; then
            install_mcp_json "$MCP_SRC" "$MCP_DST" "$UV_PATH" "$FEEDBACK_PYTHON" "$FEEDBACK_MCP_DIR"
        fi
        if [ "$HAS_CODEX" = true ]; then
            # 合并 Codex config.toml MCP 服务器配置
            CODEX_CONFIG_SRC="$CODEX_SRC/config.toml"
            CODEX_CONFIG_DST="$CODEX_DST/config.toml"
            if [ -f "$CODEX_CONFIG_SRC" ]; then
                config_content=$(cat "$CODEX_CONFIG_SRC")
                config_content="${config_content//__UV_PATH__/$UV_PATH}"
                config_content="${config_content//__FEEDBACK_MCP_PYTHON__/$FEEDBACK_PYTHON}"
                config_content="${config_content//__FEEDBACK_SERVER_PATH__/$FEEDBACK_MCP_DIR/server.py}"
                mkdir -p "$CODEX_DST"
                if [ -f "$CODEX_CONFIG_DST" ] && [ "$FORCE" = false ]; then
                    cp "$CODEX_CONFIG_DST" "${CODEX_CONFIG_DST}.bak_$(date +%Y%m%d_%H%M%S)"
                    # 增量模式：追加缺失的 MCP 服务器
                    existing=$(cat "$CODEX_CONFIG_DST")
                    added=false
                    if ! echo "$existing" | grep -q '\[mcp_servers\.interactiveFeedback\]'; then
                        echo "" >> "$CODEX_CONFIG_DST"
                        echo "$config_content" | sed -n '/\[mcp_servers\.interactiveFeedback\]/,/^$/p' >> "$CODEX_CONFIG_DST"
                        echo "$config_content" | sed -n '/\[mcp_servers\.interactiveFeedback\.env\]/,/^$/p' >> "$CODEX_CONFIG_DST"
                        added=true
                    fi
                    if ! echo "$existing" | grep -q '\[mcp_servers\.markitdown\]'; then
                        echo "" >> "$CODEX_CONFIG_DST"
                        echo "$config_content" | sed -n '/\[mcp_servers\.markitdown\]/,/^$/p' >> "$CODEX_CONFIG_DST"
                        added=true
                    fi
                    if [ "$added" = true ]; then
                        echo "  + config.toml (增量合并，追加 MCP 服务器)"
                    else
                        echo "  + config.toml (MCP 服务器已存在，无需修改)"
                    fi
                else
                    [ -f "$CODEX_CONFIG_DST" ] && cp "$CODEX_CONFIG_DST" "${CODEX_CONFIG_DST}.bak_$(date +%Y%m%d_%H%M%S)"
                    echo "$config_content" > "$CODEX_CONFIG_DST"
                    echo "  + config.toml (已替换路径)"
                fi
            fi
        fi
    else
        echo "  警告：找不到反馈服务虚拟环境 Python: $FEEDBACK_PYTHON" >&2
        echo "  请确认 uv sync 是否成功完成" >&2
    fi
else
    echo "  警告：未找到 uv，请先安装: https://docs.astral.sh/uv/"
    echo "  然后手动执行: cd $FEEDBACK_MCP_DIR && uv sync"
fi

# --- 验证 ---
echo "[验证]"
CHECKS=""
if [ "$HAS_VSCODE" = true ]; then
    CHECKS="$CHECKS ~/.copilot/instructions/:$COPILOT_DST/instructions"
    CHECKS="$CHECKS ~/.copilot/skills/:$COPILOT_DST/skills"
    CHECKS="$CHECKS VS_Code_mcp.json:$MCP_DST"
fi
if [ "$HAS_CURSOR" = true ]; then
    CHECKS="$CHECKS ~/.cursor/mcp.json:$CURSOR_DST/mcp.json"
    CHECKS="$CHECKS ~/.cursor/rules/:$CURSOR_DST/rules"
    CHECKS="$CHECKS ~/.cursor/skills/:$CURSOR_DST/skills"
    CHECKS="$CHECKS ~/.cursor/skills-cursor/:$CURSOR_DST/skills-cursor"
fi
if [ "$HAS_CODEX" = true ]; then
    CHECKS="$CHECKS ~/.codex/AGENTS.md:$CODEX_DST/AGENTS.md"
    CHECKS="$CHECKS ~/.codex/config.toml:$CODEX_DST/config.toml"
fi
CHECKS="$CHECKS Interactive-Feedback-MCP:$FEEDBACK_MCP_DIR"

for item in $CHECKS; do
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
if [ "$HAS_VSCODE" = true ]; then echo "  1. 重启 VS Code"; fi
if [ "$HAS_CURSOR" = true ]; then echo "  2. 重启 Cursor，验证 MCP Server 是否正常加载"; fi
if [ "$HAS_CODEX" = true ]; then echo "  3. 重启 VS Code Codex 扩展，验证 MCP 工具是否正常加载"; fi
echo "  4. 如需其他 MCP（GitHub、Context7 等），按需手动安装"