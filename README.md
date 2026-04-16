# Cursor + VS Code GitHub Copilot 个人配置

本仓库备份了 **Cursor** 和 **VS Code GitHub Copilot** 的全局配置，支持换电脑后一键还原。

## 包含内容

| 目录/文件 | 说明 |
|-----------|------|
| `.copilot/instructions/` | VS Code Copilot 全局指令文件（中文规范、代码审查、AUTOSAR 等） |
| `.copilot/skills/` | VS Code Copilot 自定义 Skill 集合 |
| `cursor/mcp.json` | Cursor MCP 服务器配置 |
| `cursor/rules/` | Cursor 全局 Rules（.mdc 格式） |
| `cursor/skills/` | Cursor Skills |
| `cursor/skills-cursor/` | Cursor 内置 Skills（canvas, hooks 等） |
| `cursor/settings.json` | Cursor 编辑器设置（Copilot/MCP 相关） |
| `vscode/mcp.json` | VS Code MCP 服务器配置 |
| `vscode/settings.json` | VS Code 编辑器设置（Copilot/Chat 相关） |
| `restore.ps1` | Windows 一键还原脚本 |
| `restore.sh` | Linux/macOS 一键还原脚本 |
| `sync.ps1` | 从当前机器同步配置到仓库并推送 |

## MCP 服务器列表

| 服务器 | 用途 | Cursor | VS Code |
|--------|------|:------:|:-------:|
| context7 | 实时文档查询 | ✓ | ✓ |
| github | GitHub API 交互 | ✓ | ✓ |
| chrome-devtools | Chrome 调试工具 | ✓ | ✓ |
| lark_mcp | 飞书 API | ✓ | ✓ |
| interactive-feedback | Qt 交互反馈窗口 | ✓ | ✓ |
| microsoft/markitdown | 文档转换 | - | ✓ |

## 新电脑快速还原

### 前提条件

1. [VS Code](https://code.visualstudio.com/) 和/或 [Cursor](https://cursor.com/)
2. [Git](https://git-scm.com/)
3. [Node.js](https://nodejs.org/)（MCP 需要 npx）
4. [uv](https://docs.astral.sh/uv/)（Interactive-Feedback-MCP 和 markitdown 需要）

### Windows (PowerShell)

```powershell
# 1. 克隆本仓库
git clone https://github.com/yinheljl/vscode-copilot-config.git C:\Temp\copilot-restore
cd C:\Temp\copilot-restore

# 2. 运行还原脚本
.\restore.ps1

# 可选：预览模式（不实际修改）
.\restore.ps1 -DryRun

# 可选：跳过 Interactive-Feedback-MCP（如不需要）
.\restore.ps1 -SkipFeedbackMCP
```

### Linux / macOS

```bash
git clone https://github.com/yinheljl/vscode-copilot-config.git /tmp/copilot-restore
cd /tmp/copilot-restore
chmod +x restore.sh
./restore.sh
```

### 手动还原

若不想运行脚本，可手动操作：

```powershell
# VS Code Copilot 配置
Copy-Item -Recurse ".\.copilot" "$env:USERPROFILE\" -Force
Copy-Item ".\vscode\mcp.json" "$env:APPDATA\Code\User\mcp.json" -Force

# Cursor 配置
Copy-Item ".\cursor\mcp.json" "$env:USERPROFILE\.cursor\mcp.json" -Force
Copy-Item -Recurse ".\cursor\rules" "$env:USERPROFILE\.cursor\" -Force
Copy-Item -Recurse ".\cursor\skills" "$env:USERPROFILE\.cursor\" -Force
Copy-Item -Recurse ".\cursor\skills-cursor" "$env:USERPROFILE\.cursor\" -Force

# Interactive-Feedback-MCP
git clone https://github.com/rooney2020/qt-interactive-feedback-mcp.git "$env:USERPROFILE\.cursor\Interactive-Feedback-MCP"
cd "$env:USERPROFILE\.cursor\Interactive-Feedback-MCP"
uv sync
```

## Token 与环境变量配置

### GitHub MCP Token

`mcp.json` 中 GitHub MCP Server 的 token 使用了输入变量 `${GITHUB_MCP_TOKEN}`。

- **VS Code**：首次打开 Copilot Chat 时会弹出输入框
- **Cursor**：在 Settings > MCP 中配置

所需 GitHub Personal Access Token 权限：`repo`, `read:org`（可选）

### 飞书 MCP

需要设置环境变量：
- `LARK_APP_ID` — 飞书应用 ID
- `LARK_APP_SECRET` — 飞书应用密钥

## Interactive-Feedback-MCP

[qt-interactive-feedback-mcp](https://github.com/rooney2020/qt-interactive-feedback-mcp) 提供 Qt 桌面交互反馈窗口，让 AI 在执行任务时能通过弹窗与用户交互确认。

- 还原脚本会自动克隆到 `~/.cursor/Interactive-Feedback-MCP/` 并运行 `uv sync`
- 需要 Python 3.11+（uv 会自动管理）
- Cursor 中通过 `mcp-feedback.mdc` 规则自动启用
- VS Code Copilot 中通过 `main.instructions.md` 中的交互反馈规范启用

## 同步更新

修改了本地配置后，推送更新到本仓库：

```powershell
cd <仓库目录>
.\sync.ps1                              # 同步并推送
.\sync.ps1 -Message "更新 MCP 配置"     # 自定义提交信息
.\sync.ps1 -NoPush                      # 只提交不推送
```

## Cursor 一键配置提示词

换电脑后，在 Cursor 中可以发送以下提示词让 AI 自动完成所有配置：

> 请按照 https://github.com/yinheljl/vscode-copilot-config 帮我配置，并更新全局 Rules、mcp.json、skills 等

## 格式差异说明

| 特性 | Cursor | VS Code |
|------|--------|---------|
| MCP 配置键名 | `mcpServers` | `servers` |
| MCP 条目格式 | 无需 `type` 字段 | 需要 `type: "stdio"` |
| 规则格式 | `.mdc` + YAML frontmatter | `.instructions.md` + YAML frontmatter |
| 超时配置 | `mcp.json` 中 `timeout`（秒）+ `settings.json` 中 `mcp.server.timeout`（毫秒） | 不支持 |
| 自动批准 | `autoApprove` 字段 | 不支持 |

> **注意**：本仓库为私有仓库，仅限个人使用。
