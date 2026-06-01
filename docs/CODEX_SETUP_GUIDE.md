# Codex 安装、搭建与配置简易操作文档

本文面向公司内部同事，目标是让新用户能按步骤完成 Codex 安装、登录、公司统一配置导入、验证和后续更新。

本文基于当前仓库 `vscode-copilot-config` 编写，推荐优先使用本仓库脚本完成 Codex 配置，不建议手工复制配置文件。

## 1. 适用范围

- 主要适用：Windows 11 / Windows 10 新版本。
- 兼容适用：macOS、Linux、Windows WSL2。
- 适用工具：Codex App、Codex CLI、Codex IDE Extension。
- 公司统一配置来源：本仓库的 `codex/` 目录和 `restore.ps1` / `restore.sh` 脚本。

完成后应达到以下状态：

- `~/.codex/AGENTS.md` 已写入公司统一行为规范。
- `~/.codex/skills/` 已写入公司维护的 Codex skills。
- `~/.codex/config.toml` 已配置 `markitdown` MCP 服务器。
- 如启用 `dcg`，`~/.codex/hooks.json` 和 `~/.codex/hooks/` 已写入破坏性命令防护 hook。
- 重启 Codex 后，新会话能读取上述配置。

## 2. 准备工作

Windows 用户建议先确认：

```powershell
git --version
$PSVersionTable.PSVersion
```

如果没有 Git，先安装 Git for Windows。公司标准环境如有软件分发平台，优先使用公司分发平台；否则可用 Git 官网安装包。

Codex 使用上还需要：

- 一个可使用 Codex 的 ChatGPT / OpenAI 账号。
- 能访问 GitHub 和 OpenAI / ChatGPT 相关域名的网络。
- PowerShell 终端。
- 如使用 WSL2，建议仓库放在 Linux home 下，例如 `~/code/repo`，不要放在 `/mnt/c/...`。

## 3. 安装 Codex

### 3.1 Windows 推荐方式：Codex App

1. 打开官方 Codex App 文档：<https://developers.openai.com/codex/app>
2. 点击 Windows 下载入口安装 Codex App。
3. 打开 Codex App，使用 ChatGPT 账号或 OpenAI API key 登录。
4. 选择本地项目目录，首次使用建议选择 `Local` 模式。
5. 在 PowerShell 中验证本机是否已有 CLI：

```powershell
codex --version
```

能输出版本号即可，例如 `codex-cli 0.135.0`。

### 3.2 macOS / Linux / WSL2：Codex CLI

官方 CLI 安装命令：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
codex
```

首次运行 `codex` 会提示登录，可选择 ChatGPT 账号或 OpenAI API key。

非交互式安装可用：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
```

Windows 上如果需要 Linux 原生环境，先安装 WSL2：

```powershell
wsl --install
wsl
```

进入 WSL shell 后再执行上面的 macOS / Linux CLI 安装命令。

## 4. 导入公司 Codex 配置

### 4.1 Windows 一键配置

首次配置：

```powershell
git clone https://github.com/yinheljl/vscode-copilot-config.git "$env:USERPROFILE\.copilot-config"
Set-ExecutionPolicy -Scope Process Bypass -Force
& "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex
```

如果已经克隆过仓库：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
& "$env:USERPROFILE\.copilot-config\update.ps1" -Target Codex
```

如果希望无人值守安装/刷新 `dcg` 破坏性命令防护：

```powershell
& "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex -AutoInstallDcg
```

如果公司环境暂时不允许安装 `dcg`，但仍想写入软层规则和 MCP 配置：

```powershell
& "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex -SkipDcg
```

### 4.2 macOS / Linux / WSL2 一键配置

首次配置：

```bash
git clone https://github.com/yinheljl/vscode-copilot-config.git ~/.copilot-config
bash ~/.copilot-config/restore.sh --target=codex
```

已配置用户更新：

```bash
bash ~/.copilot-config/update.sh --target=codex
```

无人值守安装/刷新 `dcg`：

```bash
bash ~/.copilot-config/restore.sh --target=codex --auto-install-dcg
```

跳过 `dcg`：

```bash
bash ~/.copilot-config/restore.sh --target=codex --skip-dcg
```

## 5. 脚本实际做了什么

执行 `restore.ps1 -Target Codex` 或 `restore.sh --target=codex` 后，脚本会按当前仓库模板写入用户级 Codex 配置：

| 目标文件/目录 | 来源 | 作用 |
|---|---|---|
| `~/.codex/AGENTS.md` | `codex/AGENTS.md` | 公司统一行为规范，例如中文回复、自动修复代码、谨慎变更、目标驱动验证 |
| `~/.codex/skills/` | `codex/skills/` | 公司维护的 Codex skills，例如文档处理、表格处理、代码审查、安全护栏 |
| `~/.codex/config.toml` | `codex/config.toml` | 合并 MCP 配置，目前默认包含 `markitdown` |
| `~/.codex/hooks.json` | `codex/hooks.json` | 注册 Codex PreToolUse hook |
| `~/.codex/hooks/` | `codex/hooks/` | 低噪音 `dcg` 过滤器，高危命令才调用 `dcg` |

脚本默认是增量模式，会尽量保留用户已有配置。使用 `-Force` / `--force` 才会覆盖目标配置。

## 6. 验证配置是否成功

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

- 能看到 `AGENTS.md`、`config.toml` 和 `destructive-command-guard` skill。
- `codex mcp list` 中能看到 `markitdown`。
- 重启 Codex 后，新会话应自动加载公司规则和 skills。

如果已安装 `dcg`，可再验证：

```powershell
dcg --version
dcg test 'rm -rf C:\Temp\dcg-smoke'
```

`dcg test` 只是分析字符串，不会真的删除目录。预期应返回阻止或高风险判断。

## 7. 常用维护命令

更新公司配置：

```powershell
& "$env:USERPROFILE\.copilot-config\update.ps1" -Target Codex
```

只预览不写入：

```powershell
& "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex -DryRun
```

覆盖式重装 Codex 配置：

```powershell
& "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex -Force
```

关闭硬层 hook，但保留软层 skill：

```powershell
& "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex -DisableDcgHooks
```

## 8. 推荐的 Windows Sandbox 配置

OpenAI 官方建议 Windows 原生 Codex 优先使用 `elevated` sandbox；如果公司电脑策略阻止管理员批准流程，再临时使用 `unelevated`。

可在 `~/.codex/config.toml` 中添加：

```toml
[windows]
sandbox = "elevated"
# sandbox = "unelevated" # elevated 无法使用时再启用
```

不建议日常使用 `danger-full-access`。全权限模式不受项目目录限制，误操作风险更高。

## 9. 常见问题

### PowerShell 提示脚本执行策略拦截

在当前终端临时放行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
```

然后重新执行 `restore.ps1` 或 `update.ps1`。

### `codex mcp list` 没看到 `markitdown`

先重新执行：

```powershell
& "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex
```

脚本会检测或安装 `uv`，并把 `markitdown` MCP 写入 `~/.codex/config.toml`。首次调用 `markitdown` 时可能需要联网下载工具包。

### 配置后 Codex 没有读取新规则

处理顺序：

1. 退出并重启 Codex App / CLI / IDE Extension。
2. 确认 `~/.codex/AGENTS.md` 存在。
3. 确认当前项目没有更近层级的 `AGENTS.override.md` 覆盖了规则。
4. 在 Codex 中询问："请列出当前加载的 AGENTS.md 来源。"

### 公司电脑无法启用 Windows elevated sandbox

先用 `unelevated` 临时继续工作，并把错误信息、Windows 版本、`CODEX_HOME/.sandbox/sandbox.log` 交给 IT 或管理员排查。

### 不想安装 dcg

可以使用：

```powershell
& "$env:USERPROFILE\.copilot-config\restore.ps1" -Target Codex -SkipDcg
```

这样不会安装 `dcg`，也不会启用硬层 hook；但 `destructive-command-guard` skill 仍会作为软层规则生效。

## 10. 维护者注意事项

- 不要提交 `.env.local`、API key、GitHub token 或任何账号凭据。
- 本仓库已将 `.env.local` 加入 `.gitignore`。
- 当前仓库的 Codex skills 管理路径是 `codex/skills/` 到 `~/.codex/skills/`，与仓库脚本保持一致。
- OpenAI 官方 Codex Skills 文档可能会继续演进；如官方路径或格式发生变化，优先更新 `restore.ps1` / `restore.sh`，再更新本文档。
- 发布配置更新后，通知同事运行 `update.ps1 -Target Codex` 或 `update.sh --target=codex`。

## 11. 官方资料

- Codex App：<https://developers.openai.com/codex/app>
- Codex CLI：<https://developers.openai.com/codex/cli>
- Windows 使用说明：<https://developers.openai.com/codex/windows>
- Config basics：<https://developers.openai.com/codex/config-basic>
- AGENTS.md：<https://developers.openai.com/codex/guides/agents-md>
- MCP：<https://developers.openai.com/codex/mcp>
- Hooks：<https://developers.openai.com/codex/hooks>
- Agent Skills：<https://developers.openai.com/codex/skills>
