# Codex 全局配置中心

> 面向 OpenAI Codex 的全局 `AGENTS.md`、Skills、MCP 和安全 hooks 配置仓库。

当前版本：`1.5.7`

本分支是 **Codex-only** 分支，只保留 Codex 相关内容。`main` 分支仍保留原来的多 Agent 配置。

## 快速开始

### Windows

```powershell
git clone --branch codex/codex-setup-doc --single-branch https://github.com/yinheljl/ai-agent-config.git "$env:USERPROFILE\.ai-agent-config"
Set-ExecutionPolicy -Scope Process Bypass -Force
& "$env:USERPROFILE\.ai-agent-config\restore.ps1"
```

如需无人值守安装/刷新 `dcg` 破坏性命令防护：

```powershell
& "$env:USERPROFILE\.ai-agent-config\restore.ps1" -AutoInstallDcg
```

### macOS / Linux / WSL2

```bash
git clone --branch codex/codex-setup-doc --single-branch https://github.com/yinheljl/ai-agent-config.git ~/.ai-agent-config
bash ~/.ai-agent-config/restore.sh
```

如需无人值守安装/刷新 `dcg`：

```bash
bash ~/.ai-agent-config/restore.sh --auto-install-dcg
```

配置完成后，重启 Codex App / Codex CLI / Codex IDE Extension。

## AI Agent 辅助配置

如果同事已经能打开 Codex 或其他本地 AI Agent，建议直接把下面这段话发给 Agent，让它按文档执行。首次配置时建议先 dry-run，再正式写入。

```text
请按照 https://github.com/yinheljl/ai-agent-config/tree/codex/codex-setup-doc 的 README，帮我在当前设备安装或更新 Codex 全局配置。

要求：
1. 如果配置仓库目录不存在，克隆 codex/codex-setup-doc 分支到 ~/.ai-agent-config（Windows PowerShell 用 $env:USERPROFILE\.ai-agent-config）；如果目录已存在，先确认它在 codex/codex-setup-doc 分支并拉取最新代码，或直接运行 update 脚本。
2. 先执行 restore 的 dry-run，让我确认将写入哪些文件。
3. 确认后执行 restore，写入 ~/.codex/AGENTS.md、~/.codex/skills/、MCP 和安全 hooks。
4. 不要同步或覆盖 Codex 自带的 .system skills；只处理本仓库管理的用户侧配置。
5. 如需安装或刷新 dcg，请先说明它的用途和来源，再让我确认。
6. 完成后运行验证命令，并告诉我是否需要重启 Codex。
```

## 仓库结构

| 路径 | 说明 |
|---|---|
| `codex/AGENTS.md` | Codex 全局行为规范 |
| `codex/config.toml` | Codex MCP 与 hooks feature 模板 |
| `codex/hooks.json` | Codex `PreToolUse` hook 模板 |
| `codex/hooks/` | 低噪音 `dcg` 过滤器和说明 |
| `codex/skills/` | Codex Skills，包含文档处理、代码审查、MCP 构建、安全护栏等 |
| `docs/CODEX_SETUP_GUIDE.md` | 面向同事的 Codex 安装、搭建、配置操作文档 |
| `restore.ps1` / `restore.sh` | 首次安装或重新写入 Codex 配置 |
| `update.ps1` / `update.sh` | 拉取仓库更新并重新执行 restore |
| `sync.ps1` / `sync.sh` | 从本机 `~/.codex` 同步自定义 `AGENTS.md` 和 skills 回仓库 |
| `scripts/validate_config.py` | 校验 Codex JSON/TOML 模板 |
| `scripts/check_version_sync.py` | 校验 `VERSION` 与 README 版本号一致 |

## restore 做了什么

`restore.ps1` / `restore.sh` 会写入或合并以下内容：

| 用户目录 | 来源 | 说明 |
|---|---|---|
| `~/.codex/AGENTS.md` | `codex/AGENTS.md` | 全局行为规范 |
| `~/.codex/skills/` | `codex/skills/` | Codex skills |
| `~/.codex/config.toml` | `codex/config.toml` | 追加/更新 `markitdown` MCP 与 `hooks` feature |
| `~/.codex/hooks.json` | `codex/hooks.json` | `dcg` hook 注册文件 |
| `~/.codex/hooks/` | `codex/hooks/` | hook 过滤器脚本 |

脚本默认是增量模式。加 `-Force` / `--force` 时，只会覆盖本仓库管理的目标；Codex 自带 `.system` skills 和其他非本仓库 skill 会保留。

## Skills 边界

本仓库只维护用户侧/团队侧共享 skills，也就是会写入 `~/.codex/skills/` 的内容。

Codex 自带的系统 skills 通常位于 `.system` 或由官方插件随 Codex 分发，它们应由 Codex 自身、官方插件或插件更新机制维护；本仓库不复制、不覆盖、不同步这些系统 skills。`sync.ps1` / `sync.sh` 也会跳过 `.system`。

## 常用命令

Windows：

```powershell
& "$env:USERPROFILE\.ai-agent-config\restore.ps1" -DryRun
& "$env:USERPROFILE\.ai-agent-config\restore.ps1" -Force
& "$env:USERPROFILE\.ai-agent-config\restore.ps1" -SkipDcg
& "$env:USERPROFILE\.ai-agent-config\update.ps1"
& "$env:USERPROFILE\.ai-agent-config\sync.ps1"
```

macOS / Linux / WSL2：

```bash
bash ~/.ai-agent-config/restore.sh --dry-run
bash ~/.ai-agent-config/restore.sh --force
bash ~/.ai-agent-config/restore.sh --skip-dcg
bash ~/.ai-agent-config/update.sh
bash ~/.ai-agent-config/sync.sh
```

## MCP 配置

当前默认配置两个 MCP server：

| Server | 用途 | 启动方式 |
|---|---|---|
| `markitdown` | 将 PDF、Word、Excel、PowerPoint 等文件转成 Markdown，便于 Codex 读取 | `uv tool run markitdown-mcp` |
| `openaiDeveloperDocs` | 查询 OpenAI / Codex 官方开发者文档 | `https://developers.openai.com/mcp` |

`restore` 会检测或安装 `uv`，并把 `uv` 的路径写入 `~/.codex/config.toml`。`openaiDeveloperDocs` 使用官方 Streamable HTTP MCP，不需要本地命令。

## 安全防护

本仓库提供两层防护：

- 软层：`codex/skills/destructive-command-guard/SKILL.md`，让 Codex 在生成高危命令前主动二次确认。
- 硬层：Codex `PreToolUse` hook + 社区项目 `dcg`，在 shell 命令执行前拦截高危命令。

默认行为：

- 未安装 `dcg` 时，脚本会询问是否安装；非交互环境默认不安装。
- 使用 `-AutoInstallDcg` / `--auto-install-dcg` 可跳过询问。
- 使用 `-DisableDcgHooks` / `--disable-dcg-hooks` 可保留 `dcg` 但关闭 Codex hook。
- 使用 `-SkipDcg` / `--skip-dcg` 会跳过 `dcg` 安装和 hook 写入。

更多细节见 [codex/hooks/README.md](codex/hooks/README.md)。

## 验证

```powershell
.\.venv\Scripts\python.exe scripts\validate_config.py
.\.venv\Scripts\python.exe scripts\check_version_sync.py
```

没有虚拟环境时也可以使用系统 Python 3.11+：

```bash
python scripts/validate_config.py
python scripts/check_version_sync.py
bash -n restore.sh update.sh sync.sh
```

## 上游核对记录

最近核对：2026-06-01。

| 项目 | 核对结果 | 本仓库处理 |
|---|---|---|
| Codex CLI | 本机 `codex-cli 0.135.0`，npm `@openai/codex` 最新同为 `0.135.0` | 无需修改安装脚本 |
| Codex Hooks | 官方文档说明 `PreToolUse` 不支持 `continue` 字段，允许时应退出 0 且不输出 | 已更新 `dcg_filter.py` / `dcg_filter.ps1` |
| Codex MCP | 官方支持 STDIO 与 Streamable HTTP MCP server | 保留 `markitdown`，新增官方 `openaiDeveloperDocs` MCP |
| Codex Skills | 官方系统 skills 由 Codex / 插件自身维护 | 本仓库不维护 `.system` skills，只维护用户侧共享 skills |
| `dcg` | GitHub 最新 release 为 `v0.5.6` | `-AutoInstallDcg` / `--auto-install-dcg` 现在会刷新已安装的 `dcg` |
| `markitdown-mcp` | PyPI 最新为 `0.0.1a4`，`markitdown` 最新为 `0.1.6` | 继续使用 `uv tool run markitdown-mcp` 获取当前版本 |

## 官方资料

- Codex App：<https://developers.openai.com/codex/app>
- Codex CLI：<https://developers.openai.com/codex/cli>
- Windows 使用说明：<https://developers.openai.com/codex/windows>
- Config basics：<https://developers.openai.com/codex/config-basic>
- AGENTS.md：<https://developers.openai.com/codex/guides/agents-md>
- MCP：<https://developers.openai.com/codex/mcp>
- Hooks：<https://developers.openai.com/codex/hooks>
- Agent Skills：<https://developers.openai.com/codex/skills>
