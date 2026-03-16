---
description: "MISRA C:2012 合规指南，嵌入式 C 代码静态分析规则参考。Use when writing or reviewing C code for safety-critical systems, MISRA compliance, or static analysis."
applyTo: "**/*.{c,h}"
---
# MISRA C:2012 合规指南

在编写和审查 C 代码时，遵循以下 MISRA C:2012 关键规则。违反标记为 **Required** 的规则不可接受；**Advisory** 规则应尽量遵守。

## 必须遵守（Required / Mandatory）

### 类型安全
- **Rule 10.1** 操作数不应具有不合适的基本类型（如在布尔表达式中使用算术类型）
- **Rule 10.3** 表达式的值不应赋给更窄的基本类型
- **Rule 10.4** 算术运算的操作数应具有相同的基本类型
- **Rule 10.8** 复合表达式的值不应强制转换为不同的基本类型类别
- **Rule 11.3** 不应在指向不同对象类型的指针之间进行强制转换（除 `void*`）

### 控制流
- **Rule 14.3** 控制表达式不应是不变的（避免 `if(1)` / `if(0)`，调试宏除外）
- **Rule 15.1** 不应使用 `goto` 语句
- **Rule 15.6** 复合语句的主体应括在大括号中（包括单行 `if/for/while`）
- **Rule 15.7** 所有 `if...else if` 结构应以 `else` 子句结束
- **Rule 16.1** 所有 `switch` 语句应格式良好（每个 case 以 break/return 结束）
- **Rule 16.4** 每个 `switch` 语句应有 `default` 子句

### 指针与数组
- **Rule 17.5** 不应声明具有多于 2 级间接指针的对象
- **Rule 18.1** 指针算术的结果应指向同一数组内
- **Rule 18.2** 不应对不指向同一数组的指针执行减法
- **Rule 18.4** 不应有超过 2 级的指针间接

### 副作用
- **Rule 13.2** 表达式的值及其副作用的求值顺序不应依赖于求值顺序
- **Rule 13.5** `&&` 和 `||` 的右操作数不应包含持久性副作用

### 函数
- **Rule 8.2** 函数类型应带有命名参数的原型形式
- **Rule 8.4** 当定义具有外部链接的对象或函数时，应先有兼容的声明
- **Rule 8.13** 指向不被修改的对象的指针参数应声明为 `const`
- **Rule 17.2** 函数不应直接或间接地调用自身（禁止递归）
- **Rule 17.7** 非 void 函数的返回值不应被丢弃

### 预处理
- **Rule 20.3** `#include` 指令后应跟随 `<filename>` 或 `"filename"`
- **Rule 20.4** 宏不应与关键字同名

### 内存与动态分配
- **Dir 4.12** 不应使用动态内存分配（`malloc`, `calloc`, `realloc`, `free`）
- **Rule 21.3** 不应使用 `<stdlib.h>` 的内存分配和释放函数

### 标准库限制
- **Rule 21.6** 不应使用 `<stdio.h>` 的输入/输出函数（嵌入式场景）
- **Rule 21.10** 不应使用标准库时间日期函数

## 建议遵守（Advisory）

- **Rule 2.2** 不应有无效代码（dead code）
- **Rule 2.7** 函数参数不应未使用（未使用参数用 `(void)param;` 抑制）
- **Dir 4.1** Run-time 错误应最小化
- **Dir 4.6** 应使用 `typedef` 替代基本数值类型（推荐 `stdint.h`）
- **Dir 4.8** 如果指针仅用于访问结构体的一个成员，考虑传递该成员
- **Rule 3.1** 注释中不应包含 `/*` 或 `//` 子序列（嵌套注释）
- **Rule 8.7** 仅在一个翻译单元中引用的对象或函数应使用内部链接（`static`）
- **Rule 8.9** 仅在一个函数中引用的对象应在块作用域中定义
- **Rule 11.5** 不建议将 `void*` 转换为指向对象的指针类型（若不可避免，建议使用显式强转并添加注释说明原因）
- **Rule 20.5** 不应使用 `#undef`（宏一旦定义应保持有效至翻译单元结束）

## 实践建议

- 在代码审查中标注 MISRA 违规时，注明规则编号，如 `/* MISRA C:2012 Rule 15.7 violation - else clause added */`
- 对于不可避免的偏差，使用注释记录偏差理由：`/* DEVIATION: Rule X.Y - <reason> */`
- 静态分析工具（Polyspace、PC-lint、cppcheck --addon=misra）应集成到 CI 流程
- 对 MCAL 生成代码和第三方库代码，可标记为排除范围
