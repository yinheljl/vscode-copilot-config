# VS Code & Cursor & Codex & Claude 全局配置中心

> **一键配置 VS Code GitHub Copilot、Cursor、Codex 和 Claude 的全局 Rules、Skills、MCP 服务器等。**
> **支持 AI Agent 自动配置、增量更新。**

当前版本：`1.4.10`

---

## 🤖 AI Agent 操作指南

> **本节内容供 AI Agent（GitHub Copilot、Cursor AI、Codex、Claude 等）直接解析和执行。**
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

3. **提示用户重启所有已安装的 IDE**（VS Code、Cursor、Codex、Claude 等）

> **脚本会自动检测并配置所有已安装的 IDE**（VS Code / Cursor / Codex / Claude），无需手动指定。
>
> **可选参数**（仅在用户明确要求时使用）：
>
> | 用户意图 | 参数 |
> |----------|------|
> | 仅配置指定 IDE | `-Target Codex`、`-Target VSCode,Cursor`、`-Target Claude` |
> | 覆盖已有配置 | `-Force` |
> | 组合使用 | `-Target Codex -Force` |
>
> **IDE 识别规则**：当用户明确提到特定 IDE 时添加 `-Target`：
> - "Copilot" / "VS Code" / "VSCode" → `-Target VSCode`
> - "Cursor" → `-Target Cursor`
> - "Codex" → `-Target Codex`
> - "Claude" / "Claude Code" → `-Target Claude`
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
   & "$env:USERPROFILE\.copilot-config\update.ps1" -Target Claude
   ```
   ```bash
   # Linux / macOS
   bash ~/.copilot-config/update.sh
   # Linux / macOS — 仅更新指定 IDE
   bash ~/.copilot-config/update.sh --target=codex
   bash ~/.copilot-config/update.sh --target=claude
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
| `claude/CLAUDE.md` | Claude 全局行为规范（5 条编码准则） |
| `claude/skills/` | Claude 全局 Skills（9 个，扁平结构，与其他 IDE 技能内容同源） |
| `claude/hooks/` | Claude Code PreToolUse dcg 低噪音过滤器 |
| `copilot/instructions/` | VS Code Copilot 全局指令（中文规范、Python 虚拟环境、5 条编码准则等） |
| `copilot/skills/` | VS Code Copilot 自定义 Skill（按分类组织的 9 个，含安全护栏） |
| `copilot/hooks/` | GitHub Copilot preToolUse dcg 低噪音过滤器 |
| `codex/AGENTS.md` | Codex 全局指令（AGENTS.md 格式，5 条编码准则） |
| `codex/config.toml` | Codex MCP 服务器配置模板（默认 `[features] codex_hooks = true`） |
| `codex/skills/` | **Codex 全局 Skills（9 个，扁平结构，与 Cursor / Copilot / Claude 技能内容同源）** |
| `codex/hooks/README.md` | **Codex PreToolUse 低噪音硬兜底说明（restore 脚本检测/安装社区方案 [dcg](https://github.com/Dicklesworthstone/destructive_command_guard)）** |
| `codex/hooks.json` | Codex Hooks 配置模板（轻量过滤器先筛选，再按需调用 `dcg`） |
| `cursor/mcp.json` | Cursor MCP 服务器配置模板（含路径占位符） |
| `cursor/rules/` | Cursor 全局 Rules（`.mdc` 格式） |
| `cursor/skills/` | Cursor Skills（按分类组织的 9 个，与 Copilot / Codex / Claude 技能内容同源） |
| `cursor/settings.json` | Cursor 编辑器设置模板 |
| `cursor/hooks.json` / `cursor/hooks/` | Cursor beforeShellExecution dcg 低噪音过滤器 |
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
| markitdown (Microsoft) | 将 Word/PDF/PPT/Excel 等文件转换为 Markdown，AI 可直接读取 | 通过 `uvx tool run` 按需启动，无需本地安装 |

> 其他 MCP 服务（GitHub、Context7 等）不由本仓库自动安装，按需手动配置。
> mcp.json 模板不包含任何 API Key 或 Token，路径使用占位符，由还原脚本自动替换。

## 📐 全局 Rules

| 规则文件 | 适用于 | 说明 |
|----------|--------|------|
| `claude/CLAUDE.md` | Claude | 中文回复、Python 虚拟环境、5 条编码准则（简洁/精准/目标驱动） |
| `copilot/instructions/copilot-instructions.md` | VS Code Copilot | 中文回复、Python 虚拟环境、5 条编码准则（简洁/精准/目标驱动） |
| `codex/AGENTS.md` | Codex | 中文回复、Python 虚拟环境、5 条编码准则（简洁/精准/目标驱动） |
| `cursor/rules/mcp-feedback.mdc` | Cursor | 中文回复、Python 虚拟环境、5 条编码准则（简洁/精准/目标驱动） |

## 🛠️ Skills 清单

### 共享 Skills（Cursor + VS Code Copilot + Codex + Claude 四套同源）

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
| 🛡️ 安全 | **destructive-command-guard** | **拦截 `rm -rf` / `Remove-Item -Recurse` / `git reset --hard` / `DROP TABLE` 等高危命令的软兜底** |

> Cursor 自带的官方 Skills（babysit / canvas / create-rule 等）由 Cursor 安装时附带，不在本仓库管理范围内。

## 🛡️ 安全防护（破坏性命令双层兜底）

**背景**：Codex 等 AI agent 在 Windows 上有过整盘删除事故（典型如 `powershell -c "cmd /c rmdir /s /q F:\foo"` 中 PowerShell × cmd 的转义符冲突，实际执行成 `rmdir /s /q F:\` 整盘清空）。本仓库默认启用**软层 SKILL + dcg 低噪音硬层 hook**。

> ### ⚠️ Windows 用户必读（不影响一键配置，但要知情）
>
> Codex 当前 PreToolUse hook 的 matcher 只能按工具名匹配 `Bash`，不能只匹配 `rm -rf` / `git reset --hard` 等危险命令。为减少 token / 上下文噪音，本仓库默认让 hook 先进入轻量过滤器；只有命令看起来高危时，才调用 `dcg` 本体。

### 软层 — `destructive-command-guard` Skill（跨 4 IDE / 跨平台）

通过 `SKILL.md` 的 `description` 中的 trigger 关键词，让 Cursor / Copilot / Codex / Claude 在生成 `rm` / `del` / `rmdir` / `Remove-Item` / `git reset --hard` / `DROP TABLE` 等命令前自动加载并强制 `AskQuestion` 二次确认。

| 项 | 详情 |
|----|------|
| ✅ 平台 | Windows / macOS / Linux 全部生效 |
| ✅ IDE | Cursor / VS Code Copilot / Codex / Claude 四家同源 |
| 💰 成本 | description 约 200 tokens 注入 system prompt，完整 SKILL.md 仅在触发时加载 |
| ⚠️ 局限 | 属于 prompt 层，模型在极端情况（上下文严重压缩、`--full-auto` / `--yolo` / `danger-full-access`）可能绕过 |

### 硬层 — 社区方案 [dcg](https://github.com/Dicklesworthstone/destructive_command_guard)（默认启用低噪音 hook）

经过对比 OpenAI 官方文档与社区方案，本仓库**不自研 hook 脚本**，改为引用社区项目 [`Dicklesworthstone/destructive_command_guard`（dcg）](https://github.com/Dicklesworthstone/destructive_command_guard)：

| 维度 | 详情 |
|------|------|
| ⭐ 关注度 | GitHub **846+ stars**（截至 2026-04），restore 会从 GitHub Releases 解析 latest tag（本机验证为 `v0.4.5`），活跃维护中 |
| 🛠 实现 | Rust 二进制（SIMD 加速，sub-millisecond latency）+ codecov 覆盖率徽章 |
| 📦 规则覆盖 | **49+ 安全 packs**：`core.git` / `core.filesystem` 默认开；`database.postgresql` / `kubernetes.kubectl` / `cloud.aws` / `terraform` / `containers.docker` / `secrets.vault` 等可选开 |
| 🔗 跨 agent | 同一份配置同时支持 Codex CLI / Claude Code / Gemini CLI / Copilot CLI / Cursor / OpenCode / Aider |
| 🌍 跨平台 | Linux x86_64/aarch64、macOS Intel/Apple Silicon、**Windows x86_64**（原生 .exe） |
| 🔐 安装校验 | 官方 `install.ps1` / `install.sh` 强制 SHA256；可选 cosign / Sigstore 签名 |
| 🚪 绕过机制 | `DCG_BYPASS=1`、`dcg allow-once <code>`、`dcg allowlist add` 三档可控豁免 |
| 🧯 失败模式 | 默认 fail-open（任何超时 / 解析错误都放行，不阻塞开发） |
| 📜 透明 | 所有规则在 `dcg packs --verbose` 可枚举；自定义 packs 用 YAML 写在 `.dcg/packs/` |

**restore 脚本的 dcg 自动配置流程**：

1. **检测**：`dcg` / `dcg.exe` 是否已在 PATH 或 `~/.local/bin/` 下
2. **询问** `[y/N]`：未安装时弹出确认（你必须明确同意才会动手；或 `-AutoInstallDcg` / `--auto-install-dcg` 跳过询问；或 `-SkipDcg` / `--skip-dcg` 完全跳过）
3. **下载并校验**：
   - **macOS / Linux**：直接代理调用上游官方 `install.sh`（含 SHA256 校验 + 可选 cosign 签名）
   - **Windows**：因为上游 `install.ps1` 在 Windows PowerShell 5.1（系统默认 shell）下有兼容 bug（`Invoke-WebRequest -UseBasicParsing` 返回 byte[] 而非 string，导致它的 `.Trim()` 抛异常）—— `restore.ps1` 用 PS 5.1 兼容代码**复刻同样的流程**：从 GitHub Releases 拉 `dcg-x86_64-pc-windows-msvc.zip` + 上游 `.sha256` 强制校验 → 解压 → 写 `~/.local/bin/dcg.exe` → 加用户 PATH。**信任锚点不变**（zip 与 .sha256 都是 dcg 上游发布的 GitHub Release artifact）
4. **低噪音 hook**：部署 Codex / Claude Code / Cursor / Copilot 对应的过滤器；Codex 额外设置 `codex_hooks = true`
5. **按需调用 dcg**：过滤器只在命令看起来涉及删除、危险 git、数据库清空、格式化、云资源销毁等高危模式时调用 `dcg`
6. 重启对应 AI 工具会话

详见 [`codex/hooks/README.md`](codex/hooks/README.md)。

### 企业级可信任性（诚实披露）

| 维度 | 软层 SKILL（本仓库自研） | 硬层 dcg（社区方案） |
|------|--------------------|------------------|
| 维护方 | 本仓库 | [@Dicklesworthstone](https://github.com/Dicklesworthstone)（个人） |
| 代码量 | 9 个 SKILL.md（其中 1 个 destructive-command-guard） | Rust 二进制（49+ packs） |
| 测试覆盖 | 由本仓库 CI 校验 description schema | 上游 codecov 覆盖率徽章公开可查 |
| 供应链 | 仅 Markdown 文本，零运行时依赖 | Rust 二进制；MIT 协议；源码可审；官方安装器强制 SHA256 |
| 安装责任 | 本仓库脚本直接复制文件 | macOS/Linux：代理调用上游 `install.sh`（信任完全归上游）。Windows：因上游 `install.ps1` 在 PS 5.1 下有兼容 bug，本仓库用 PS 5.1 兼容代码**复刻**同样流程（信任锚点不变：仍下载上游 zip + 用上游 `.sha256` 校验） |
| **Bus factor** | 本仓库维护者团队 | **1（作者明确声明不接受外部 PR）** ← 必须了解的风险 |
| 升级方式 | `git pull` + `restore` | `dcg update` 或重跑 `restore -AutoInstallDcg` |
| 影响面 | 跨 IDE 跨平台 | 全平台 dcg 命令行可用；Codex hook 默认启用轻量过滤器，高危命令才进入 dcg 本体 |

**为什么用 dcg 而不是自研**：
- 自研 hook 等同重新发明轮子；dcg 已有 49 个 packs 覆盖 git / 数据库 / k8s / 云厂商 / IaC 等，单仓库难以维护到这个广度
- dcg 上游做了 SIMD 加速、heredoc 扫描、内联脚本扫描（如 `python -c "shutil.rmtree(...)"`），这些复杂场景自研难以做对
- 标准化协议：dcg 同时跨 7 个 AI agent 兼容，便于团队混用

**为什么不直接 `irm | iex` / `curl | bash` 自动装**：
- 用户的供应链信任决策必须由用户自己做。restore 默认弹 `[y/N]`；明确同意（或显式 `-AutoInstallDcg` 旗标）后再下载
- 即使同意，也是**调用上游官方安装器**——SHA256 校验、cosign 验证、PATH 管理 都是 dcg 官方逻辑负责，本仓库不接管这些环节的责任

**为什么仍然保留软层 SKILL**：
- 万一 dcg 仓库哪天消失（Bus factor 1），软层 SKILL 仍然 100% 可用
- 硬层 hook 使用轻量过滤器，尽量避免每次 shell 调用都产生 dcg 校验噪音；高危命令仍进入 dcg 本体

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

# 4. Codex：AGENTS.md + skills（dcg 低噪音 hook 由 restore 脚本部署）
New-Item -ItemType Directory -Path "$env:USERPROFILE\.codex" -Force
Copy-Item "C:\Temp\copilot-config\codex\AGENTS.md" "$env:USERPROFILE\.codex\AGENTS.md" -Force
Copy-Item -Recurse "C:\Temp\copilot-config\codex\skills" "$env:USERPROFILE\.codex\" -Force

# 5. Claude：CLAUDE.md + skills
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude" -Force
Copy-Item "C:\Temp\copilot-config\claude\CLAUDE.md" "$env:USERPROFILE\.claude\CLAUDE.md" -Force
Copy-Item -Recurse "C:\Temp\copilot-config\claude\skills" "$env:USERPROFILE\.claude\" -Force

```

> 手动安装时需自行处理 mcp.json 和 config.toml 模板中的路径占位符替换，详见 `vscode/mcp.json`、`cursor/mcp.json` 和 `codex/config.toml`。本仓库不再自动安装或配置 Interactive-Feedback-MCP。

### 可选参数（脚本安装）

```powershell
.\restore.ps1                        # 增量模式（默认，保留用户已有配置）
.\restore.ps1 -Force                 # 完全覆盖模式
.\restore.ps1 -DryRun                # 预览模式，不实际修改
.\restore.ps1 -Target Codex          # 仅配置 Codex
.\restore.ps1 -Target Claude         # 仅配置 Claude
.\restore.ps1 -Target VSCode,Cursor  # 仅配置 VS Code 和 Cursor
.\restore.ps1 -Target Codex -Force   # 仅覆盖 Codex 配置
.\restore.ps1 -AutoInstallDcg        # 未装 dcg 时自动下载并校验上游 release，不再交互询问
.\restore.ps1 -DisableDcgHooks       # 安装/检测 dcg，但跳过所有 dcg hook 部署；Codex 设为 codex_hooks=false
.\restore.ps1 -SkipDcg               # 跳过 dcg 安装与所有 dcg hook 部署；Codex 设为 codex_hooks=false
```

```bash
# Linux / macOS
bash restore.sh                      # 增量模式（默认）
bash restore.sh --force              # 完全覆盖模式
bash restore.sh --target=codex       # 仅配置 Codex
bash restore.sh --target=claude      # 仅配置 Claude
bash restore.sh --target=vscode,cursor  # 仅配置 VS Code 和 Cursor
bash restore.sh --force --target=codex  # 仅覆盖 Codex 配置
bash restore.sh --auto-install-dcg   # 未装 dcg 时直接调用官方 install.sh，不再交互询问
bash restore.sh --disable-dcg-hooks  # 安装/检测 dcg，但跳过所有 dcg hook 部署；Codex 设为 codex_hooks=false
bash restore.sh --skip-dcg           # 跳过 dcg 安装与所有 dcg hook 部署；Codex 设为 codex_hooks=false
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

| 特性 | Cursor | VS Code | Codex | Claude |
|------|--------|---------|-------|--------|
| MCP 配置格式 | `mcp.json` (`mcpServers`) | `mcp.json` (`servers`) | `config.toml` (`[mcp_servers]`) | 不由本仓库配置 |
| MCP 条目格式 | 无需 `type` 字段 | 需要 `type: "stdio"` | TOML 表格式 | 不适用 |
| 规则格式 | `.mdc` + YAML frontmatter | `.instructions.md` + YAML frontmatter | `AGENTS.md`（纯 Markdown） | `CLAUDE.md`（纯 Markdown） |

## 🗺️ 路线图

- [x] AI Agent 自动配置支持
- [x] 远程更新 + 版本检查
- [x] VS Code Codex 自动配置
- [x] sync.sh（Linux/macOS 双向同步）
- [x] CI 校验 JSON/TOML 模板与版本号同步
- [x] Codex 全局 Agent Skills（与 Cursor/Copilot/Claude 技能内容同源）
- [x] 破坏性命令双层兜底（软层 SKILL.md + 硬层社区方案 [dcg](https://github.com/Dicklesworthstone/destructive_command_guard)）
- [ ] 设置页面内一键更新按钮
- [ ] 更多 MCP 服务器预配置

## 📄 许可

[MIT License](LICENSE) — 自由使用、修改、分发，无任何担保。
