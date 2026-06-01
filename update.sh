#!/usr/bin/env bash
# Pull the latest Codex-only configuration and restore it locally.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/REPO_URL" ]; then
    REPO_URL="$(tr -d '[:space:]' < "$SCRIPT_DIR/REPO_URL")"
else
    REPO_URL="https://github.com/yinheljl/ai-agent-config.git"
fi
REPO_BRANCH="${REPO_BRANCH:-codex/codex-setup-doc}"

if [ -f "$SCRIPT_DIR/VERSION" ]; then
    REPO_DIR="$SCRIPT_DIR"
elif [ -f "$PWD/VERSION" ]; then
    REPO_DIR="$PWD"
else
    REPO_DIR="$HOME/.ai-agent-config"
fi

DRY_RUN=false
CHECK_ONLY=false
RESTORE_ARGS=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true; RESTORE_ARGS="$RESTORE_ARGS $arg" ;;
        --check-only) CHECK_ONLY=true ;;
        --force|--auto-install-dcg|--disable-dcg-hooks|--skip-dcg) RESTORE_ARGS="$RESTORE_ARGS $arg" ;;
        -h|--help)
            cat <<'EOF'
Usage: bash update.sh [options]

Options:
  --dry-run
  --check-only
  --force
  --auto-install-dcg
  --disable-dcg-hooks
  --skip-dcg
EOF
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

get_local_version() {
    if [ -f "$1/VERSION" ]; then
        tr -d '[:space:]' < "$1/VERSION"
    else
        echo "0.0.0"
    fi
}

get_remote_version() {
    local raw_url="${REPO_URL%.git}"
    raw_url="${raw_url//github.com/raw.githubusercontent.com}/$REPO_BRANCH/VERSION"
    curl -fsSL "$raw_url" 2>/dev/null | tr -d '[:space:]' || true
}

echo ""
echo "========================================"
echo "  Codex configuration update"
echo "========================================"
echo ""

LOCAL_VER="$(get_local_version "$REPO_DIR")"
REMOTE_VER="$(get_remote_version)"
echo "Local version:  $LOCAL_VER"
echo "Remote version: ${REMOTE_VER:-unknown}"

if [ "$CHECK_ONLY" = true ]; then
    if [ -n "$REMOTE_VER" ] && [ "$LOCAL_VER" != "$REMOTE_VER" ]; then
        echo "Update available: $LOCAL_VER -> $REMOTE_VER" >&2
        exit 1
    fi
    echo "Already up to date."
    exit 0
fi

echo ""
echo "[1/2] Sync repository"
if [ -d "$REPO_DIR/.git" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "  [DryRun] git fetch origin $REPO_BRANCH"
        echo "  [DryRun] git switch $REPO_BRANCH"
        echo "  [DryRun] git pull --ff-only origin $REPO_BRANCH"
    else
        current_branch="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)"
        if [ "$current_branch" != "$REPO_BRANCH" ]; then
            git -C "$REPO_DIR" fetch origin "$REPO_BRANCH"
            git -C "$REPO_DIR" switch "$REPO_BRANCH"
        fi
        git -C "$REPO_DIR" pull --ff-only origin "$REPO_BRANCH"
    fi
else
    command -v git >/dev/null 2>&1 || {
        echo "git is required for first-time update. Install git or clone $REPO_URL manually." >&2
        exit 1
    }
    if [ "$DRY_RUN" = true ]; then
        echo "  [DryRun] git clone --branch $REPO_BRANCH --single-branch $REPO_URL $REPO_DIR"
    else
        git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$REPO_DIR"
    fi
fi

echo ""
echo "[2/2] Restore Codex configuration"
RESTORE_SCRIPT="$REPO_DIR/restore.sh"
[ -f "$RESTORE_SCRIPT" ] || { echo "restore.sh not found: $RESTORE_SCRIPT" >&2; exit 1; }
bash "$RESTORE_SCRIPT" $RESTORE_ARGS
