<#
    .SYNOPSIS
        Install or update .ai-collab in a Windows project.

    .DESCRIPTION
        PowerShell counterpart to bootstrap.sh for users without WSL or Git Bash.
        Adds .ai-collab as a submodule (or updates it), then invokes the bash
        init script via `bash` if available (Git for Windows ships one).

        Requirements:
        - git
        - python (must be on PATH; Windows installer typically registers `python`)
        - bash (Git for Windows ships /usr/bin/bash; required for init script)

    .PARAMETER RepoUrl
        Override the repo URL (default: alexchenyu/ai-collab-standard).

    .PARAMETER TargetDir
        Project root (default: current directory).

    .PARAMETER Lang
        Language rule for templates: zh | en (default: zh).

    .PARAMETER ProjectName
        Project name passed to init script.

    .PARAMETER NoHook
        Skip pre-commit hook installation.

    .EXAMPLE
        iwr -useb https://raw.githubusercontent.com/alexchenyu/ai-collab-standard/main/scripts/bootstrap.ps1 | iex

    .EXAMPLE
        ./bootstrap.ps1 -ProjectName "MyApp" -Lang en
#>

param(
    [string]$RepoUrl = $env:AI_COLLAB_REPO_URL,
    [string]$TargetDir = ".",
    [string]$Lang = "zh",
    [string]$ProjectName = "",
    [switch]$NoHook,
    [switch]$EnableCodexSkills
)

$ErrorActionPreference = "Stop"

if (-not $RepoUrl) {
    $RepoUrl = "https://github.com/alexchenyu/ai-collab-standard.git"
}

function Write-Note($msg) { Write-Host "[ai-collab-bootstrap] $msg" }

function Require-Cmd($name, $hint) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Error "$name not found on PATH. $hint"
        exit 1
    }
}

Require-Cmd git "Install Git for Windows: https://git-scm.com/download/win"
Require-Cmd python "Install Python 3 from https://www.python.org/downloads/windows/ and tick 'Add Python to PATH'."
Require-Cmd bash "Bash is required for the init script. Git for Windows includes one at C:\Program Files\Git\bin\bash.exe."

Push-Location $TargetDir
try {
    if (-not (Test-Path ".git")) {
        Write-Note "git repo not found; running git init"
        git init | Out-Null
    }

    if ((Test-Path ".ai-collab/.git") -or (Test-Path ".ai-collab/.git" -PathType Leaf)) {
        Write-Note "updating existing .ai-collab"
        git -C .ai-collab fetch origin
        $defaultBranch = (git -C .ai-collab symbolic-ref --short refs/remotes/origin/HEAD 2>$null) -replace '^origin/', ''
        if (-not $defaultBranch) { $defaultBranch = "main" }
        Write-Note "checking out origin/$defaultBranch"
        git -C .ai-collab checkout "origin/$defaultBranch"
    } elseif (Test-Path ".ai-collab") {
        Write-Error ".ai-collab exists but is not a git checkout; move it aside or remove it first"
        exit 1
    } else {
        Write-Note "adding .ai-collab submodule"
        git submodule add $RepoUrl .ai-collab
    }

    $initArgs = @(".ai-collab/scripts/init_ai_collab_docs.sh", ".", "--lang", $Lang)
    if ($ProjectName) { $initArgs += @("--project-name", $ProjectName) }
    if (-not $NoHook) { $initArgs += "--install-hook" }
    if ($EnableCodexSkills) { $initArgs += "--enable-codex-skills" }

    Write-Note "running init via bash"
    & bash @initArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Note "running check"
    & bash ".ai-collab/scripts/check.sh" "."
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 2) { exit $LASTEXITCODE }
}
finally {
    Pop-Location
}
