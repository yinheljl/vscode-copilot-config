#!/usr/bin/env python3
"""校验 VERSION 文件与 README.md 中的版本号是否一致。"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
README = (ROOT / "README.md").read_text(encoding="utf-8")

# 匹配「当前版本：`X.Y.Z`」或「当前版本：X.Y.Z」
pattern = re.compile(r"当前版本：`?([0-9][0-9.\-A-Za-z]*)`?")
match = pattern.search(README)
if not match:
    print("X 未在 README.md 中找到「当前版本：」字段")
    sys.exit(1)

readme_ver = match.group(1)
if readme_ver != VERSION:
    print(f"X VERSION ({VERSION}) 与 README.md ({readme_ver}) 不一致")
    sys.exit(1)

print(f"OK VERSION={VERSION} 与 README 同步")
