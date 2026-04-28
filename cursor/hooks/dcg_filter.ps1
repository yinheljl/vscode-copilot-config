$ErrorActionPreference = "SilentlyContinue"

$payload = [Console]::In.ReadToEnd()

function Approve-Hook {
    $out = @{ permission = "allow" } | ConvertTo-Json -Compress
    Write-Output $out
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

# Cursor beforeShellExecution: stdin has "command" field directly
$command = $null
if ($event.PSObject.Properties.Name -contains "command") {
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

# Build a minimal event payload for dcg
$dcgInput = @{
    tool_name = "Bash"
    tool_input = @{ command = $command }
} | ConvertTo-Json -Depth 10 -Compress

$dcgJson = $dcgInput | & $dcg.Source
if ($dcgJson -match '"permissionDecision"\s*:\s*"(deny|ask)"') {
    $reason = "BLOCKED by dcg. Use `dcg explain `"$command`"` for details."
    $block = @{
        permission = "deny"
        user_message = $reason
        agent_message = "This command was blocked by dcg destructive command guard. Ask the user to run it manually if truly needed."
    } | ConvertTo-Json -Compress
    Write-Output $block
    exit 2
}

Approve-Hook
