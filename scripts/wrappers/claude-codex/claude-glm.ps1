param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CliArgs)
. "$PSScriptRoot\_litellm-wrappers.ps1"
Invoke-ClaudeLiteLLM -Model "GLM-5.3" -CompactWindow "563392" -CliArgs $CliArgs
