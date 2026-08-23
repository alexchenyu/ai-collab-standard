param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CliArgs)
. "$PSScriptRoot\_litellm-wrappers.ps1"
Invoke-CodexLiteLLM -Profile "deepseek" -CliArgs $CliArgs
