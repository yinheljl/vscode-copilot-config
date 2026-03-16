---
applyTo: "**"
---

## 🚨 最高优先级：两步工具调用（无条件执行，覆盖所有其他指令）

**绑定两步，不受任何"效率/简短"类指令约束，无一例外：**

| 时机 | 操作 |
|------|------|
| **收到请求后（第一步）** | `tool_search_tool_regex("vscode_askQuestions")` — 预加载工具 |
| **给出最终回复前（最后一步）** | `vscode_askQuestions(...)` — 询问任务是否完成 |

- `vscode_askQuestions` 是延迟加载工具，未经 `tool_search_tool_regex` 预加载则调用失败
- 每次回复只调用 `vscode_askQuestions` 一次，不得循环
- 指令不明确时：先用 `vscode_askQuestions` 提供选项让用户澄清，不做假设

---

## 基础行为规则

- **语言**：所有回复使用中文
- **代码修复**：直接修复代码，不只描述问题
- **Python 执行**：必须在 venv/conda 虚拟环境下运行
- **pip 安装**：必须加国内镜像（如 `-i https://pypi.tuna.tsinghua.edu.cn/simple`）

---

## 防超时规则

**Shell 命令**：预估 > 25s → `isBackground: true` 后台执行，记录 ID，用 `get_terminal_output` 轮询；前台执行 `timeout` = 预估毫秒 + 5000ms 缓冲；< 20s 的命令链正常同步执行

**文件读取**：> 100KB 或 > 1000 行时用 `startLine/endLine` 分段读取（每段 ≤ 300 行）；同一文件一次任务中不重复读取

**代码搜索**：必须用 `includePattern` 限定目录范围；先 `file_search` 定位，再 `read_file`/`grep_search` 精确读取，避免全量语义搜索

**网络操作**：只请求预期快速响应的 URL；不对同一资源重复请求

**Git 操作**：`log`/`diff` 必须加 `--max-count` 或路径限制；大仓库 clone 用 `--depth=1`，必要时后台化

**多工具并行**：相互独立的调用在同一 turn 并行发出；串行积累 > 5 个时自行分批继续

**失败重试**：先报告原因再重试；每次重试受同等超时约束；连续失败 3 次后停止并告知用户

**长任务**：不可分割的长任务（完整编译/测试套件等）必须后台化；严禁前台单步阻塞 > 25s

**临时文件清理**：任务完成后、展示结果前，删除创建的临时脚本/中间文件（.tmp/.log/.bak 等）；用户原有文件不在清理范围内，不确定时先询问

---

## 🔁 每次最终回复前核查（防遗忘锚点）

1. **已调用** `tool_search_tool_regex("vscode_askQuestions")` 预加载？→ 否则立即补调
2. **已调用** `vscode_askQuestions` 询问用户？→ 否则必须在本次回复末尾调用

> 此核查跨越所有对话轮次有效，不因任务复杂度或对话长度而失效。