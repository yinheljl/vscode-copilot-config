# Codex Skills 说明

## 安装位置

所有技能由 `restore.ps1` / `restore.sh` 自动安装到 Codex 全局技能目录：

- **Windows**：`%USERPROFILE%\.codex\skills\`
- **macOS / Linux**：`~/.codex/skills/`（亦兼容 `~/.agents/skills/` 新约定）

> Codex CLI / IDE 扩展 / Codex 桌面端会自动扫描该目录下所有子文件夹的 `SKILL.md`。
> 如果安装后 Codex 仍未识别，**请重启 Codex**（CLI 会在下一轮新会话生效；桌面端需完整退出再启动）。
> 详见 [Codex 官方 Agent Skills 文档](https://developers.openai.com/codex/skills)。

## 与本仓库内 `cursor/skills/`、`copilot/skills/`、`claude/skills/` 的关系

四套目录内容**完全一致**，由 `sync.ps1` / `sync.sh` 双向同步保证。本目录额外存在的原因：

- **Cursor / VS Code Copilot / Claude 与 Codex 是不同的 agent 进程**，各自只读自己的全局技能目录
- Codex CLI 默认根本不读取 `~/.cursor/skills` 或 `~/.copilot/skills` 或 `~/.claude/skills`
- 因此必须为 Codex 单独维护一份饕像

如果你只用 Cursor + Copilot + Claude，本目录可以不部署（`restore` 在未检测到 Codex 时会自动跳过）。

---

## 来源说明

| 类型 | 说明 |
|------|------|
| **Anthropic 官方** | https://github.com/anthropics/skills（Apache 2.0 / source-available） |
| **社区成熟仓库** | https://github.com/alirezarezvani/claude-skills（MIT） |
| **本仓库自研** | `safety/destructive-command-guard` SKILL.md（破坏性命令软兜底，硬层使用社区方案 dcg，详见下文安全章节） |

---

## 已安装技能清单（共 9 个）

> 目录结构为**扁平层**：`skills/<技能名>/SKILL.md`（不再按分类子目录组织）

| 技能 | 类别 | 用途 | 来源 |
|------|------|------|------|
| docx | 文档 | Word 文档创建、编辑、批注 | Anthropic 官方 |
| xlsx | 文档 | Excel 表格处理、公式、图表 | Anthropic 官方 |
| pptx | 文档 | PowerPoint 演示文稿 | Anthropic 官方 |
| pdf  | 文档 | PDF 提取、合并、标注、填表 | Anthropic 官方 |
| webapp-testing | 测试 | Web 应用测试（Playwright） | Anthropic 官方 |
| code-reviewer | 生产力 | 多语言代码评审（TS/Python/Go/Swift） | alirezarezvani/claude-skills |
| mcp-builder   | 生产力 | MCP 服务器构建 | Anthropic 官方 |
| codebase-onboarding | 工程 | 代码库分析与上手文档生成 | alirezarezvani/claude-skills |
| **destructive-command-guard** | 🛡️ 安全 | 在执行 `rm -rf` / `Remove-Item -Recurse` / `git reset --hard` / `DROP TABLE` 等高危命令前强制二次确认（**软兜底**） | 本仓库自研 |

---

## 双层安全防护

Codex 历史上出现过多起整盘删除事故（典型如 PowerShell × cmd 嵌套调用导致的 F 盘清空）。本仓库提供**软 + 硬**双层兜底：

### 软层（本目录）

`destructive-command-guard/SKILL.md` —— 通过 `description` 中的 trigger 关键词，让 Codex 在生成 `rm`/`del`/`rmdir`/`Remove-Item`/`git reset --hard` 等命令前自动加载该 skill，强制二次确认。

**特点**：
- 跨平台（Windows / macOS / Linux）
- 跨 IDE（同一份内容也部署到 cursor/skills 与 copilot/skills）
- 零依赖，重启 Codex 即生效

**局限**：
- 软规则属于 prompt 层，模型在上下文严重压缩或 `--full-auto` / `--yolo` 模式下仍可能绕过 —— 这正是下方硬层 hook 存在的原因（hook 不依赖模型自觉性）

### 硬层（社区方案 dcg，由 restore 脚本自动配置）

> **Windows 用户**：OpenAI 官方文档当前明确 "Hooks are currently disabled on Windows"（标注为 *temporarily*）。restore.ps1 仍会询问安装 dcg.exe（命令行工具 + 其他 agent 仍可用），但**不会部署 `~/.codex/hooks.json`**。Windows 主机上 Codex 的兜底当前**只有软层 SKILL**——请确保启用。

经过对比 OpenAI 官方文档与社区方案，本仓库使用 [`Dicklesworthstone/destructive_command_guard`（dcg）](https://github.com/Dicklesworthstone/destructive_command_guard)：

- **关注度与维护**：GitHub 846+ stars，最近 release `v0.4.0`（2026-04），活跃维护；上游 codecov 覆盖率徽章公开可查
- **实现**：Rust 二进制（SIMD 加速，sub-millisecond latency）
- **覆盖**：49+ 安全 packs（`core.git` / `core.filesystem` 默认开启，可加 `database.postgresql` / `kubernetes.kubectl` / `cloud.aws` / `terraform` / `containers.docker` / `secrets.vault` 等）
- **跨 agent 兼容**：Codex CLI / Claude Code / Gemini CLI / Copilot CLI / Cursor / OpenCode / Aider 一份配置全用
- **跨平台**：Linux x86_64/aarch64、macOS Intel/Apple Silicon、**Windows x86_64**（原生 .exe）
- **绕过机制**：`DCG_BYPASS=1 <cmd>` / `dcg allow-once <code>` / `dcg allowlist add <rule>`
- **失败模式**：默认 fail-open（任何超时 / 解析错误都放行，不阻塞开发）

**Bus factor 风险（必须了解）**：dcg 由 [@Dicklesworthstone](https://github.com/Dicklesworthstone) 个人维护，作者明确声明不接受外部 PR。即便如此，相比自研 49 个 packs，社区方案在覆盖广度与维护成本上显著更优。企业用户如担心可 fork 一份。

**自动配置流程（restore 脚本一键完成）**：

1. **检测**：`dcg` / `dcg.exe` 是否在 PATH 或 `~/.local/bin/` 下
2. **询问** `[y/N]`：未安装时弹出确认（你必须明确同意；或显式旗标 `-AutoInstallDcg` / `--auto-install-dcg` 跳过询问；或 `-SkipDcg` / `--skip-dcg` 完全跳过）
3. **代理调用官方安装器**：`install.ps1` / `install.sh` 完成 SHA256 校验、解压到 `~/.local/bin/`、写入 PATH
4. **macOS / Linux**：自动部署 `~/.codex/hooks.json` + 启用 `[features] codex_hooks = true`
5. **Windows**：装好 dcg.exe 后跳过 hooks.json（Codex 引擎暂禁用 hook）
6. 重启 Codex 会话

restore 脚本**只代理调用上游官方安装器**，不重写下载/校验逻辑——出问题归 dcg 上游。

详见 [`codex/hooks/README.md`](../hooks/README.md)。

---

## 自编写技能规范

| 规范项 | 要求 |
|--------|------|
| 可追溯性 | 内容可追溯至公开标准或通用工程实践 |
| Minimum Inputs | 明确执行所需最小输入 |
| Evidence Discipline | 输出包含可验证证据（检查清单、日志摘要等） |
| Constraints | 明确执行限制条件（如仅读、不修改生产配置） |
| SKILL.md 结构 | 含 `name`、`description` 的 YAML frontmatter |

---

## 使用方式

在 Codex CLI / 桌面端对话中直接描述需求即可，Codex 会根据 `SKILL.md` 的 `description` 自动决定是否加载某个 skill：

- 示例：「用 PDF skill 从 xxx.pdf 提取表单字段」
- 示例：「帮我做一下这个 PR 的 code review」
- 示例：「分析这个代码库，生成上手文档」

> 任何包含「删除」「清理」「rm」「reset」字样的请求会自动触发 `destructive-command-guard`。

---

## 迁移到新电脑

直接运行仓库根目录的 `update.ps1` / `update.sh`（会自动 `git pull` + `restore`），或仅运行 `restore.ps1` / `restore.sh`。

> restore 脚本会**自动询问**是否安装 dcg（硬层）；想跳过询问就加 `-AutoInstallDcg` / `--auto-install-dcg`；想完全跳过就加 `-SkipDcg` / `--skip-dcg`。Windows 上 dcg.exe 仍会装上，但 Codex hook 部署会被跳过（Codex 引擎暂禁用 Windows hook）。
