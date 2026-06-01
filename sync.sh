#!/usr/bin/env bash
# Sync local Codex user-authored configuration back into this repository.

set -euo pipefail

DRY_RUN=false
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force) FORCE=true ;;
        -h|--help)
            cat <<'EOF'
Usage: bash sync.sh [options]

Options:
  --dry-run   Print planned sync without writing files
  --force     Replace existing skill directories before copying
EOF
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_SRC="$HOME/.codex"
CODEX_DST="$SCRIPT_DIR/codex"

echo ""
echo "========================================"
echo "  Sync Codex config into repository"
echo "========================================"
echo ""

[ -d "$CODEX_SRC" ] || { echo "Local Codex directory not found: $CODEX_SRC" >&2; exit 1; }

if [ "$DRY_RUN" = true ]; then
    echo "  [DryRun] $CODEX_SRC/AGENTS.md -> $CODEX_DST/AGENTS.md"
    echo "  [DryRun] $CODEX_SRC/skills -> $CODEX_DST/skills"
    exit 0
fi

mkdir -p "$CODEX_DST"

if [ -f "$CODEX_SRC/AGENTS.md" ]; then
    cp -f "$CODEX_SRC/AGENTS.md" "$CODEX_DST/AGENTS.md"
    echo "  + codex/AGENTS.md"
else
    echo "  - ~/.codex/AGENTS.md not found; skipped" >&2
fi

if [ -d "$CODEX_SRC/skills" ]; then
    mkdir -p "$CODEX_DST/skills"
    synced=0
    for dir in "$CODEX_SRC"/skills/*/; do
        [ -d "$dir" ] || continue
        name="$(basename "$dir")"
        case "$name" in
            .system|codex-primary-runtime) continue ;;
        esac
        target="$CODEX_DST/skills/$name"
        if [ -d "$target" ] && [ "$FORCE" = true ]; then
            rm -rf "$target"
        fi
        mkdir -p "$target"
        cp -R "$dir"/. "$target"/
        synced=$((synced + 1))
    done
    echo "  + codex/skills/ ($synced skills)"
else
    echo "  - ~/.codex/skills not found; skipped" >&2
fi

echo ""
echo "Templates not synced: codex/config.toml, codex/hooks.json, codex/hooks/."
echo "Review git diff before committing."
