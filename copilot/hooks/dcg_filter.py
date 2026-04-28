#!/usr/bin/env python3
"""Low-noise GitHub Copilot preToolUse gate for dcg.

Copilot preToolUse hooks fire before every tool invocation.
This script only invokes dcg for Bash commands that look potentially destructive.

Copilot stdout schema: {"permissionDecision": "allow|deny", "permissionDecisionReason": "..."}
  - toolArgs is a JSON STRING: {"toolName":"bash","toolArgs":"{\"command\":\"...\"}"}
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
    | \b(chmod\s+-R\s+777|Set-ExecutionPolicy\s+Unrestricted)\b
    | \b(npm\s+uninstall\s+-g|pip\s+uninstall\s+-y)\b
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)


def approve() -> int:
    print(json.dumps({"permissionDecision": "allow"}, separators=(",", ":")))
    return 0


def deny(reason: str) -> int:
    print(json.dumps({
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }, separators=(",", ":")))
    return 0


def extract_command(event: object) -> str:
    if not isinstance(event, dict):
        return ""
    tool_name = event.get("toolName", "")
    if tool_name != "bash":
        return ""
    # Copilot: toolArgs is a JSON string, not a parsed object
    args = event.get("toolArgs")
    if isinstance(args, str):
        try:
            args = json.loads(args)
        except json.JSONDecodeError:
            return ""
    if isinstance(args, dict):
        cmd = args.get("command")
        return cmd if isinstance(cmd, str) else ""
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

    dcg = shutil.which("dcg") or shutil.which("dcg.exe")
    if not dcg:
        return approve()

    dcg_input = json.dumps({
        "tool_name": "Bash",
        "tool_input": {"command": command},
    }, separators=(",", ":"))

    proc = subprocess.run([dcg], input=dcg_input, text=True, capture_output=True)
    sys.stderr.write(proc.stderr)
    if proc.stdout.strip():
        try:
            decision = json.loads(proc.stdout)
            if decision.get("hookSpecificOutput", {}).get("permissionDecision") == "deny":
                return deny(f"BLOCKED by dcg. Use `dcg explain \"{command}\"` for details.")
        except (json.JSONDecodeError, AttributeError):
            pass
    return approve()


if __name__ == "__main__":
    raise SystemExit(main())
