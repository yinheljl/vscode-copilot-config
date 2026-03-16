---
applyTo: "**/*.c,**/*.h,**/*.cpp,**/*.py"
---
# 系统化调试策略

## 5步调试协议

```
1. REPRODUCE → 确认问题可稳定复现（间歇性问题先找触发条件）
2. ISOLATE   → 找最小失败案例（缩小到最少代码量）
3. DIAGNOSE  → 识别根本原因（不是症状，是原因）
4. FIX       → 最小化修复（不要顺手重构无关代码）
5. VERIFY    → 验证修复未引入新问题
```

## 嵌入式 / MCU 常见 Bug 模式

**硬件外设不工作**：按顺序排查 — ① 时钟使能（PCC/RCC）→ ② 寄存器读回验证写入生效 → ③ GPIO 方向（PDDR/MODER）→ ④ 引脚复用配置（MUX）

**栈溢出 / 内存踩踏**（症状：随机崩溃、Hardfault、变量莫名被改）：① 查 OS Task 栈峰值（`OsTaskStackUsage`）→ ② ISR/Task 内大数组改 `static` → ③ 用 Lauterbach/J-Link 查 stack canary

**并发 / 竞态**（症状：偶发错误，单步正常）：① ISR 与主循环共享变量必须加 `volatile` → ② 确认共享数据访问在 `SchM_Enter/Exit` 临界区内

**CAN / 通信不通**：物理层（终端电阻 120Ω）→ 波特率一致 → CanIf HRH 过滤 → PduR Tx/Rx 路径完整 → `Com_MainFunctionRx/Tx` 调用周期正确

**变量值异常（疑似被覆盖）**：设 Data Watchpoint 监视变量地址 → 断点触发时查调用栈 → 必要时用 J-Link/Lauterbach ETM trace 回溯

## 通用调试原则

**二分法（曾经正常现在坏）**：`git bisect` 定位引入 commit → 代码中间加断点缩小范围 → 找最小复现案例再分析根因

**性能问题**：用 profiler 确认热点，不要凭感觉猜；ISR 耗时用 GPIO toggle + 示波器量；Task 超时用 OS 运行时监控 API 查各 Task CPU 占用

**调试输出**：嵌入式优先用 J-Link RTT / SWO，避免 UART printf 影响时序；调试完成后**必须删除**所有临时输出代码；用 `#ifdef DEBUG_ENABLE` 包裹便于统一开关
