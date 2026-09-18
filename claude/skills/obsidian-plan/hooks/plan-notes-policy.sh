#!/usr/bin/env bash
# SessionStart hook: tells Claude whether this machine keeps plan notes.
#
# Plan notes are OFF unless OBSIDIAN_PLAN_VAULT names an existing directory: the Obsidian vault
# holding the plan notes.
# OBSIDIAN_PLAN_DIR optionally names the folder the note folders live in, relative to the vault.
# It defaults to "Projects"; use "." to put them at the vault root itself.
# Set them per-machine in ~/.claude/settings.json, which is not tracked by any repo:
#   { "env": { "OBSIDIAN_PLAN_VAULT": "/path/to/vault", "OBSIDIAN_PLAN_DIR": "Projects" } }
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

root=${OBSIDIAN_PLAN_VAULT-}
dir=${OBSIDIAN_PLAN_DIR-Projects}

if [ -z "$root" ]; then
  emit "Plan notes are OFF on this machine: OBSIDIAN_PLAN_VAULT is unset. Do not create or update plan notes, and do not offer to."
  exit 0
fi

if [ ! -d "$root" ]; then
  emit "Plan notes are OFF on this machine: OBSIDIAN_PLAN_VAULT is set to '$root', which is not an existing directory. Do not create or update plan notes. Report the misconfiguration if plan notes come up." \
       "OBSIDIAN_PLAN_VAULT points to $root, which does not exist. Plan notes are disabled until that is fixed."
  exit 0
fi

# OBSIDIAN_PLAN_DIR is relative to the vault root; it may not be absolute or climb out of it.
case $dir in
  /*|*..*)
    emit "Plan notes are OFF on this machine: OBSIDIAN_PLAN_DIR is set to '$dir', which is not a path inside the vault. Do not create or update plan notes. Report the misconfiguration if plan notes come up." \
         "OBSIDIAN_PLAN_DIR is '$dir', which must be a relative path inside OBSIDIAN_PLAN_VAULT. Plan notes are disabled until that is fixed."
    exit 0
    ;;
esac

while [ "${dir%/}" != "$dir" ]; do dir=${dir%/}; done

if [ -z "$dir" ] || [ "$dir" = "." ]; then
  notes=$root
else
  notes="$root/$dir"
fi

if [ -d "$notes" ]; then
  state="It already exists."
else
  state="It does not exist yet; create it when the first note is written."
fi

emit "Plan notes are ON for this machine. Vault root: $root. Plan notes live under $notes ($notes/<TICKET>/Plan.md, or $notes/<Project>/Plan.md when work spans several tickets). $state Follow the obsidian-plan skill for the conventions."
