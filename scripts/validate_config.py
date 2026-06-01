#!/usr/bin/env python3
"""Validate Codex-only configuration templates."""

from __future__ import annotations

import json
import sys
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

JSON_FILES = [
    "codex/hooks.json",
]

TOML_FILES = [
    "codex/config.toml",
]

REQUIRED_PATHS = [
    "codex/AGENTS.md",
    "codex/skills/destructive-command-guard/SKILL.md",
    "codex/hooks/dcg_filter.py",
    "codex/hooks/dcg_filter.ps1",
]


def main() -> int:
    failed: list[tuple[str, str]] = []

    for rel in REQUIRED_PATHS:
        if not (ROOT / rel).exists():
            failed.append((rel, "required Codex file is missing"))
        else:
            print(f"  OK  {rel}")

    for rel in JSON_FILES:
        path = ROOT / rel
        try:
            json.loads(path.read_text(encoding="utf-8"))
            print(f"  OK  {rel}")
        except Exception as exc:  # noqa: BLE001 - report validator failures clearly
            failed.append((rel, f"JSON parse failed: {exc}"))

    for rel in TOML_FILES:
        path = ROOT / rel
        try:
            with path.open("rb") as f:
                tomllib.load(f)
            print(f"  OK  {rel}")
        except Exception as exc:  # noqa: BLE001
            failed.append((rel, f"TOML parse failed: {exc}"))

    if failed:
        print("\nValidation failed:")
        for rel, message in failed:
            print(f"  X  {rel}: {message}")
        return 1

    print("\nCodex configuration templates validated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
