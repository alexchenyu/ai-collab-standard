param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CliArgs)
. "$PSScriptRoot\_litellm-wrappers.ps1"
Invoke-ClaudeLiteLLM `
    -Model "Kimi-K3" `
    -CompactWindow "900000" `
    -MaxContext "1048576" `
    -SettingsPath (Join-Path $PSScriptRoot "claude-kimi-settings.json") `
    -CliArgs $CliArgs
