---
applyTo: "**/*.c,**/*.h,**/*.s,**/*.ld"
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

## AUTOSAR 开发规范

### BSW（基础软件层）
- BSW 模块修改仅通过 Tresos/EB 配置工具生成，**不要手动编辑**生成代码
- 生成代码目录（如 `output/generated/`）中的文件不应手动修改
- BSW 模块 API 调用遵循 AUTOSAR 标准接口（如 `Can_Write()`, `Com_SendSignal()`）
- 理解 BSW 模块依赖关系：`ComStack` → `PduR` → `CanIf` → `Can` (MCAL)

### SWC（软件组件层）
- SWC 通过 RTE 接口与其他组件通信，不直接调用 BSW API
- Runnable 函数命名遵循 `<SWC名>_<Runnable名>` 约定
- Runnable 映射到 OS Task，注意执行周期和优先级配置
- 使用 Rte_Read / Rte_Write / Rte_Call 访问端口，不直接访问全局变量

### RTE 与端口
- Sender-Receiver（S/R）端口用于数据交换
- Client-Server（C/S）端口用于服务调用
- 端口数据类型必须与 ARXML 定义一致
- 访问 RTE 接口前检查返回值（`RTE_E_OK`）

### NvM（非易失性内存）
- NvM Block 的 RAM Mirror 和 ROM Default 必须正确配置
- 使用 `NvM_ReadBlock` / `NvM_WriteBlock` 异步操作，通过回调或轮询确认完成
- 启动时等待 NvM_ReadAll 完成后再访问 NvM 数据

### 诊断（UDS/DTC）
- DTC 状态管理通过 `Dem_SetEventStatus()` 报告
- 诊断服务实现遵循 ISO 14229 (UDS) 规范
- 安全访问（0x27 服务）的算法不在源码中硬编码密钥

### OS 与调度
- Task 优先级分配遵循 Rate-Monotonic 原则（周期越短优先级越高）
- 共享资源通过 AUTOSAR OS Resource 机制保护（`GetResource`/`ReleaseResource`）
- Alarm/Schedule Table 配置需与 Runnable 周期一致

---

## NXP S32K3xx 平台特定

### 时钟与电源
- 时钟树配置务必校验（HSE/PLL/分频器），修改前备份配置
- 低功耗模式切换需按规定序列操作

### Flash & 安全
- Flash 操作期间禁止从同一 Flash Bank 执行代码
- HSE 密钥管理遵循 NXP 安全编程指南
- Bootloader 更新需验证签名/CRC

### 外设驱动
- MCAL 驱动配置通过 EB Tresos 生成，仅修改配置面板中的参数
- ADC 采样需考虑采样时间与通道切换稳定时间
- CAN FD 帧配置注意 BRS 和数据段波特率
- 低功耗模式切换需按规定序列操作（STANDBY/RUN/VLPR）

### Flash & 安全
- Flash 操作（编程/擦除）期间禁止从同一 Flash Bank 执行代码
- HSE（Hardware Security Engine）密钥管理遵循 NXP 安全编程指南
- Bootloader 更新需验证签名/CRC

### 外设驱动
- MCAL 驱动配置通过 EB Tresos 生成，仅修改配置面板中的参数
- ADC 采样需考虑采样时间与通道切换稳定时间
- CAN FD 帧配置注意 BRS（Bit Rate Switch）和数据段波特率
