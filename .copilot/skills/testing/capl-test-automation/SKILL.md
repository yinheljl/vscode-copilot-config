---
name: capl-test-automation
description: Guides writing and understanding CAPL (CAN Access Programming Language) scripts for Vector CANoe/CANalyzer test automation. Use when creating CAPL automation scripts, UDS/CAN test sequences, or debugging CAPL code. References Vector CAPL documentation.
---

# CAPL Test Automation

Guides writing and understanding CAPL scripts for Vector CANoe/CANalyzer diagnostic and bus test automation.

## Minimum Inputs

- **Task description**: e.g., "send UDS 0x22 request", "monitor CAN traffic", "verify response timing"
- **Optional**: CAN ID, DLC, payload; DBC/signal names; timing requirements (ms)

## Evidence Discipline

Output must include:
- CAPL code with event handlers (on timer, on message, on signal)
- Comments for key logic and timing
- Note on bus/channel if multi-channel setup

## Constraints

- CAPL is event-driven: no blocking loops in handlers; use timers for delays
- Use `output()` for sending; `this` for received message in `on message`
- Do not assume CANoe version; use common CAPL syntax (compatible with CANoe 10+)

## Supported CAPL Constructs

| 类型 | 语法示例 | 说明 |
|------|----------|------|
| 变量 | `variables { mstimer t; message 0x7DF msg; }` | 声明定时器、消息 |
| 定时器 | `setTimer(t, 100);` `on timer t { ... }` | 毫秒级延时，事件驱动 |
| 发送 | `output(msg);` `output(this);` | 发送 CAN 报文 |
| 接收 | `on message 0x7E8 { ... }` | 按 ID 接收 |
| 信号 | `on signal EngineSpeed { ... }` | 需 DBC 绑定 |
| 诊断 | `diagRequest ... diagSendRequest` | 使用 CDD/ODX 时 |

## UDS 常用模式

- **TesterPresent**: 周期发送 0x3E 保持会话
- **ReadDID**: 0x22 + DID，等待 0x62 响应
- **P2/P2* 超时**: 用 `setTimer` 实现响应超时检测

## Reference Standards

- Vector CAPL Programming Guide
- CANoe/CANalyzer 帮助文档
- ISO 14229（UDS 与 CAPL 诊断节点配合）
