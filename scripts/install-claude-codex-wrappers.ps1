<#
    .SYNOPSIS
        Install machine-local Claude Code / Codex LiteLLM wrappers on Windows.

    .DESCRIPTION
        PowerShell counterpart to install-claude-codex-wrappers.sh.
        Writes ~/.config/litellm/client.env (bash-compatible, shared with WSL/Git Bash),
        copies wrappers to ~/.local/bin as .ps1 + .cmd (cmd/PowerShell can run claude-kimi),
        including claude-fix-transcripts, and appends Codex LiteLLM profiles without
        changing the top-level official model.

    .PARAMETER Key
        LiteLLM virtual key (not LITELLM_MASTER_KEY). Omit to reuse client.env.

    .PARAMETER Wan
        Use https://api.365ui.com

    .PARAMETER BaseUrl
        Custom LiteLLM root URL (no /v1).

    .PARAMETER Force
        Overwrite existing client.env.

    .EXAMPLE
        .\install-claude-codex-wrappers.ps1 -Key 'sk-...'

    .EXAMPLE
        .\install-claude-codex-wrappers.ps1 -Wan
#>
param(
    [string]$Key = "",
    [string]$BaseUrl = "",
    [switch]$Wan,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$LanBaseUrl = "http://us-agent.supermicro.com:4500"
$WanBaseUrl = "https://api.365ui.com"
$HomeDir = $env:USERPROFILE
if ($env:LITELLM_CLIENT_ENV) {
    $ClientEnv = $env:LITELLM_CLIENT_ENV
} else {
    $ClientEnv = Join-Path $HomeDir ".config\litellm\client.env"
}
$BinDir = Join-Path $HomeDir ".local\bin"
$CodexToml = Join-Path $HomeDir ".codex\config.toml"
$ClaudeSettings = Join-Path $HomeDir ".claude\settings.json"
$WrapperSrc = Join-Path $PSScriptRoot "wrappers\claude-codex"

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-Utf8NoBomFile([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function ConvertTo-BashSingleQuoted([string]$Value) {
    return "'" + ($Value -replace "'", "'\''") + "'"
}

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

function Read-ExistingClientEnv([string]$Path) {
    $out = @{ Key = ""; Base = "" }
    if (-not (Test-Path -LiteralPath $Path)) { return $out }
    Get-Content -LiteralPath $Path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^(?:export\s+)?LITELLM_API_KEY=(.*)$') {
            $out.Key = Unquote-BashValue $Matches[1]
        } elseif ($line -match '^(?:export\s+)?LITELLM_BASE_URL=(.*)$') {
            $out.Base = Unquote-BashValue $Matches[1]
        }
    }
    return $out
}

function Protect-UserOnlyFile([string]$Path) {
    $acl = Get-Acl -LiteralPath $Path
    $acl.SetAccessRuleProtection($true, $false)
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $sid,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $acl.SetAccessRule($rule)
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Write-ClientEnv([string]$Path, [string]$Url, [string]$ApiKey) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $body = @(
        "# Claude Code / Codex client virtual key, not LITELLM_MASTER_KEY"
        "export LITELLM_BASE_URL=$(ConvertTo-BashSingleQuoted $Url)"
        "export LITELLM_API_KEY=$(ConvertTo-BashSingleQuoted $ApiKey)"
    ) -join "`n"
    [System.IO.File]::WriteAllText($Path, $body + "`n", $Utf8NoBom)
    Protect-UserOnlyFile $Path
}

function Ensure-UserPath([string]$Dir) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ([string]::IsNullOrEmpty($userPath)) { $userPath = "" }
    $parts = $userPath -split ";" | Where-Object { $_ -ne "" }
    $already = $false
    foreach ($p in $parts) {
        if ($p.TrimEnd("\") -ieq $Dir.TrimEnd("\")) { $already = $true; break }
    }
    if (-not $already) {
        $joined = if ($userPath) { "$Dir;$userPath" } else { $Dir }
        [Environment]::SetEnvironmentVariable("Path", $joined, "User")
        Write-Host "Added $Dir to the user PATH (open a new terminal to apply it)."
    } else {
        Write-Host "The user PATH already contains $Dir."
    }
    if ($env:Path -notlike "*$Dir*") {
        $env:Path = "$Dir;$env:Path"
    }
}

function Add-CodexProfile([string]$TomlPath, [string]$Name, [string]$Body) {
    $pattern = '(?m)^\[profiles\.' + [regex]::Escape($Name) + '\]'
    $current = [System.IO.File]::ReadAllText($TomlPath)
    if ($current -match $pattern) {
        Write-Host "Codex profile already exists: $Name"
        return
    }
    [System.IO.File]::AppendAllText($TomlPath, "`n$Body`n", $Utf8NoBom)
    Write-Host "Added [profiles.$Name]."
}

function Update-CodexToml([string]$Path, [string]$CodexBaseUrl) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
    }
    $text = [System.IO.File]::ReadAllText($Path)
    $officialModel = "gpt-5.1-codex-max"
    if ($text -match '(?m)^model = "([^"]*)"') {
        $officialModel = $Matches[1]
    }

    if ($text -match '(?m)^\[model_providers\.litellm\]') {
        $lines = New-Object System.Collections.Generic.List[string]
        $inLitellm = $false
        foreach ($line in ($text -split "`n")) {
            $stripped = $line.TrimEnd("`r")
            if ($stripped.StartsWith("[") -and $stripped.Trim() -eq "[model_providers.litellm]") {
                $inLitellm = $true
                [void]$lines.Add($line)
                continue
            }
            if ($inLitellm -and $stripped.StartsWith("[") -and $stripped.Trim() -ne "[model_providers.litellm]") {
                $inLitellm = $false
            }
            if ($inLitellm -and $stripped.StartsWith("base_url")) {
                $nl = ""
                if ($line.EndsWith("`r")) { $nl = "`r" }
                [void]$lines.Add("base_url = `"$CodexBaseUrl`"$nl")
                continue
            }
            [void]$lines.Add($line)
        }
        $text = [string]::Join("`n", $lines)
        Write-Utf8NoBomFile $Path $text
        Write-Host "Updated the Codex LiteLLM base_url."
    } else {
        $block = @"

[model_providers.litellm]
name = "LiteLLM"
base_url = "$CodexBaseUrl"
env_key = "LITELLM_API_KEY"
wire_api = "responses"
request_max_retries = 4
stream_max_retries = 10
stream_idle_timeout_ms = 3600000
"@
        [System.IO.File]::AppendAllText($Path, $block, $Utf8NoBom)
        Write-Host "Added [model_providers.litellm]."
    }

    Add-CodexProfile $Path "deepseek" @"
[profiles.deepseek]
model = "DeepSeek-V4-Flash-0731"
model_provider = "litellm"
"@
    Add-CodexProfile $Path "kimi" @"
[profiles.kimi]
model = "Kimi-K3"
model_provider = "litellm"
"@
    Add-CodexProfile $Path "openai" @"
[profiles.openai]
model = "$officialModel"
model_provider = "openai"
"@
}

if (-not (Test-Path -LiteralPath $WrapperSrc)) {
    Write-Error "Wrapper template directory not found: $WrapperSrc"
    exit 1
}

$resolvedBase = $LanBaseUrl
$baseUrlSet = $false
if ($Wan) {
    $resolvedBase = $WanBaseUrl
    $baseUrlSet = $true
}
if (-not [string]::IsNullOrEmpty($BaseUrl)) {
    $resolvedBase = $BaseUrl
    $baseUrlSet = $true
}
$resolvedBase = $resolvedBase.TrimEnd("/")
if ($resolvedBase -like "*/v1") {
    Write-Error "Do not include /v1 in the LiteLLM root URL. Codex adds it automatically."
    exit 1
}

$existing = Read-ExistingClientEnv $ClientEnv
if ([string]::IsNullOrEmpty($Key)) { $Key = $existing.Key }
if (-not $baseUrlSet -and -not [string]::IsNullOrEmpty($existing.Base)) {
    $resolvedBase = $existing.Base
}
if ([string]::IsNullOrEmpty($Key)) {
    Write-Error "A virtual key is required. Usage: .\install-claude-codex-wrappers.ps1 -Key 'sk-your-virtual-key'"
    exit 1
}
if ($Key -like "*MASTER*" -or $Key -like "sk-supersuper*") {
    Write-Error "This looks like LITELLM_MASTER_KEY. Use a client virtual key instead."
    exit 1
}

$writeEnv = $true
if ((Test-Path -LiteralPath $ClientEnv) -and -not $Force) {
    if ($Key -eq $existing.Key -and $resolvedBase -eq $existing.Base) {
        Write-Host "Keeping existing client.env: $ClientEnv"
        $writeEnv = $false
    } else {
        Write-Host "Updating client.env: $ClientEnv"
    }
} else {
    Write-Host "Writing client.env: $ClientEnv"
}
if ($writeEnv) {
    Write-ClientEnv -Path $ClientEnv -Url $resolvedBase -ApiKey $Key
}

if (-not (Test-Path -LiteralPath $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
}

$names = @(
    "claude-kimi",
    "claude-deepseek",
    "claude-glm",
    "claude-official",
    "claude-fix-transcripts",
    "codex-kimi",
    "codex-deepseek",
    "codex-official"
)
Copy-Item -LiteralPath (Join-Path $WrapperSrc "_litellm-wrappers.ps1") -Destination (Join-Path $BinDir "_litellm-wrappers.ps1") -Force
$shim = Get-Content -LiteralPath (Join-Path $WrapperSrc "shim.cmd") -Raw
foreach ($name in $names) {
    Copy-Item -LiteralPath (Join-Path $WrapperSrc "$name.ps1") -Destination (Join-Path $BinDir "$name.ps1") -Force
    Write-Utf8NoBomFile (Join-Path $BinDir "$name.cmd") $shim
}
Write-Host "Installed wrappers to $BinDir."

Update-CodexToml -Path $CodexToml -CodexBaseUrl "$resolvedBase/v1"
Ensure-UserPath $BinDir

Write-Host ""
Write-Host "Installed commands:"
Write-Host "  claude-kimi          # Claude Code + Kimi K3"
Write-Host "  claude-deepseek      # Claude Code + DeepSeek V4 Flash"
Write-Host "  claude-glm           # Claude Code + GLM-5.3"
Write-Host "  claude-official      # Anthropic official"
Write-Host "  claude-fix-transcripts  # Repair Kimi/DeepSeek transcripts for official resume"
Write-Host "  codex-deepseek       # Codex + DeepSeek V4 Flash"
Write-Host "  codex-kimi           # Codex + Kimi K3"
Write-Host "  codex-official       # OpenAI official"
Write-Host ""
Write-Host "client.env: $ClientEnv"
Write-Host "LiteLLM:    $resolvedBase"
Write-Host "Open a new terminal, then run claude-kimi or codex-deepseek."

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Warning "claude was not found. Install it with: npm install -g @anthropic-ai/claude-code"
}
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Warning "codex was not found. Install it with: npm install -g @openai/codex"
}
if (Test-Path -LiteralPath $ClaudeSettings) {
    $settings = Get-Content -LiteralPath $ClaudeSettings -Raw
    if ($settings -match '"env"') {
        Write-Warning "$ClaudeSettings contains an env field that may override wrapper variables. Remove ANTHROPIC_* entries before using claude-kimi."
    }
    if ($settings -match '"model"\s*:\s*"opus') {
        Write-Warning "$ClaudeSettings still pins model to opus*. Change it to Kimi-K3 or remove the field if /status still shows opus."
    }
}
