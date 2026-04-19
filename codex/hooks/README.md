# Codex Hooks（破坏性命令硬兜底）

> **重要前置**：Codex 官方文档明确说明 **"Hooks are currently disabled on Windows"**（[来源](https://developers.openai.com/codex/hooks)）。本目录的所有 hook 配置在你的 Windows 主机上 Codex 桌面端 / CLI **当前不会被调用**。仅在 macOS / Linux / WSL2 下生效。等待 OpenAI 官方解禁后将自动可用。

## 这是什么？

[Codex Hooks](https://developers.openai.com/codex/hooks) 是 Codex 在工具调用前后同步触发的外部进程。本仓库使用 `PreToolUse` 钩子拦截破坏性 Bash 命令——这是模型 prompt 之外的**硬兜底**。

为了避免重复造轮子并降低维护成本，**硬层防护使用社区项目 [`Dicklesworthstone/destructive_command_guard`（dcg）](https://github.com/Dicklesworthstone/destructive_command_guard)**：

| 维度 | dcg |
|------|------|
| ⭐ 受关注度 | GitHub 846 stars，活跃维护中（最近 release 2026-04） |
| 🛠 实现 | Rust 二进制（SIMD 加速，sub-millisecond latency） |
| 📦 包大小 | 49+ 安全 packs（git / 文件系统 / databases / k8s / docker / cloud / terraform 等） |
| 🔗 兼容性 | Codex CLI / Claude Code / Gemini CLI / Copilot CLI / Cursor / OpenCode / Aider / Continue |
| ✅ Codex 协议 | wire format 兼容 Claude Code，使用 `~/.codex/hooks.json` 注册 |
| 🧪 测试 | 上游有 codecov 覆盖率徽章 |
| ⚠️ 风险（必须诚实披露） | 单人维护（Bus factor 1），作者明确不接受外部 PR；属于供应链依赖 |

## 启用条件

1. **平台**：macOS / Linux / WSL2（Windows 上 Codex hook 整体被禁用）
2. **dcg 已安装**：`dcg` 命令在 PATH 里
3. `~/.codex/config.toml` 中存在 `[features]\ncodex_hooks = true`
4. `~/.codex/hooks.json` 文件存在且 JSON 合法（由 `restore` 脚本自动部署）
5. 重启 Codex 会话

## 安装 dcg（用户自行决定，restore 脚本不代为执行）

`restore.ps1` / `restore.sh` 在非 Windows 平台**只检测** `dcg` 是否存在；若未安装，会打印官方安装命令但**不会自动 `curl | bash`**（避免供应链风险默认外加到用户身上）。

官方一键安装：

```bash
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/destructive_command_guard/main/install.sh" | bash -s -- --easy-mode
```

或源码编译：

```bash
cargo install --git https://github.com/Dicklesworthstone/destructive_command_guard
```

## 验证 hook 是否生效

```bash
# Linux / macOS
which dcg && dcg --version
cat ~/.codex/hooks.json

# 让 Codex 试着执行一个会被拦截的命令，看是否报 deny
# 例如在 Codex 对话中说："请执行 rm -rf /"，应被立即拦截
dcg explain "rm -rf /"
```

## 临时绕过（极少用）

dcg 内置完整的绕过机制：

| 方式 | 范围 | 命令 |
|------|------|------|
| 环境变量 | 单条命令 | `DCG_BYPASS=1 <command>` |
| 一次性放行码 | 单条命令 | 复制 block 提示里的短码，运行 `dcg allow-once <code>` |
| 永久白名单 | 规则 / 命令 | `dcg allowlist add core.git:reset-hard -r "reason"` |
| 完全禁用 | 全部命令 | 注释掉 `~/.codex/hooks.json` 中的 PreToolUse 段 |

## 自定义规则

dcg 支持项目级自定义 packs。在仓库根放置 `.dcg/packs/<name>.yaml`，并在 `~/.config/dcg/config.toml` 加入：

```toml
[packs]
custom_paths = [".dcg/packs/*.yaml"]
```

详见 [dcg docs/custom-packs.md](https://github.com/Dicklesworthstone/destructive_command_guard/blob/main/docs/custom-packs.md)。

## 已知限制（来自上游与 Codex 引擎）

- **Windows 不可用**：Codex 引擎层面禁用，与 dcg 实现无关
- **只拦 Bash**：Codex 当前 `PreToolUse` matcher 只支持 `Bash` 工具，不拦截 `apply_patch` / `Edit` / `Write` 等
- **可被绕过**：模型可以把命令写到磁盘脚本里再执行；hook 是有用的护栏但不是绝对的强制边界（dcg 与官方文档都承认这点）

## 软层兜底（任何平台都生效）

跨 IDE 的 [`destructive-command-guard` SKILL.md](../skills/safety/destructive-command-guard/SKILL.md) 通过 prompt 层面引导 Codex / Cursor / Copilot 在生成危险命令前 `AskQuestion` 二次确认。Windows 平台下 SKILL 是你**唯一**的兜底，请保持启用。
