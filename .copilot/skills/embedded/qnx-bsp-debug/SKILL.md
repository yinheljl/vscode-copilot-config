---
name: qnx-bsp-debug
description: Guides QNX BSP debugging for boot, drivers, and network. Use when debugging QNX BSP builds, startup failures, or driver issues.
---

# QNX BSP Debug

Provides structured debugging guidance for QNX Board Support Packages (BSP).

## Minimum Inputs

- **BSP path or log**: Path to BSP source/build, or boot/console log
- **Issue** (optional): e.g., "boot hang", "driver not loading", "network unreachable"

## Evidence Discipline

Output must include:
- Step-by-step checklist aligned with symptom
- Common causes and fixes (from QNX docs / BSP conventions)
- Log parsing hints (procnto, io-pkt, dev-*)
- Suggested commands (pidin, slog2info, etc.)

## Constraints

- Read-only guidance; do not modify BSP without explicit user request
- Distinguish QNX 7.x vs. 6.x where behavior differs
- Reference official QNX BSP guide where applicable

## Workflow

1. **Symptom classification**: Boot, driver, network, filesystem
2. **Checklist**: Per symptom, ordered by likelihood
3. **Log analysis**: Parse provided log for errors
4. **Next steps**: Commands, config changes, docs

## Reference Standards

- QNX BSP Developer's Guide
- QNX System Architecture
- QNX Momentics documentation
