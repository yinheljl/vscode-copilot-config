---
name: can-log-triage
description: Triages CAN bus log files for anomalies, extracts abnormal frames, and suggests troubleshooting directions. Use when analyzing CAN logs, DBC files, or diagnosing vehicle communication issues. References ISO 11898, common DBC parsing practices.
---

# CAN Log Triage

Guides analysis of CAN bus log files to identify anomalies and suggest troubleshooting steps.

## Supported Log File Extensions

| 后缀 | 格式 | 说明 |
|------|------|------|
| .asc | Vector ASCII | Vector CANalyzer/CANoe 文本格式 |
| .blf | Binary Logging Format | Vector 二进制格式 |
| .csv | Comma-Separated Values | 通用 CSV，需含时间戳、ID、数据 |
| .trc | PCAN Trace | PEAK PCAN 格式 |
| .log | 通用文本 | 需符合常见 CAN 日志结构（时间 ID 数据） |

未列出的格式需用户提供解析说明或转换后再分析。

## Minimum Inputs

- **Log file path**: 支持上述后缀的 CAN 日志文件
- **Optional**: DBC file path for signal decoding; target CAN IDs or time range

## Evidence Discipline

Output must include:
- Summary table: abnormal frame count, ID list, time range
- Per-ID anomaly description (e.g., missing, stuck, burst)
- Suggested root causes (e.g., ECU reset, bus-off, wiring)
- Recommended next steps (scope, DBC check, ECU logs)

## Constraints

- Read-only: do not modify source logs
- If DBC unavailable, report raw hex; do not guess signal names without DBC
- Clearly mark "requires DBC" when signal-level analysis is needed

## Workflow

1. **Load log**: Parse log format, extract frame list
2. **Baseline**: Identify expected IDs from DBC or first N seconds
3. **Anomaly detection**: Missing IDs, stuck values, error frames, bus-off
4. **Report**: Structured output per Evidence Discipline

## Reference Standards

- ISO 11898 (CAN physical/data link)
- Common DBC (Vector/PEAK) conventions for signal extraction
