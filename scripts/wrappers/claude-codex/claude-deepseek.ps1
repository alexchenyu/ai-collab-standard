param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CliArgs)
. "$PSScriptRoot\_litellm-wrappers.ps1"
Invoke-ClaudeLiteLLM -Model "DeepSeek-V4-Flash-0731" -CompactWindow "655360" -CliArgs $CliArgs
