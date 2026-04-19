# Codex Hooks（破坏性命令硬兜底）

## 这是什么？

[Codex Hooks](https://developers.openai.com/codex/hooks) 是 Codex 在工具调用前后同步触发的外部进程。本仓库使用 `PreToolUse` 钩子拦截破坏性 Bash 命令——这是模型 prompt 之外的**硬兜底**。

| 文件 | 作用 |
|------|------|
| `pre_tool_use_guard.py` | 校验 Bash 命令；命中 deny 模式直接 return `permissionDecision: deny`，命令永远不会进 shell |
| `test_pre_tool_use_guard.py` | 自检测试（26 个用例覆盖 rm -rf /, Windows 删盘, PowerShell × cmd 嵌套, git push --force 等） |
| `../hooks.json` | Hook 配置模板，由 `restore.ps1` / `restore.sh` 部署到 `~/.codex/hooks.json` 并替换 Python 路径 |

## 工作原理

```
[Codex 准备执行 Bash 命令]
        ↓
[读取 ~/.codex/hooks.json]
        ↓
[调用 python pre_tool_use_guard.py（stdin = JSON 命令信息）]
        ↓
   ┌────┴────┐
   ↓         ↓
匹配 DENY    匹配 ASK / 不匹配
   ↓         ↓
返回 deny    放行（仅记录到日志）
   ↓         ↓
[阻断]    [Codex 继续执行]
```

## 启用条件（restore 脚本会自动满足）

1. `~/.codex/config.toml` 中存在 `[features]\ncodex_hooks = true`
2. `~/.codex/hooks.json` 文件存在且 JSON 合法
3. `~/.codex/hooks/pre_tool_use_guard.py` 存在且 Python 解释器可用
4. 重启 Codex 会话

## 验证 hook 是否生效

```powershell
# Windows
$env:USERPROFILE | ForEach-Object { Get-Content "$_\.codex\hooks.json" }

# 让 Codex 试着执行一个会被拦截的命令，看是否报 deny
# 例如在 Codex 对话中说："请执行 rm -rf /"，应被立即拦截
```

```bash
# Linux / macOS
cat ~/.codex/hooks.json
```

## 临时绕过（极少用）

如果你**确实**需要让 Codex 执行某个被拦截的命令，按优先级有两种方式：

1. **会话级**：在仓库根目录创建空文件 `.codex-allow-destructive`，hook 检测到后会放行所有命令（仍记录到 `~/.codex/hooks/logs/`）
2. **永久禁用**：注释掉 `~/.codex/config.toml` 的 `codex_hooks = true`，重启 Codex（**强烈不推荐**）

## 审计日志

所有触发（含 ASK 灰名单）会写入 `~/.codex/hooks/logs/guard-YYYYMM.log`，每行一条 JSON。事后可用：

```powershell
Get-Content "$env:USERPROFILE\.codex\hooks\logs\guard-202604.log" |
    ForEach-Object { $_ | ConvertFrom-Json } |
    Where-Object { $_.event -eq 'deny' } |
    Format-Table ts, reason, command -AutoSize
```

## 自定义模式

直接编辑 `pre_tool_use_guard.py` 顶部的 `DENY_PATTERNS` / `ASK_PATTERNS` 列表。每条 `(regex, reason)`。修改后**必须**先跑 `python codex/hooks/test_pre_tool_use_guard.py` 自检通过，再 sync 到本机：

```powershell
.\sync.ps1 -Message "feat(safety): tighten guard rules"
.\restore.ps1
# 重启 Codex
```

## 已知限制

- Codex 当前 `PreToolUse` matcher **只支持 `Bash` 工具**（不拦截 `apply_patch`、`Edit`、`Write` 等）。这是 Codex 自身限制，详见 [openai/codex#14754](https://github.com/openai/codex/issues/14754)。
- 拦截**仅对模型生成的 shell 命令生效**；用户在 Codex 终端里手敲的命令不经过 hook。
- 如果命令通过 `bash -c '... ; ...'` 多语句拼接，需要正则覆盖到子段——这就是为什么 guard 用宽松的 `\b...\b` 而非精确锚定。
