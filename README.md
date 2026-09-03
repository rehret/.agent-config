# agent-config

Config, skills and prompts for the coding agents I use. Agent-agnostic at the top level; anything
specific to one agent nests under a folder named for it.

```
claude/
  CLAUDE.md               symlinked to ~/.claude/CLAUDE.md
  skills/                 symlinked into ~/.claude/skills/
  plan-notes-policy.sh    SessionStart hook, wired up in ~/.claude/settings.json
  plan-notes-policy.ps1   the same hook for machines with no bash
```

## Setup on a new machine

Link the config into `~/.claude`. Claude Code follows symlinks, so everything stays editable in
place here and is picked up from `~/.claude`.

macOS and Linux:

```sh
ln -s ~/.agent-config/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -s ~/.agent-config/claude/skills/tars ~/.claude/skills/tars
ln -s ~/.agent-config/claude/skills/bishop ~/.claude/skills/bishop
ln -s ~/.agent-config/claude/skills/obsidian-plan ~/.claude/skills/obsidian-plan
```

Windows, in a shell with Developer Mode on or running elevated:

```powershell
New-Item -ItemType SymbolicLink -Path $HOME\.claude\CLAUDE.md -Target $HOME\.agent-config\claude\CLAUDE.md
New-Item -ItemType SymbolicLink -Path $HOME\.claude\skills\tars -Target $HOME\.agent-config\claude\skills\tars
New-Item -ItemType SymbolicLink -Path $HOME\.claude\skills\bishop -Target $HOME\.agent-config\claude\skills\bishop
New-Item -ItemType SymbolicLink -Path $HOME\.claude\skills\obsidian-plan -Target $HOME\.agent-config\claude\skills\obsidian-plan
```

### Enabling plan notes

Plan notes are off until a machine opts in, so a new machine needs nothing here unless you want
them. To turn them on, set the vault root and the `SessionStart` hook in `~/.claude/settings.json`.
That file is not tracked here, which is what keeps the choice per-machine. Merge these keys into
whatever it already contains.

macOS and Linux:

```json
{
  "env": { "PLAN_NOTES": "/path/to/vault" },
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "bash ~/.agent-config/claude/plan-notes-policy.sh" } ] }
    ]
  }
}
```

Windows, using the PowerShell twin. The two scripts emit identical JSON, so nothing else differs:

```json
{
  "env": { "PLAN_NOTES": "C:\\Users\\me\\Notes" },
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "shell": "powershell", "command": "& \"$HOME/.agent-config/claude/plan-notes-policy.ps1\"" } ] }
    ]
  }
}
```

There is no platform matcher for hooks and none is needed: `~/.claude/settings.json` is already
per-machine, so each machine names the script it can run and neither script knows the other exists.

If the hook does not fire on Windows, the likely cause is shell selection, since Claude Code routes
a `command` through Git Bash when present and PowerShell otherwise. Skip the shell entirely with the
`args` form, which spawns the interpreter directly with no shell and no path expansion. It needs an
absolute path, which is no burden in a per-machine file:

```json
{
  "type": "command",
  "command": "pwsh",
  "args": ["-NoProfile", "-File", "C:\\Users\\me\\.agent-config\\claude\\plan-notes-policy.ps1"]
}
```

## CLAUDE.md

`claude/CLAUDE.md` holds my global instructions for every project: tone, scripting and
documentation preferences, commit-trailer and Artifact rules, and how the per-project Obsidian plan
note is triggered. The conventions live in the `obsidian-plan` skill.

Plan notes are opt-in per machine and off by default. `PLAN_NOTES` names the Obsidian vault root;
without it nothing is written and nothing is offered. `plan-notes-policy.sh` runs on `SessionStart`
and tells Claude which way this machine is set, so the policy arrives on its own rather than
depending on Claude to go looking for it.

## Skills

| Skill | What it does |
|---|---|
| `claude/skills/tars` | Pairing mode. I write the code; Claude scopes it into task cards, verifies each one, argues on merit, and owns the docs. Invoked as `/tars`. |
| `claude/skills/bishop` | Pairing mode, inverted. Claude writes the code in small reviewed batches, one logical change at a time, naming the judgment call it made and stopping for my check before the next. Invoked as `/bishop`. |
| `claude/skills/obsidian-plan` | Conventions for the per-project plan note in my Obsidian vault. Off unless `PLAN_NOTES` is set. |
