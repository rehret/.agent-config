#!/usr/bin/env pwsh
# SessionStart hook: tells Claude whether this machine keeps Obsidian plan notes.
# PowerShell twin of plan-notes-policy.sh, for machines with no bash available.
#
# Plan notes are OFF unless PLAN_NOTES names an existing directory (the vault root).
# Set it per-machine in ~/.claude/settings.json, which no repo tracks:
#   { "env": { "PLAN_NOTES": "C:\\Users\\me\\Notes" } }
# and point the hook at this file with "shell": "powershell".
#
# ConvertTo-Json handles the escaping, which matters more here than in the bash
# twin: a Windows vault path is full of backslashes that must survive into valid
# JSON.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Policy {
    param(
        [Parameter(Mandatory)][string] $Context,
        [string] $Message
    )
    $out = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName     = 'SessionStart'
            additionalContext = $Context
        }
        suppressOutput = $true
    }
    if ($Message) { $out['systemMessage'] = $Message }
    $out | ConvertTo-Json -Compress -Depth 5
}

$vault = $env:PLAN_NOTES

if ([string]::IsNullOrWhiteSpace($vault)) {
    Write-Policy -Context 'Obsidian plan notes are OFF on this machine: PLAN_NOTES is unset. Do not create or update plan notes, and do not offer to.'
    exit 0
}

if (-not (Test-Path -LiteralPath $vault -PathType Container)) {
    Write-Policy `
        -Context "Obsidian plan notes are OFF on this machine: PLAN_NOTES is set to '$vault', which is not an existing directory. Do not create or update plan notes. Report the misconfiguration if plan notes come up." `
        -Message "PLAN_NOTES points to $vault, which does not exist. Plan notes are disabled until that is fixed."
    exit 0
}

# Build the note path with this platform's separator rather than hardcoding one.
$sep = [IO.Path]::DirectorySeparatorChar
$notePath = "$(Join-Path $vault 'Projects')$sep<TICKET>${sep}Plan.md"

Write-Policy -Context "Obsidian plan notes are ON for this machine. Vault root: $vault. Plan notes live at $notePath. Follow the obsidian-plan skill for the conventions."
