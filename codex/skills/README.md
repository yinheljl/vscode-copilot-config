# Codex Skills 说明

## 安装位置

所有技能由 `restore.ps1` / `restore.sh` 自动安装到 Codex 全局技能目录：

- **Windows**：`%USERPROFILE%\.codex\skills\`
- **macOS / Linux**：`~/.codex/skills/`（亦兼容 `~/.agents/skills/` 新约定）

> Codex CLI / IDE 扩展 / Codex 桌面端会自动扫描该目录下所有子文件夹的 `SKILL.md`。
> 如果安装后 Codex 仍未识别，**请重启 Codex**（CLI 会在下一轮新会话生效；桌面端需完整退出再启动）。
> 详见 [Codex 官方 Agent Skills 文档](https://developers.openai.com/codex/skills)。

## 与本仓库内 `cursor/skills/`、`copilot/skills/` 的关系

三套目录内容**完全一致**，由 `sync.ps1` / `sync.sh` 双向同步保证。本目录额外存在的原因：

- **Cursor / VS Code Copilot 与 Codex 是不同的 agent 进程**，各自只读自己的全局技能目录
- Codex CLI 默认根本不读取 `~/.cursor/skills` 或 `~/.copilot/skills`
- 因此必须为 Codex 单独维护一份镜像

如果你只用 Cursor + Copilot，本目录可以不部署（`restore` 在未检测到 Codex 时会自动跳过）。

---

## 来源说明

| 类型 | 说明 |
|------|------|
| **Anthropic 官方** | https://github.com/anthropics/skills（Apache 2.0 / source-available） |
| **社区成熟仓库** | https://github.com/alirezarezvani/claude-skills（MIT） |
| **本仓库自研** | `safety/destructive-command-guard`（破坏性命令安全护栏，详见下文安全章节） |

---

## 已安装技能清单（共 9 个）

### 文档类 (document)

| 技能 | 用途 | 来源 |
|------|------|------|
| docx | Word 文档创建、编辑、批注 | Anthropic 官方 |
| xlsx | Excel 表格处理、公式、图表 | Anthropic 官方 |
| pptx | PowerPoint 演示文稿 | Anthropic 官方 |
| pdf  | PDF 提取、合并、标注、填表 | Anthropic 官方 |

### 测试类 (testing)

| 技能 | 用途 | 来源 |
|------|------|------|
| webapp-testing | Web 应用测试（Playwright） | Anthropic 官方 |

### 生产力类 (productivity)

| 技能 | 用途 | 来源 |
|------|------|------|
| code-reviewer | 多语言代码评审（TS/Python/Go/Swift） | alirezarezvani/claude-skills |
| mcp-builder   | MCP 服务器构建 | Anthropic 官方 |

### 工程类 (engineering)

| 技能 | 用途 | 来源 |
|------|------|------|
| codebase-onboarding | 代码库分析与上手文档生成 | alirezarezvani/claude-skills |

### 🛡️ 安全类 (safety)

| 技能 | 用途 | 来源 |
|------|------|------|
| destructive-command-guard | 在执行 `rm -rf` / `Remove-Item -Recurse` / `git reset --hard` / `DROP TABLE` 等高危命令前强制二次确认（**软兜底**） | 本仓库自研 |

---

## 双层安全防护

Codex 历史上出现过多起整盘删除事故（典型如 PowerShell × cmd 嵌套调用导致的 F 盘清空）。本仓库提供**软 + 硬**双层兜底：

### 软层（本目录）

`safety/destructive-command-guard/SKILL.md` —— 通过 `description` 中的 trigger 关键词，让 Codex 在生成 `rm`/`del`/`rmdir`/`Remove-Item`/`git reset --hard` 等命令前自动加载该 skill，强制二次确认。

**特点**：
- 跨平台（Windows / macOS / Linux）
- 跨 IDE（同一份内容也部署到 cursor/skills 与 copilot/skills）
- 零依赖，重启 Codex 即生效

**局限**：
- 软规则属于 prompt 层，模型在上下文严重压缩或 `--full-auto` / `--yolo` 模式下仍可能绕过 —— 这正是下方硬层 hook 存在的原因（hook 不依赖模型自觉性）

### 硬层（hook，由 `restore` 脚本自动安装）

**本仓库自研** `codex/hooks/pre_tool_use_guard.py` —— 注册到 Codex 官方 [`PreToolUse` Hook](https://developers.openai.com/codex/hooks)：

- **零外部依赖**：仅 ~200 行 Python，**只用标准库**（`json`、`re`、`sys`、`subprocess`），无 npm、无 pip install
- **源码全部可审计**：脚本与规则都在仓库内（`codex/hooks/pre_tool_use_guard.py`），企业可在合并前自行 review
- **CI 强制覆盖**：`codex/hooks/test_pre_tool_use_guard.py` 26 个 case（17 deny + 9 allow），由 `.github/workflows/validate.yml` 在每次 PR 上跑
- **接口契约稳定**：使用 OpenAI Codex CLI 官方 PreToolUse Hook 协议，不依赖任何第三方包/CLI
- **拦截时机正确**：命令在**进入 shell 之前**就被检查，模型层无法绕过
- **审计日志**：所有触发记录写入 `~/.codex/hooks/logs/`，可对接企业 SIEM
- **可控豁免**：仅当 cwd 下显式存在 `.codex-allow-destructive` 时放行（短期排错用）

如果本机未安装 Python 3.8+，`restore` 脚本会自动跳过硬层并打印警告，软层（skill 规则）仍然生效。

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

直接运行仓库根目录的 `update.ps1` / `update.sh`（会自动 `git pull` + `restore` + 部署 `pre_tool_use_guard.py` hook），或仅运行 `restore.ps1` / `restore.sh`。
