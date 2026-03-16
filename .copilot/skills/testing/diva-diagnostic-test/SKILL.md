---
name: diva-diagnostic-test
description: Guides CANoe.DiVa diagnostic test configuration, ODX/CDD-based test generation, and VDS (Vector Diagnostic Scripting) for custom sequences. Use when configuring DiVa test modules, writing VDS scripts, or generating UDS diagnostic test cases from ODX. References Vector CANoe.DiVa documentation.
---

# DiVa Diagnostic Test

Guides CANoe.DiVa diagnostic test setup, ODX-based test generation, and VDS scripting for custom sequences.

## Minimum Inputs

- **Task**: e.g., "generate UDS test from ODX", "write VDS script for security access", "configure DiVa test module"
- **Optional**: ODX/CDD file path; target services (e.g., 0x22, 0x2E); protocol (UDS, KWP2000, OBD)

## Evidence Discipline

Output must include:
- Step-by-step configuration or script structure
- Reference to ODX/CDD elements where applicable
- Protocol/session/security considerations for UDS

## Constraints

- DiVa test generation requires valid ODX or CANdela (CDD) input
- VDS scripts are C#/VB.NET; run in Vector Indigo/CANoe/vFlash
- Do not invent ODX schema; reference ISO 22901-1 (ODX) where needed

## DiVa 主要能力

| 能力 | 说明 |
|------|------|
| 测试生成 | 从 ODX/CDD 自动生成正负向测试用例 |
| 协议验证 | 物理/功能寻址、时序、格式、会话/安全等级 |
| VDS 脚本 | C#/VB.NET 自定义诊断序列，可录制转脚本 |
| 集成 | 支持 CANoe、Indigo、HiL、CI/CD |

## VDS 脚本要点

- **语言**: C# 或 VB.NET
- **典型操作**: 发送诊断请求、解析响应、安全访问、读 DTC、刷写前后动作
- **录制**: CANoe/Indigo 中录制诊断序列可导出为 VDS 脚本

## ODX 与测试范围

- ODX 定义服务、DID、DTC、会话、安全等级
- DiVa 据此生成：有效请求测试、无效请求测试（NRC 验证）、时序测试

## Reference Standards

- Vector CANoe.DiVa 文档
- ISO 22901-1 (ODX)
- ISO 14229 (UDS)
- Vector VDS Library 文档
