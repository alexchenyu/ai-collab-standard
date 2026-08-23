param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CliArgs)
. "$PSScriptRoot\_litellm-wrappers.ps1"
Invoke-ClaudeLiteLLM -Model "Kimi-K3" -CompactWindow "502000" -CliArgs $CliArgs
