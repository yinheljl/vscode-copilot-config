# VS Code & Cursor & Codex 全局配置中心

> **一键配置 VS Code GitHub Copilot、Cursor 和 Codex 的全局 Rules、Skills、MCP 服务器等。**
> **支持 AI Agent 自动配置、增量更新。**

当前版本：`1.2.0`

---

## 🤖 AI Agent 操作指南

> **本节内容供 AI Agent（GitHub Copilot、Cursor AI、Codex 等）直接解析和执行。**
> **当用户提到本仓库 URL 或要求配置/更新时，请按以下指令操作。**

### 场景一：首次配置

**触发条件**：用户说 _"请按照 https://github.com/yinheljl/vscode-copilot-config 帮我配置"_ 或类似表述。

**IDE 识别规则**：AI Agent 应根据用户措辞判断要配置的 IDE：
- 用户提到 "Copilot" / "VS Code" / "VSCode" → `-Target VSCode`
- 用户提到 "Cursor" → `-Target Cursor`
- 用户提到 "Codex" → `-Target Codex`
- 用户提到多个 IDE → `-Target VSCode,Cursor` 等组合
- 用户未指定或说"全部配置" → 不传 `-Target`（默认配置所有已安装的 IDE）
- 用户提到"覆盖" / "覆盖模式" / "干净安装" → 加 `-Force`

**操作步骤**：

1. **检查前置依赖**
   ```powershell
   # 必需：Git
   git --version
   # 必需：uv（Interactive-Feedback-MCP 依赖）
   uv --version
   ```
   - 如果 `uv` 未安装：
     - Windows: `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`
     - Linux/macOS: `curl -LsSf https://astral.sh/uv/install.sh | sh`

2. **克隆仓库到持久目录**
   ```powershell
   # Windows
   git clone https://github.com/yinheljl/vscode-copilot-config.git "$env:USERPROFILE\.copilot-config"
   ```
   ```bash
   # Linux / macOS
   git clone https://github.com/yinheljl/vscode-copilot-config.git ~/.copilot-config
   ```

3. **执行还原脚本**（根据用户意图选择参数）
   ```powershell
   # Windows — 全部配置（默认）
   & "$env:USERPROFILE\.copilot-config\restore.ps1"
   # Windows — 仅配置指定 IDE
   & "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex
   # Windows — 覆盖模式 + 指定 IDE
   & "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex -Force
   ```
   ```bash
   # Linux / macOS — 全部配置（默认）
   bash ~/.copilot-config/restore.sh
   # Linux / macOS — 仅配置指定 IDE
   bash ~/.copilot-config/restore.sh --target=codex
   # Linux / macOS — 覆盖模式 + 指定 IDE
   bash ~/.copilot-config/restore.sh --force --target=codex
   ```

4. **验证**
   - 确认 `~/.copilot/instructions/` 和 `~/.copilot/skills/` 已创建（VS Code）
   - 确认 `~/MCP/Interactive-Feedback-MCP/` 目录存在且 `.venv` 已初始化
   - 确认对应 IDE 的 `mcp.json` 已生成
   - 确认 Codex 用户已有 `~/.codex/AGENTS.md` 和 `~/.codex/config.toml`（如已安装 Codex）
   - 提示用户重启已安装的 IDE

> **自动检测**：还原脚本会自动检测电脑上安装了哪些 IDE（VS Code / Cursor / Codex），仅配置已安装的环境。
>
> **按 IDE 配置**：使用 `-Target` 参数可仅配置指定的 IDE，不影响其他 IDE 的配置：
> ```powershell
> & "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex          # 仅 Codex
> & "$env:USERPROFILE\.copilot-config\restore.ps1" -Target VSCode,Cursor  # 仅 VS Code 和 Cursor
> ```
>
> **增量模式**（默认）：只添加/更新配置文件，不删除用户已有的自定义 Rules、Skills、MCP 服务器。`mcp.json` 中已有的服务器配置会被保留。
>
> **覆盖模式**：如果用户希望完全覆盖（例如干净安装），使用 `-Force` 参数：
> ```powershell
> & "$env:USERPROFILE\.copilot-config\restore.ps1" -Force
> & "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex -Force   # 仅覆盖 Codex
> ```

### 场景二：更新配置

**触发条件**：用户说 _"vscode-copilot-config 有更新，请帮我更新"_ 或类似表述。

**操作步骤**：

1. **运行更新脚本**（自动完成 git pull + 重新还原）
   ```powershell
   # Windows — 全部更新
   & "$env:USERPROFILE\.copilot-config\update.ps1"
   # Windows — 仅更新指定 IDE
   & "$env:USERPROFILE\.copilot-config\update.ps1" -Target Codex
   ```
   ```bash
   # Linux / macOS
   bash ~/.copilot-config/update.sh
   # Linux / macOS — 仅更新指定 IDE
   bash ~/.copilot-config/update.sh --target=codex
   ```
   > 如果持久目录不存在，update 脚本会自动克隆仓库到 `~/.copilot-config`。

2. **验证版本**
   - 读取 `VERSION` 文件确认已更新到最新版本
   - 提示用户重启编辑器

### 场景三：一键更新

已完成首次配置的用户可随时在终端执行：

```powershell
# Windows — 按 Ctrl+` 打开 VS Code 终端
& "$env:USERPROFILE\.copilot-config\update.ps1"
```

```bash
# Linux / macOS
~/.copilot-config/update.sh
```

或直接对 AI 说：_"帮我更新 copilot 全局配置"_

### 极简指令（适用于免费/基础模型）

> **如果你使用的 AI 模型能力较弱（如免费 Auto 模式），直接复制以下命令到终端执行即可，不需要 AI 做任何判断。**

**Windows（按 Ctrl+` 打开终端）：**
```powershell
# 首次安装（一键完成克隆 + 配置所有 IDE）
git clone https://github.com/yinheljl/vscode-copilot-config.git "$env:USERPROFILE\.copilot-config"; & "$env:USERPROFILE\.copilot-config\restore.ps1"

# 后续更新（一键拉取 + 重新配置）
& "$env:USERPROFILE\.copilot-config\update.ps1"
```

**Linux / macOS：**
```bash
# 首次安装
git clone https://github.com/yinheljl/vscode-copilot-config.git ~/.copilot-config && bash ~/.copilot-config/restore.sh

# 后续更新
bash ~/.copilot-config/update.sh
```

> 前提：需已安装 Git 和 uv。未安装 uv 请先执行：
> - Windows: `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`
> - Linux/macOS: `curl -LsSf https://astral.sh/uv/install.sh | sh`

---

## 📦 仓库结构

| 目录/文件 | 说明 |
|-----------|------|
| `copilot/instructions/` | VS Code Copilot 全局指令（中文规范、交互反馈策略、防超时等） |
| `copilot/skills/` | VS Code Copilot 自定义 Skill（8 个） |
| `codex/AGENTS.md` | Codex 全局指令（AGENTS.md 格式，中文规范、交互反馈策略） |
| `codex/config.toml` | Codex MCP 服务器配置模板（含路径占位符） |
| `cursor/mcp.json` | Cursor MCP 服务器配置模板（含路径占位符） |
| `cursor/rules/` | Cursor 全局 Rules（`.mdc` 格式） |
| `cursor/skills/` | Cursor Skills（与 Copilot 共享的 8 个） |
| `cursor/skills-cursor/` | Cursor 专属 Skills（11 个） |
| `cursor/settings.json` | Cursor 编辑器设置模板 |
| `vscode/mcp.json` | VS Code MCP 服务器配置模板（含路径占位符） |
| `vscode/settings.json` | VS Code 编辑器设置模板 |
| `restore.ps1` / `restore.sh` | 配置还原脚本（首次安装用） |
| `update.ps1` / `update.sh` | 远程拉取 + 还原（更新用） |
| `sync.ps1` | 从本机同步配置到仓库并推送 |
| `VERSION` | 当前版本号 |

## 🔌 MCP 服务器

还原脚本自动部署的 MCP 服务：

| 服务器 | 用途 | 安装位置 |
|--------|------|----------|
| Interactive-Feedback-MCP | Qt 桌面交互反馈窗口，让 AI 通过弹窗与用户持续对话 | `~/MCP/Interactive-Feedback-MCP` |
| markitdown (Microsoft) | 将 Word/PDF/PPT/Excel 等文件转换为 Markdown，AI 可直接读取 | 通过 `uvx tool run` 按需启动，无需本地安装 |

> 反馈服务统一安装到用户级共享目录，VS Code、Cursor 和 Codex 各自使用不同启动方式。
> 其他 MCP 服务（GitHub、Context7 等）不由本仓库自动安装，按需手动配置。
> mcp.json 模板不包含任何 API Key 或 Token，路径使用占位符，由还原脚本自动替换。

## 📐 全局 Rules

| 规则文件 | 适用于 | 说明 |
|----------|--------|------|
| `copilot/instructions/main.instructions.md` | VS Code Copilot | 中文回复、Python 虚拟环境、交互反馈策略、防超时 |
| `codex/AGENTS.md` | Codex | 中文回复、Python 虚拟环境、交互反馈策略 |
| `cursor/rules/mcp-feedback.mdc` | Cursor | interactive_feedback 交互反馈机制 |

## 🛠️ Skills 清单

### 共享 Skills（Cursor + VS Code）

| 分类 | 技能 | 用途 |
|------|------|------|
| 文档 | docx | Word 文档创建、编辑、批注 |
| 文档 | xlsx | Excel 表格处理、公式、图表 |
| 文档 | pptx | PowerPoint 演示文稿 |
| 文档 | pdf | PDF 提取、合并、标注、填表 |
| 测试 | webapp-testing | Web 应用测试（Playwright） |
| 生产力 | code-reviewer | 多语言代码评审 |
| 生产力 | mcp-builder | MCP 服务器构建指南 |
| 工程 | codebase-onboarding | 代码库分析与上手文档生成 |

### Cursor 专属 Skills（`cursor/skills-cursor/`）

babysit、canvas、create-hook、create-rule、create-skill、create-subagent、migrate-to-skills、shell、statusline、update-cli-config、update-cursor-settings

## 🔧 手动安装

如果不想使用 AI Agent 或脚本，可以手动操作：

### Windows

```powershell
# 1. 克隆仓库
git clone https://github.com/yinheljl/vscode-copilot-config.git C:\Temp\copilot-config

# 2. 复制 VS Code Copilot 配置
Copy-Item -Recurse "C:\Temp\copilot-config\copilot\*" "$env:USERPROFILE\.copilot\" -Force

# 3. 复制 Cursor 配置
Copy-Item -Recurse "C:\Temp\copilot-config\cursor\rules" "$env:USERPROFILE\.cursor\" -Force
Copy-Item -Recurse "C:\Temp\copilot-config\cursor\skills" "$env:USERPROFILE\.cursor\" -Force
Copy-Item -Recurse "C:\Temp\copilot-config\cursor\skills-cursor" "$env:USERPROFILE\.cursor\" -Force

# 4. 复制 Codex 配置
New-Item -ItemType Directory -Path "$env:USERPROFILE\.codex" -Force
Copy-Item "C:\Temp\copilot-config\codex\AGENTS.md" "$env:USERPROFILE\.codex\AGENTS.md" -Force

# 5. 安装 Interactive-Feedback-MCP
git clone https://github.com/rooney2020/qt-interactive-feedback-mcp.git "$env:USERPROFILE\MCP\Interactive-Feedback-MCP"
cd "$env:USERPROFILE\MCP\Interactive-Feedback-MCP"
uv sync
```

> 手动安装时需自行处理 mcp.json 和 config.toml 模板中的路径占位符替换，详见 `vscode/mcp.json`、`cursor/mcp.json` 和 `codex/config.toml`。

### 可选参数（脚本安装）

```powershell
.\restore.ps1                        # 增量模式（默认，保留用户已有配置）
.\restore.ps1 -Force                 # 完全覆盖模式
.\restore.ps1 -DryRun                # 预览模式，不实际修改
.\restore.ps1 -SkipFeedbackMCP       # 跳过 Interactive-Feedback-MCP
.\restore.ps1 -Target Codex          # 仅配置 Codex
.\restore.ps1 -Target VSCode,Cursor  # 仅配置 VS Code 和 Cursor
.\restore.ps1 -Target Codex -Force   # 仅覆盖 Codex 配置
```

```bash
# Linux / macOS
bash restore.sh                      # 增量模式（默认）
bash restore.sh --force              # 完全覆盖模式
bash restore.sh --target=codex       # 仅配置 Codex
bash restore.sh --target=vscode,cursor  # 仅配置 VS Code 和 Cursor
bash restore.sh --force --target=codex  # 仅覆盖 Codex 配置
```

## ❓ 常见问题

### Windows 执行策略拦截 restore.ps1

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\restore.ps1
```

### ZIP 下载方式使用

无 Git 时，脚本会自动通过 ZIP 下载。也可手动：

1. 下载 https://github.com/yinheljl/vscode-copilot-config/archive/refs/heads/main.zip
2. 解压后运行 `restore.ps1`

### 格式差异说明

| 特性 | Cursor | VS Code | Codex |
|------|--------|---------|-------|
| MCP 配置格式 | `mcp.json` (`mcpServers`) | `mcp.json` (`servers`) | `config.toml` (`[mcp_servers]`) |
| MCP 条目格式 | 无需 `type` 字段 | 需要 `type: "stdio"` | TOML 表格式 |
| 规则格式 | `.mdc` + YAML frontmatter | `.instructions.md` + YAML frontmatter | `AGENTS.md`（纯 Markdown） |

## 🗺️ 路线图

- [x] AI Agent 自动配置支持
- [x] 远程更新 + 版本检查
- [x] VS Code Codex 自动配置
- [ ] 设置页面内一键更新按钮
- [ ] 更多 MCP 服务器预配置

## 🙏 致谢

- [rooney2020/qt-interactive-feedback-mcp](https://github.com/rooney2020/qt-interactive-feedback-mcp) — Interactive-Feedback-MCP 恢复流程和验证思路
- [dragonstylecc/Interactive-Feedback-With-Capture-MCP](https://github.com/dragonstylecc/Interactive-Feedback-With-Capture-MCP) — 截图反馈功能参考

## 📄 许可

本仓库为个人配置集，供自由使用和参考。