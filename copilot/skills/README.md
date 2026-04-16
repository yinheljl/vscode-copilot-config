# Cursor Skills 说明

## 安装位置

所有技能已安装至 Cursor 全局目录：

- **Windows**：`C:\Users\59977\.cursor\skills\`
- **macOS/Linux**：`~/.cursor/skills/`

Cursor 会自动识别该目录下的技能，无需额外配置。

---

## 来源说明

| 类型 | 说明 |
|------|------|
| **Anthropic 官方** | https://github.com/anthropics/skills（109k★, Apache 2.0 / source-available） |
| **社区成熟仓库** | https://github.com/alirezarezvani/claude-skills（9k★, MIT） |

---

## 已安装技能清单（共 8 个）

### 文档类 (document)

| 技能 | 用途 | 来源 |
|------|------|------|
| docx | Word 文档创建、编辑、批注 | Anthropic 官方 |
| xlsx | Excel 表格处理、公式、图表 | Anthropic 官方 |
| pptx | PowerPoint 演示文稿 | Anthropic 官方 |
| pdf | PDF 提取、合并、标注、填表 | Anthropic 官方 |

### 测试类 (testing)

| 技能 | 用途 | 来源 |
|------|------|------|
| webapp-testing | Web 应用测试（Playwright） | Anthropic 官方 |

### 生产力类 (productivity)

| 技能 | 用途 | 来源 |
|------|------|------|
| code-reviewer | 多语言代码评审（TS/Python/Go/Swift） | alirezarezvani/claude-skills |
| mcp-builder | MCP 服务器构建 | Anthropic 官方 |

### 工程类 (engineering)

| 技能 | 用途 | 来源 |
|------|------|------|
| codebase-onboarding | 代码库分析与上手文档生成 | alirezarezvani/claude-skills |

---

## 自编写技能规范说明

自编写技能均满足以下规范：

| 规范项 | 要求 | 依据 |
|--------|------|------|
| 可追溯性 | 内容可追溯至公开标准或通用工程实践 | 不得加入无依据结论 |
| Minimum Inputs | 明确执行所需最小输入 | 确保可验证 |
| Evidence Discipline | 输出包含可验证证据 | 检查清单、日志摘要等 |
| Constraints | 执行限制条件 | 如仅读、不修改生产配置 |
| SKILL.md 结构 | 含 name、description（YAML frontmatter） | Cursor create-skill 规范 |

---

## 使用方式

在 Cursor 对话中直接描述需求即可，AI 会根据上下文自动选择合适技能：

- 示例：「用 PDF skill 从 xxx.pdf 提取表单字段」
- 示例：「帮我做一下这个 PR 的 code review」
- 示例：「用 mcp-builder 创建一个 MCP 服务器」
- 示例：「分析这个代码库，生成上手文档」

---

## 迁移到新电脑

使用仓库的还原脚本 `restore.ps1` / `restore.sh` 一键还原，或手动复制到对应路径后重启即可。
