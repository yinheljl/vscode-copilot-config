# AI Agent Skills 说明（Copilot 镜像）

## 安装位置

所有技能已安装至以下全局目录（Cursor 与 Copilot 保持同步）：

| 平台 | 全局目录 |
|------|----------|
| **Cursor** | `C:\Users\59977\.cursor\skills\` |
| **Copilot** | `C:\Users\59977\.copilot\skills\` |

Agent Skills 采用 `SKILL.md` 开放标准，跨平台兼容。

---

## 来源说明

| 类型 | 说明 |
|------|------|
| **网络下载** | 从公开仓库获取，已注明来源 URL 与许可证 |
| **自编写** | 依据行业标准自行编写，含 Minimum Inputs、Evidence Discipline、Constraints 三段约束，可追溯至公开规范 |

---

## 已安装技能清单（共 24 个）

### 文档类 (document)

| 技能 | 用途 | 来源 | 依据/规范 |
|------|------|------|-----------|
| docx | Word 文档创建、编辑、批注 | 网络下载 | https://github.com/anthropics/skills（Apache 2.0 / source-available） |
| xlsx | Excel 表格处理、公式、图表 | 网络下载 | https://github.com/anthropics/skills（Apache 2.0 / source-available） |
| pptx | PowerPoint 演示文稿 | 网络下载 | https://github.com/anthropics/skills（Apache 2.0 / source-available） |
| pdf | PDF 提取、合并、标注 | 网络下载 | https://github.com/anthropics/skills（Apache 2.0 / source-available） |

### 测试类 (testing)

| 技能 | 用途 | 来源 | 依据/规范 |
|------|------|------|-----------|
| webapp-testing | Web 应用测试（Playwright） | 网络下载 | https://github.com/anthropics/skills（Apache 2.0） |
| api-test-suite-builder | API 测试套件生成 | 网络下载 | https://github.com/alirezarezvani/claude-skills（依仓库） |
| senior-qa | 高级 QA 流程与测试设计 | 网络下载 | https://github.com/alirezarezvani/claude-skills（依仓库） |
| capl-test-automation | CAPL 测试自动化（CANoe 脚本） | 自编写 | 符合规范；依据 Vector CAPL 文档、CANoe 帮助 |
| diva-diagnostic-test | DiVa 诊断测试（ODX/VDS） | 自编写 | 符合规范；依据 Vector CANoe.DiVa、ISO 22901-1（ODX）、VDS Library |

### 架构类 (architecture)

| 技能 | 用途 | 来源 | 依据/规范 |
|------|------|------|-----------|
| system-architect | 系统架构设计 | 网络下载 | https://github.com/aj-geddes/claude-code-bmad-skills（bmad-skills） |

### 生产力类 (productivity)

| 技能 | 用途 | 来源 | 依据/规范 |
|------|------|------|-----------|
| skill-creator | 技能创建与优化 | 网络下载 | https://github.com/anthropics/skills（Apache 2.0） |
| mcp-builder | MCP 服务器构建 | 网络下载 | https://github.com/anthropics/skills（Apache 2.0） |
| code-reviewer | 代码评审 | 网络下载 | https://github.com/alirezarezvani/claude-skills（依仓库） |
| polarion-requirements | Polarion ALM 需求管理与追溯 | 自编写 | 符合规范；依据 Siemens Polarion REST API、ReqIF（ISO 29148） |

### 车载类 (automotive)

| 技能 | 用途 | 来源 | 依据/规范 |
|------|------|------|-----------|
| autosar-bsw-review | AUTOSAR BSW 配置与代码评审 | 自编写 | 符合规范；依据 AUTOSAR BSW SWS、MCAL SRS |
| uds-diagnostic-flow | UDS 诊断流程指导 | 自编写 | 符合规范；依据 ISO 14229（UDS）、ISO 15765-2 |
| can-log-triage | CAN 日志快速分诊 | 自编写 | 符合规范；依据 ISO 11898、DBC 通用约定 |
| someip-service-debug | SOME/IP 服务调试 | 自编写 | 符合规范；依据 SOME/IP 规范、AUTOSAR SOME/IP 绑定 |
| doip-diagnostic-gateway | DoIP 网关诊断 | 自编写 | 符合规范；依据 ISO 13400-1/2（DoIP） |

### 嵌入式类 (embedded)

| 技能 | 用途 | 来源 | 依据/规范 |
|------|------|------|-----------|
| qnx-bsp-debug | QNX BSP 调试流程 | 自编写 | 符合规范；依据 QNX BSP Developer's Guide、System Architecture |
| bootloader-update-safety | Bootloader 升级安全 | 自编写 | 符合规范；依据 ISO 14229（0x31/0x36/0x37）、ISO/SAE 21434 |

### 安全类 (security)

| 技能 | 用途 | 来源 | 依据/规范 |
|------|------|------|-----------|
| automotive-tara-lite | 轻量 TARA 威胁分析 | 自编写 | 符合规范；依据 ISO/SAE 21434（汽车网络安全）、SAE J3061 |

### 代码库智能类 (codebase-intelligence)

| 技能 | 用途 | 来源 | 依据/规范 |
|------|------|------|-----------|
| nexus-mapper | 代码库全量分析，生成持久化 `.nexus-map/` 知识库（架构图、依赖、测试覆盖、热点） | 网络下载 | https://github.com/Haaaiawd/Nexus-skills（MIT） |
| nexus-query | 代码结构即时查询（AST 骨架、反向依赖、变更影响半径、耦合热点） | 网络下载 | https://github.com/Haaaiawd/Nexus-skills（MIT） |

---

## 自编写技能规范说明

自编写技能均满足以下规范：

| 规范项 | 要求 | 依据 |
|--------|------|------|
| 可追溯性 | 内容可追溯至公开标准或通用工程实践 | 不得加入无依据结论 |
| Minimum Inputs | 明确执行所需最小输入 | 确保可验证 |
| Evidence Discipline | 输出包含可验证证据 | 检查清单、日志摘要等 |
| Constraints | 执行限制条件 | 如仅读、不修改生产配置 |
| SKILL.md 结构 | 含 name、description（YAML frontmatter） | Agent Skills 开放标准规范 |

---

## 使用方式

在 AI 对话中直接描述需求即可，Agent 会根据上下文自动选择合适技能：

- 示例：「用 PDF skill 从 xxx.pdf 提取表单字段」
- 示例：「按 UDS 诊断流程帮我设计 0x22 读 DID 的序列」
- 示例：「用 CAN 日志分诊帮我分析这个 log 文件」
- 示例：「用 CAPL 写一个 UDS TesterPresent 周期发送的脚本」
- 示例：「DiVa 如何从 ODX 生成 UDS 测试用例」
- 示例：「用 nexus-mapper 分析当前代码库并生成知识图谱」
- 示例：「用 nexus-query 查一下谁引用了 MDL_FuelTank 模块」

---

## 同步说明

本目录与 `C:\Users\59977\.cursor\skills\` 保持同步。两边使用完全相同的 SKILL.md 文件和脚本。

更新流程：
1. 在 Cursor skills 目录中新增/修改技能
2. 将变更同步复制到本目录
3. 同步更新两边的 `README.md`
