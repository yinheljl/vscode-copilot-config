$ErrorActionPreference = "SilentlyContinue"

$payload = [Console]::In.ReadToEnd()

function Approve-Hook {
    # Windsurf: exit 0 = allow（命令继续执行）
    exit 0
}

function Deny-Hook([string]$reason) {
    # Windsurf: exit 2 = block（命令被阻止）；stderr 文本会显示在 Cascade UI 上
    [Console]::Error.WriteLine($reason)
    exit 2
}

if ([string]::IsNullOrWhiteSpace($payload)) {
    Approve-Hook
}

try {
    $event = $payload | ConvertFrom-Json -ErrorAction Stop
} catch {
    Approve-Hook
}

# Windsurf pre_run_command 输入：{ "agent_action_name": "pre_run_command", "tool_info": { "command_line": "...", "cwd": "..." } }
$command = $null
if ($event.PSObject.Properties.Name -contains "tool_info" -and $event.tool_info) {
    if ($event.tool_info.PSObject.Properties.Name -contains "command_line") {
        $command = [string]$event.tool_info.command_line
    }
}

if ([string]::IsNullOrWhiteSpace($command)) {
    Approve-Hook
}

$riskPattern = @'
(?isx)
(
  \b(rm|del|rd|rmdir|Remove-Item|ri|erase)\b
| \b(find\b[\s\S]*\s-delete\b)
| \bxargs\b[\s\S]*\b(rm|del|rmdir|Remove-Item)\b
| \bgit\s+reset\b[\s\S]*\s--hard\b
| \bgit\s+checkout\b[\s\S]*\s--\s+
| \bgit\s+restore\b(?![\s\S]*\s--staged\b)
| \bgit\s+clean\b
| \bgit\s+branch\b[\s\S]*\s-D\b
| \bgit\s+stash\s+(drop|clear)\b
| \bgit\s+push\b[\s\S]*\s--force(?=\s|$)
| \bgit\s+(filter-branch|filter-repo|rebase)\b
| \b(DROP\s+(DATABASE|SCHEMA|TABLE)|TRUNCATE\s+TABLE|DELETE\s+FROM)\b
| \b(redis-cli\b[\s\S]*\bFLUSH(ALL|DB)\b)
| \b(kubectl|oc)\s+delete\b
| \bterraform\s+destroy\b
| \b(cdk|pulumi)\s+destroy\b
| \b(docker|podman)\s+(system\s+prune|volume\s+rm|volume\s+prune|network\s+prune|container\s+prune|image\s+prune)\b
| \b(aws\s+s3\s+rb|gcloud\s+projects\s+delete)\b
| \b(Format-Volume|diskpart|mkfs(\.[A-Za-z0-9_+-]+)?|dd\s+if=|cipher\s+/w|fsutil)\b
| \b(sdelete|sdelete64)\b
| \bvssadmin\s+delete\s+shadows\b
| \bbcdedit\b[\s\S]*\s/delete\b
| \bwevtutil\s+cl\b
| \bwmic\s+path\s+win32_process\s+call\s+terminate\b
| \b(Get-CimInstance|gcim)\b[\s\S]*\bWin32_Process\b[\s\S]*\|\s*\b(Remove-CimInstance|rcim)\b
| \b(Get-CimInstance|gcim)\b[\s\S]*\bWin32_Process\b[\s\S]*\|\s*\b(Invoke-CimMethod|icim)\b[\s\S]*\b-?MethodName\s+Terminate\b
| \b(Invoke-CimMethod|icim)\b[\s\S]*\b-?ClassName\s+Win32_Process\b[\s\S]*\b-?MethodName\s+Terminate\b
| \b(Invoke-CimMethod|icim)\b[\s\S]*\b-?MethodName\s+Terminate\b[\s\S]*\b-?ClassName\s+Win32_Process\b
| \b(chmod\s+-R\s+777|Set-ExecutionPolicy\s+Unrestricted)\b
| \b(npm\s+uninstall\s+-g|pip\s+uninstall\s+-y)\b
)
'@

if ($command -notmatch $riskPattern) {
    Approve-Hook
}

$localBlockPattern = @'
(?isx)
(
  ^\s*(Remove-Item|ri)\b
| ^\s*(powershell|pwsh)(\.exe)?\b[\s\S]*\b(Remove-Item|ri|Format-Volume|diskpart|Set-ExecutionPolicy\s+Unrestricted)\b
| ^\s*cmd(\.exe)?\s+/[cq]\s*["']?\s*(del|rd|rmdir|erase)\b
| ^\s*(Format-Volume|diskpart)\b
| \b(sdelete|sdelete64)\b
| \bvssadmin\s+delete\s+shadows\b
| \bbcdedit\b[\s\S]*\s/delete\b
| \bwevtutil\s+cl\b
| \bwmic\s+path\s+win32_process\s+call\s+terminate\b
| \b(Get-CimInstance|gcim)\b[\s\S]*\bWin32_Process\b[\s\S]*\|\s*\b(Remove-CimInstance|rcim)\b
| \b(Get-CimInstance|gcim)\b[\s\S]*\bWin32_Process\b[\s\S]*\|\s*\b(Invoke-CimMethod|icim)\b[\s\S]*\b-?MethodName\s+Terminate\b
| \b(Invoke-CimMethod|icim)\b[\s\S]*\b-?ClassName\s+Win32_Process\b[\s\S]*\b-?MethodName\s+Terminate\b
| \b(Invoke-CimMethod|icim)\b[\s\S]*\b-?MethodName\s+Terminate\b[\s\S]*\b-?ClassName\s+Win32_Process\b
)
'@

if ($command -match $localBlockPattern) {
    Deny-Hook "BLOCKED by local destructive command guard. This Windows destructive command is not safely handled by dcg on this machine. Ask the user to run it manually if truly needed."
}

$dcg = Get-Command dcg -ErrorAction SilentlyContinue
if (-not $dcg) {
    $dcg = Get-Command dcg.exe -ErrorAction SilentlyContinue
}
if (-not $dcg) {
    Approve-Hook
}

# dcg 期望 Claude PreToolUse 格式输入：{ tool_name: "Bash", tool_input: { command: "..." } }
# 把 Windsurf 的 pre_run_command 重新包装一遍后喂给 dcg。
$dcgPayload = @{
    tool_name  = "Bash"
    tool_input = @{ command = $command }
} | ConvertTo-Json -Depth 5 -Compress

# dcg 通过 stdout JSON 表达决策（permissionDecision: allow/ask/deny）；stderr 是给人看的原因。
# Windsurf show_output:true 会把 stderr 显示给用户，所以我们让 dcg 的 stderr 自然流出。
$dcgStdout = $dcgPayload | & $dcg.Source

if ($dcgStdout -match '"permissionDecision"\s*:\s*"(deny|ask)"') {
    # 用户选择：ask 也阻断（与 Claude 端语义对齐）。dcg 已经把人类可读原因写到 stderr。
    exit 2
}
exit 0
