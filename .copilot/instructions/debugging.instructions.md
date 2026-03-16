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

### 硬件外设不工作
```c
/* 排查顺序 */
// 1. 时钟使能了吗？
PCC->PCCn[PCC_PORTD_INDEX] |= PCC_PCCn_CGC_MASK;  /* 检查是否有这行 */

// 2. 寄存器值读回验证
uint32_t val = PORT->PCR[pin];  /* 读回确认写入生效 */

// 3. GPIO 方向正确吗？（输出要设 PDDR）
PTD->PDDR |= (1 << pin);
```

### 栈溢出 / 内存踩踏
```c
/* 症状：随机崩溃、变量值莫名被改、Hardfault */
/* 排查 */
// 1. 查看 OS Task 栈使用峰值（AUTOSAR: OsTaskStackUsage）
// 2. 检查大数组是否在 ISR/Task 内声明为局部变量（建议改 static）
// 3. 用 Lauterbach/J-Link 查看 stack canary 是否被踩

/* 防御 */
static uint8_t buffer[256];  /* ISR 内用 static，避免占用栈 */
```

### 并发/竞态问题
```c
/* 症状：偶发错误，单步调试正常，正常运行出错 */
/* 排查 */
// 1. 是否有 ISR 和主循环共享变量未加 volatile？
volatile uint8_t g_flag;

// 2. 是否在临界区外访问共享数据？
SchM_Enter_Module_Area();
/* 访问共享数据 */
SchM_Exit_Module_Area();
```

### CAN/通信问题
```
排查顺序：
1. 物理层：示波器量总线电平，确认终端电阻（120Ω）
2. 波特率：验证发送/接收双方一致
3. ID 过滤：确认 CanIf 的 HRH 过滤配置
4. PDU 路由：PduR routing table 中 Rx/Tx 路径完整
5. 软件处理：Com_MainFunctionRx/Tx 调用周期是否正确
```

### 变量值异常（怀疑被意外覆盖）
```
排查步骤：
1. 设置数据断点（Data Watchpoint）监视该变量地址
2. 运行，断点触发时查看调用栈找到写入者
3. 使用 J-Link/Lauterbach 的 ETM trace 回溯执行历史
```

## 通用调试原则

### 二分查找法（Bisect）
```
适用于"之前好的，现在坏了"：
1. git bisect 找到引入问题的 commit
2. 在代码中间加断点，判断前半段正常还是后半段有问题
3. 缩小到最小复现范围后再分析原因
```

### 性能问题排查
```
1. 先用 profiler 确认热点（不要凭感觉猜）
2. ISR 执行时间：用 GPIO toggle + 示波器量（最准确）
3. Task 周期超时：用 OS 的运行时监控 API 查各 Task CPU 占用
```

### 调试输出原则
- 嵌入式：优先用 J-Link RTT / SWO 输出，避免 UART printf 影响时序
- 调试完成后**必须删除**所有临时 printf/RTT 输出代码
- 用 `#ifdef DEBUG_ENABLE` 包裹调试代码，方便统一开关
