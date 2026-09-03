#!/usr/bin/env bash
# SessionStart hook: tells Claude whether this machine keeps Obsidian plan notes.
#
# Plan notes are OFF unless PLAN_NOTES names an existing directory (the vault root).
# Set it per-machine in ~/.claude/settings.json, which is not tracked by any repo:
#   { "env": { "PLAN_NOTES": "/path/to/vault" } }
#
# Kept jq-free and bash 3.2 safe so it runs on a stock macOS shell.

set -u

# emit <additionalContext> [systemMessage]
emit() {
  ctx=$1
  msg=${2-}
  ctx=${ctx//\\/\\\\}
  ctx=${ctx//\"/\\\"}
  if [ -n "$msg" ]; then
    msg=${msg//\\/\\\\}
    msg=${msg//\"/\\\"}
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"},"systemMessage":"%s","suppressOutput":true}\n' "$ctx" "$msg"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"},"suppressOutput":true}\n' "$ctx"
  fi
}

vault=${PLAN_NOTES-}

if [ -z "$vault" ]; then
  emit "Obsidian plan notes are OFF on this machine: PLAN_NOTES is unset. Do not create or update plan notes, and do not offer to."
  exit 0
fi

if [ ! -d "$vault" ]; then
  emit "Obsidian plan notes are OFF on this machine: PLAN_NOTES is set to '$vault', which is not an existing directory. Do not create or update plan notes. Report the misconfiguration if plan notes come up." \
       "PLAN_NOTES points to $vault, which does not exist. Plan notes are disabled until that is fixed."
  exit 0
fi

emit "Obsidian plan notes are ON for this machine. Vault root: $vault. Plan notes live at $vault/Projects/<TICKET>/Plan.md. Follow the obsidian-plan skill for the conventions."
