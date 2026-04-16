# Cursor + VS Code GitHub Copilot 个人配置

本仓库备份了 **Cursor** 和 **VS Code GitHub Copilot** 的全局配置，支持换电脑后一键还原。

## 仓库结构

| 目录/文件 | 说明 |
|-----------|------|
| `copilot/instructions/` | VS Code Copilot 全局指令（中文规范、交互反馈策略、防超时等） |
| `copilot/skills/` | VS Code Copilot 自定义 Skill 集合（8 个） |
| `cursor/mcp.json` | Cursor MCP 服务器配置模板 |
| `cursor/rules/` | Cursor 全局 Rules（.mdc 格式） |
| `cursor/skills/` | Cursor Skills（与 Copilot 相同的 8 个） |
| `cursor/skills-cursor/` | Cursor 内置 Skills（canvas、hooks 等 11 个） |
| `cursor/settings.json` | Cursor 编辑器设置（Copilot/MCP 相关） |
| `vscode/mcp.json` | VS Code MCP 服务器配置模板 |
| `vscode/settings.json` | VS Code 编辑器设置（Copilot/Chat 相关） |
| `restore.ps1` | Windows 一键还原脚本 |
| `restore.sh` | Linux/macOS 一键还原脚本 |
| `sync.ps1` | 从当前机器同步配置到仓库并推送 |

## 项目来源

本仓库的 Interactive-Feedback-MCP 恢复流程和验证思路，参考了 [rooney2020/qt-interactive-feedback-mcp](https://github.com/rooney2020/qt-interactive-feedback-mcp)。当前还原脚本默认也是从该仓库拉取反馈服务，并在本地生成适配 Cursor 与 VS Code 的模板配置。

## MCP 服务器

仓库当前自动部署的只有 **Interactive-Feedback-MCP**（Qt 桌面交互反馈窗口）。为避免 VS Code 与 Cursor 耦合到 `.cursor` 目录，反馈服务统一安装到用户级共享目录：Windows 为 `%USERPROFILE%\MCP\Interactive-Feedback-MCP`，Linux/macOS 为 `~/MCP/Interactive-Feedback-MCP`。其中 VS Code 使用该目录下虚拟环境的 Python 直接启动，Cursor 保持原有的 `uv run` 启动方式。其他 MCP 服务（GitHub、Context7、Markitdown、Chrome DevTools 等）仍按需安装或手动补充配置。

| 服务器 | 用途 | 安装方式 |
|--------|------|----------|
| interactiveFeedback | Qt 交互反馈窗口，让 AI 能通过弹窗与用户交互 | 还原脚本自动克隆到用户级共享 MCP 目录 |

## 恢复范围说明

默认执行本仓库的还原脚本时，恢复范围是：

1. Cursor 和 VS Code 的全局规则、instructions、skills、settings。
2. Interactive-Feedback-MCP 的安装与对应模板配置。
3. README 和还原脚本中已经明确声明的配置项。

默认**不自动恢复**的内容是：

1. GitHub、Context7、Markitdown、Chrome DevTools 等其他 MCP 服务。
2. 任何 API Key、Token、个人账号信息。
3. README 和脚本没有声明的额外工具或扩展。

## 给 AI 的推荐提示词

如果你已经把本仓库克隆到新电脑，并在仓库目录中打开 VS Code，可以直接对 AI 说：

```text
请参考当前仓库 README 和还原脚本，帮我在这台电脑上恢复 Cursor + VS Code GitHub Copilot 的全局规则、skills、settings，以及 README 中自动恢复范围内的 MCP 配置。
先检查 Node.js 和 uv 是否已安装；如果缺失直接帮我安装。
先执行 DryRun，确认后再正式执行。
完成后分别验证 Cursor 和 VS Code 的 interactiveFeedback MCP 是否正常。
对于 README 未声明自动恢复的 MCP，不要自行安装，除非我再要求。
```

如果你不想先 DryRun，可以把上面那句里的“先执行 DryRun，确认后再正式执行”删掉。

## 全局 Rules

| 规则文件 | 适用于 | 说明 |
|----------|--------|------|
| `copilot/instructions/main.instructions.md` | VS Code Copilot | 中文回复、Python 虚拟环境、交互反馈策略、防超时 |
| `cursor/rules/mcp-feedback.mdc` | Cursor | interactive_feedback 交互反馈机制 |

## Skills 清单（Cursor + VS Code 共享）

### 文档类 (document)

| 技能 | 用途 |
|------|------|
| docx | Word 文档创建、编辑、批注 |
| xlsx | Excel 表格处理、公式、图表 |
| pptx | PowerPoint 演示文稿 |
| pdf | PDF 提取、合并、标注、填表 |

### 测试类 (testing)

| 技能 | 用途 |
|------|------|
| webapp-testing | Web 应用测试（Playwright） |

### 生产力类 (productivity)

| 技能 | 用途 |
|------|------|
| code-reviewer | 多语言代码评审（TS/Python/Go/Swift） |
| mcp-builder | MCP 服务器构建指南 |

### 工程类 (engineering)

| 技能 | 用途 |
|------|------|
| codebase-onboarding | 代码库分析与上手文档生成 |

### Cursor 内置 Skills（cursor/skills-cursor/）

babysit、canvas、create-hook、create-rule、create-skill、create-subagent、migrate-to-skills、shell、statusline、update-cli-config、update-cursor-settings

## 新电脑快速还原

### 前提条件

1. [VS Code](https://code.visualstudio.com/) 和/或 [Cursor](https://cursor.com/)
2. [Node.js](https://nodejs.org/)（部分 MCP 扩展需要 npx）
3. [uv](https://docs.astral.sh/uv/)（Interactive-Feedback-MCP 需要）
4. [Git](https://git-scm.com/)（可选，无 git 时脚本会自动通过 ZIP 下载）

> VS Code 模板默认开启 `chat.mcp.autostart`。首次使用 Markitdown 时，`uvx` 可能会先下载依赖，冷启动会比其他 MCP 更慢，这属于正常现象。

### Windows (PowerShell)

**方式一：通过 git clone**

```powershell
git clone https://github.com/yinheljl/vscode-copilot-config.git C:\Temp\copilot-restore
cd C:\Temp\copilot-restore
.\restore.ps1
```

**方式二：下载 ZIP（无需 git）**

1. 打开 https://github.com/yinheljl/vscode-copilot-config/archive/refs/heads/main.zip
2. 解压到任意目录（如 `C:\Temp\copilot-restore`）
3. 运行脚本：

```powershell
cd C:\Temp\copilot-restore
.\restore.ps1
```

**方式三：直接拷贝文件夹**

如果已有本仓库的完整文件夹（U 盘拷贝、网盘同步等），直接进入该目录运行：

```powershell
cd <仓库文件夹路径>
.\restore.ps1
```

**可选参数：**

```powershell
.\restore.ps1 -DryRun          # 预览模式，不实际修改
.\restore.ps1 -SkipFeedbackMCP # 跳过 Interactive-Feedback-MCP
```

### Linux / macOS

```bash
# 方式一：git clone
git clone https://github.com/yinheljl/vscode-copilot-config.git /tmp/copilot-restore
cd /tmp/copilot-restore
chmod +x restore.sh
./restore.sh

# 方式二：下载 ZIP
curl -fsSL https://github.com/yinheljl/vscode-copilot-config/archive/refs/heads/main.zip -o /tmp/copilot.zip
unzip -q /tmp/copilot.zip -d /tmp/copilot-restore
cd /tmp/copilot-restore/vscode-copilot-config-main
chmod +x restore.sh
./restore.sh
```

> 还原脚本会自动检测是否安装了 git。如有 git 则用 git clone 安装 Interactive-Feedback-MCP，否则自动通过 ZIP 下载。

### 手动还原

```powershell
# VS Code Copilot 配置
Copy-Item -Recurse ".\copilot\*" "$env:USERPROFILE\.copilot\" -Force

# Cursor 配置
Copy-Item -Recurse ".\cursor\rules" "$env:USERPROFILE\.cursor\" -Force
Copy-Item -Recurse ".\cursor\skills" "$env:USERPROFILE\.cursor\" -Force
Copy-Item -Recurse ".\cursor\skills-cursor" "$env:USERPROFILE\.cursor\" -Force

# Interactive-Feedback-MCP
git clone https://github.com/rooney2020/qt-interactive-feedback-mcp.git "$env:USERPROFILE\MCP\Interactive-Feedback-MCP"
cd "$env:USERPROFILE\MCP\Interactive-Feedback-MCP"
uv sync
```

> 手动还原时，需要分别处理两套模板：
> Cursor 的 `cursor/mcp.json` 需将 `__UV_PATH__` 替换为 uv 的绝对路径，并将 `__FEEDBACK_MCP_DIR__` 替换为反馈服务目录；
> VS Code 的 `vscode/mcp.json` 需将 `__FEEDBACK_MCP_PYTHON__` 替换为虚拟环境 Python 的绝对路径，并将 `__FEEDBACK_SERVER_PATH__` 替换为 `server.py` 的绝对路径。还原脚本会自动完成这一步。

### 首次启动检查

1. 重启 Cursor 和 VS Code，让新的 `mcp.json` 与 `settings.json` 生效。
2. 在 MCP 服务器列表里确认 `interactiveFeedback` 已发现工具；VS Code 日志中应能看到 `Discovered 1 tools`。
3. GitHub、Context7、Markitdown 不由本仓库自动安装；如需与当前机器完全一致，仍需在扩展商城安装或手动补充对应配置。
4. Context7 和 GitHub 的 API Key/Token 不应提交到仓库；推荐使用环境变量或用户级私有配置管理。

## 常见排错

### Windows 执行策略拦截 restore.ps1

如果 PowerShell 因执行策略阻止 `restore.ps1` 运行，可仅在当前会话临时放行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\restore.ps1
```

### ZIP 目录不能直接用于 sync.ps1 推送

`sync.ps1` 需要当前目录本身就是一个 Git 仓库。如果你是通过 GitHub ZIP 解压得到目录，脚本会明确提示缺少 `.git`。这种情况下请先使用 `git clone` 获取完整仓库，再运行 `sync.ps1`。

### 日志不直观时如何验证 interactiveFeedback

如果重启后日志里没有直观看到 `Discovered 1 tools`，可以直接使用 Interactive-Feedback-MCP 虚拟环境里的 `fastmcp` 客户端执行 `list_tools`。只要 Cursor 和 VS Code 两端都能列出 `interactive_feedback`，就说明模板配置和服务启动都正常。

### MCP 已安装但当前会话里没有 interactive_feedback 工具

还原成功、`list_tools` 验证通过，只能说明 MCP 服务和模板配置正常；**不代表当前这一个 Copilot 会话已经把 `interactive_feedback` 注册进模型可调用工具列表**。如果当前会话工具列表里看不到该工具，应视为会话级工具注册问题，此时应降级使用 `vscode_askQuestions`，而不是把任务误判为可以直接结束。

## 同步更新

修改了本地配置后，推送更新到本仓库：

```powershell
cd <仓库目录>
.\sync.ps1                              # 同步并推送
.\sync.ps1 -Message "更新 MCP 配置"     # 自定义提交信息
.\sync.ps1 -NoPush                      # 只提交不推送
```

> `sync.ps1` 依赖当前目录中的 `.git` 元数据。若当前目录来自 ZIP 解压，请先重新 `git clone` 仓库。

## 格式差异说明

| 特性 | Cursor | VS Code |
|------|--------|---------|
| MCP 配置键名 | `mcpServers` | `servers` |
| MCP 条目格式 | 无需 `type` 字段 | 需要 `type: "stdio"` |
| 规则格式 | `.mdc` + YAML frontmatter | `.instructions.md` + YAML frontmatter |
| 超时配置 | `mcp.json` 中 `timeout`（秒）+ `settings.json` 中 `mcp.server.timeout`（毫秒） | 不支持 |
| 自动批准 | `autoApprove` 字段 | 不支持 |

> **注意**：本仓库为私有仓库，仅限个人使用。仓库中的 mcp.json 模板不应包含任何 API Key 或 Token，路径使用占位符。
