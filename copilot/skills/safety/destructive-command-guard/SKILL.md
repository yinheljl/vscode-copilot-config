---
name: "destructive-command-guard"
description: "破坏性命令安全护栏。当将要执行可能导致数据丢失的命令前必须强制二次确认，包括 rm -rf / Remove-Item -Recurse / rmdir /s / del /s/q / git reset --hard / git clean -fd / git checkout -- / git push --force / git branch -D / git stash drop / find -delete / xargs rm / DROP TABLE / TRUNCATE / Format-Volume / diskpart 等。Use this skill before running any file deletion, git history rewriting, database drop, disk format, or PowerShell × cmd 混合调用。Trigger: rm, del, rmdir, Remove-Item, git reset, git clean, git checkout --, git push --force, git branch -D, DROP, TRUNCATE, Format, diskpart, rd /s, mkfs."
---

# Destructive Command Guard（破坏性命令安全护栏）

> 本 skill 是**软兜底**，配合下列**硬兜底**可获得最强保护：
>
> - Codex：本仓库自研 `codex/hooks/pre_tool_use_guard.py` PreToolUse 钩子（仅 Python 标准库，无任何第三方依赖；由 `restore` 脚本自动安装到 `~/.codex/hooks/`，并随安装运行 26 项 self-test）
> - 该 hook 与 Codex 沙箱**完全独立**：在 `--full-auto` / `--yolo` / `sandbox_mode = "danger-full-access"` 等"完全开放"模式下**仍然 100% 生效**（命令在进入 shell 前被拦截）—— 这正是 hook 设计的核心价值
> - 频繁 `git commit` + 启用 Windows 卷影副本 / 第三方实时备份（适用任何模式）
>
> 沙箱只是可选的"额外一层"，**本仓库不强制要求开启沙箱**。

---

## When to Trigger

只要你（Agent）**即将**生成或执行下列任何命令，必须**先**触发本 skill：

### 文件系统破坏

| 平台 | 命令模式 |
|------|----------|
| Bash | `rm -rf`、`rm -fr`、`rm -r -f`、`rm -Rf`、`unlink`、`shred` |
| PowerShell | `Remove-Item -Recurse`、`Remove-Item -Force`、`rd -r`、`ri -r`、`rmdir -Recurse` |
| cmd | `rmdir /s`、`rd /s`、`del /s/q`、`del /f /s` |
| 跨语言 | `python -c "...os.system('rm ...')"`、`python -c "shutil.rmtree(...)"`、`node -e "fs.rmSync(...)"` |
| 通用 | `find ... -delete`、`xargs rm`、`xargs -I{} rm`、`Get-ChildItem ... | Remove-Item` |

### Git 历史破坏

- `git reset --hard`、`git reset --merge`
- `git checkout -- <files>`、`git restore --source=...`
- `git clean -fd`、`git clean -fdx`
- `git branch -D`（强制删除未合并分支）
- `git stash drop`、`git stash clear`
- `git push --force`（**不带** `--force-with-lease`）
- `git worktree remove --force`
- `git filter-branch`、`git filter-repo`、`git rebase -i` 中的 `drop`

### 磁盘 / 系统级

- `mkfs.*`、`Format-Volume`、`format`、`diskpart`
- `dd if=... of=/dev/...`
- `cipher /w`、`fsutil`

### 数据库 / 不可逆数据

- `DROP DATABASE`、`DROP TABLE`、`DROP SCHEMA`
- `TRUNCATE TABLE`
- `DELETE FROM <table>`（不带 WHERE 子句）
- `redis-cli FLUSHALL`、`FLUSHDB`
- `kubectl delete namespace`、`kubectl delete pv`
- `terraform destroy`、`cdk destroy`
- `aws s3 rb --force`、`gcloud projects delete`

### 包 / 全局环境

- `npm uninstall -g`、`pip uninstall -y`（针对系统级）
- `rm -rf node_modules`（仅在用户明确要求时允许，仍需提示一次）
- `Set-ExecutionPolicy Unrestricted`、`chmod -R 777 /`

---

## Windows 平台特别警告（F 盘 / D 盘删盘事故根因）

Codex / Cursor 在 Windows 上经常生成**混合 shell** 调用，如：

```powershell
powershell -Command "cmd /c rmdir /s /q F:\MyProject\__pycache__"
```

**`\"` 在 PowerShell 中不是合法转义符**，路径在两层 shell 之间被截断为 `F:\`，最终 cmd 实际执行：

```cmd
rmdir /s /q F:\
```

→ 整盘清空，且**不进回收站**。

### 强制规则

1. **绝不**使用 `powershell ... cmd /c ...` 这种嵌套调用做删除。
2. 在 PowerShell 中删除文件**必须**使用纯 PowerShell：
   ```powershell
   Get-ChildItem -Recurse -Directory -Filter __pycache__ |
       Remove-Item -Recurse -Force
   ```
3. **绝不**在删除路径中使用未展开的变量（`$path`、`%var%`、`~`）—— 必须用 `Resolve-Path` / `Get-Item` 先解析为绝对路径并打印。
4. **绝不**使用以驱动器盘符开头但路径只有 1 段的目标（如 `D:\`、`F:\\`、`C:\Users\`）—— 这些是顶层目录，几乎一定是 bug。

---

## 必须执行的工作流

### 1) 拒绝 → 解释 → 二次确认

发现属于上面任意一类的命令时，**绝不直接执行**。先按以下顺序输出：

1. 用一段话向用户说明**将要做什么**、**会影响哪些路径**、**是否可逆**。
2. 列出受影响路径的**绝对路径**（不能是 `~`、`$HOME`、相对路径或环境变量）。
3. 显式列出**会被删除的文件数 / 大小**预估（如已知）。
4. 调用 `AskQuestion`（可用时）让用户选择：
   - `confirm` — 我已检查路径，继续执行
   - `dryrun` — 改为 dry-run / `--dry-run` / `WhatIf` 先预览
   - `cancel` — 取消
5. 仅在用户回 `confirm` 后执行。

### 2) 默认走"软删除"

只要平台支持，删除前先尝试以下替代：

| 平台 | 软删除替代 |
|------|------------|
| Windows | `Remove-Item ... -Force` 改为 PowerShell 的 `[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(..., 'OnlyErrorDialogs', 'SendToRecycleBin')`，或调用 `Recycle-Item`（PSRecycleBin 模块） |
| macOS | `trash` (brew install trash) |
| Linux | `gio trash` 或 `trash-cli` |

只有在用户明确说"永久删除"时，才允许走 `rm -rf` / `Remove-Item -Force`。

### 3) Git 操作的特殊规则

| 危险操作 | 必须替代为 |
|----------|------------|
| `git reset --hard HEAD~N` | 先 `git stash` 保存，再 `git reset --hard` |
| `git checkout -- file` | 先 `git diff file` 给用户看一遍，确认后再执行 |
| `git clean -fd` | 先 `git clean -nd`（dry-run）展示 |
| `git push --force` | 必须改为 `git push --force-with-lease` |
| `git branch -D feature` | 先确认 `git log feature ^main` 输出为空（无未合并提交），否则停下问 |

### 4) 上下文压缩 / 长会话失忆防护

每次会话上下文被压缩或长度超过 30 轮后，重新读取本 skill 一遍，**不要假设**之前的安全约定仍然生效。

---

## 路径白名单 / 黑名单（默认建议）

### 黑名单（**永不删除**）

- `.git/`、`.git/**`（任何 Git 元数据）
- `~/.ssh/`、`~/.aws/`、`~/.config/`、`~/.local/`
- `~/.codex/`、`~/.cursor/`、`~/.copilot/`、`~/.claude/`（IDE 配置）
- `C:\Windows\`、`C:\Program Files\`、`C:\ProgramData\`、`/etc/`、`/usr/`、`/var/`
- 用户文档目录：`~/Documents`、`~/Pictures`、`~/Desktop`、`~/Downloads`
- 任何驱动器盘符根目录：`C:\`、`D:\`、`E:\`、`/`、`/mnt/<drive>/`

### 灰名单（**默认软删 + 询问**）

- `node_modules/`、`__pycache__/`、`.venv/`、`.gradle/`、`.next/`、`build/`、`dist/`、`target/`
- 这些虽然可重生成，但删除前仍要列出绝对路径并请用户确认。

### 白名单（**当前会话 cwd 内可直接执行 dry-run，且 dry-run 通过后才真删**）

- 仅项目工作目录内（`$PWD`、`$REPO_ROOT`）
- 必须确认目标路径是 `$PWD` 的子路径

---

## Anti-Patterns（绝对禁止）

```bash
# 1) 任何到驱动器根的递归删除
rm -rf /
rm -rf ~
rm -rf $HOME
rm -rf C:\\
Remove-Item -Recurse -Force F:\

# 2) PowerShell × cmd 嵌套（F 盘事故根因）
powershell -c "cmd /c rmdir /s /q $somePath"

# 3) 未解析变量直接删除
rm -rf "$1"
Remove-Item -Recurse -Force $env:SOMEDIR

# 4) 通过 interpreter 一行夹带
python -c "import shutil; shutil.rmtree('/some/path')"
node -e "require('fs').rmSync('/some/path', {recursive: true, force: true})"

# 5) 强制覆盖远程历史，无 lease
git push --force origin main

# 6) 上下文压缩后"自言自语"恢复工作区
# 自动 git restore / git reset --hard 找回"干净状态"——绝对不允许
```

---

## What to Do Instead

- 长任务做完一个里程碑就 `git commit` 一次（即使是 WIP commit）
- 删除前 `ls -la <path>` 或 `Get-ChildItem <path>` 看一眼
- 用 `--dry-run` / `-WhatIf` / `git clean -nd` 先预览
- 重要操作前用 `AskQuestion` 工具二次确认
- 不知道时**停下来问**，宁可慢一点，绝不删错

---

## Related Hard Layer（硬兜底）

本 skill 是软层。硬层由本仓库自研、`restore` 脚本自动配置：

- **代码位置**：`codex/hooks/pre_tool_use_guard.py`（约 200 行 Python，**仅依赖标准库**，零 npm / 零 pip）
- **接口契约**：使用 OpenAI Codex CLI 官方 [`PreToolUse` Hook](https://developers.openai.com/codex/hooks)，匹配 `Bash` 工具调用，命中危险模式时返回 `permissionDecision: "deny"` 拦截
- **CI 保障**：随仓库附带 `codex/hooks/test_pre_tool_use_guard.py`，26 个 case（17 deny + 9 allow），由 `.github/workflows/validate.yml` 在每次 PR 强制运行
- **审计日志**：每次拦截/审计自动写入 `~/.codex/hooks/logs/`
- **可临时绕过**：仓库根目录放置 `.codex-allow-destructive` 即可豁免（仅限当前 cwd）

如果硬层因任何原因未启用（Python 缺失、feature flag 未开等），请用户在终端执行：

```bash
# 检查 hook 配置是否生效
cat ~/.codex/hooks.json

# 检查 feature flag 是否开启（必须有 [features] codex_hooks = true）
cat ~/.codex/config.toml

# 重新跑一次自检（应输出 26 passed）
python ~/.codex/hooks/test_pre_tool_use_guard.py
```
