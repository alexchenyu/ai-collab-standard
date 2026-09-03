# Shared helpers for Claude Code / Codex LiteLLM wrappers (Windows PowerShell 5.1+).
# Installed to ~/.local/bin by install-claude-codex-wrappers.ps1. Do not commit keys.

$script:DefaultLiteLLMBase = "http://us-agent.supermicro.com:4500"

function Unquote-BashValue([string]$Raw) {
    if ([string]::IsNullOrEmpty($Raw)) { return "" }
    $v = $Raw.Trim()
    if ($v.Length -ge 2) {
        $q = $v[0]
        if (($q -eq [char]"'" -or $q -eq [char]'"') -and $v[$v.Length - 1] -eq $q) {
            return $v.Substring(1, $v.Length - 2)
        }
    }
    return $v
}

function Import-LiteLLMClientEnv {
    $clientEnv = $env:LITELLM_CLIENT_ENV
    if ([string]::IsNullOrEmpty($clientEnv)) {
        $clientEnv = Join-Path $env:USERPROFILE ".config\litellm\client.env"
    }
    if (-not (Test-Path -LiteralPath $clientEnv)) {
        throw "LITELLM_API_KEY is missing. Run install-claude-codex-wrappers.ps1 first: $clientEnv"
    }
    Get-Content -LiteralPath $clientEnv -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^(?:export\s+)?LITELLM_API_KEY=(.*)$') {
            $env:LITELLM_API_KEY = Unquote-BashValue $Matches[1]
        } elseif ($line -match '^(?:export\s+)?LITELLM_BASE_URL=(.*)$') {
            $env:LITELLM_BASE_URL = Unquote-BashValue $Matches[1]
        }
    }
    if ([string]::IsNullOrEmpty($env:LITELLM_API_KEY)) {
        throw "LITELLM_API_KEY is missing from $clientEnv"
    }
    if ([string]::IsNullOrEmpty($env:LITELLM_BASE_URL)) {
        $env:LITELLM_BASE_URL = $script:DefaultLiteLLMBase
    }
}

function Remove-EnvVars([string[]]$Names) {
    foreach ($name in $Names) {
        Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
    }
}

function Invoke-TrackedCli {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$InstallHint,
        [string[]]$CliArgs
    )
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        if ([string]::IsNullOrEmpty($InstallHint)) {
            $InstallHint = "npm install -g $Name"
        }
        throw "$Name was not found. Install it with: $InstallHint"
    }
    if ($null -eq $CliArgs) { $CliArgs = @() }
    & $cmd @CliArgs
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    exit $code
}

function Invoke-ClaudeLiteLLM {
    param(
        [Parameter(Mandatory = $true)][string]$Model,
        [Parameter(Mandatory = $true)][string]$CompactWindow,
        [string]$MaxContext = "",
        [string]$SettingsPath = "",
        [string[]]$CliArgs
    )
    Import-LiteLLMClientEnv
    Remove-EnvVars @("ANTHROPIC_API_KEY")
    $env:ANTHROPIC_BASE_URL = $env:LITELLM_BASE_URL
    $env:ANTHROPIC_AUTH_TOKEN = $env:LITELLM_API_KEY
    $env:ANTHROPIC_MODEL = $Model
    $env:ANTHROPIC_SMALL_FAST_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_FABLE_MODEL = $Model
    $env:CLAUDE_CODE_SUBAGENT_MODEL = $Model
    $env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = $CompactWindow
    if ($MaxContext) {
        $env:CLAUDE_CODE_MAX_CONTEXT_TOKENS = $MaxContext
    } else {
        $env:CLAUDE_CODE_MAX_CONTEXT_TOKENS = $CompactWindow
    }
    $env:CLAUDE_CODE_EFFORT_LEVEL = "max"
    $forward = @()
    if ($SettingsPath) { $forward += @("--settings", $SettingsPath) }
    if ($CliArgs) { $forward += $CliArgs }
    Invoke-TrackedCli -Name "claude" -InstallHint "npm install -g @anthropic-ai/claude-code" -CliArgs $forward
}

function Invoke-ClaudeOfficial {
    param([string[]]$CliArgs)
    Remove-EnvVars @(
        "ANTHROPIC_BASE_URL",
        "ANTHROPIC_AUTH_TOKEN",
        "ANTHROPIC_API_KEY",
        "ANTHROPIC_MODEL",
        "ANTHROPIC_SMALL_FAST_MODEL",
        "ANTHROPIC_DEFAULT_OPUS_MODEL",
        "ANTHROPIC_DEFAULT_SONNET_MODEL",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        "ANTHROPIC_DEFAULT_FABLE_MODEL",
        "CLAUDE_CODE_SUBAGENT_MODEL",
        "CLAUDE_CODE_AUTO_COMPACT_WINDOW",
        "CLAUDE_CODE_MAX_CONTEXT_TOKENS",
        "CLAUDE_CODE_EFFORT_LEVEL"
    )
    Invoke-TrackedCli -Name "claude" -InstallHint "npm install -g @anthropic-ai/claude-code" -CliArgs $CliArgs
}

function Invoke-CodexLiteLLM {
    param(
        [Parameter(Mandatory = $true)][string]$Profile,
        [string[]]$CliArgs
    )
    Import-LiteLLMClientEnv
    Remove-EnvVars @("OPENAI_BASE_URL", "OPENAI_API_KEY")
    $forward = @("-p", $Profile)
    if ($CliArgs) { $forward += $CliArgs }
    Invoke-TrackedCli -Name "codex" -InstallHint "npm install -g @openai/codex" -CliArgs $forward
}

function Invoke-CodexOfficial {
    param([string[]]$CliArgs)
    Remove-EnvVars @("OPENAI_BASE_URL", "LITELLM_API_KEY")
    $forward = @("-p", "openai")
    if ($CliArgs) { $forward += $CliArgs }
    Invoke-TrackedCli -Name "codex" -InstallHint "npm install -g @openai/codex" -CliArgs $forward
}
