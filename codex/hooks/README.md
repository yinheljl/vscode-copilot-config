# Codex Hooks（破坏性命令硬兜底）

> **Windows 说明**：OpenAI 当前 Codex 文档已经包含 Windows hooks 配置项（如 `hooks.windows_managed_dir`），不再声明 Windows hooks 禁用。`restore.ps1` 会在 `dcg.exe` 已安装后部署 `~/.codex/hooks.json`，并确保 `~/.codex/config.toml` 启用 `[features] codex_hooks = true`。

## 这是什么？

[Codex Hooks](https://developers.openai.com/codex/hooks) 是 Codex 在工具调用前后同步触发的外部进程。`PreToolUse` 钩子可以在 Codex 真正执行 Bash 命令前拦下来——这是 prompt 之外的**硬兜底**。

为了避免重复造轮子，**硬层使用社区项目 [`Dicklesworthstone/destructive_command_guard`（dcg）](https://github.com/Dicklesworthstone/destructive_command_guard)**：

| 维度 | dcg |
|------|------|
| 受关注度 | GitHub 846+ stars，活跃维护中；restore 会从 GitHub Releases 解析 latest tag（本机验证为 v0.4.5） |
| 实现 | Rust 二进制（SIMD 加速，sub-millisecond 延迟） |
| 包大小 | 49+ 安全 packs（git / 文件系统 / databases / k8s / docker / cloud / terraform 等） |
| 跨 agent | Codex CLI / Claude Code / Gemini CLI / Copilot CLI / Cursor / OpenCode / Aider / Continue |
| Codex 协议 | wire format 兼容 Claude Code，使用 `~/.codex/hooks.json` 注册 |
| 跨平台 | Linux x86_64 / aarch64、macOS Intel / Apple Silicon、**Windows x86_64**（原生 .exe） |
| 安装包校验 | 官方 install 脚本强制 SHA256，可选 cosign / Sigstore 签名验证 |
| ⚠️ 风险（必须诚实披露） | 单人维护（Bus factor 1），作者明确不接受外部 PR；属于供应链依赖 |

## restore 脚本如何处理 dcg？

为了"一键配置"但又不偷偷碰用户的 PATH，`restore.ps1` / `restore.sh` 的策略是：

1. **检测**：`dcg` / `dcg.exe` 是否已在 PATH 或 `~/.local/bin/` 下
2. **询问**：未安装时弹出 `[y/N]` 确认（你必须明确同意才会动手）
3. **下载并校验**：
   - **macOS / Linux**：代理调用上游官方 `install.sh`（含 SHA256 校验 + 可选 cosign）
   - **Windows**：上游 `install.ps1` 在 Windows PowerShell 5.1（系统默认 shell）下有 bug——它假设 `Invoke-WebRequest -UseBasicParsing` 返回 string，但 PS 5.1 实际返回 byte[]，导致 SHA256 校验逻辑抛 `Checksum file not found`。`restore.ps1` 用 PS 5.1 兼容代码**复刻同样的官方流程**：GitHub API 取 latest tag → 下载 `dcg-x86_64-pc-windows-msvc.zip` → 拉上游 `.sha256` 强制校验 → 解压 → 安装到 `~/.local/bin/dcg.exe` → 写入用户 PATH。**信任锚点完全不变**（artifact 与 hash 都是 dcg 官方发布物，本仓库不参与签名 / 不 host 二进制）
4. **跳过询问**：加 `-AutoInstallDcg`（PowerShell）/ `--auto-install-dcg`（bash）旗标
5. **完全跳过**：加 `-SkipDcg`（PowerShell）/ `--skip-dcg`（bash）旗标

非交互式 stdin（CI、管道）默认**不会**安装 dcg——必须显式传入 `--auto-install-dcg` 才会装。

| 操作系统 | 装 dcg 二进制 | 部署 `~/.codex/hooks.json` | Codex 运行时是否调用 hook |
|---------|---------------|---------------------------|--------------------------|
| Windows（PowerShell） | ✅ 自动询问安装 | ✅ 部署 | ✅ 启用 `codex_hooks = true` 后生效 |
| macOS / Linux | ✅ 自动询问安装 | ✅ 部署 | ✅ 启用 `codex_hooks = true` 后生效 |
| WSL2 内的 Linux Codex | ✅ | ✅ | ✅ |
| Git Bash / MSYS / Cygwin | ⚠️ 提示走 PowerShell 安装 | ✅ 已安装 dcg 后可部署 | 取决于实际运行的 Codex surface |

## 启用条件清单

1. `dcg` 命令在 PATH（restore 询问后自动安装）
2. `~/.codex/config.toml` 里有 `[features]\ncodex_hooks = true`（restore 自动追加）
3. `~/.codex/hooks.json` 文件存在且 JSON 合法（restore 自动部署）
4. **重启 Codex 会话**

## 验证 hook 是否生效

```bash
# Linux / macOS / Windows 都适用：检查 dcg 二进制可用
dcg --version
dcg test "rm -rf /"     # 应返回 decision = block

# 检查 Codex hook 文件
cat ~/.codex/hooks.json
grep codex_hooks ~/.codex/config.toml

# 让 Codex 真正触发：在 Codex 对话内说 "请执行 rm -rf /"，应被立即拦截
```

## 临时绕过（极少用）

dcg 内置完整的绕过机制，详见上游文档：

| 方式 | 范围 | 命令 |
|------|------|------|
| 环境变量 | 单条命令 | `DCG_BYPASS=1 <command>` |
| 一次性放行码 | 单条命令 | 复制 block 提示里的短码，`dcg allow-once <code>` |
| 永久白名单 | 规则 / 命令 | `dcg allowlist add core.git:reset-hard -r "reason"` |
| 完全禁用 | 全部命令 | 删除 `~/.codex/hooks.json` 中 PreToolUse 段 |

## 自定义规则

dcg 支持项目级自定义 packs。在仓库根放置 `.dcg/packs/<name>.yaml`，并在 `~/.config/dcg/config.toml` 加入：

```toml
[packs]
custom_paths = [".dcg/packs/*.yaml"]
```

详见 [dcg docs/custom-packs.md](https://github.com/Dicklesworthstone/destructive_command_guard/blob/main/docs/custom-packs.md)。

## 已知限制（来自上游与 Codex 引擎）

- **版本依赖**：需要当前 Codex 支持 hooks feature flag。OpenAI 当前文档包含 Windows hooks 配置项；如果你使用旧版 Codex，请先升级。
- **只拦 Bash**：Codex 当前 `PreToolUse` matcher 只支持 `Bash` 工具，不拦 `apply_patch` / `Edit` / `Write` 等
- **可被绕过**：模型可以把命令写到磁盘脚本里再执行；hook 是有用的护栏但不是绝对的强制边界（dcg 与官方文档都承认这点）
- **dcg Bus factor = 1**：单人维护项目，作者明确不接受外部 PR。如果 dcg 仓库哪天消失，可以无缝切回纯软层 SKILL（仍然有效）

## 软层兜底（任何平台、任何情况下都生效）

跨 IDE 的 [`destructive-command-guard` SKILL.md](../skills/destructive-command-guard/SKILL.md) 通过 prompt 层面引导 Codex / Cursor / Copilot / Claude 在生成危险命令前 `AskQuestion` 二次确认。

- SKILL 提供"模型主动避开"，dcg hook 提供"运行时强制阻断"，两层独立。
