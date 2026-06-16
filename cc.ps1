#!/usr/bin/env pwsh
# cc.ps1 — Claude Code wrapper (Windows) with session naming and cleanup prompts.
# Mirrors ./cc (zsh) and ./cc.bash.
#
# Run it directly:                pwsh -File .\cc.ps1 [claude args...]
# Or add a function to your PowerShell $PROFILE so `cc` calls it:
#   function cc { & "C:\path\to\cc.ps1" @args }
#
# Configuration (set as environment variables):
#   CC_SKIP_NAME=1        — never prompt for name
#   CC_SKIP_EXIT=1        — never prompt on exit
#   CC_AUTO_CLEAN_DAYS=90 — days threshold for the 'clean' option

[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Rest = @())

$SkipName = if ($env:CC_SKIP_NAME) { $env:CC_SKIP_NAME } else { '0' }
$SkipExit = if ($env:CC_SKIP_EXIT) { $env:CC_SKIP_EXIT } else { '0' }
$AutoCleanDays = if ($env:CC_AUTO_CLEAN_DAYS) { $env:CC_AUTO_CLEAN_DAYS } else { '90' }

function Test-CcFlag {
    param([string[]] $List, [string] $Flag)
    foreach ($a in $List) { if ($a -eq $Flag -or $a -like "$Flag=*") { return $true } }
    return $false
}

$claudeArgs = @()

# Passthrough: don't prompt if --name, -n, or -p/--print is already set
if ((Test-CcFlag $Rest '--name') -or (Test-CcFlag $Rest '-n')) { $SkipName = '1' }
if ((Test-CcFlag $Rest '-p') -or (Test-CcFlag $Rest '--print')) { $SkipName = '1'; $SkipExit = '1' }

# Prompt for session name
if ($SkipName -ne '1') {
    Write-Host -NoNewline 'Session name (enter to skip): ' -ForegroundColor Cyan
    $name = Read-Host
    if ($name) {
        $claudeArgs += @('-n', $name)
        Write-Host "-> $name" -ForegroundColor Green
    }
}

# Timestamp marker for finding the session transcript
$start = Get-Date

# Launch Claude Code
& claude @claudeArgs @Rest
$code = $LASTEXITCODE

# Post-session prompt
if ($SkipExit -ne '1' -and $code -eq 0) {
    Write-Host ''
    Write-Host -NoNewline 'Keep this session transcript? [Y/n/clean]: ' -ForegroundColor Yellow
    $ans = Read-Host
    if ($ans) { $ans = $ans.ToLower() } else { $ans = '' }

    switch -Regex ($ans) {
        '^(n|no)$' {
            $projects = Join-Path $env:USERPROFILE '.claude\projects'
            $latest = Get-ChildItem -Path $projects -Recurse -Filter *.jsonl -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\subagents\\' -and $_.LastWriteTime -gt $start } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latest) {
                $sid = [System.IO.Path]::GetFileNameWithoutExtension($latest.Name)
                Remove-Item $latest.FullName -Force -ErrorAction SilentlyContinue
                $dir = Join-Path $latest.DirectoryName $sid
                if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
                Write-Host 'Transcript removed.' -ForegroundColor DarkGray
            }
            else {
                Write-Host 'No transcript found to remove.' -ForegroundColor DarkGray
            }
        }
        '^(clean|c)$' {
            if (Get-Command claude-recall -ErrorAction SilentlyContinue) {
                claude-recall clean --older-than $AutoCleanDays
            }
            else {
                Write-Host 'claude-recall not found in PATH. Install it for cleanup.' -ForegroundColor DarkGray
            }
        }
        default {
            Write-Host 'Session kept.' -ForegroundColor DarkGray
        }
    }
}

exit $code
