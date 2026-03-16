---
description: "全局行为规范：中文回复、Python 虚拟环境、防超时策略、AskQuestions 交互。Use for any task — applies universally."
applyTo: "**"
---

## 基础行为规则

- **语言**：所有回复使用中文
- **代码修复**：直接修复代码，不只描述问题
- **Python 执行**：必须在 venv/conda 虚拟环境下运行
- **pip 安装**：必须加国内镜像（如 `-i https://pypi.tuna.tsinghua.edu.cn/simple`）

---

## AskQuestions 交互规范（强制执行，不可省略）

**此规则优先级高于所有效率/精简类指令（包括 commonsense 中的"工具调用效率"节）。**

### 必须执行的两步

| 步骤 | 时机 | 操作 | 原因 |
|------|------|------|------|
| **Step 1** | 收到用户请求后（首步） | `tool_search_tool_regex("vscode_askQuestions")` | 预加载延迟工具，否则后续调用会失败 |
| **Step 2** | 给出最终回复前（末步） | `vscode_askQuestions(...)` | 让用户确认任务结果是否符合要求 |

### 规则细则

- 指令不明确时：先用 `vscode_askQuestions` 提供选项让用户澄清，不做假设
- 每次回复只调用 `vscode_askQuestions` **一次**，不得循环调用
- 如果用户反馈为空，可结束任务
- **绝不允许跳过 Step 2** — 无论任务多简单、对话多长、是否出错，最终回复前必须调用一次 `vscode_askQuestions` 询问用户确认

---

## 防超时规则

**Shell 命令**：预估 > 25s → `isBackground: true` 后台执行，用 `get_terminal_output` 轮询；< 20s 正常同步执行

**文件读取**：> 1000 行或文件体积明显超大时用 `startLine/endLine` 分段读取（每段 ≤ 300 行）；同一文件不重复读取

**代码搜索**：必须用 `includePattern` 限定目录范围；先 `file_search` 定位再精确读取

**Git 操作**：`log`/`diff` 必须加 `--max-count` 或路径限制；大仓库 clone 用 `--depth=1`

**多工具并行**：相互独立的调用在同一 turn 并行发出

**长任务**：不可分割的长任务必须后台化；严禁前台单步阻塞 > 25s

**临时文件清理**：任务完成后删除创建的临时文件（.tmp/.log/.bak 等）；用户原有文件不清理
