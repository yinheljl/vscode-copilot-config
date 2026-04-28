$ErrorActionPreference = "SilentlyContinue"

$payload = [Console]::In.ReadToEnd()

function Approve-Hook {
    # Claude Code: exit 0 (no JSON output required) = allow
    exit 0
}

if ([string]::IsNullOrWhiteSpace($payload)) {
    Approve-Hook
}

try {
    $event = $payload | ConvertFrom-Json -ErrorAction Stop
} catch {
    Approve-Hook
}

$command = $null
if ($event.PSObject.Properties.Name -contains "tool_input" -and $event.tool_input) {
    if ($event.tool_input.PSObject.Properties.Name -contains "command") {
        $command = [string]$event.tool_input.command
    }
}
if (-not $command -and $event.PSObject.Properties.Name -contains "toolInput" -and $event.toolInput) {
    if ($event.toolInput.PSObject.Properties.Name -contains "command") {
        $command = [string]$event.toolInput.command
    }
}
if (-not $command -and $event.PSObject.Properties.Name -contains "command") {
    $command = [string]$event.command
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
| \b(chmod\s+-R\s+777|Set-ExecutionPolicy\s+Unrestricted)\b
| \b(npm\s+uninstall\s+-g|pip\s+uninstall\s+-y)\b
)
'@

if ($command -notmatch $riskPattern) {
    Approve-Hook
}

$dcg = Get-Command dcg -ErrorAction SilentlyContinue
if (-not $dcg) {
    $dcg = Get-Command dcg.exe -ErrorAction SilentlyContinue
}
if (-not $dcg) {
    Approve-Hook
}

if (($event.PSObject.Properties.Name -notcontains "tool_name") -and
    ($event.PSObject.Properties.Name -notcontains "toolName")) {
    $event | Add-Member -MemberType NoteProperty -Name "tool_name" -Value "Bash" -Force
    $payload = $event | ConvertTo-Json -Depth 20 -Compress
}

# Claude Code exit code semantics differ from Codex:
#   exit 0  = allow (action proceeds)
#   exit 2  = BLOCK (stderr message shown to Claude)
#   exit 1  = non-blocking error (action still proceeds — do NOT use for blocking)
$payload | & $dcg.Source
$dcgExit = $LASTEXITCODE
if ($dcgExit -ne 0) { exit 2 }
exit 0
