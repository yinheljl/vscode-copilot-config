#!/usr/bin/env bash
# restore.sh — 还原 Cursor + VS Code GitHub Copilot + Codex + Claude 个人配置（Linux / macOS）
# 自动检测已安装的 IDE，仅配置已安装的环境。
# 默认增量模式（不覆盖用户已有配置），使用 --force 切换为覆盖模式。

set -euo pipefail

# 参数解析
FORCE=false
TARGET_ALL=true
TARGET_VSCODE=false
TARGET_CURSOR=false
TARGET_CODEX=false
TARGET_CLAUDE=false
AUTO_INSTALL_DCG=false
SKIP_DCG=false
DISABLE_DCG_HOOKS=false
for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=true ;;
        --auto-install-dcg) AUTO_INSTALL_DCG=true ;;
        --disable-dcg-hooks) DISABLE_DCG_HOOKS=true ;;
        --skip-dcg) SKIP_DCG=true ;;
        --target=*)
            TARGET_ALL=false
            target_list="${arg#--target=},"
            while [ -n "$target_list" ]; do
                t="${target_list%%,*}"
                target_list="${target_list#*,}"
                [ -z "$t" ] && continue
                case "$(echo "$t" | tr '[:upper:]' '[:lower:]')" in
                    vscode) TARGET_VSCODE=true ;;
                    cursor) TARGET_CURSOR=true ;;
                    codex)  TARGET_CODEX=true ;;
                    claude) TARGET_CLAUDE=true ;;
                    all)    TARGET_ALL=true ;;
                esac
            done
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COPILOT_SRC="$SCRIPT_DIR/copilot"
COPILOT_DST="$HOME/.copilot"
COPILOT_HOOKS_SRC="$COPILOT_SRC/hooks"
COPILOT_HOOKS_DST="$COPILOT_DST/hooks"
CURSOR_SRC="$SCRIPT_DIR/cursor"
CURSOR_DST="$HOME/.cursor"
CURSOR_HOOKS_SRC="$CURSOR_SRC/hooks.json"
CURSOR_HOOKS_DST="$CURSOR_DST/hooks.json"
CURSOR_HOOKS_DIR_SRC="$CURSOR_SRC/hooks"
CURSOR_HOOKS_DIR_DST="$CURSOR_DST/hooks"
CLAUDE_SRC="$SCRIPT_DIR/claude"
CLAUDE_DST="$HOME/.claude"
CLAUDE_CONFIG_SRC="$CLAUDE_SRC/CLAUDE.md"
CLAUDE_CONFIG_DST="$CLAUDE_DST/CLAUDE.md"
CLAUDE_SKILLS_SRC="$CLAUDE_SRC/skills"
CLAUDE_SKILLS_DST="$CLAUDE_DST/skills"
CLAUDE_HOOKS_SRC="$CLAUDE_SRC/hooks"
CLAUDE_HOOKS_DST="$CLAUDE_DST/hooks"
CLAUDE_SETTINGS_DST="$CLAUDE_DST/settings.json"
CODEX_SRC="$SCRIPT_DIR/codex"
CODEX_DST="$HOME/.codex"
CODEX_SKILLS_SRC="$CODEX_SRC/skills"
CODEX_SKILLS_DST="$CODEX_DST/skills"
CODEX_HOOKS_SRC="$CODEX_SRC/hooks"
CODEX_HOOKS_DST="$CODEX_DST/hooks"
CODEX_HOOKS_JSON_SRC="$CODEX_SRC/hooks.json"
CODEX_HOOKS_JSON_DST="$CODEX_DST/hooks.json"

# VS Code / Cursor 用户配置目录（macOS 和 Linux 路径不同）
if [[ "$OSTYPE" == "darwin"* ]]; then
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
    CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
else
    VSCODE_USER_DIR="$HOME/.config/Code/User"
    CURSOR_USER_DIR="$HOME/.config/Cursor/User"
fi

MCP_SRC="$SCRIPT_DIR/vscode/mcp.json"
MCP_DST="$VSCODE_USER_DIR/mcp.json"
VSCODE_SETT_SRC="$SCRIPT_DIR/vscode/settings.json"
VSCODE_SETT_DST="$VSCODE_USER_DIR/settings.json"
CURSOR_SETT_SRC="$SCRIPT_DIR/cursor/settings.json"
CURSOR_SETT_DST="$CURSOR_USER_DIR/settings.json"

# ============================
# IDE 自动检测
# ============================
HAS_VSCODE=false
HAS_CURSOR=false
HAS_CODEX=false
HAS_CLAUDE=false

if [ -d "$VSCODE_USER_DIR" ] || command -v code &>/dev/null; then
    HAS_VSCODE=true
fi

if [ -d "$CURSOR_DST" ] || command -v cursor &>/dev/null; then
    HAS_CURSOR=true
fi

if [ -d "$CODEX_DST" ] || command -v codex &>/dev/null; then
    HAS_CODEX=true
fi

if [ -d "$CLAUDE_DST" ] || command -v claude &>/dev/null; then
    HAS_CLAUDE=true
fi

# ============================
# --target 参数过滤
# ============================
if [ "$TARGET_ALL" = false ]; then
    [ "$TARGET_VSCODE" = false ] && HAS_VSCODE=false
    [ "$TARGET_CURSOR" = false ] && HAS_CURSOR=false
    [ "$TARGET_CODEX"  = false ] && HAS_CODEX=false
    [ "$TARGET_CLAUDE" = false ] && HAS_CLAUDE=false
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

test_dcg_installed() {
    command -v dcg >/dev/null 2>&1 && return 0
    [ -x "$HOME/.local/bin/dcg" ] && return 0
    return 1
}

invoke_dcg_installer() {
    # 调用 dcg 官方 install.sh：自动选择平台二进制，强制 SHA256 校验，可选 cosign 签名验证。
    # 我们只是"代理调用官方安装器"，不重写下载/校验逻辑（出问题归上游 dcg 维护者）。
    local installer_url="https://raw.githubusercontent.com/Dicklesworthstone/destructive_command_guard/main/install.sh"
    echo "    → 拉取并执行: curl -fsSL $installer_url | bash -s -- --easy-mode"
    if ! command -v curl >/dev/null 2>&1; then
        echo "    ✗ 未安装 curl，无法运行官方安装器" >&2
        return 1
    fi
    if curl -fsSL "$installer_url" | bash -s -- --easy-mode; then
        # install.sh --easy-mode 把 ~/.local/bin 加到了 PATH（写入 ~/.bashrc / ~/.zshrc），但当前 shell 还没刷新
        export PATH="$HOME/.local/bin:$PATH"
        return 0
    fi
    return 1
}

set_codex_hooks_feature() {
    local enabled="$1"
    local cfg_dst="$CODEX_DST/config.toml"
    if [ ! -f "$cfg_dst" ]; then
        mkdir -p "$CODEX_DST"
        printf '[features]\ncodex_hooks = %s\n' "$enabled" > "$cfg_dst"
        echo "    + config.toml 设置 [features] codex_hooks = $enabled"
        return
    fi
    if command -v python3 >/dev/null 2>&1; then
        local result
        result=$(CFG="$cfg_dst" VALUE="$enabled" python3 - <<'PY'
import os, re, shutil, time
p = os.environ['CFG']
v = os.environ['VALUE']
with open(p, 'r', encoding='utf-8') as f:
    s = f.read()
if re.search(r'(?m)^\s*codex_hooks\s*=\s*(true|false)\b', s):
    s2 = re.sub(r'(?m)^(\s*codex_hooks\s*=\s*)(true|false)\b', r'\g<1>' + v, s, count=1)
elif re.search(r'(?m)^\[features\]\s*$', s):
    s2 = re.sub(r'(?m)^\[features\]\s*$', '[features]\ncodex_hooks = ' + v, s, count=1)
else:
    s2 = s.rstrip() + '\n\n[features]\ncodex_hooks = ' + v + '\n'
if s2 != s:
    shutil.copy2(p, p + '.bak_' + time.strftime('%Y%m%d_%H%M%S'))
    with open(p, 'w', encoding='utf-8') as f:
        f.write(s2)
    print('changed')
else:
    print('unchanged')
PY
)
        if [ "$result" = "changed" ]; then
            echo "    + config.toml 设置 [features] codex_hooks = $enabled"
        fi
    else
        local tmp
        tmp=$(mktemp)
        trap 'rm -f "$tmp"' RETURN
        if grep -qE '^[[:space:]]*codex_hooks[[:space:]]*=[[:space:]]*(true|false)([[:space:]]*($|#).*)?$' "$cfg_dst"; then
            awk -v value="$enabled" '
                BEGIN { updated = 0 }
                {
                    if (!updated && $0 ~ /^[[:space:]]*codex_hooks[[:space:]]*=[[:space:]]*(true|false)([[:space:]]*($|#).*)?$/) {
                        sub(/true|false/, value)
                        updated = 1
                    }
                    print
                }
            ' "$cfg_dst" > "$tmp"
        elif grep -qE '^\[features\][[:space:]]*$' "$cfg_dst"; then
            awk -v value="$enabled" '
                BEGIN { inserted = 0 }
                {
                    print
                    if (!inserted && $0 ~ /^\[features\][[:space:]]*$/) {
                        print "codex_hooks = " value
                        inserted = 1
                    }
                }
            ' "$cfg_dst" > "$tmp"
        else
            cat "$cfg_dst" > "$tmp"
            printf '\n[features]\ncodex_hooks = %s\n' "$enabled" >> "$tmp"
        fi
        if ! cmp -s "$cfg_dst" "$tmp"; then
            cp "$cfg_dst" "${cfg_dst}.bak_$(date +%Y%m%d_%H%M%S)"
            trap - RETURN
            mv "$tmp" "$cfg_dst"
            echo "    + config.toml 设置 [features] codex_hooks = $enabled"
        else
            rm -f "$tmp"
            trap - RETURN
        fi
    fi
}

install_codex_hooks() {
    # 硬层防护使用社区方案 dcg（Dicklesworthstone/destructive_command_guard）。
    # 设计原则：
    #   1) 调用官方 install.sh，不自己实现下载/SHA256/cosign 校验逻辑
    #   2) 不默默 curl|bash；首次安装需用户交互式确认（Y/N），或通过 --auto-install-dcg 旗标显式同意
    #   3) Codex PreToolUse matcher 当前按 Bash 工具名触发；默认使用轻量过滤器，只在疑似高危命令时调用 dcg

    echo "  Codex 硬层（破坏性命令防护 dcg）："

    if [ "$SKIP_DCG" = true ]; then
        echo "    → --skip-dcg 已启用，跳过 dcg 全部步骤，并关闭 Codex hooks。软层 SKILL 仍生效。"
        set_codex_hooks_feature false
        return
    fi

    local uname_s
    uname_s=$(uname -s 2>/dev/null || echo unknown)
    local is_windows_host=false
    case "$uname_s" in
        MINGW*|MSYS*|CYGWIN*) is_windows_host=true ;;
    esac

    # Step 1: 检测 dcg
    local dcg_installed=false
    if test_dcg_installed; then
        dcg_installed=true
        local dcg_ver
        dcg_ver=$(dcg --version 2>/dev/null | head -n 1 || echo "unknown")
        echo "    ✓ 已检测到 dcg：$dcg_ver"
    else
        echo "    × 未检测到 dcg（社区方案 destructive_command_guard）"
        local should_install=false
        if [ "$is_windows_host" = true ]; then
            # Windows / Git Bash 上不运行 install.sh，必须走 PowerShell 的 restore.ps1。
            echo "    ⚠ 当前是 Git Bash / MSYS / Cygwin。dcg 在 Windows 上需要走 PowerShell restore.ps1。"
            echo "      请在 PowerShell 内运行：./restore.ps1 -Target Codex -AutoInstallDcg"
        elif [ "$AUTO_INSTALL_DCG" = true ]; then
            should_install=true
            echo "    --auto-install-dcg 已启用，自动安装。"
        else
            echo ""
            echo "    将通过官方 install.sh 安装 dcg："
            echo "      源:    https://github.com/Dicklesworthstone/destructive_command_guard"
            echo "      安装到: $HOME/.local/bin/dcg"
            echo "      校验:   官方安装器内置 SHA256（强制） + cosign（如果你装了）"
            if [ -t 0 ]; then
                read -r -p "    是否安装 dcg？[y/N] " resp
                case "$resp" in
                    y|Y|yes|YES) should_install=true ;;
                esac
            else
                echo "    （非交互式 stdin，未安装。下次加 --auto-install-dcg 自动安装。）"
            fi
        fi
        if [ "$should_install" = true ]; then
            if invoke_dcg_installer; then
                if test_dcg_installed; then
                    dcg_installed=true
                    echo "    ✓ dcg 安装成功"
                else
                    echo "    ⚠ 安装脚本结束但仍找不到 dcg，请手动确认 PATH 是否包含 $HOME/.local/bin" >&2
                fi
            else
                echo "    ✗ 安装失败，请查看上方输出" >&2
            fi
        elif [ "$is_windows_host" = false ]; then
            echo "    → 跳过 dcg 安装。软层 SKILL 仍生效；如需启用硬层，重跑 --auto-install-dcg。"
        fi
    fi

    # Step 2: 用户显式关闭时，仅保留 dcg 二进制。
    if [ "$DISABLE_DCG_HOOKS" = true ]; then
        echo "    → --disable-dcg-hooks 已启用：保留 dcg 二进制，但关闭 Codex PreToolUse hook。"
        set_codex_hooks_feature false
        return
    fi

    # Step 3: 默认启用低噪音 hook，需要 dcg 已装才部署 hooks.json
    if [ "$dcg_installed" = false ]; then
        echo "    → dcg 未安装，无法启用 hooks.json。"
        if [ "$is_windows_host" = true ]; then
            echo "      请在 PowerShell 内运行：./restore.ps1 -Target Codex -AutoInstallDcg"
        fi
        set_codex_hooks_feature false
        return
    fi

    # 部署 hooks 过滤器 + hooks.json
    if [ -d "$CODEX_HOOKS_SRC" ]; then
        if [ "$FORCE" = true ]; then
            copy_dir_replace "$CODEX_HOOKS_SRC" "$CODEX_HOOKS_DST"
            echo "  + hooks/（覆盖，低噪音 dcg 过滤器）"
        else
            copy_dir_merge "$CODEX_HOOKS_SRC" "$CODEX_HOOKS_DST"
            echo "  + hooks/（增量，低噪音 dcg 过滤器）"
        fi
        if [ -f "$CODEX_HOOKS_DST/dcg_filter.py" ]; then
            chmod +x "$CODEX_HOOKS_DST/dcg_filter.py" 2>/dev/null || true
        fi
    fi
    if [ -f "$CODEX_HOOKS_JSON_SRC" ]; then
        local hook_command
        if command -v python3 >/dev/null 2>&1 && [ -f "$CODEX_HOOKS_DST/dcg_filter.py" ]; then
            hook_command="python3 \"$CODEX_HOOKS_DST/dcg_filter.py\""
        else
            hook_command="dcg"
        fi
        if [ -f "$CODEX_HOOKS_JSON_DST" ] && [ "$FORCE" = false ]; then
            cp "$CODEX_HOOKS_JSON_DST" "${CODEX_HOOKS_JSON_DST}.bak_$(date +%Y%m%d_%H%M%S)"
        fi
        if command -v python3 >/dev/null 2>&1; then
            SRC="$CODEX_HOOKS_JSON_SRC" DST="$CODEX_HOOKS_JSON_DST" HOOK_COMMAND="$hook_command" python3 - <<'PY'
import json, os
src = os.environ['SRC']
dst = os.environ['DST']
hook_command = os.environ['HOOK_COMMAND']
with open(src, 'r', encoding='utf-8') as f:
    s = f.read().replace('__DCG_HOOK_COMMAND__', hook_command.replace('\\', '\\\\').replace('"', '\\"'))
json.loads(s)
with open(dst, 'w', encoding='utf-8') as f:
    f.write(s)
PY
        else
            sed "s#__DCG_HOOK_COMMAND__#dcg#g" "$CODEX_HOOKS_JSON_SRC" > "$CODEX_HOOKS_JSON_DST"
        fi
        echo "  + hooks.json（低噪音过滤器 → dcg）"
    fi

    set_codex_hooks_feature true
}

install_claude_hooks() {
    # Claude Code 硬层：部署低噪音 dcg PreToolUse hook（claude/hooks/ → ~/.claude/hooks/），
    # 并把 hook 注册到 ~/.claude/settings.json。
    # 与 Codex 硬层共享同一套 dcg 二进制，但退出码语义不同（exit 0=allow, exit 2=block）。

    echo "  Claude Code 硬层（破坏性命令防护 dcg）："

    if [ "$SKIP_DCG" = true ]; then
        echo "    → --skip-dcg 已启用，跳过 Claude Code dcg hook。软层 SKILL 仍生效。"
        return
    fi
    if [ "$DISABLE_DCG_HOOKS" = true ]; then
        echo "    → --disable-dcg-hooks 已启用，跳过 Claude Code dcg hook 部署。"
        return
    fi

    if ! test_dcg_installed; then
        echo "    → dcg 未安装，跳过 Claude Code PreToolUse hook。软层 SKILL 仍生效。"
        return
    fi

    # 1. 部署 claude/hooks/ → ~/.claude/hooks/
    if [ -d "$CLAUDE_HOOKS_SRC" ]; then
        if [ "$FORCE" = true ]; then
            copy_dir_replace "$CLAUDE_HOOKS_SRC" "$CLAUDE_HOOKS_DST"
            echo "    + ~/.claude/hooks/（覆盖，低噪音 dcg 过滤器）"
        else
            copy_dir_merge "$CLAUDE_HOOKS_SRC" "$CLAUDE_HOOKS_DST"
            echo "    + ~/.claude/hooks/（增量，低噪音 dcg 过滤器）"
        fi
    fi

    # 2. 合并 hooks.PreToolUse 条目到 ~/.claude/settings.json
    local hook_cmd
    if command -v python3 >/dev/null 2>&1 && [ -f "$CLAUDE_HOOKS_DST/dcg_filter.py" ]; then
        hook_cmd="python3 \"$CLAUDE_HOOKS_DST/dcg_filter.py\""
    elif [ -f "$CLAUDE_HOOKS_DST/dcg_filter.ps1" ]; then
        hook_cmd="powershell -NoProfile -ExecutionPolicy Bypass -File \"$CLAUDE_HOOKS_DST/dcg_filter.ps1\""
    else
        hook_cmd="dcg"
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo "    ! 未安装 python3，跳过 Claude settings.json hook 注册。" >&2
        return
    fi

    HOOK_CMD="$hook_cmd" SETTINGS_DST="$CLAUDE_SETTINGS_DST" FORCE="$FORCE" python3 - <<'PY'
import json, os, sys

hook_cmd = os.environ['HOOK_CMD']
settings_dst = os.environ['SETTINGS_DST']
force = os.environ.get('FORCE', 'false') == 'true'

new_group = {
    "matcher": "Bash",
    "hooks": [
        {
            "type": "command",
            "command": hook_cmd,
            "timeout": 10
        }
    ]
}

if not os.path.exists(settings_dst):
    os.makedirs(os.path.dirname(settings_dst), exist_ok=True)
    obj = {"hooks": {"PreToolUse": [new_group]}}
    with open(settings_dst, 'w', encoding='utf-8') as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)
    print("    + ~/.claude/settings.json（新建，写入 dcg PreToolUse hook）")
    sys.exit(0)

with open(settings_dst, 'r', encoding='utf-8') as f:
    cfg = json.load(f)

has_dcg = False
if "hooks" in cfg and isinstance(cfg["hooks"], dict):
    for g in cfg["hooks"].get("PreToolUse", []):
        for h in g.get("hooks", []):
            if "dcg_filter" in h.get("command", ""):
                has_dcg = True
                break
        if has_dcg:
            break

if has_dcg and not force:
    print("    + ~/.claude/settings.json（dcg hook 已存在，未修改）")
    sys.exit(0)

# backup
import shutil, time
shutil.copy2(settings_dst, settings_dst + '.bak_' + time.strftime('%Y%m%d_%H%M%S'))

if "hooks" not in cfg:
    cfg["hooks"] = {}
if "PreToolUse" not in cfg["hooks"]:
    cfg["hooks"]["PreToolUse"] = []

if force and has_dcg:
    cfg["hooks"]["PreToolUse"] = [
        g for g in cfg["hooks"]["PreToolUse"]
        if not any("dcg_filter" in h.get("command", "") for h in g.get("hooks", []))
    ]
    cfg["hooks"]["PreToolUse"].append(new_group)
else:
    cfg["hooks"]["PreToolUse"].append(new_group)

with open(settings_dst, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("    + ~/.claude/settings.json（已写入 dcg PreToolUse hook）")
PY
}

install_cursor_hooks() {
    # Cursor 硬层：部署低噪音 dcg beforeShellExecution hook（cursor/hooks.json + cursor/hooks/ → ~/.cursor/）。
    # Cursor 的 preToolUse deny 有已知 bug，因此使用 beforeShellExecution（仅 Shell 命令触发）。

    echo "  Cursor 硬层（破坏性命令防护 dcg）："

    if [ "$SKIP_DCG" = true ]; then
        echo "    → --skip-dcg 已启用，跳过 Cursor dcg hook。软层 SKILL 仍生效。"
        return
    fi
    if [ "$DISABLE_DCG_HOOKS" = true ]; then
        echo "    → --disable-dcg-hooks 已启用，跳过 Cursor dcg hook 部署。"
        return
    fi

    if ! test_dcg_installed; then
        echo "    → dcg 未安装，跳过 Cursor beforeShellExecution hook。软层 SKILL 仍生效。"
        return
    fi

    # 1. 部署 cursor/hooks/ → ~/.cursor/hooks/
    if [ -d "$CURSOR_HOOKS_DIR_SRC" ]; then
        if [ "$FORCE" = true ]; then
            copy_dir_replace "$CURSOR_HOOKS_DIR_SRC" "$CURSOR_HOOKS_DIR_DST"
            echo "    + ~/.cursor/hooks/（覆盖，dcg 过滤器）"
        else
            copy_dir_merge "$CURSOR_HOOKS_DIR_SRC" "$CURSOR_HOOKS_DIR_DST"
            echo "    + ~/.cursor/hooks/（增量，dcg 过滤器）"
        fi
    fi

    # 2. 部署 cursor/hooks.json → ~/.cursor/hooks.json
    if [ ! -f "$CURSOR_HOOKS_SRC" ]; then
        return
    fi

    local hook_cmd
    local dcg_script="$CURSOR_HOOKS_DIR_DST/dcg_filter.ps1"
    if [ -f "$dcg_script" ]; then
        hook_cmd="powershell -NoProfile -ExecutionPolicy Bypass -File \"$dcg_script\""
    elif command -v python3 >/dev/null 2>&1 && [ -f "$CURSOR_HOOKS_DIR_DST/dcg_filter.py" ]; then
        hook_cmd="python3 \"$CURSOR_HOOKS_DIR_DST/dcg_filter.py\""
    else
        hook_cmd="dcg"
    fi

    if [ -f "$CURSOR_HOOKS_DST" ] && [ "$FORCE" = false ]; then
        cp "$CURSOR_HOOKS_DST" "${CURSOR_HOOKS_DST}.bak_$(date +%Y%m%d_%H%M%S)"
    fi

    if command -v python3 >/dev/null 2>&1; then
        SRC="$CURSOR_HOOKS_SRC" DST="$CURSOR_HOOKS_DST" HOOK_COMMAND="$hook_cmd" python3 - <<'PY'
import json, os
src = os.environ['SRC']
dst = os.environ['DST']
hook_command = os.environ['HOOK_COMMAND']
with open(src, 'r', encoding='utf-8') as f:
    s = f.read().replace('__CURSOR_DCG_HOOK_COMMAND__', hook_command.replace('\\', '\\\\').replace('"', '\\"'))
json.loads(s)
with open(dst, 'w', encoding='utf-8') as f:
    f.write(s)
PY
        echo "    + ~/.cursor/hooks.json（beforeShellExecution → dcg 过滤器）"
    else
        sed "s#__CURSOR_DCG_HOOK_COMMAND__#$hook_cmd#g" "$CURSOR_HOOKS_SRC" > "$CURSOR_HOOKS_DST"
        echo "    + ~/.cursor/hooks.json（beforeShellExecution → dcg，已替换路径）"
    fi
}

install_copilot_hooks() {
    # Copilot 硬层：部署低噪音 dcg preToolUse hook（copilot/hooks/ → ~/.copilot/hooks/）。
    # Copilot preToolUse stdin 格式：{"toolName":"bash","toolArgs":"{\"command\":\"...\"}"}

    echo "  Copilot 硬层（破坏性命令防护 dcg）："

    if [ "$SKIP_DCG" = true ]; then
        echo "    → --skip-dcg 已启用，跳过 Copilot dcg hook。软层 SKILL 仍生效。"
        return
    fi
    if [ "$DISABLE_DCG_HOOKS" = true ]; then
        echo "    → --disable-dcg-hooks 已启用，跳过 Copilot dcg hook 部署。"
        return
    fi

    if ! test_dcg_installed; then
        echo "    → dcg 未安装，跳过 Copilot preToolUse hook。软层 SKILL 仍生效。"
        return
    fi

    # 部署 copilot/hooks/ → ~/.copilot/hooks/
    if [ -d "$COPILOT_HOOKS_SRC" ]; then
        if [ "$FORCE" = true ]; then
            copy_dir_replace "$COPILOT_HOOKS_SRC" "$COPILOT_HOOKS_DST"
            echo "    + ~/.copilot/hooks/（覆盖，dcg 过滤器）"
        else
            copy_dir_merge "$COPILOT_HOOKS_SRC" "$COPILOT_HOOKS_DST"
            echo "    + ~/.copilot/hooks/（增量，dcg 过滤器）"
        fi
        if [ -f "$COPILOT_HOOKS_DST/dcg_filter.py" ]; then
            chmod +x "$COPILOT_HOOKS_DST/dcg_filter.py" 2>/dev/null || true
        fi
    fi

    # 替换 dcg-guard.json 中的占位符为实际路径
    local guard_json="$COPILOT_HOOKS_DST/dcg-guard.json"
    if [ -f "$guard_json" ] && command -v python3 >/dev/null 2>&1; then
        local ps1_path="$COPILOT_HOOKS_DST/dcg_filter.ps1"
        local py_path="$COPILOT_HOOKS_DST/dcg_filter.py"
        local ps1_cmd="powershell -NoProfile -ExecutionPolicy Bypass -File \"$ps1_path\""
        local py_cmd="python3 \"$py_path\""
        PS1_CMD="$ps1_cmd" PY_CMD="$py_cmd" GUARD="$guard_json" python3 - <<'PY'
import json, os
ps1_cmd = os.environ['PS1_CMD']
py_cmd = os.environ['PY_CMD']
guard = os.environ['GUARD']
with open(guard, 'r', encoding='utf-8') as f:
    s = f.read()
s = s.replace('__COPILOT_DCG_HOOK_POWERSHELL__', ps1_cmd.replace('\\', '\\\\').replace('"', '\\"'))
s = s.replace('__COPILOT_DCG_HOOK_BASH__', py_cmd.replace('\\', '\\\\').replace('"', '\\"'))
json.loads(s)
with open(guard, 'w', encoding='utf-8') as f:
    f.write(s)
PY
        echo "    + ~/.copilot/hooks/dcg-guard.json（preToolUse → dcg 过滤器）"
    fi
}

# 将任意字符串安全地编码为 JSON 字符串字面量内部（不含外层引号）
# 用于把路径替换进 mcp.json 模板时正确转义 \ 和 " 等字符
json_escape_value() {
    if command -v python3 &>/dev/null; then
        python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.argv[1])[1:-1])' "$1"
    else
        # 回退：仅转义最常见的 \ 与 "（控制字符在 macOS/Linux 路径中极罕见）
        printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
    fi
}

# 增量合并 JSONC settings：仅追加目标中缺失的顶层键，最大限度保留原文格式与注释
merge_json_settings() {
    local src="$1" dst="$2"
    [ ! -f "$src" ] && return
    if [ ! -f "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        echo "  + 已创建 $(basename "$dst")"
        return
    fi
    if ! command -v python3 &>/dev/null; then
        echo "  ! 未安装 python3，跳过 settings.json 合并: $dst" >&2
        return
    fi
    cp "$dst" "${dst}.bak_$(date +%Y%m%d_%H%M%S)"
    SRC="$src" DST="$dst" python3 - <<'PY'
import json, os, re, sys

src_path = os.environ['SRC']
dst_path = os.environ['DST']

def strip_jsonc(text):
    placeholders = []
    def repl(m):
        placeholders.append(m.group(0))
        return f'__JSONC_STR_{len(placeholders)-1}__'
    s = re.sub(r'"(\\.|[^"\\])*"', repl, text)
    s = re.sub(r'//[^\r\n]*', '', s)
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r',(\s*[}\]])', r'\1', s)
    for i, p in enumerate(placeholders):
        s = s.replace(f'__JSONC_STR_{i}__', p)
    return s

with open(src_path, 'r', encoding='utf-8') as f:
    src_raw = f.read()
with open(dst_path, 'r', encoding='utf-8') as f:
    dst_raw = f.read()

try:
    src_obj = json.loads(strip_jsonc(src_raw))
except Exception as e:
    print(f"  源 settings 解析失败，跳过: {e}", file=sys.stderr)
    sys.exit(0)

try:
    dst_obj = json.loads(strip_jsonc(dst_raw))
except Exception as e:
    print(f"  现有 settings.json 解析失败（含语法错误），跳过合并: {e}", file=sys.stderr)
    sys.exit(0)

if not isinstance(src_obj, dict) or not isinstance(dst_obj, dict):
    print("  settings.json 顶层不是对象，跳过", file=sys.stderr)
    sys.exit(0)

missing = {k: v for k, v in src_obj.items() if k not in dst_obj}
if not missing:
    print("  + settings.json (所有键已存在，未修改，注释保留)")
    sys.exit(0)

trimmed = dst_raw.rstrip()
if not trimmed.endswith('}'):
    print("  目标 settings.json 不以 '}' 结尾，跳过追加", file=sys.stderr)
    sys.exit(0)

body = trimmed[:-1].rstrip()
additions = []
for k, v in missing.items():
    val = json.dumps(v, ensure_ascii=False, indent=2)
    val_lines = val.split('\n')
    val_lines = [val_lines[0]] + ['  ' + ln for ln in val_lines[1:]]
    additions.append('  ' + json.dumps(k, ensure_ascii=False) + ': ' + '\n'.join(val_lines))

insertion = ',\n'.join(additions)
sep = '' if (body.endswith(',') or body.endswith('{')) else ','
new_raw = f"{body}{sep}\n{insertion}\n}}\n"

with open(dst_path, 'w', encoding='utf-8') as f:
    f.write(new_raw)
print(f"  + settings.json (追加 {len(missing)} 个缺失键，原注释保留)")
PY
}

install_mcp_json() {
    local src="$1" dst="$2" uv_path="$3"
    [ ! -f "$src" ] && return
    local content
    if command -v python3 &>/dev/null; then
        # 通过 Python 完成"读模板 + JSON 转义 + 占位符替换"
        # 避免 bash ${var//pat/repl} 把替换串里的 \\ 收缩为 \ 的隐患
        content=$(SRC="$src" UV="$uv_path" python3 - <<'PY'
import os, json, sys
with open(os.environ['SRC'], 'r', encoding='utf-8') as f:
    s = f.read()
def esc(v): return json.dumps(v)[1:-1]
s = s.replace('__UV_PATH__', esc(os.environ['UV']))
sys.stdout.write(s)
PY
)
    else
        # 回退：bash 直接替换（典型 Linux/macOS 路径不含 \ 或 "，足够用）
        content=$(cat "$src")
        content="${content//__UV_PATH__/$uv_path}"
    fi
    mkdir -p "$(dirname "$dst")"

    if [ -f "$dst" ] && [ "$FORCE" = false ]; then
        # 增量模式：备份并通过 Python 进行安全 JSON 合并（不依赖字符串插值）
        cp "$dst" "${dst}.bak_$(date +%Y%m%d_%H%M%S)"
        if command -v python3 &>/dev/null; then
            if NEW_DATA="$content" DST="$dst" python3 - <<'PY' 2>/dev/null
import json, os
dst = os.environ['DST']
new_data = json.loads(os.environ['NEW_DATA'])
with open(dst, 'r', encoding='utf-8') as f:
    existing = json.load(f)
for key in ('servers', 'mcpServers'):
    if key in existing:
        existing[key].pop('interactiveFeedback', None)
        existing[key].pop('interactive-feedback', None)
    if key in new_data:
        servers = existing.setdefault(key, {})
        servers.pop('interactiveFeedback', None)
        servers.pop('interactive-feedback', None)
        servers.update(new_data[key])
with open(dst, 'w', encoding='utf-8') as f:
    json.dump(existing, f, indent=2, ensure_ascii=False)
PY
            then
                echo "  + mcp.json (增量合并，保留已有服务器)"
                return
            fi
        fi
        # python 不可用或解析失败则回退到覆盖
        printf '%s\n' "$content" > "$dst"
        echo "  + mcp.json (已替换路径，Python 合并失败已回退)"
    else
        [ -f "$dst" ] && cp "$dst" "${dst}.bak_$(date +%Y%m%d_%H%M%S)"
        printf '%s\n' "$content" > "$dst"
        echo "  + mcp.json (已替换路径)"
    fi
}

echo "========================================"
echo "  Cursor + VS Code Copilot + Codex + Claude 配置还原"
echo "========================================"
echo ""

# 显示模式
if [ "$FORCE" = true ]; then
    echo "[模式] 完全覆盖（--force）"
else
    echo "[模式] 增量合并（保留用户已有配置）"
fi
if [ "$TARGET_ALL" = false ]; then
    active_targets=""
    [ "$TARGET_VSCODE" = true ] && active_targets="${active_targets:+$active_targets, }VSCode"
    [ "$TARGET_CURSOR" = true ] && active_targets="${active_targets:+$active_targets, }Cursor"
    [ "$TARGET_CODEX"  = true ] && active_targets="${active_targets:+$active_targets, }Codex"
    [ "$TARGET_CLAUDE" = true ] && active_targets="${active_targets:+$active_targets, }Claude"
    echo "[目标] 仅配置: $active_targets"
fi

# 显示检测结果
echo "[IDE 检测]"
if [ "$HAS_VSCODE" = true ]; then echo "  + VS Code"; fi
if [ "$HAS_CURSOR" = true ]; then echo "  + Cursor"; fi
if [ "$HAS_CODEX" = true ]; then echo "  + Codex"; fi
if [ "$HAS_CLAUDE" = true ]; then echo "  + Claude"; fi
if [ "$HAS_VSCODE" = false ] && [ "$HAS_CURSOR" = false ] && [ "$HAS_CODEX" = false ] && [ "$HAS_CLAUDE" = false ]; then
    if [ "$TARGET_ALL" = false ]; then
        echo "  指定的 IDE 未安装，仍将安装配置（IDE 安装后即可使用）。"
        [ "$TARGET_VSCODE" = true ] && HAS_VSCODE=true
        [ "$TARGET_CURSOR" = true ] && HAS_CURSOR=true
        [ "$TARGET_CODEX"  = true ] && HAS_CODEX=true
        [ "$TARGET_CLAUDE" = true ] && HAS_CLAUDE=true
    else
        echo "  未检测到任何 IDE，将安装所有配置（IDE 安装后即可使用）。"
        HAS_VSCODE=true
        HAS_CURSOR=true
        HAS_CODEX=true
        HAS_CLAUDE=true
    fi
fi
echo ""

# --- 1. 还原 copilot → ~/.copilot (VS Code) ---
if [ "$HAS_VSCODE" = true ]; then
    echo "[1] 还原 VS Code Copilot 配置（instructions + skills + hooks）..."
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

        # VS Code settings.json 合并（与 PowerShell 版本对齐）
        if [ -f "$VSCODE_SETT_SRC" ]; then
            merge_json_settings "$VSCODE_SETT_SRC" "$VSCODE_SETT_DST"
        fi

        # hooks（preToolUse 硬兜底，使用社区方案 dcg）
        install_copilot_hooks
    fi
fi

# --- 2. 还原 Cursor 配置 ---
if [ "$HAS_CURSOR" = true ]; then
    echo "[2] 还原 Cursor 配置（rules + skills + hooks）..."
    if [ ! -d "$CURSOR_SRC" ]; then
        echo "  警告：找不到源目录: $CURSOR_SRC" >&2
    else
        mkdir -p "$CURSOR_DST"

        for subdir in rules skills; do
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

        # settings.json 合并（与 PowerShell 版本对齐）
        if [ -f "$CURSOR_SETT_SRC" ]; then
            merge_json_settings "$CURSOR_SETT_SRC" "$CURSOR_SETT_DST"
        fi

        # hooks（beforeShellExecution 硬兜底，使用社区方案 dcg）
        install_cursor_hooks
    fi
fi

# --- 3. 还原 Codex 配置 ---
if [ "$HAS_CODEX" = true ]; then
    echo "[3] 还原 Codex 配置（AGENTS.md + skills + 低噪音 hooks）..."
    if [ ! -d "$CODEX_SRC" ]; then
        echo "  警告：找不到源目录: $CODEX_SRC" >&2
    else
        mkdir -p "$CODEX_DST"
        AGENTS_SRC="$CODEX_SRC/AGENTS.md"
        AGENTS_DST="$CODEX_DST/AGENTS.md"
        if [ -f "$AGENTS_SRC" ]; then
            [ -f "$AGENTS_DST" ] && cp "$AGENTS_DST" "${AGENTS_DST}.bak_$(date +%Y%m%d_%H%M%S)"
            cp "$AGENTS_SRC" "$AGENTS_DST"
            echo "  + AGENTS.md"
        fi
        # skills/  ← 与 cursor/skills、copilot/skills、claude/skills 技能内容同源（含安全护栏 skill）
        if [ -d "$CODEX_SKILLS_SRC" ]; then
            if [ "$FORCE" = true ]; then
                copy_dir_replace "$CODEX_SKILLS_SRC" "$CODEX_SKILLS_DST"
                echo "  + skills/ (覆盖)"
            else
                copy_dir_merge "$CODEX_SKILLS_SRC" "$CODEX_SKILLS_DST"
                echo "  + skills/ (增量)"
            fi
        fi
        # hooks.json + config.toml feature flag（默认启用低噪音硬兜底，使用社区方案 dcg）
        install_codex_hooks
    fi
fi

# --- 4. 还原 Claude 配置 ---
if [ "$HAS_CLAUDE" = true ]; then
    echo "[4] 还原 Claude 配置（CLAUDE.md + skills + 低噪音 hooks）..."
    if [ ! -d "$CLAUDE_SRC" ]; then
        echo "  警告：找不到源目录: $CLAUDE_SRC" >&2
    else
        mkdir -p "$CLAUDE_DST"
        if [ -f "$CLAUDE_CONFIG_SRC" ]; then
            [ -f "$CLAUDE_CONFIG_DST" ] && cp "$CLAUDE_CONFIG_DST" "${CLAUDE_CONFIG_DST}.bak_$(date +%Y%m%d_%H%M%S)"
            cp "$CLAUDE_CONFIG_SRC" "$CLAUDE_CONFIG_DST"
            echo "  + CLAUDE.md"
        fi
        if [ -d "$CLAUDE_SKILLS_SRC" ]; then
            if [ "$FORCE" = true ]; then
                copy_dir_replace "$CLAUDE_SKILLS_SRC" "$CLAUDE_SKILLS_DST"
                echo "  + skills/ (覆盖)"
            else
                copy_dir_merge "$CLAUDE_SKILLS_SRC" "$CLAUDE_SKILLS_DST"
                echo "  + skills/ (增量)"
            fi
        fi
        # hooks（低噪音硬兜底，使用社区方案 dcg）
        install_claude_hooks
    fi
fi

# --- 5. 生成 MCP 配置 ---
if [ "$HAS_CURSOR" = true ] || [ "$HAS_VSCODE" = true ] || [ "$HAS_CODEX" = true ]; then
    echo "[5] 配置 MCP 服务器..."
    UV_PATH=$(resolve_uv_path || true)
    if [ -z "$UV_PATH" ]; then
        echo "  未找到 uv，正在自动安装..."
        if curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null; then
            # 刷新 PATH
            export PATH="$HOME/.local/bin:$PATH"
            UV_PATH=$(resolve_uv_path || true)
            if [ -n "$UV_PATH" ]; then
                echo "  + uv 安装成功: $UV_PATH"
            else
                echo "  警告：uv 安装后仍未找到，请手动检查" >&2
            fi
        else
            echo "  警告：uv 自动安装失败" >&2
            echo "  请手动安装: https://docs.astral.sh/uv/" >&2
        fi
    fi
    if [ -z "$UV_PATH" ]; then
        echo "  警告：未找到 uv，请先安装: https://docs.astral.sh/uv/"
    fi

    [ -z "$UV_PATH" ] && UV_PATH="$HOME/.local/bin/uv"

    if [ "$HAS_CURSOR" = true ]; then
        install_mcp_json "$CURSOR_SRC/mcp.json" "$CURSOR_DST/mcp.json" "$UV_PATH"
    fi
    if [ "$HAS_VSCODE" = true ]; then
        install_mcp_json "$MCP_SRC" "$MCP_DST" "$UV_PATH"
    fi
    if [ "$HAS_CODEX" = true ]; then
        # 合并 Codex config.toml MCP 服务器配置
        CODEX_CONFIG_SRC="$CODEX_SRC/config.toml"
        CODEX_CONFIG_DST="$CODEX_DST/config.toml"
        if [ -f "$CODEX_CONFIG_SRC" ]; then
            if command -v python3 &>/dev/null; then
                # TOML 基本字符串与 JSON 字符串转义规则一致：用 Python 一次性读取+转义+替换
                config_content=$(SRC="$CODEX_CONFIG_SRC" UV="$UV_PATH" python3 - <<'PY'
import os, json, sys
with open(os.environ['SRC'], 'r', encoding='utf-8') as f:
    s = f.read()
def esc(v): return json.dumps(v)[1:-1]
s = s.replace('__UV_PATH__', esc(os.environ['UV']))
sys.stdout.write(s)
PY
)
            else
                config_content=$(cat "$CODEX_CONFIG_SRC")
                config_content="${config_content//__UV_PATH__/$UV_PATH}"
            fi
            mkdir -p "$CODEX_DST"
            if [ -f "$CODEX_CONFIG_DST" ] && [ "$FORCE" = false ]; then
                cp "$CODEX_CONFIG_DST" "${CODEX_CONFIG_DST}.bak_$(date +%Y%m%d_%H%M%S)"
                if command -v python3 &>/dev/null; then
                    merged_ok=false
                    if NEW_CONTENT="$config_content" DST="$CODEX_CONFIG_DST" python3 - <<'PY'
import os, re, sys
new_content = os.environ['NEW_CONTENT']
dst = os.environ['DST']
with open(dst, 'r', encoding='utf-8') as f:
    existing = f.read()
legacy_re = re.compile(r'(?ms)^\[mcp_servers\.(?:interactiveFeedback|interactive-feedback)(?:\.[^\]]+)?\]\s*.*?(?=^\[|\Z)')
original = existing
existing = legacy_re.sub('', existing)
removed_legacy = existing != original
# 仅按"顶层 [mcp_servers.NAME]"切块，子表（如 .env）随父块一同保留
header_re = re.compile(r'(?m)^\[mcp_servers\.([A-Za-z_][A-Za-z0-9_-]*)\]\s*$')
matches = list(header_re.finditer(new_content))
to_add = []
for i, m in enumerate(matches):
    name = m.group(1)
    if f'[mcp_servers.{name}]' in existing:
        continue
    start = m.start()
    end = matches[i+1].start() if i+1 < len(matches) else len(new_content)
    to_add.append(new_content[start:end].rstrip())
if not to_add and not removed_legacy:
    print('  + config.toml (MCP 服务器已存在，无需修改)')
    sys.exit(0)
result = existing.rstrip()
if to_add:
    result += '\n\n' + '\n\n'.join(to_add)
result = result.rstrip() + '\n'
with open(dst, 'w', encoding='utf-8') as f:
    f.write(result)
if removed_legacy:
    print('  + config.toml (增量合并，已移除旧 interactiveFeedback 服务器)')
else:
    print(f'  + config.toml (增量合并，追加 {len(to_add)} 个 MCP 服务器)')
PY
                    then
                        merged_ok=true
                    fi
                    if [ "$merged_ok" = false ]; then
                        printf '%s\n' "$config_content" > "$CODEX_CONFIG_DST"
                        echo "  + config.toml (Python 合并失败，已覆盖)"
                    fi
                else
                    echo "  ! 未安装 python3，已直接覆盖 config.toml" >&2
                    printf '%s\n' "$config_content" > "$CODEX_CONFIG_DST"
                fi
            else
                [ -f "$CODEX_CONFIG_DST" ] && cp "$CODEX_CONFIG_DST" "${CODEX_CONFIG_DST}.bak_$(date +%Y%m%d_%H%M%S)"
                echo "$config_content" > "$CODEX_CONFIG_DST"
                echo "  + config.toml (已替换路径)"
            fi
        fi
    fi
fi

# --- 验证 ---
echo "[验证]"
CHECKS=""
if [ "$HAS_VSCODE" = true ]; then
    CHECKS="$CHECKS ~/.copilot/instructions/:$COPILOT_DST/instructions"
    CHECKS="$CHECKS ~/.copilot/skills/:$COPILOT_DST/skills"
    if [ "$SKIP_DCG" = false ] && [ "$DISABLE_DCG_HOOKS" = false ]; then
        CHECKS="$CHECKS ~/.copilot/hooks/:$COPILOT_HOOKS_DST"
    fi
    CHECKS="$CHECKS VS_Code_mcp.json:$MCP_DST"
fi
if [ "$HAS_CURSOR" = true ]; then
    CHECKS="$CHECKS ~/.cursor/mcp.json:$CURSOR_DST/mcp.json"
    CHECKS="$CHECKS ~/.cursor/rules/:$CURSOR_DST/rules"
    CHECKS="$CHECKS ~/.cursor/skills/:$CURSOR_DST/skills"
    if [ "$SKIP_DCG" = false ] && [ "$DISABLE_DCG_HOOKS" = false ]; then
        CHECKS="$CHECKS ~/.cursor/hooks.json:$CURSOR_HOOKS_DST"
        CHECKS="$CHECKS ~/.cursor/hooks/:$CURSOR_HOOKS_DIR_DST"
    fi
fi
if [ "$HAS_CODEX" = true ]; then
    CHECKS="$CHECKS ~/.codex/AGENTS.md:$CODEX_DST/AGENTS.md"
    CHECKS="$CHECKS ~/.codex/config.toml:$CODEX_DST/config.toml"
    CHECKS="$CHECKS ~/.codex/skills/:$CODEX_SKILLS_DST"
    CHECKS="$CHECKS ~/.codex/skills/destructive-command-guard/:$CODEX_SKILLS_DST/destructive-command-guard"
    CHECKS="$CHECKS ~/.codex/hooks.json:$CODEX_HOOKS_JSON_DST"
fi
if [ "$HAS_CLAUDE" = true ]; then
    CHECKS="$CHECKS ~/.claude/CLAUDE.md:$CLAUDE_CONFIG_DST"
    CHECKS="$CHECKS ~/.claude/skills/:$CLAUDE_SKILLS_DST"
    CHECKS="$CHECKS ~/.claude/skills/destructive-command-guard/:$CLAUDE_SKILLS_DST/destructive-command-guard"
    if [ "$SKIP_DCG" = false ] && [ "$DISABLE_DCG_HOOKS" = false ]; then
        CHECKS="$CHECKS ~/.claude/hooks/:$CLAUDE_HOOKS_DST"
    fi
fi
for item in $CHECKS; do
    name="${item%%:*}"
    path="${item#*:}"
    if [ -e "$path" ]; then
        echo "  + $name"
    else
        echo "  - $name (未找到)"
    fi
done

# dcg 二进制独立检查（未安装时软层 SKILL 仍生效）
if [ "$HAS_CODEX" = true ] && [ "$SKIP_DCG" = false ]; then
    if test_dcg_installed; then
        echo "  + dcg 二进制（社区方案 destructive_command_guard）"
    else
        echo "  ~ dcg 未安装（硬层未启用；软层 SKILL 仍生效）"
    fi
    if [ "$DISABLE_DCG_HOOKS" = true ]; then
        echo "  + Codex dcg hook 已按参数关闭"
    elif [ -f "$CODEX_HOOKS_JSON_DST" ]; then
        echo "  + Codex dcg hook（默认启用，低噪音过滤器）"
    else
        echo "  - Codex dcg hook（默认启用但 hooks.json 未找到）"
    fi
fi
if [ "$HAS_CLAUDE" = true ] && [ "$SKIP_DCG" = false ]; then
    if test_dcg_installed; then
        echo "  + dcg 二进制（Claude Code 硬层已启用）"
    else
        echo "  ~ dcg 未安装（Claude Code 硬层未启用；软层 SKILL 仍生效）"
    fi
    if [ "$DISABLE_DCG_HOOKS" = true ]; then
        echo "  + Claude Code dcg hook 已按参数跳过"
    elif [ -d "$CLAUDE_HOOKS_DST" ]; then
        echo "  + Claude Code dcg hook（低噪音过滤器）"
    else
        echo "  ~ Claude Code dcg hook（hooks/ 未找到）"
    fi
fi
if [ "$HAS_CURSOR" = true ] && [ "$SKIP_DCG" = false ]; then
    if [ "$DISABLE_DCG_HOOKS" = true ]; then
        echo "  + Cursor dcg hook 已按参数跳过"
    elif [ -f "$CURSOR_HOOKS_DST" ]; then
        echo "  + Cursor dcg hook（beforeShellExecution）"
    else
        echo "  ~ Cursor dcg hook（hooks.json 未找到）"
    fi
fi
if [ "$HAS_VSCODE" = true ] && [ "$SKIP_DCG" = false ]; then
    if [ "$DISABLE_DCG_HOOKS" = true ]; then
        echo "  + Copilot dcg hook 已按参数跳过"
    elif [ -d "$COPILOT_HOOKS_DST" ]; then
        echo "  + Copilot dcg hook（preToolUse）"
    else
        echo "  ~ Copilot dcg hook（hooks/ 未找到）"
    fi
fi

echo ""
echo "========================================"
echo "  还原完成！"
echo "========================================"
echo ""
echo "后续步骤："
if [ "$HAS_VSCODE" = true ]; then echo "  - 重启 VS Code"; fi
if [ "$HAS_CURSOR" = true ]; then echo "  - 重启 Cursor，验证 MCP Server 是否正常加载"; fi
if [ "$HAS_CODEX" = true ]; then echo "  - 重启 VS Code Codex 扩展，验证 MCP 工具是否正常加载"; fi
if [ "$HAS_CLAUDE" = true ]; then echo "  - 重启 Claude Code"; fi
echo "  - 如需其他 MCP（GitHub、Context7 等），按需手动安装"
