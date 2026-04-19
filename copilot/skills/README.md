# VS Code Copilot Skills 说明

## 安装位置

所有技能由 `restore.ps1` / `restore.sh` 自动安装到 Copilot 全局目录：

- **Windows**：`%USERPROFILE%\.copilot\skills\`
- **macOS / Linux**：`~/.copilot/skills/`

VS Code Copilot 会自动识别该目录下的技能，无需额外配置。

---

## 来源说明

| 类型 | 说明 |
|------|------|
| **Anthropic 官方** | https://github.com/anthropics/skills（Apache 2.0 / source-available） |
| **社区成熟仓库** | https://github.com/alirezarezvani/claude-skills（MIT） |
| **本仓库自研** | `safety/destructive-command-guard` |

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
| destructive-command-guard | 在执行 `rm -rf` / `Remove-Item -Recurse` / `git reset --hard` / `DROP TABLE` 等高危命令前强制二次确认 | 本仓库自研 |

> 该 skill 同时部署在 `cursor/skills/`、`copilot/skills/`、`codex/skills/` 三处。本仓库 `restore.ps1` / `restore.sh` 默认会**询问**是否一并安装社区方案 [`dcg`](https://github.com/Dicklesworthstone/destructive_command_guard) 作为硬兜底（846+ stars / 49+ packs / Rust 二进制 / Windows + macOS + Linux 原生支持；通过代理调用 dcg 官方 install 脚本，含 SHA256 校验）。**Windows 上 Codex 引擎暂禁用 hooks**（OpenAI 标注为 *temporarily*），dcg.exe 仍会被装上以供其他用途，但 Codex 当前不调用——所以 Windows 主机上 Codex 的兜底只有软层 SKILL。

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

在 VS Code Copilot 对话中直接描述需求即可，AI 会根据上下文自动选择合适技能：

- 示例：「用 PDF skill 从 xxx.pdf 提取表单字段」
- 示例：「帮我做一下这个 PR 的 code review」
- 示例：「用 mcp-builder 创建一个 MCP 服务器」
- 示例：「分析这个代码库，生成上手文档」

---

## 迁移到新电脑

直接运行仓库根目录的 `restore.ps1` / `restore.sh` 即可一键还原；或将本目录复制到目标机器的 `~/.copilot/skills/` 后重启 VS Code。
