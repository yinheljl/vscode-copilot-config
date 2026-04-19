#!/usr/bin/env python3
"""
Codex PreToolUse 硬兜底 hook - 拦截破坏性 Bash 命令。

由 ~/.codex/hooks.json 在每次 Bash 工具调用前同步执行：

    python3 ~/.codex/hooks/pre_tool_use_guard.py

Codex 会通过 stdin 传入 JSON：
    {
      "tool_name": "Bash",
      "tool_input": {"command": "...", "description": "..."},
      "session_id": "...", "cwd": "...", ...
    }

返回（stdout）以下结构即可阻止命令执行：
    {
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": "..."
      }
    }

退出码 0 = 放行；非 0 也会被 Codex 视为软失败但**不阻断**——所以阻断必须靠 stdout。

零依赖：仅使用 Python 3.8+ 标准库。
"""
from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path

# ============================================================
# 拦截规则
# ============================================================
# DENY = 直接拒绝，不允许执行
# ASK  = 仅记录到日志（Codex 当前 PreToolUse 没有"询问用户"语义，
#        想询问需要 deny + 让模型重新规划。我们记录后放行，
#        软层 destructive-command-guard SKILL.md 会让模型自己问。）

_DRIVE_ROOT = r"[A-Za-z]:[\\/]+"  # C:\, D:/, etc.

DENY_PATTERNS: list[tuple[str, str]] = [
    # 1) 删根 / 删 home
    (r"\brm\s+(?:-[a-zA-Z]*r[a-zA-Z]*\s+)?(?:-[a-zA-Z]*f[a-zA-Z]*\s+)?(?:--no-preserve-root\s+)?/\s*$",
     "rm 直接指向根目录 /"),
    (r"\brm\s+-[rRf]+\s+--no-preserve-root\b", "rm --no-preserve-root（强制删根）"),
    (r"\brm\s+-[rRf]+\s+(?:~|\$HOME|\$\{HOME\})(?:\s|/|$)",
     "rm 删除用户家目录"),
    (r"\brm\s+-[rRf]+\s+/\*", "rm 删除根目录所有文件"),
    (r"\brm\s+-[rRf]+\s+/(?:bin|boot|dev|etc|home|lib|opt|root|sbin|srv|sys|usr|var)(?:/?\s|$)",
     "rm 删除系统关键目录"),

    # 2) Windows: 删盘符根
    (rf"(?:Remove-Item|ri|del|rmdir|rd)\b.*(?:-Recurse|/s|/S).*\s{_DRIVE_ROOT}\s*['\"]?\s*$",
     "Remove-Item / rmdir /s 指向驱动器根（C:\\、D:\\ 等）"),
    (rf"\brmdir\s+/[sS]\s+/[qQ]\s+{_DRIVE_ROOT}\s*['\"]?\s*$",
     "rmdir /s /q 指向驱动器根"),
    (rf"\bdel\s+/[fFsSqQ /]+\s+{_DRIVE_ROOT}",
     "del /f/s/q 指向驱动器根"),

    # 3) PowerShell × cmd 嵌套（F 盘事故根因）
    (r"powershell(?:\.exe)?[^|;&]*\b(?:cmd(?:\.exe)?|cmd\s*/c)\b[^|;&]*\b(?:rmdir|del|rd)\b",
     "PowerShell 调用 cmd 执行删除——历史上的 F 盘事故根因"),
    (r"cmd(?:\.exe)?\s*/c\s+powershell[^|;&]*\bRemove-Item\b",
     "cmd 调用 PowerShell 删除——同上风险"),

    # 4) Git 强制覆盖远程
    (r"\bgit\s+push\s+(?:.*\s)?--force\b(?!.*--force-with-lease)(?!-with-lease)",
     "git push --force 不带 --force-with-lease"),
    (r"\bgit\s+push\s+(?:.*\s)?-f\b(?!.*--force-with-lease)",
     "git push -f 不带 --force-with-lease"),

    # 5) 磁盘 / 卷格式化
    (r"\bmkfs\.\w+\b", "mkfs 文件系统格式化"),
    (r"\bFormat-Volume\b", "PowerShell Format-Volume"),
    (r"\b(?:format|diskpart)\b\s+[A-Za-z]:", "format / diskpart 针对盘符"),
    (r"\bdd\s+if=.+\s+of=/dev/", "dd 写入 /dev/ 设备"),

    # 6) 数据库不可逆
    (r"\bDROP\s+(?:DATABASE|SCHEMA)\b", "SQL DROP DATABASE/SCHEMA"),
    (r"\bTRUNCATE\s+TABLE\b", "SQL TRUNCATE TABLE"),
    (r"FLUSHALL\b", "Redis FLUSHALL"),

    # 7) 云资源不可逆
    (r"\bterraform\s+destroy\b(?!.*--target)", "terraform destroy 全量销毁"),
    (r"\baws\s+s3\s+rb\b.*--force", "aws s3 rb --force"),
    (r"\bkubectl\s+delete\s+(?:namespace|ns|pv|persistentvolume)\b", "kubectl delete namespace/pv"),
    (r"\bgcloud\s+projects\s+delete\b", "gcloud projects delete"),

    # 8) 系统级提权 / 危险开放
    (r"\bchmod\s+-R\s+777\s+/(?:\s|$)", "chmod -R 777 /"),
    (r"\bSet-ExecutionPolicy\b.*\bUnrestricted\b.*\b(?:LocalMachine|MachinePolicy)\b",
     "Set-ExecutionPolicy Unrestricted 系统级"),
]

# 仅记录、不拦截（"灰名单"），写入审计日志，让用户事后能查
ASK_PATTERNS: list[tuple[str, str]] = [
    (r"\brm\s+-[rRf]+\s+", "rm -rf"),
    (r"\b(?:Remove-Item|ri)\b.*-Recurse", "Remove-Item -Recurse"),
    (r"\bgit\s+reset\s+--hard\b", "git reset --hard"),
    (r"\bgit\s+clean\s+-[fdx]+", "git clean -fd"),
    (r"\bgit\s+branch\s+-D\b", "git branch -D"),
    (r"\bgit\s+stash\s+(?:drop|clear)\b", "git stash drop/clear"),
    (r"\bgit\s+filter-(?:branch|repo)\b", "git filter-branch"),
    (r"\bDELETE\s+FROM\s+\w+\s*;", "DELETE FROM ... 不带 WHERE"),
]

LOG_DIR = Path.home() / ".codex" / "hooks" / "logs"


def deny(reason: str, command: str, matched: str) -> dict:
    """构造 deny 输出。permissionDecisionReason 会被注入到模型上下文中，让模型自己复盘。"""
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                f"[destructive-command-guard] 已拦截高危命令：{reason}\n"
                f"匹配模式：{matched}\n"
                f"命令片段：{command[:200]}\n"
                "若你确实需要执行此操作，请：\n"
                "  1) 通过 AskQuestion 工具向用户解释清楚（路径、影响、是否可逆）\n"
                "  2) 在用户明确 confirm 后，改用更安全的等价方式（如先 dry-run、用回收站、加 --force-with-lease 等）\n"
                "  3) 若用户依然要求强制执行，请提示用户临时移除 ~/.codex/hooks.json 中的 PreToolUse 段，"
                "   或在仓库根目录创建 .codex-allow-destructive 文件后重试。"
            ),
        }
    }


def write_audit(entry: dict) -> None:
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        log_file = LOG_DIR / f"guard-{datetime.now().strftime('%Y%m')}.log"
        with log_file.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception:
        # 日志失败不应影响放行决策
        pass


def is_bypass_allowed(cwd: str) -> bool:
    """允许在仓库根放置 .codex-allow-destructive 文件来临时关闭拦截（供有意识的用户使用）。"""
    try:
        return (Path(cwd) / ".codex-allow-destructive").exists()
    except Exception:
        return False


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        # 无法解析输入：放行，但记录
        write_audit({
            "ts": datetime.now().isoformat(),
            "event": "parse_error",
            "stdin_size": -1,
        })
        return 0

    if payload.get("tool_name") != "Bash":
        return 0

    tool_input = payload.get("tool_input") or {}
    command = (tool_input.get("command") or "").strip()
    cwd = payload.get("cwd") or ""

    if not command:
        return 0

    # 用户显式 bypass
    if is_bypass_allowed(cwd):
        write_audit({
            "ts": datetime.now().isoformat(),
            "event": "bypass",
            "session_id": payload.get("session_id"),
            "cwd": cwd,
            "command": command[:500],
        })
        return 0

    # 1) DENY 优先
    for pat, reason in DENY_PATTERNS:
        if re.search(pat, command, flags=re.IGNORECASE | re.MULTILINE):
            write_audit({
                "ts": datetime.now().isoformat(),
                "event": "deny",
                "reason": reason,
                "pattern": pat,
                "session_id": payload.get("session_id"),
                "cwd": cwd,
                "command": command[:500],
            })
            sys.stdout.write(json.dumps(deny(reason, command, pat), ensure_ascii=False))
            sys.stdout.flush()
            return 0

    # 2) ASK：仅审计，不拦截（让上层 SKILL.md 软规则去引导模型 AskQuestion）
    for pat, reason in ASK_PATTERNS:
        if re.search(pat, command, flags=re.IGNORECASE | re.MULTILINE):
            write_audit({
                "ts": datetime.now().isoformat(),
                "event": "ask",
                "reason": reason,
                "pattern": pat,
                "session_id": payload.get("session_id"),
                "cwd": cwd,
                "command": command[:500],
            })
            break

    return 0


if __name__ == "__main__":
    sys.exit(main())
