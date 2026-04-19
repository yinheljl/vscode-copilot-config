# VS Code & Cursor & Codex 全局配置中心

> **一键配置 VS Code GitHub Copilot、Cursor 和 Codex 的全局 Rules、Skills、MCP 服务器等。**
> **支持 AI Agent 自动配置、增量更新。**

当前版本：`1.3.0`

---

## 🤖 AI Agent 操作指南

> **本节内容供 AI Agent（GitHub Copilot、Cursor AI、Codex 等）直接解析和执行。**
> **当用户提到本仓库 URL 或要求配置/更新时，请按以下指令操作。**
>
> ⚠️ **重要：必须通过运行 `restore.ps1` / `restore.sh` 脚本来配置，禁止手动复制文件。脚本会自动处理 IDE 检测、路径替换、MCP 安装等所有工作。**

### 场景一：首次配置

**触发条件**：用户说 _"请按照 https://github.com/yinheljl/vscode-copilot-config 帮我配置"_ 或类似表述。

**操作步骤（按顺序执行，不可跳过）**：

1. **克隆仓库**（如 `~/.copilot-config` 已存在则跳过）
   ```powershell
   # Windows
   git clone https://github.com/yinheljl/vscode-copilot-config.git "$env:USERPROFILE\.copilot-config"
   ```
   ```bash
   # Linux / macOS
   git clone https://github.com/yinheljl/vscode-copilot-config.git ~/.copilot-config
   ```

2. **运行还原脚本**（脚本会自动安装 uv、克隆 MCP 项目、生成配置，无需手动安装任何依赖）
   ```powershell
   # Windows
   & "$env:USERPROFILE\.copilot-config\restore.ps1"
   ```
   ```bash
   # Linux / macOS
   bash ~/.copilot-config/restore.sh
   ```

3. **提示用户重启所有已安装的 IDE**（VS Code、Cursor 等）

> **脚本会自动检测并配置所有已安装的 IDE**（VS Code / Cursor / Codex），无需手动指定。
>
> **可选参数**（仅在用户明确要求时使用）：
>
> | 用户意图 | 参数 |
> |----------|------|
> | 仅配置指定 IDE | `-Target Codex`、`-Target VSCode,Cursor` |
> | 覆盖已有配置 | `-Force` |
> | 组合使用 | `-Target Codex -Force` |
>
> **IDE 识别规则**：当用户明确提到特定 IDE 时添加 `-Target`：
> - "Copilot" / "VS Code" / "VSCode" → `-Target VSCode`
> - "Cursor" → `-Target Cursor`
> - "Codex" → `-Target Codex`
> - "覆盖" / "覆盖模式" / "干净安装" → 加 `-Force`
> - 未指定 → 不传 `-Target`（配置所有 IDE）

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
| `cursor/settings.json` | Cursor 编辑器设置模板 |
| `vscode/mcp.json` | VS Code MCP 服务器配置模板（含路径占位符） |
| `vscode/settings.json` | VS Code 编辑器设置模板 |
| `restore.ps1` / `restore.sh` | 配置还原脚本（首次安装用） |
| `update.ps1` / `update.sh` | 远程拉取 + 还原（更新用） |
| `sync.ps1` / `sync.sh` | 从本机同步配置到仓库并推送 |
| `VERSION` | 当前版本号 |
| `REPO_URL` | 仓库地址常量（fork 后只改这一处即可） |
| `scripts/validate_config.py` | 校验所有配置模板（CI 与本地通用） |
| `.github/workflows/validate.yml` | GitHub Actions：JSON/TOML 语法 + 版本号同步检查 |

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
| `codex/AGENTS.md` | Codex | 中文回复、Python 虚拟环境、AskQuestion 澄清机制 |
| `cursor/rules/mcp-feedback.mdc` | Cursor | 中文回复、Python 虚拟环境、AskQuestion 澄清机制 |

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

> Cursor 自带的官方 Skills（babysit / canvas / create-rule 等）由 Cursor 安装时附带，不在本仓库管理范围内。

## 🔧 手动安装

如果不想使用 AI Agent 或脚本，可以手动操作：

### Windows

```powershell
# 1. 克隆仓库
git clone https://github.com/yinheljl/vscode-copilot-config.git C:\Temp\copilot-config

# 2. VS Code Copilot：仅复制 instructions 与 skills 两个子目录
foreach ($sub in "instructions","skills") {
    Copy-Item -Recurse "C:\Temp\copilot-config\copilot\$sub" "$env:USERPROFILE\.copilot\" -Force
}

# 3. Cursor：rules / skills
foreach ($sub in "rules","skills") {
    Copy-Item -Recurse "C:\Temp\copilot-config\cursor\$sub" "$env:USERPROFILE\.cursor\" -Force
}

# 4. Codex：AGENTS.md
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
- [x] sync.sh（Linux/macOS 双向同步）
- [x] CI 校验 JSON/TOML 模板与版本号同步
- [ ] 设置页面内一键更新按钮
- [ ] 更多 MCP 服务器预配置

## 🙏 致谢

- [rooney2020/qt-interactive-feedback-mcp](https://github.com/rooney2020/qt-interactive-feedback-mcp) — Interactive-Feedback-MCP 恢复流程和验证思路
- [dragonstylecc/Interactive-Feedback-With-Capture-MCP](https://github.com/dragonstylecc/Interactive-Feedback-With-Capture-MCP) — 截图反馈功能参考

## 📄 许可

[MIT License](LICENSE) — 自由使用、修改、分发，无任何担保。