# Codex Hooks

本目录保存 Codex `PreToolUse` hook 的低噪音过滤器。

## 作用

Codex hooks 是 Codex 在工具调用前后同步触发的外部进程。`PreToolUse` 可以在 shell 命令真正执行前做最后检查。

本仓库使用两层防护：

- 软层：`codex/skills/destructive-command-guard/SKILL.md`
- 硬层：`codex/hooks.json` + 本目录过滤器 + 社区项目 `dcg`

## 为什么需要过滤器

Codex 当前 hook matcher 主要按工具名匹配，例如 `Bash` 或 `shell_command`。这意味着如果直接把 matcher 配成 shell 工具，普通命令也会触发 hook。

因此本目录的脚本先做轻量判断：

1. 普通命令直接放行。
2. 看起来涉及删除、危险 git、数据库清空、格式化、云资源销毁等操作时，再调用 `dcg`。
3. `dcg` 返回 `deny` 或 `ask` 时，结果原样交给 Codex。

## 文件说明

| 文件 | 平台 | 说明 |
|---|---|---|
| `dcg_filter.ps1` | Windows / PowerShell | Windows Codex hook 入口 |
| `dcg_filter.py` | macOS / Linux / WSL2 | Unix-like Codex hook 入口 |

`restore.ps1` / `restore.sh` 会把这些文件复制到 `~/.codex/hooks/`，并生成 `~/.codex/hooks.json`。

## 启用条件

1. `dcg` 或 `dcg.exe` 在 PATH 中。
2. `~/.codex/config.toml` 中有：

```toml
[features]
hooks = true
```

3. `~/.codex/hooks.json` 存在且 JSON 合法。
4. 重启 Codex。

## 验证

```bash
dcg --version
dcg test "rm -rf /"
```

`dcg test` 只分析字符串，不会执行删除。预期应返回阻止或高风险判断。

也可以在 Codex 新会话里要求它删除一个临时测试目录；如果 hook 生效，应被拦截或要求确认。

## 关闭

重新运行：

```powershell
.\restore.ps1 -DisableDcgHooks
```

或：

```bash
bash restore.sh --disable-dcg-hooks
```

这会在 `~/.codex/config.toml` 中设置 `hooks = false`。软层 skill 不受影响。

完全跳过 `dcg`：

```powershell
.\restore.ps1 -SkipDcg
```

```bash
bash restore.sh --skip-dcg
```

## 限制

- hook 是运行时护栏，不等于系统级沙箱。
- 如果命令被写进脚本文件再执行，hook 只能看到执行脚本的命令，不能保证理解脚本全部内容。
- 需要当前 Codex 版本支持 hooks feature。
- `dcg` 是社区项目，属于供应链依赖；如团队策略不允许安装，可使用 `-SkipDcg`，仅保留软层 skill。
