#!/usr/bin/env python3
"""Low-noise Windsurf Cascade pre_run_command gate for dcg.

Windsurf Cascade Hooks 的 pre_run_command 在每条 Cascade 命令执行前触发。
本脚本只对疑似破坏性命令调用 dcg，其余直接放行，避免 dcg 启动开销。

Windsurf 退出码协议：
  exit 0  = allow（命令继续）
  exit 2  = block（命令被阻止；stderr 文本显示在 Cascade UI）
"""

import json
import re
import shutil
import subprocess
import sys


RISK_RE = re.compile(
    r"""
    (
      \b(rm|del|rd|rmdir|Remove-Item|ri|erase)\b
    | \bfind\b[\s\S]*\s-delete\b
    | \bxargs\b[\s\S]*\b(rm|del|rmdir|Remove-Item)\b
    | \bgit\s+reset\b[\s\S]*\s--hard\b
    | \bgit\s+checkout\b[\s\S]*\s--\s+
    | \bgit\s+restore\b(?![\s\S]*\s--staged\b)
    | \bgit\s+clean\b
    | \bgit\s+branch\b[\s\S]*\s-D\b
    | \bgit\s+stash\s+(drop|clear)\b
    | \bgit\s+push\b[\s\S]*\s--force(?=\s|$)
    | \bgit\s+(filter-branch|filter-repo|rebase)\b
    | \b(DROP\s+(DATABASE|SCHEMA|TABLE)|TRUNCATE\s+TABLE|DELETE\s+FROM)\b
    | \bredis-cli\b[\s\S]*\bFLUSH(ALL|DB)\b
    | \b(kubectl|oc)\s+delete\b
    | \bterraform\s+destroy\b
    | \b(cdk|pulumi)\s+destroy\b
    | \b(docker|podman)\s+(system\s+prune|volume\s+rm|volume\s+prune|network\s+prune|container\s+prune|image\s+prune)\b
    | \b(aws\s+s3\s+rb|gcloud\s+projects\s+delete)\b
    | \b(Format-Volume|diskpart|mkfs(\.[A-Za-z0-9_+-]+)?|dd\s+if=|cipher\s+/w|fsutil)\b
    | \b(sdelete|sdelete64)\b
    | \bvssadmin\s+delete\s+shadows\b
    | \bbcdedit\b[\s\S]*\s/delete\b
    | \bwevtutil\s+cl\b
    | \bwmic\s+path\s+win32_process\s+call\s+terminate\b
    | \b(Get-CimInstance|gcim)\b[\s\S]*\bWin32_Process\b[\s\S]*\|\s*\b(Remove-CimInstance|rcim)\b
    | \b(Get-CimInstance|gcim)\b[\s\S]*\bWin32_Process\b[\s\S]*\|\s*\b(Invoke-CimMethod|icim)\b[\s\S]*\b-?MethodName\s+Terminate\b
    | \b(Invoke-CimMethod|icim)\b[\s\S]*\b-?ClassName\s+Win32_Process\b[\s\S]*\b-?MethodName\s+Terminate\b
    | \b(Invoke-CimMethod|icim)\b[\s\S]*\b-?MethodName\s+Terminate\b[\s\S]*\b-?ClassName\s+Win32_Process\b
    | \b(chmod\s+-R\s+777|Set-ExecutionPolicy\s+Unrestricted)\b
    | \b(npm\s+uninstall\s+-g|pip\s+uninstall\s+-y)\b
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)

LOCAL_BLOCK_RE = re.compile(
    r"""
    (
      ^\s*(Remove-Item|ri)\b
    | ^\s*(powershell|pwsh)(\.exe)?\b[\s\S]*\b(Remove-Item|ri|Format-Volume|diskpart|Set-ExecutionPolicy\s+Unrestricted)\b
    | ^\s*cmd(\.exe)?\s+/[cq]\s*["']?\s*(del|rd|rmdir|erase)\b
    | ^\s*(Format-Volume|diskpart)\b
    | \b(sdelete|sdelete64)\b
    | \bvssadmin\s+delete\s+shadows\b
    | \bbcdedit\b[\s\S]*\s/delete\b
    | \bwevtutil\s+cl\b
    | \bwmic\s+path\s+win32_process\s+call\s+terminate\b
    | \b(Get-CimInstance|gcim)\b[\s\S]*\bWin32_Process\b[\s\S]*\|\s*\b(Remove-CimInstance|rcim)\b
    | \b(Get-CimInstance|gcim)\b[\s\S]*\bWin32_Process\b[\s\S]*\|\s*\b(Invoke-CimMethod|icim)\b[\s\S]*\b-?MethodName\s+Terminate\b
    | \b(Invoke-CimMethod|icim)\b[\s\S]*\b-?ClassName\s+Win32_Process\b[\s\S]*\b-?MethodName\s+Terminate\b
    | \b(Invoke-CimMethod|icim)\b[\s\S]*\b-?MethodName\s+Terminate\b[\s\S]*\b-?ClassName\s+Win32_Process\b
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)


def approve() -> int:
    return 0


def deny(reason: str) -> int:
    print(reason, file=sys.stderr)
    return 2


def extract_command(event: object) -> str:
    # Windsurf pre_run_command: { agent_action_name, tool_info: { command_line, cwd } }
    if not isinstance(event, dict):
        return ""
    info = event.get("tool_info")
    if isinstance(info, dict) and isinstance(info.get("command_line"), str):
        return info["command_line"]
    return ""


def main() -> int:
    payload = sys.stdin.read()
    if not payload.strip():
        return approve()
    try:
        event = json.loads(payload)
    except json.JSONDecodeError:
        return approve()

    command = extract_command(event)
    if not command or not RISK_RE.search(command):
        return approve()
    if LOCAL_BLOCK_RE.search(command):
        return deny("BLOCKED by local destructive command guard. This Windows destructive command is not safely handled by dcg on this machine. Ask the user to run it manually if truly needed.")

    dcg = shutil.which("dcg") or shutil.which("dcg.exe")
    if not dcg:
        return approve()

    # dcg 期望 Claude PreToolUse 格式输入。把 Windsurf 的 pre_run_command 重新包装。
    dcg_payload = json.dumps({
        "tool_name": "Bash",
        "tool_input": {"command": command},
    }, separators=(",", ":"))

    proc = subprocess.run([dcg], input=dcg_payload, text=True, capture_output=True)
    # dcg 的 stderr 是人类可读的"为何阻止"原因，转发给 Windsurf show_output 显示。
    if proc.stderr:
        sys.stderr.write(proc.stderr)
    if proc.stdout.strip():
        try:
            decision = json.loads(proc.stdout)
            verdict = decision.get("hookSpecificOutput", {}).get("permissionDecision")
            # 用户选择：ask 也阻断（与 Claude 端语义对齐）
            if verdict in {"deny", "ask"}:
                return 2
        except (json.JSONDecodeError, AttributeError):
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
