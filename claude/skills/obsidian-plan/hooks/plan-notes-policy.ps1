#!/usr/bin/env pwsh
# SessionStart hook: tells Claude whether this machine keeps plan notes.
# PowerShell twin of plan-notes-policy.sh, for machines with no bash available.
#
# Plan notes are OFF unless OBSIDIAN_PLAN_VAULT names an existing directory: the Obsidian vault
# holding the plan notes.
# OBSIDIAN_PLAN_DIR optionally names the folder the note folders live in, relative to the vault.
# It defaults to "Projects"; use "." to put them at the vault root itself.
# Set them per-machine in ~/.claude/settings.json, which no repo tracks:
#   { "env": { "OBSIDIAN_PLAN_VAULT": "C:\\Users\\me\\Notes", "OBSIDIAN_PLAN_DIR": "Projects" } }
# and point the hook at this file with "shell": "powershell".
#
# ConvertTo-Json handles the escaping, which matters more here than in the bash
# twin: a Windows notes path is full of backslashes that must survive into valid
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

$root = $env:OBSIDIAN_PLAN_VAULT
$dir  = $env:OBSIDIAN_PLAN_DIR
if ([string]::IsNullOrWhiteSpace($dir)) { $dir = "Projects" }

if ([string]::IsNullOrWhiteSpace($root)) {
    Write-Policy -Context 'Plan notes are OFF on this machine: OBSIDIAN_PLAN_VAULT is unset. Do not create or update plan notes, and do not offer to.'
    exit 0
}

if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    Write-Policy `
        -Context "Plan notes are OFF on this machine: OBSIDIAN_PLAN_VAULT is set to '$root', which is not an existing directory. Do not create or update plan notes. Report the misconfiguration if plan notes come up." `
        -Message "OBSIDIAN_PLAN_VAULT points to $root, which does not exist. Plan notes are disabled until that is fixed."
    exit 0
}

# OBSIDIAN_PLAN_DIR is relative to the vault root; it may not be absolute or climb out of it.
if ([IO.Path]::IsPathRooted($dir) -or $dir -match '\.\.') {
    Write-Policy `
        -Context "Plan notes are OFF on this machine: OBSIDIAN_PLAN_DIR is set to '$dir', which is not a path inside the vault. Do not create or update plan notes. Report the misconfiguration if plan notes come up." `
        -Message "OBSIDIAN_PLAN_DIR is '$dir', which must be a relative path inside OBSIDIAN_PLAN_VAULT. Plan notes are disabled until that is fixed."
    exit 0
}

$dir = $dir.TrimEnd('/', '\')
if ($dir -eq '.' -or $dir -eq '') { $notes = $root } else { $notes = Join-Path $root $dir }

if (Test-Path -LiteralPath $notes -PathType Container) {
    $state = 'It already exists.'
} else {
    $state = 'It does not exist yet; create it when the first note is written.'
}

# Build the note paths with this platform's separator rather than hardcoding one.
$sep = [IO.Path]::DirectorySeparatorChar
$ticketPath  = "$notes$sep<TICKET>${sep}Plan.md"
$projectPath = "$notes$sep<Project>${sep}Plan.md"

Write-Policy -Context "Plan notes are ON for this machine. Vault root: $root. Plan notes live under $notes ($ticketPath, or $projectPath when work spans several tickets). $state Follow the obsidian-plan skill for the conventions."
