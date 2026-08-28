# agent-config

Config, skills and prompts for the coding agents I use. Agent-agnostic at the top level; anything
specific to one agent nests under a folder named for it.

```
claude/
  skills/       symlinked into ~/.claude/skills/
```

## Setup on a new machine

```sh
ln -s ~/.agent-config/claude/skills/tars ~/.claude/skills/tars
```

Claude Code follows symlinks, so the skill is editable in place here and picked up from `~/.claude`.

## Skills

| Skill | What it does |
|---|---|
| `claude/skills/tars` | Pairing mode. I write the code; Claude scopes it into task cards, verifies each one, argues on merit, and owns the docs. Invoked as `/tars`. |
