#!/usr/bin/env python3
"""
pre_tool_use_guard.py 的最小自检测试。

用法：
    python codex/hooks/test_pre_tool_use_guard.py

通过条件：所有 DENY case 必须返回 deny；所有 ALLOW case 必须放行。
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
GUARD = ROOT / "pre_tool_use_guard.py"

# (case_name, command, expected: 'deny' or 'allow')
CASES: list[tuple[str, str, str]] = [
    # -------- DENY (硬拦截) --------
    ("rm -rf /",                        "rm -rf /",                                          "deny"),
    ("rm -rf ~",                        "rm -rf ~",                                          "deny"),
    ("rm -rf $HOME",                    "rm -rf $HOME",                                      "deny"),
    ("rm -rf /etc",                     "rm -rf /etc",                                       "deny"),
    ("rm --no-preserve-root",           "rm -rf --no-preserve-root /",                       "deny"),
    ("rmdir F:\\",                      "rmdir /s /q F:\\",                                  "deny"),
    ("Remove-Item C:\\",                "Remove-Item -Recurse -Force C:\\",                  "deny"),
    ("powershell-cmd-rmdir",            "powershell -Command \"cmd /c rmdir /s /q F:\\foo\"", "deny"),
    ("git push --force",                "git push --force origin main",                      "deny"),
    ("mkfs.ext4",                       "mkfs.ext4 /dev/sda1",                               "deny"),
    ("dd of=/dev/sda",                  "dd if=/dev/zero of=/dev/sda bs=1M",                 "deny"),
    ("DROP DATABASE",                   "psql -c 'DROP DATABASE prod;'",                     "deny"),
    ("TRUNCATE TABLE",                  "mysql -e 'TRUNCATE TABLE users;'",                  "deny"),
    ("terraform destroy",               "terraform destroy -auto-approve",                   "deny"),
    ("aws s3 rb --force",               "aws s3 rb s3://my-bucket --force",                  "deny"),
    ("kubectl delete namespace",        "kubectl delete namespace prod",                     "deny"),
    ("chmod -R 777 /",                  "chmod -R 777 /",                                    "deny"),

    # -------- ALLOW (放行，灰名单仅记录) --------
    ("rm -rf node_modules (allowed)",   "rm -rf node_modules",                               "allow"),
    ("git reset --hard HEAD~1 (ask)",   "git reset --hard HEAD~1",                           "allow"),
    ("git push --force-with-lease",     "git push --force-with-lease origin main",           "allow"),
    ("git clean -nd (dry-run)",         "git clean -nd",                                     "allow"),
    ("ls -la",                          "ls -la",                                            "allow"),
    ("python script.py",                "python script.py --arg",                            "allow"),
    ("docker compose down",             "docker compose down",                               "allow"),
    ("npm install",                     "npm install",                                       "allow"),
    ("Remove-Item single file",         "Remove-Item ./tmp.log",                             "allow"),
]


def run_guard(command: str) -> tuple[int, str]:
    payload = {
        "tool_name": "Bash",
        "tool_input": {"command": command},
        "session_id": "test",
        "cwd": str(ROOT),
    }
    proc = subprocess.run(
        [sys.executable, str(GUARD)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        timeout=10,
    )
    return proc.returncode, proc.stdout


def main() -> int:
    failed: list[str] = []
    for name, cmd, expected in CASES:
        rc, out = run_guard(cmd)
        is_deny = False
        if out.strip():
            try:
                resp = json.loads(out)
                is_deny = (
                    resp.get("hookSpecificOutput", {}).get("permissionDecision") == "deny"
                )
            except json.JSONDecodeError:
                pass
        actual = "deny" if is_deny else "allow"
        ok = (actual == expected)
        marker = "OK " if ok else "FAIL"
        print(f"  {marker}  [{actual:5}] {name}: {cmd}")
        if not ok:
            failed.append(name)

    print("")
    if failed:
        print(f"X  {len(failed)} 用例失败：")
        for f in failed:
            print(f"   - {f}")
        return 1
    print(f"OK  全部 {len(CASES)} 个用例通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
