#!/usr/bin/env python3
"""
校验仓库中的所有配置模板是否合法：
- JSON：vscode/mcp.json, cursor/mcp.json
- JSONC：vscode/settings.json, cursor/settings.json
- TOML：codex/config.toml

供 GitHub Actions 与本地手动校验复用。
"""
import json
import re
import sys
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

PURE_JSON = [
    "vscode/mcp.json",
    "cursor/mcp.json",
]
JSONC = [
    "vscode/settings.json",
    "cursor/settings.json",
]
TOML_FILES = [
    "codex/config.toml",
]


def strip_jsonc(raw: str) -> str:
    placeholders: list[str] = []

    def keep(m: re.Match[str]) -> str:
        placeholders.append(m.group(0))
        return f"__STR_{len(placeholders)-1}__"

    s = re.sub(r'"(?:\\.|[^"\\])*"', keep, raw)
    s = re.sub(r"(?m)//[^\r\n]*", "", s)
    s = re.sub(r"(?s)/\*.*?\*/", "", s)
    s = re.sub(r",(\s*[}\]])", r"\1", s)
    for i, p in enumerate(placeholders):
        s = s.replace(f"__STR_{i}__", p)
    return s


def main() -> int:
    failed: list[tuple[str, str]] = []

    for rel in PURE_JSON:
        path = ROOT / rel
        try:
            json.loads(path.read_text(encoding="utf-8"))
            print(f"  OK  {rel}")
        except Exception as e:
            failed.append((rel, f"JSON 解析失败: {e}"))

    for rel in JSONC:
        path = ROOT / rel
        try:
            json.loads(strip_jsonc(path.read_text(encoding="utf-8")))
            print(f"  OK  {rel} (JSONC)")
        except Exception as e:
            failed.append((rel, f"JSONC 解析失败: {e}"))

    for rel in TOML_FILES:
        path = ROOT / rel
        try:
            with path.open("rb") as f:
                tomllib.load(f)
            print(f"  OK  {rel}")
        except Exception as e:
            failed.append((rel, f"TOML 解析失败: {e}"))

    if failed:
        print("\n校验失败：")
        for rel, msg in failed:
            print(f"  X  {rel}: {msg}")
        return 1

    print("\n所有模板校验通过。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
