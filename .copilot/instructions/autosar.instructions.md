---
applyTo: "**/*.c,**/*.h,**/*.arxml,**/*.xdm"
---
# AUTOSAR 架构与开发规范

## 分层架构原则

### 层次隔离
- **SWC 层**只通过 RTE 接口通信，禁止直接引用 BSW 头文件或调用 BSW API
- **BSW 层**代码由配置工具（EB Tresos）生成，手动修改会在重新生成时丢失
- **MCAL 层**直接操作硬件寄存器，仅通过 EB Tresos 配置修改

### 代码分类
```
Application Layer (SWC)    → 手动编写（你的主要工作）
RTE                        → 自动生成（不要手动编辑）
Service Layer (BSW)        → 配置生成 + 少量 Callout 手写
ECU Abstraction Layer      → 配置生成
MCAL                       → 配置生成
```

## SWC 开发指南

### Runnable 实现
- Runnable 是 SWC 的执行入口，由 OS Task 按配置周期调用
- 每个 Runnable 函数签名遵循：`void <SwcName>_<RunnableName>(void)`
- Runnable 内不应有阻塞等待，执行时间应可预测

### 端口访问模式
```c
/* Sender-Receiver 读取 */
Std_ReturnType ret;
DataType value;
ret = Rte_Read_<Port>_<Element>(&value);
if (ret == RTE_E_OK) { /* 使用 value */ }

/* Sender-Receiver 写入 */
Rte_Write_<Port>_<Element>(value);

/* Client-Server 调用 */
ret = Rte_Call_<Port>_<Operation>(param1, &result);
```

### 状态管理
- 使用 Per-Instance Memory（PIM）或 NvM 存储持久状态
- 初始化 Runnable（`Init` event）中完成状态初始化
- 状态机实现推荐使用 `switch-case` + 状态枚举

## BSW 配置注意事项

### ComStack 配置链
```
COM → PduR → CanIf/LinIf/FrIf → Can/Lin/Fr (MCAL)
         ↕
    Dcm/Dem (诊断)
```
- Signal 到 PDU 的映射必须与 DBC/ARXML 通信矩阵一致
- PDU Routing 路径在 PduR 中配置，确保 Tx/Rx 路径完整
- CanIf HOH 配置需与 Can MCAL 的 MB 配置对应

### BswM 状态管理
- BswM Rules 定义通信控制逻辑（如 NM 状态 → 通信模式切换）
- Action Lists 中的动作顺序需仔细验证（如先关闭 COM 再关闭 CanIf）

### EcuM / SchM
- EcuM 管理 ECU 启动/关机序列，确保 BSW 初始化顺序正确
- SchM 提供 BSW 模块间的互斥保护（`SchM_Enter_<Module>_<Area>()` / `SchM_Exit_...`）

## 常见错误模式

### ❌ 直接访问全局变量（绕过 RTE）
```c
/* 错误 */
extern uint8 g_speed;
speed = g_speed;

/* 正确 */
Rte_Read_RPort_Speed(&speed);
```

### ❌ 在 SWC 中直接操作硬件
```c
/* 错误 */
GPIO_BASE->PDOR |= (1 << PIN);

/* 正确 - 通过 IoHwAb 抽象层 */
Rte_Call_RPort_IoHwAb_SetDigitalOutput(PIN_ID, STD_HIGH);
```

### ❌ 忽略 RTE 返回值
```c
/* 错误 */
Rte_Read_RPort_Temp(&temp);
ProcessTemp(temp);

/* 正确 */
if (Rte_Read_RPort_Temp(&temp) == RTE_E_OK) {
    ProcessTemp(temp);
}
```
