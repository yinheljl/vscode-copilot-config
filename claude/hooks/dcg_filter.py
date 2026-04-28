#!/usr/bin/env python3
"""Low-noise Claude Code PreToolUse gate for dcg.

Claude Code PreToolUse hooks are invoked for every matching tool action.
This script only invokes dcg for commands that look potentially destructive;
otherwise it approves immediately.

Claude Code exit codes:
  exit 0  = allow (action proceeds)
  exit 2  = BLOCK (stderr message shown to Claude)
  exit 1  = non-blocking error (action still proceeds — do NOT use for blocking)
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
    | \b(chmod\s+-R\s+777|Set-ExecutionPolicy\s+Unrestricted)\b
    | \b(npm\s+uninstall\s+-g|pip\s+uninstall\s+-y)\b
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)

LOCAL_BLOCK_RE = re.compile(
    r"""
    (
      \b(sdelete|sdelete64)\b
    | \bvssadmin\s+delete\s+shadows\b
    | \bbcdedit\b[\s\S]*\s/delete\b
    | \bwevtutil\s+cl\b
    | \bwmic\s+path\s+win32_process\s+call\s+terminate\b
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)


def approve() -> int:
    return 0


def deny(reason: str) -> int:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }, separators=(",", ":")))
    return 0


def extract_command(event: object) -> str:
    if not isinstance(event, dict):
        return ""
    for key in ("tool_input", "toolInput"):
        value = event.get(key)
        if isinstance(value, dict) and isinstance(value.get("command"), str):
            return value["command"]
    value = event.get("command")
    return value if isinstance(value, str) else ""


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

    if isinstance(event, dict) and "tool_name" not in event and "toolName" not in event:
        event["tool_name"] = "Bash"
        payload = json.dumps(event, separators=(",", ":"))

    proc = subprocess.run([dcg], input=payload, text=True, capture_output=True)
    # dcg communicates decisions via stdout JSON (permissionDecision field), NOT exit code.
    # stderr contains the human-readable text block — pass it through to the user.
    sys.stderr.write(proc.stderr)
    if proc.stdout.strip():
        try:
            decision = json.loads(proc.stdout)
            if decision.get("hookSpecificOutput", {}).get("permissionDecision") in {"deny", "ask"}:
                # Claude Code processes PreToolUse permissionDecision JSON on exit 0.
                sys.stdout.write(proc.stdout)
                return 0
        except (json.JSONDecodeError, AttributeError):
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
