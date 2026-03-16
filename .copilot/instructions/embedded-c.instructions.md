---
description: "嵌入式 C / MCU / NXP S32K3xx 开发规范，涵盖内存安全、中断处理、编码风格。Use when writing embedded C code, MCU firmware, or working with NXP S32K platforms."
applyTo: "**/*.{c,h,s,ld}"
---
# 嵌入式 C / MCU / AUTOSAR 开发规范

## 通用嵌入式 C 规范

### 内存与资源
- 禁止使用 `malloc`/`free` 等动态内存分配，所有缓冲区必须静态分配
- 所有数组访问必须进行边界检查
- 使用 `volatile` 修饰硬件寄存器映射变量和 ISR 共享变量
- 栈使用量在设计时预估并验证，避免深层递归（推荐禁止递归）
- 优先使用 `stdint.h` 定宽类型（`uint8_t`, `uint16_t`, `uint32_t`），避免 `int`/`short`

### 中断与并发
- ISR 应尽可能短小，仅设置标志位或入队数据，业务逻辑在主循环/任务中处理
- ISR 与主程序共享数据必须使用 `volatile` + 临界区保护（`SchM_Enter/Exit` 或 `SuspendAllInterrupts`）
- 避免在 ISR 中调用非重入函数

### 位操作与寄存器
- 使用位掩码宏操作寄存器：`REG |= MASK;` 置位，`REG &= ~MASK;` 清零
- 优先使用 MCAL/HAL 提供的 API 而非直接操作寄存器地址
- 寄存器配置序列应添加注释说明来源（如 Datasheet Section X.Y.Z）

### 编码风格
- 函数体长度控制在 75 行以内
- 每个函数只做一件事（单一职责）
- switch-case 中每个 case 必须有 `break` 或 `/* fall-through */` 注释
- 所有 `if-else if` 链必须有 `else` 分支（至少包含断言或错误处理）
- 使用 `const` 修饰不会被修改的参数和局部变量
- 头文件使用 include guard：`#ifndef MODULE_H ... #define MODULE_H ... #endif`

### 编译与警告
- 编译器警告级别设为最高（`-Wall -Wextra -Werror` 或等效选项）
- 所有警告视为错误处理
- 禁止使用编译器扩展（除非有平台必要性并添加注释说明）

---

## AUTOSAR 补充规范

> AUTOSAR 核心架构、SWC 开发、BSW 配置等详见 autosar.instructions.md，此处仅列出与嵌入式 C 编码直接相关的补充点。

### 诊断安全
- 安全访问（0x27 服务）的算法不在源码中硬编码密钥

---

## NXP S32K3xx 平台特定

### 时钟与电源
- 时钟树配置务必校验（HSE/PLL/分频器），修改前备份配置
- 低功耗模式切换需按规定序列操作（STANDBY/RUN/VLPR）

### Flash & 安全
- Flash 操作（编程/擦除）期间禁止从同一 Flash Bank 执行代码
- HSE（Hardware Security Engine）密钥管理遵循 NXP 安全编程指南
- Bootloader 更新需验证签名/CRC

### 外设驱动
- MCAL 驱动配置通过 EB Tresos 生成，仅修改配置面板中的参数
- ADC 采样需考虑采样时间与通道切换稳定时间
- CAN FD 帧配置注意 BRS（Bit Rate Switch）和数据段波特率
