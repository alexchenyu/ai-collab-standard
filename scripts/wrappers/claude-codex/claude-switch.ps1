param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("official", "kimi")]
    [string]$Backend,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

$ErrorActionPreference = "Stop"
$prep = Join-Path $PSScriptRoot "claude-session-prep.js"
$prepArgs = @("--backend", $Backend, "--continue", "--cwd", (Get-Location).Path)
$forward = @()

if ($CliArgs) {
    if ($CliArgs[0] -eq "--continue") {
        if ($CliArgs.Count -gt 1) { $forward = $CliArgs[1..($CliArgs.Count - 1)] }
    } elseif ($CliArgs[0] -eq "--resume") {
        if ($CliArgs.Count -lt 2) {
            throw "claude-switch: --resume requires a session ID"
        }
        $prepArgs = @(
            "--backend", $Backend,
            "--resume", $CliArgs[1],
            "--cwd", (Get-Location).Path
        )
        if ($CliArgs.Count -gt 2) { $forward = $CliArgs[2..($CliArgs.Count - 1)] }
    } else {
        $forward = $CliArgs
    }
}
if ($forward.Count -gt 0 -and $forward[0] -eq "--") {
    if ($forward.Count -gt 1) {
        $forward = $forward[1..($forward.Count - 1)]
    } else {
        $forward = @()
    }
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "claude-switch: node is required"
}

$sessionId = (& node $prep @prepArgs).Trim()
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ([string]::IsNullOrWhiteSpace($sessionId)) {
    throw "claude-switch: session preparation returned no session ID"
}

$target = Join-Path $PSScriptRoot "claude-$Backend.ps1"
$launchArgs = @()
if ($Backend -eq "official") { $launchArgs += @("--model", "default") }
$launchArgs += @("--resume", $sessionId)
$launchArgs += $forward

& $target @launchArgs
exit $LASTEXITCODE
