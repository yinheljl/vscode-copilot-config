# VS Code GitHub Copilot 个人配置

本仓库备份了我的 VS Code GitHub Copilot 全局配置，包括：

- **`.copilot/instructions/`** — 全局指令文件（代码审查规范、AUTOSAR、MISRA-C 等）
- **`.copilot/skills/`** — 自定义 Skill 集合（automotive、embedded、document 等）
- **`vscode/mcp.json`** — MCP 服务器配置（context7、github、markitdown）

## 目录结构

```
.copilot/
  instructions/           # 全局 .instructions.md 文件
  skills/                 # 自定义 Skill（SKILL.md + 脚本资源）
vscode/
  mcp.json                # MCP 服务器配置（token 用占位符，需手动设置环境变量）
restore.ps1               # 一键还原脚本（Windows PowerShell）
restore.sh                # 一键还原脚本（Linux/macOS bash）
```

## 新电脑快速还原

### 前提条件

1. 已安装 [VS Code](https://code.visualstudio.com/)
2. 已安装 [Git](https://git-scm.com/)
3. 已安装 [Node.js](https://nodejs.org/)（MCP 需要 npx）
4. 已安装 [uv/uvx](https://docs.astral.sh/uv/)（markitdown MCP 需要）

### 步骤

```powershell
# 1. 克隆本仓库（只需做一次）
git clone https://github.com/yinheljl/vscode-copilot-config.git C:\Temp\copilot-restore
cd C:\Temp\copilot-restore

# 2. 运行还原脚本
.\restore.ps1
```

### 手动还原

若不想运行脚本，可手动操作：

```powershell
# 复制 .copilot 配置到用户目录
Copy-Item -Recurse ".\\.copilot" "$env:USERPROFILE\\" -Force

# 复制 mcp.json 到 VS Code 用户配置目录
Copy-Item ".\\vscode\\mcp.json" "$env:APPDATA\\Code\\User\\mcp.json" -Force
```

## MCP Token 配置

`mcp.json` 中 GitHub MCP Server 的 token 使用了 VS Code 的输入变量 `${GITHUB_MCP_TOKEN}`。  
首次在新电脑打开 VS Code 后，Copilot Chat 会弹出输入框让你填写 token 值。

你的 GitHub Personal Access Token 需要以下权限：
- `repo`（仓库读写）
- `read:org`（组织信息，可选）

## 同步更新

当你修改了 instructions 或 skills 后，推送更新到本仓库：

```powershell
cd C:\Temp\copilot-restore   # 或仓库所在目录
.\sync.ps1                   # 从当前机器同步最新配置并推送
```

> **注意**：本仓库为私有仓库，仅限个人使用。
