# claude-fix-transcripts
# 修复 Kimi-K3 / DeepSeek（经 LiteLLM 中转）时期 Claude Code 会话记录（.jsonl）
# 里的非 Anthropic 官方格式残留，使这些会话可以被 claude / claude-official
# 正常 resume。Windows 对应 install-claude-codex-wrappers.sh 里的同名 bash wrapper。
#
# 已知三类问题（resume 时全量回放历史，触发官方 API 400）：
#   1. 工具调用 id 形如 "Bash:12"（含冒号），违反 ^[a-zA-Z0-9_-]+$
#      报错：tool_use.id: String should match pattern '^[a-zA-Z0-9_-]+$'
#   2. 空文本块 "text":""（API 要求 text 非空）
#      报错：text content blocks must be non-empty
#   3. user/assistant 消息空内容 "content":[] / "content":""
#
# 用法：
#   claude-fix-transcripts <session.jsonl> [更多文件...]
#   claude-fix-transcripts --all     # 扫描 ~/.claude/projects 下全部 .jsonl
#
# 注意：先关闭对应的 Claude Code 会话再修（运行中的会话仍按内存里的旧数据
# 工作，且继续按旧格式写入）。2 分钟内有写入的文件会被视为活跃会话而跳过。
# 原文件备份为 <file>.fixbak。修复后重新 claude --resume 选择该会话即可。

param(
    [switch]$All,
    [Alias("h")]
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Show-Usage {
    $text = @(
        "claude-fix-transcripts",
        "修复 Kimi-K3 / DeepSeek（经 LiteLLM 中转）时期 Claude Code 会话记录（.jsonl）",
        "里的非 Anthropic 官方格式残留，使这些会话可以被 claude / claude-official",
        "正常 resume。",
        "",
        "用法：",
        "  claude-fix-transcripts <session.jsonl> [更多文件...]",
        "  claude-fix-transcripts --all     # 扫描 ~/.claude/projects 下全部 .jsonl",
        "",
        "注意：先关闭对应的 Claude Code 会话再修。2 分钟内有写入的文件会被跳过。",
        "原文件备份为 <file>.fixbak。"
    ) -join "`n"
    Write-Host $text
}

function Test-NeedsFix([string]$Text) {
    if ([regex]::IsMatch($Text, '"(?:tool_use_)?id":"[A-Za-z][A-Za-z0-9_]*:[0-9]+"')) {
        return $true
    }
    return $Text.Contains('"text":""')
}

function Repair-TranscriptText([string]$Text) {
    $lines = $Text -split "`n", 0
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        $hasCr = $line.EndsWith("`r")
        $s = if ($hasCr) { $line.Substring(0, $line.Length - 1) } else { $line }
        $s = [regex]::Replace(
            $s,
            '("id":"|"tool_use_id":")([A-Za-z][A-Za-z0-9_]*):([0-9]+")',
            '${1}${2}_${3}'
        )
        $s = $s.Replace('"text":""', '"text":" "')
        if ($s -match '"role":"(user|assistant)"') {
            $s = $s.Replace('"content":[]', '"content":[{"type":"text","text":" "}]')
            $s = $s.Replace('"content":""', '"content":" "')
        }
        if ($hasCr) { $s += "`r" }
        [void]$out.Add($s)
    }
    return [string]::Join("`n", $out)
}

function Test-Jsonl([string]$Text) {
    foreach ($line in ($Text -split "`n")) {
        $t = $line.TrimEnd("`r").Trim()
        if ($t.Length -eq 0) { continue }
        $null = ConvertFrom-Json -InputObject $t
    }
}

function Repair-One([string]$FilePath) {
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-Host "skip（不存在）: $FilePath"
        return $true
    }
    $item = Get-Item -LiteralPath $FilePath
    if (((Get-Date) - $item.LastWriteTime).TotalSeconds -lt 120) {
        Write-Host "skip（2 分钟内有写入，疑似活跃会话，先关闭再修）: $FilePath"
        return $true
    }
    $original = [System.IO.File]::ReadAllText($FilePath)
    if (-not (Test-NeedsFix $original)) {
        Write-Host "ok（无需修复）: $FilePath"
        return $true
    }
    $fixed = Repair-TranscriptText $original
    try {
        Test-Jsonl $fixed
    } catch {
        [Console]::Error.WriteLine("ERROR: 修复后 JSONL 校验失败，未改写 $FilePath")
        return $false
    }
    $backup = "$FilePath.fixbak"
    [System.IO.File]::Copy($FilePath, $backup, $true)
    [System.IO.File]::WriteAllText($FilePath, $fixed, $Utf8NoBom)
    Write-Host "fixed: $FilePath（备份: $backup）"
    return $true
}

function Get-ClaudeProjectTranscripts {
    $homeDir = $env:USERPROFILE
    if ([string]::IsNullOrEmpty($homeDir)) { $homeDir = $HOME }
    $projects = Join-Path $homeDir ".claude\projects"
    if (-not (Test-Path -LiteralPath $projects)) { return @() }
    return @(Get-ChildItem -LiteralPath $projects -Filter *.jsonl -Recurse -File -ErrorAction SilentlyContinue)
}

if ($Help) {
    Show-Usage
    exit 0
}

$rc = 0
if ($All) {
    foreach ($f in (Get-ClaudeProjectTranscripts)) {
        if (-not (Repair-One $f.FullName)) { $rc = 1 }
    }
    exit $rc
}

if (-not $Paths -or $Paths.Count -lt 1) {
    Show-Usage
    exit 1
}

foreach ($f in $Paths) {
    if (-not (Repair-One $f)) { $rc = 1 }
}
Write-Host "提示：修复后请退出并重开会话（claude --resume 选择该会话）。"
exit $rc
