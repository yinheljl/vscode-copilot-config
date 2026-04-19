#!/usr/bin/env bash
# sync.sh — 从当前机器同步 Cursor + VS Code Copilot + Codex 配置到本仓库（Linux / macOS）
#
# 同步内容：
#   ~/.copilot/{instructions,skills}        → copilot/
#   ~/.cursor/{rules,skills}                → cursor/
#   Cursor settings.json (Copilot/MCP 相关) → cursor/settings.json
#   VS Code settings.json (Copilot 相关)    → vscode/settings.json
#   ~/.codex/AGENTS.md                       → codex/AGENTS.md
# mcp.json 与 config.toml 使用模板，不从本机同步。

set -euo pipefail

MESSAGE="chore: sync config from $(hostname)"
NO_PUSH=false
for arg in "$@"; do
    case "$arg" in
        --no-push) NO_PUSH=true ;;
        -m|--message) shift; MESSAGE="$1" ;;
        --message=*) MESSAGE="${arg#*=}" ;;
    esac
done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COPILOT_SRC="$HOME/.copilot"
COPILOT_DST="$REPO_DIR/copilot"
CURSOR_SRC="$HOME/.cursor"
CURSOR_DST="$REPO_DIR/cursor"
CODEX_SRC="$HOME/.codex"
CODEX_DST="$REPO_DIR/codex"

if [[ "$OSTYPE" == "darwin"* ]]; then
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
    CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
else
    VSCODE_USER_DIR="$HOME/.config/Code/User"
    CURSOR_USER_DIR="$HOME/.config/Cursor/User"
fi
VSCODE_SETT_SRC="$VSCODE_USER_DIR/settings.json"
VSCODE_SETT_DST="$REPO_DIR/vscode/settings.json"
CURSOR_SETT_SRC="$CURSOR_USER_DIR/settings.json"
CURSOR_SETT_DST="$REPO_DIR/cursor/settings.json"

assert_git_ready() {
    if ! command -v git &>/dev/null; then
        echo "未找到 git。sync.sh 需要在已安装 git 的环境下运行。" >&2
        exit 1
    fi
    if [ ! -d "$REPO_DIR/.git" ]; then
        echo "当前目录不是 Git 仓库。请先 git clone 后再运行 sync.sh。" >&2
        exit 1
    fi
}

# 通过 Python 提取 Copilot/Cursor/MCP 相关键，并剥离敏感键
extract_copilot_settings() {
    local src="$1" dst="$2"
    [ ! -f "$src" ] && return
    if ! command -v python3 &>/dev/null; then
        echo "  ! 未安装 python3，跳过 settings 抽取: $src" >&2
        return
    fi
    SRC="$src" DST="$dst" CONTEXT_CURSOR=$([ "$src" = "$CURSOR_SETT_SRC" ] && echo "1" || echo "0") python3 - <<'PY'
import json, os, re, sys
src = os.environ['SRC']
dst = os.environ['DST']
is_cursor = os.environ['CONTEXT_CURSOR'] == '1'

with open(src, 'r', encoding='utf-8') as f:
    raw = f.read()
# 简易剥离 JSONC 注释
def strip_jsonc(s):
    # 保留字符串字面量
    placeholders = []
    def keep(m):
        placeholders.append(m.group(0))
        return f"__STR_{len(placeholders)-1}__"
    s2 = re.sub(r'"(?:\\.|[^"\\])*"', keep, s)
    s2 = re.sub(r'(?m)//[^\r\n]*', '', s2)
    s2 = re.sub(r'(?s)/\*.*?\*/', '', s2)
    s2 = re.sub(r',(\s*[}\]])', r'\1', s2)
    for i, p in enumerate(placeholders):
        s2 = s2.replace(f'__STR_{i}__', p)
    return s2

try:
    data = json.loads(strip_jsonc(raw))
except Exception as e:
    print(f"  ! 解析失败: {src} ({e})", file=sys.stderr)
    sys.exit(0)

prefixes = ['chat.', 'github.copilot']
if is_cursor:
    prefixes += ['cursor.', 'mcp.']
deny_parts = ('token', 'apikey', 'api_key', 'secret', 'password', 'bearer', 'credential')

filtered = {}
skipped = []
for k, v in data.items():
    if any(k.startswith(p) for p in prefixes):
        if any(d in k.lower() for d in deny_parts):
            skipped.append(k)
            continue
        filtered[k] = v

if skipped:
    print(f"  ! 跳过疑似敏感键: {', '.join(skipped)}")
if filtered:
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, 'w', encoding='utf-8') as f:
        json.dump(filtered, f, indent=2, ensure_ascii=False)
PY
}

echo "========================================"
echo "  同步 Cursor + VS Code + Codex 配置到仓库"
echo "========================================"
echo ""

assert_git_ready

# --- 1. Copilot ---
echo "[1/5] 同步 Copilot..."
for sub in instructions skills; do
    src="$COPILOT_SRC/$sub"
    dst="$COPILOT_DST/$sub"
    if [ -d "$src" ]; then
        rm -rf "$dst"
        mkdir -p "$(dirname "$dst")"
        cp -rf "$src" "$dst"
        echo "  + $sub"
    fi
done

# --- 2. Cursor ---
echo "[2/5] 同步 Cursor..."
mkdir -p "$CURSOR_DST"
for sub in rules skills; do
    src="$CURSOR_SRC/$sub"
    dst="$CURSOR_DST/$sub"
    if [ -d "$src" ]; then
        if [ "$sub" = "rules" ]; then
            mkdir -p "$dst"
            cp -rf "$src/"* "$dst/"
        else
            rm -rf "$dst"
            cp -rf "$src" "$dst"
        fi
        echo "  + $sub/"
    fi
done
extract_copilot_settings "$CURSOR_SETT_SRC" "$CURSOR_SETT_DST"
echo "  + settings.json (Copilot/MCP 相关)"
echo "  * mcp.json 使用模板，不从本机同步"

# --- 3. Codex ---
echo "[3/5] 同步 Codex..."
if [ -f "$CODEX_SRC/AGENTS.md" ]; then
    mkdir -p "$CODEX_DST"
    cp -f "$CODEX_SRC/AGENTS.md" "$CODEX_DST/AGENTS.md"
    echo "  + AGENTS.md"
else
    echo "  未找到 ~/.codex/AGENTS.md，跳过"
fi

# skills/ — 排除 Codex 内置 .system 和 codex-primary-runtime
if [ -d "$CODEX_SRC/skills" ]; then
    mkdir -p "$CODEX_DST/skills"
    synced=0
    for d in "$CODEX_SRC/skills"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        case "$name" in
            .system|codex-primary-runtime) continue ;;
        esac
        rm -rf "$CODEX_DST/skills/$name"
        cp -rf "$d" "$CODEX_DST/skills/$name"
        synced=$((synced+1))
    done
    [ -f "$CODEX_SRC/skills/README.md" ] && cp -f "$CODEX_SRC/skills/README.md" "$CODEX_DST/skills/README.md"
    echo "  + skills/ (同步 $synced 个用户类别，已排除 .system / codex-primary-runtime)"
else
    echo "  未找到 ~/.codex/skills/，跳过"
fi
echo "  * config.toml / hooks.json 使用模板，不从本机同步（hooks.json 引用社区方案 dcg）"

# --- 4. VS Code ---
echo "[4/5] 同步 VS Code..."
mkdir -p "$REPO_DIR/vscode"
extract_copilot_settings "$VSCODE_SETT_SRC" "$VSCODE_SETT_DST"
echo "  + settings.json (Copilot 相关)"
echo "  * mcp.json 使用模板，不从本机同步"

# --- 5. Git commit & push ---
echo "[5/5] 提交到 Git..."
cd "$REPO_DIR"
git add -A
if [ -z "$(git status --porcelain)" ]; then
    echo "  无变更，无需提交。"
else
    git commit -m "$MESSAGE"
    if [ "$NO_PUSH" = true ]; then
        echo "  + 已提交（未推送，使用 --no-push）"
    else
        git push
        echo "  + 已推送到 GitHub"
    fi
fi

echo ""
echo "========================================"
echo "  同步完成！"
echo "========================================"
