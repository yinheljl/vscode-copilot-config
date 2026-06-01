#!/usr/bin/env bash
# Restore Codex global configuration from this repository.

set -euo pipefail

DRY_RUN=false
FORCE=false
AUTO_INSTALL_DCG=false
DISABLE_DCG_HOOKS=false
SKIP_DCG=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force) FORCE=true ;;
        --auto-install-dcg) AUTO_INSTALL_DCG=true ;;
        --disable-dcg-hooks) DISABLE_DCG_HOOKS=true ;;
        --skip-dcg) SKIP_DCG=true ;;
        -h|--help)
            cat <<'EOF'
Usage: bash restore.sh [options]

Options:
  --dry-run              Print planned changes without writing files
  --force                Replace managed Codex directories instead of merging
  --auto-install-dcg     Install/refresh dcg without prompting
  --disable-dcg-hooks    Keep dcg available but disable Codex hooks
  --skip-dcg             Skip dcg install and disable Codex hooks
EOF
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_SRC="$SCRIPT_DIR/codex"
CODEX_DST="$HOME/.codex"

resolve_uv_path() {
    for p in "$HOME/.local/bin/uv" "$HOME/.cargo/bin/uv"; do
        [ -x "$p" ] && { printf '%s\n' "$p"; return 0; }
    done
    command -v uv 2>/dev/null && return 0
    return 1
}

python_cmd() {
    for candidate in python3 python; do
        if command -v "$candidate" >/dev/null 2>&1 && "$candidate" - <<'PY' >/dev/null 2>&1
import sys

raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
PY
        then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    echo "python3 or python 3.11+ is required to merge Codex config." >&2
    return 1
}

install_uv_if_missing() {
    if uv_path=$(resolve_uv_path); then
        printf '%s\n' "$uv_path"
        return
    fi

    echo "  uv not found; installing uv for markitdown MCP..." >&2
    if [ "$DRY_RUN" = true ]; then
        printf '%s\n' "$HOME/.local/bin/uv"
        return
    fi

    if curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1; then
        if uv_path=$(resolve_uv_path); then
            printf '%s\n' "$uv_path"
            return
        fi
    fi

    echo "  Warning: uv install failed or uv is still unavailable." >&2
    printf '%s\n' "$HOME/.local/bin/uv"
}

dcg_available() {
    command -v dcg >/dev/null 2>&1 || command -v dcg.exe >/dev/null 2>&1
}

copy_managed_skills() {
    mkdir -p "$CODEX_DST/skills"
    for src in "$CODEX_SRC"/skills/* "$CODEX_SRC"/skills/.[!.]* "$CODEX_SRC"/skills/..?*; do
        [ -e "$src" ] || continue
        name="$(basename "$src")"
        [ "$name" = ".system" ] && continue
        dst="$CODEX_DST/skills/$name"
        if [ "$FORCE" = true ] && [ -e "$dst" ]; then
            rm -rf "$dst"
        fi
        cp -R "$src" "$CODEX_DST/skills/"
    done
}

install_dcg_if_requested() {
    if [ "$SKIP_DCG" = true ]; then
        echo "  dcg skipped; Codex hooks will be disabled." >&2
        return 1
    fi

    if dcg_available && [ "$AUTO_INSTALL_DCG" = false ]; then
        echo "  dcg found: $(command -v dcg || command -v dcg.exe)" >&2
        return 0
    fi
    if dcg_available && [ "$AUTO_INSTALL_DCG" = true ]; then
        echo "  dcg found: $(command -v dcg || command -v dcg.exe); refreshing from upstream installer." >&2
    fi

    should_install=false
    if [ "$AUTO_INSTALL_DCG" = true ]; then
        should_install=true
    elif [ -t 0 ] && [ "$DRY_RUN" = false ]; then
        printf '  dcg is not installed. Install it now? [y/N] ' >&2
        read -r answer
        case "$answer" in
            y|Y|yes|YES) should_install=true ;;
        esac
    fi

    if [ "$should_install" != true ]; then
        echo "  dcg not installed; soft skill still applies, hard hook disabled." >&2
        return 1
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  [DryRun] would install dcg from upstream installer." >&2
        return 0
    fi

    curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/destructive_command_guard/main/install.sh?$(date +%s)" |
        bash -s -- --no-configure >/dev/null
    dcg_available
}

merge_codex_config() {
    local uv_path="$1"
    local hooks_enabled="$2"
    local config_src="$CODEX_SRC/config.toml"
    local config_dst="$CODEX_DST/config.toml"
    local py_cmd

    if [ "$DRY_RUN" = true ]; then
        echo "  [DryRun] would merge $config_src -> $config_dst"
        return
    fi

    py_cmd="$(python_cmd)"
    CONFIG_SRC="$config_src" CONFIG_DST="$config_dst" UV_PATH="$uv_path" HOOKS_ENABLED="$hooks_enabled" FORCE="$FORCE" "$py_cmd" - <<'PY'
from __future__ import annotations

import os
import re
from pathlib import Path

src = Path(os.environ["CONFIG_SRC"])
dst = Path(os.environ["CONFIG_DST"])
uv_path = os.environ["UV_PATH"]
hooks_enabled = os.environ["HOOKS_ENABLED"].lower()
force = os.environ["FORCE"].lower() == "true"

def toml_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')

if dst.exists() and not force:
    content = dst.read_text(encoding="utf-8")
    backup = dst.with_name(dst.name + ".bak")
    backup.write_text(content, encoding="utf-8")
else:
    content = src.read_text(encoding="utf-8")

content = content.replace("__UV_PATH__", toml_string(uv_path))

features_re = re.compile(r"(?ms)^\[features\]\s*\n.*?(?=^\[|\Z)")
match = features_re.search(content)
if match:
    section = match.group(0)
    if re.search(r"(?m)^\s*hooks\s*=", section):
        section = re.sub(r"(?m)^(\s*hooks\s*=\s*)(true|false)", rf"\g<1>{hooks_enabled}", section, count=1)
    else:
        section = section.rstrip() + f"\nhooks = {hooks_enabled}\n"
    content = content[: match.start()] + section + content[match.end() :]
else:
    content = content.rstrip() + f"\n\n[features]\nhooks = {hooks_enabled}\n"

content = re.sub(r"(?ms)^\[mcp_servers\.markitdown\]\s*\n.*?(?=^\[|\Z)", "", content).rstrip()
content += (
    "\n\n[mcp_servers.markitdown]\n"
    f'command = "{toml_string(uv_path)}"\n'
    'args = ["tool", "run", "markitdown-mcp"]\n'
)
content = re.sub(r"(?ms)^\[mcp_servers\.openaiDeveloperDocs\]\s*\n.*?(?=^\[|\Z)", "", content).rstrip()
content += (
    "\n\n[mcp_servers.openaiDeveloperDocs]\n"
    'url = "https://developers.openai.com/mcp"\n'
)

dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_text(content, encoding="utf-8")
PY
    echo "  + ~/.codex/config.toml"
}

install_hooks() {
    local hooks_enabled="$1"
    local py_cmd
    if [ "$hooks_enabled" != true ]; then
        echo "  Codex hard hooks disabled."
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  [DryRun] would install Codex hooks."
        return
    fi

    py_cmd="$(python_cmd)"
    mkdir -p "$CODEX_DST/hooks"
    if [ "$FORCE" = true ]; then
        rm -rf "$CODEX_DST/hooks"
        cp -R "$CODEX_SRC/hooks" "$CODEX_DST/hooks"
    else
        cp -R "$CODEX_SRC/hooks/." "$CODEX_DST/hooks/"
    fi

    local hook_script="$CODEX_DST/hooks/dcg_filter.py"
    HOOKS_JSON_SRC="$CODEX_SRC/hooks.json" HOOKS_JSON_DST="$CODEX_DST/hooks.json" HOOK_COMMAND="$py_cmd \"$hook_script\"" "$py_cmd" - <<'PY'
from __future__ import annotations

import json
import os
from pathlib import Path

src = Path(os.environ["HOOKS_JSON_SRC"])
dst = Path(os.environ["HOOKS_JSON_DST"])
command = os.environ["HOOK_COMMAND"]
raw = src.read_text(encoding="utf-8")
raw = raw.replace("__DCG_HOOK_COMMAND__", command.replace("\\", "\\\\").replace('"', '\\"'))
json.loads(raw)
dst.write_text(raw, encoding="utf-8")
PY
    echo "  + ~/.codex/hooks.json"
    echo "  + ~/.codex/hooks/"
}

echo ""
echo "========================================"
echo "  Codex configuration restore"
echo "========================================"
[ "$DRY_RUN" = true ] && echo "[DryRun] no files will be changed."
[ "$FORCE" = true ] && echo "[Force] existing Codex managed files may be overwritten."
echo ""

[ -d "$CODEX_SRC" ] || { echo "Codex source directory not found: $CODEX_SRC" >&2; exit 1; }

if [ "$DRY_RUN" = true ]; then
    echo "  [DryRun] would ensure $CODEX_DST"
else
    mkdir -p "$CODEX_DST"
fi

if [ "$DRY_RUN" = true ]; then
    echo "  [DryRun] $CODEX_SRC/AGENTS.md -> $CODEX_DST/AGENTS.md"
    echo "  [DryRun] $CODEX_SRC/skills -> $CODEX_DST/skills"
else
    [ -f "$CODEX_DST/AGENTS.md" ] && cp "$CODEX_DST/AGENTS.md" "$CODEX_DST/AGENTS.md.bak_$(date +%Y%m%d_%H%M%S)"
    cp "$CODEX_SRC/AGENTS.md" "$CODEX_DST/AGENTS.md"
    echo "  + ~/.codex/AGENTS.md"

    copy_managed_skills
    echo "  + ~/.codex/skills/"
fi

UV_PATH="$(install_uv_if_missing)"
if install_dcg_if_requested && [ "$DISABLE_DCG_HOOKS" = false ] && [ "$SKIP_DCG" = false ]; then
    HOOKS_ENABLED=true
else
    HOOKS_ENABLED=false
fi

merge_codex_config "$UV_PATH" "$HOOKS_ENABLED"
install_hooks "$HOOKS_ENABLED"

echo ""
echo "Done. Restart Codex to reload AGENTS.md, skills, MCP servers, and hooks."
