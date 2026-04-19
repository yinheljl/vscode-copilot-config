#!/usr/bin/env bash
# cleanup.sh —— 扫描并清理 AI Agent 长任务后堆积的工程级缓存与临时文件
#
# 安全设计：
#   * 默认 DryRun：仅扫描 + 打印大小，不删任何文件
#   * 仅匹配明确的可重建缓存目录名（白名单），不会动源码 / .git
#   * 必须显式加 --apply 才会真正删除
#   * 全局缓存目录（~/.cache、~/.npm 等）只显示大小并给出推荐命令，不主动删
#
# 用法：
#   bash cleanup.sh                                # DryRun
#   bash cleanup.sh --apply                        # 实际清理
#   bash cleanup.sh --path /home/me/projects --apply
#   bash cleanup.sh --skip-global

set -euo pipefail

PATH_ARG="$(pwd)"
APPLY=0
MAX_DEPTH=5
SKIP_GLOBAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)        PATH_ARG="$2"; shift 2 ;;
    --path=*)      PATH_ARG="${1#*=}"; shift ;;
    --apply)       APPLY=1; shift ;;
    --max-depth)   MAX_DEPTH="$2"; shift 2 ;;
    --max-depth=*) MAX_DEPTH="${1#*=}"; shift ;;
    --skip-global) SKIP_GLOBAL=1; shift ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 1 ;;
  esac
done

CACHE_NAMES=(
  node_modules __pycache__ .pytest_cache .mypy_cache .ruff_cache
  .next .nuxt .turbo .svelte-kit .parcel-cache
  dist build out .gradle target .tox
)

human_size() {
  local b=$1
  if (( b >= 1073741824 )); then awk -v b="$b" 'BEGIN{printf "%9.2f GB", b/1073741824}'
  elif (( b >= 1048576 ));   then awk -v b="$b" 'BEGIN{printf "%9.2f MB", b/1048576}'
  elif (( b >= 1024 ));      then awk -v b="$b" 'BEGIN{printf "%9.2f KB", b/1024}'
  else printf "%9d B " "$b"
  fi
}

dir_size_bytes() {
  if [[ -d "$1" ]]; then
    du -sb "$1" 2>/dev/null | awk '{print $1}'
  else
    echo 0
  fi
}

mode_label() {
  if [[ $APPLY -eq 1 ]]; then echo "EXECUTE (will delete)"
  else echo "DRY-RUN (will not delete)"
  fi
}

echo
echo "============================================================"
echo "  AI Agent 缓存清理   模式：$(mode_label)"
echo "  扫描根目录：$PATH_ARG"
echo "  最大深度  ：$MAX_DEPTH"
echo "============================================================"
echo

if [[ ! -d "$PATH_ARG" ]]; then
  echo "错误：路径不存在：$PATH_ARG" >&2
  exit 1
fi

declare -a FOUND_PATHS=()
declare -a FOUND_BYTES=()
TOTAL=0

echo "正在扫描工程缓存目录（白名单匹配）..."
for name in "${CACHE_NAMES[@]}"; do
  count=0
  while IFS= read -r -d '' p; do
    sz=$(dir_size_bytes "$p")
    FOUND_PATHS+=("$p")
    FOUND_BYTES+=("$sz")
    TOTAL=$((TOTAL + sz))
    count=$((count + 1))
  done < <(find "$PATH_ARG" -maxdepth "$MAX_DEPTH" -type d -name "$name" -prune -print0 2>/dev/null)
  if (( count > 0 )); then
    printf "  [%3d] %s\n" "$count" "$name"
  fi
done

echo
if (( ${#FOUND_PATHS[@]} == 0 )); then
  echo "✓ 没有找到任何工程缓存目录，磁盘很干净。"
else
  echo "工程缓存清单（按大小降序，前 30）："
  paste <(printf '%s\n' "${FOUND_BYTES[@]}") <(printf '%s\n' "${FOUND_PATHS[@]}") \
    | sort -rn -k1,1 | head -n 30 \
    | while IFS=$'\t' read -r b p; do
        printf "  [%s]  %s\n" "$(human_size "$b")" "$p"
      done
  if (( ${#FOUND_PATHS[@]} > 30 )); then
    echo "  ... 还有 $(( ${#FOUND_PATHS[@]} - 30 )) 个未列出"
  fi
  echo
  echo "合计可释放：$(human_size "$TOTAL")（共 ${#FOUND_PATHS[@]} 个目录）"
fi

if (( APPLY == 1 )) && (( ${#FOUND_PATHS[@]} > 0 )); then
  echo
  echo "开始删除..."
  ok=0; fail=0; freed=0
  for i in "${!FOUND_PATHS[@]}"; do
    if rm -rf -- "${FOUND_PATHS[$i]}" 2>/dev/null; then
      ok=$((ok + 1))
      freed=$((freed + FOUND_BYTES[$i]))
    else
      echo "  失败 ${FOUND_PATHS[$i]}"
      fail=$((fail + 1))
    fi
  done
  echo
  echo "✓ 已删除 $ok 个目录，释放 $(human_size "$freed")（失败 $fail）"
fi

if (( SKIP_GLOBAL == 0 )); then
  echo
  echo "============================================================"
  echo "  全局缓存目录（仅报告大小，不主动删）"
  echo "============================================================"

  GLOBAL_DIRS=(
    "$HOME/.cache|rm -rf ~/.cache/<具体子目录>（不要直接删 ~/.cache）"
    "$HOME/.cache/huggingface|rm -rf ~/.cache/huggingface/hub"
    "$HOME/.npm/_cacache|npm cache clean --force"
    "$HOME/.cache/pip|pip cache purge"
    "$HOME/.cargo/registry/cache|cargo cache --autoclean (cargo install cargo-cache)"
    "$HOME/.gradle/caches|rm -rf ~/.gradle/caches"
    "$HOME/.cache/yarn|yarn cache clean"
    "$HOME/.pyenv|按需手动"
  )

  for entry in "${GLOBAL_DIRS[@]}"; do
    p="${entry%%|*}"
    hint="${entry##*|}"
    if [[ -d "$p" ]]; then
      sz=$(dir_size_bytes "$p")
      if (( sz > 0 )); then
        printf "  [%s]  %s\n" "$(human_size "$sz")" "$p"
        printf "              提示：%s\n" "$hint"
      fi
    fi
  done

  if command -v docker >/dev/null 2>&1; then
    echo
    echo "  Docker 占用："
    docker system df 2>/dev/null | sed 's/^/    /'
    echo "  推荐清理：docker system prune -af --volumes"
  fi
fi

if (( APPLY == 0 )); then
  echo
  echo "提示：当前是 DryRun 模式，未实际删除任何文件。"
  echo "若确认无误，重新运行并加 --apply 真正执行："
  echo "    bash cleanup.sh --path \"$PATH_ARG\" --apply"
fi

echo
