# Codex 安装、搭建与配置简易操作文档

本文用于快速安装 Codex，并导入本仓库维护的 Codex 全局配置。

## 1. 适用范围

- Windows 10/11
- macOS
- Linux
- Windows WSL2

适用工具：

- Codex App
- Codex CLI
- Codex IDE Extension

## 2. 安装 Codex

### Windows 推荐方式

1. 打开官方 Codex App 文档：<https://developers.openai.com/codex/app>
2. 下载并安装 Windows 版 Codex App。
3. 打开 Codex App，使用 ChatGPT 账号或 OpenAI API key 登录。
4. 在 PowerShell 中验证：

```powershell
codex --version
```

### macOS / Linux / WSL2

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
codex
```

首次运行 `codex` 时按提示登录。

## 3. 导入共享配置

### Windows

```powershell
git clone --branch codex/codex-setup-doc --single-branch https://github.com/yinheljl/ai-agent-config.git "$env:USERPROFILE\.ai-agent-config"
Set-ExecutionPolicy -Scope Process Bypass -Force
& "$env:USERPROFILE\.ai-agent-config\restore.ps1"
```

如需自动安装/刷新 `dcg` 硬层安全 hook：

```powershell
& "$env:USERPROFILE\.ai-agent-config\restore.ps1" -AutoInstallDcg
```

### macOS / Linux / WSL2

```bash
git clone --branch codex/codex-setup-doc --single-branch https://github.com/yinheljl/ai-agent-config.git ~/.ai-agent-config
bash ~/.ai-agent-config/restore.sh
```

如需自动安装/刷新 `dcg`：

```bash
bash ~/.ai-agent-config/restore.sh --auto-install-dcg
```

完成后重启 Codex。

## 4. 配置内容

| 目标 | 说明 |
|---|---|
| `~/.codex/AGENTS.md` | 统一 Codex 行为规范 |
| `~/.codex/skills/` | Codex skills |
| `~/.codex/config.toml` | `markitdown` MCP 与 hooks feature |
| `~/.codex/hooks.json` | Codex `PreToolUse` hook 注册 |
| `~/.codex/hooks/` | `dcg` 低噪音过滤器 |

## 5. 验证

Windows：

```powershell
Test-Path "$env:USERPROFILE\.codex\AGENTS.md"
Test-Path "$env:USERPROFILE\.codex\config.toml"
Test-Path "$env:USERPROFILE\.codex\skills\destructive-command-guard\SKILL.md"
codex mcp list
```

macOS / Linux / WSL2：

```bash
test -f ~/.codex/AGENTS.md && echo OK
test -f ~/.codex/config.toml && echo OK
test -f ~/.codex/skills/destructive-command-guard/SKILL.md && echo OK
codex mcp list
```

预期结果：

- `codex mcp list` 能看到 `markitdown` 和 `openaiDeveloperDocs`。
- 新 Codex 会话会读取全局 `AGENTS.md` 和 skills。
- 如果启用了 `dcg`，危险 shell 命令会先经过 hook 过滤。

## 6. 更新配置

Windows：

```powershell
& "$env:USERPROFILE\.ai-agent-config\update.ps1"
```

macOS / Linux / WSL2：

```bash
bash ~/.ai-agent-config/update.sh
```

## 7. 常用选项

Windows：

```powershell
& "$env:USERPROFILE\.ai-agent-config\restore.ps1" -DryRun
& "$env:USERPROFILE\.ai-agent-config\restore.ps1" -Force
& "$env:USERPROFILE\.ai-agent-config\restore.ps1" -SkipDcg
& "$env:USERPROFILE\.ai-agent-config\restore.ps1" -DisableDcgHooks
```

macOS / Linux / WSL2：

```bash
bash ~/.ai-agent-config/restore.sh --dry-run
bash ~/.ai-agent-config/restore.sh --force
bash ~/.ai-agent-config/restore.sh --skip-dcg
bash ~/.ai-agent-config/restore.sh --disable-dcg-hooks
```

## 8. 常见问题

### 可以让 AI Agent 帮我配置吗

可以。建议对 AI Agent 这样说：

```text
请按照 https://github.com/yinheljl/ai-agent-config/tree/codex/codex-setup-doc 的 README，帮我在当前设备安装或更新 Codex 全局配置。如果 ~/.ai-agent-config 已存在，必须先检查它是否在 codex/codex-setup-doc 分支；已经在该分支时运行 update 脚本，不在该分支时先 fetch origin codex/codex-setup-doc，再 switch/create 到 FETCH_HEAD 并 pull --ff-only origin codex/codex-setup-doc，切换不了就把旧目录改名备份后重新 clone。直接运行 restore，并使用 -AutoInstallDcg / --auto-install-dcg 自动安装或刷新安全 hooks；不要让我判断 dry-run 输出。不要同步或覆盖 Codex 自带的 .system skills；只处理本仓库管理的 ~/.codex/AGENTS.md、~/.codex/skills/、MCP 和 hooks。完成后告诉我安装结果、dcg 版本号、MCP 列表，以及是否需要重启 Codex。只有遇到登录、权限、网络失败、git 冲突这类无法自动处理的问题时，才停下来说明原因和下一步。
```

### PowerShell 拦截脚本

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
```

然后重新执行 `restore.ps1`。

### `codex mcp list` 没有 markitdown

重新执行：

```powershell
& "$env:USERPROFILE\.ai-agent-config\restore.ps1"
```

脚本会重新检测 `uv` 并合并 `markitdown` MCP 配置。

### 不想安装 dcg

```powershell
& "$env:USERPROFILE\.ai-agent-config\restore.ps1" -SkipDcg
```

这样会跳过硬层 hook；软层 `destructive-command-guard` skill 仍会保留。

## 9. 维护者说明

- 当前分支只维护 Codex 配置。
- 本仓库不维护 Codex 自带的 `.system` skills。
- 不要提交 `.env.local`、API key、GitHub token。
- 修改脚本后运行 `python scripts/validate_config.py`。
- 修改 README 版本号时同步更新 `VERSION`。
