# fork-skill

Two Claude Code slash commands that let you fork the current session into a side-by-side
tmux pane, work in parallel, then merge or discard the fork when you're done.

- `/fork` — snapshot the conversation, spin up a new Claude pane with a handoff brief
- `/merge-fork` — read the fork's findings, optionally merge its branch, clean up

Works in **git repos** (creates a worktree + branch) and **outside git** (creates a notes
directory under `~/.claude/forks/`).

---

## Requirements

- [Claude Code](https://claude.ai/code) CLI installed and authenticated
- [tmux](https://github.com/tmux/tmux) — must be running inside a tmux session when you invoke `/fork`

---

## Installation

### 1. Copy the commands

```bash
./install.sh
```

Or manually:

```bash
mkdir -p ~/.claude/commands
cp commands/fork.md       ~/.claude/commands/fork.md
cp commands/merge-fork.md ~/.claude/commands/merge-fork.md
```

Claude Code loads all `.md` files from `~/.claude/commands/` as user-level slash commands.
No restart required — the commands are available immediately in any new session.

### 2. Add tmux keybindings

Open `~/.tmux.conf` and add the block from `examples/tmux.conf.snippet`:

```tmux
# Ctrl+a f  →  /fork     (vertical split)
# Ctrl+a F  →  /fork h   (horizontal split)
# Ctrl+a M  →  /merge-fork
bind-key f send-keys '/fork' Enter
bind-key F send-keys '/fork h' Enter
bind-key M send-keys '/merge-fork' Enter
```

Then reload tmux config:

```bash
tmux source-file ~/.tmux.conf
# or press:  <prefix> r   (if you have a reload binding)
```

> **Prefix note**: the snippet uses `bind-key` which always binds under your prefix key.
> If your prefix is `Ctrl+b` (default), the shortcuts become `Ctrl+b f`, `Ctrl+b F`, `Ctrl+b M`.
> If your prefix is `Ctrl+a`, they become `Ctrl+a f`, `Ctrl+a F`, `Ctrl+a M`.

See `examples/tmux.conf.snippet` for an alternative chord-style binding if you prefer a submenu.

### 3. Add permissions to skip approval prompts

Without this step, Claude will pause and ask for tool approval at each step of the fork.

Merge the contents of `examples/settings-snippet.json` into `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(git worktree add*)",
      "Bash(git worktree remove*)",
      "Bash(mkdir -p ~/.claude/forks/*)",
      "Bash(mkdir -p */.claude/worktrees*)",
      "Bash(tmux split-window*)",
      "Bash(printf '\\n# Claude Code fork worktrees\\n.claude/worktrees/\\n' >> *)",
      "Write(*FORK_HANDOFF.md)",
      "Write(*FORK_NOTES.md)"
    ]
  }
}
```

If `~/.claude/settings.json` already exists, add the `permissions.allow` array into it —
don't replace the whole file.

---

## Usage

### Forking

Inside a tmux session with Claude running:

| Action | Keybind | Slash command |
|--------|---------|---------------|
| Fork (vertical split) | `Ctrl+a f` | `/fork` or `/fork v` |
| Fork (horizontal split) | `Ctrl+a F` | `/fork h` |

Claude will:
1. Detect whether you're in a git repo
2. Create a worktree + branch (`fork/<timestamp>-<branch>`) or a notes directory
3. Write a handoff brief summarizing the current task and context
4. Open a new tmux pane with a fresh Claude session pre-loaded with that brief

The fork pane opens immediately. The fork Claude introduces itself and states what it
will explore.

### Working in the fork

The forked Claude writes findings to `FORK_NOTES.md` in its notes directory. You can
work in the main pane and the fork pane simultaneously — they share no state.

### Merging / closing

Switch back to the main pane and run:

| Action | Keybind | Slash command |
|--------|---------|---------------|
| Merge / close fork | `Ctrl+a M` | `/merge-fork` |

`/merge-fork` will:
1. Find active forks
2. Show you `FORK_NOTES.md` from the fork
3. For git forks: show the diff and commit log, then offer merge / cherry-pick / discard
4. For simple forks: offer to keep or remove the notes directory

---

## How it works

### Git mode (inside a git repo)

```
main branch  ─────────────────────────────────────▶
                   │
              /fork │
                   ▼
         fork/<timestamp>-<branch>  (git worktree)
                   │
                   │  Claude works here independently
                   ▼
              /merge-fork
                   │  merge / cherry-pick / discard
                   ▼
main branch  ──────────────────────────────────────▶
```

Each fork gets its own git worktree — a separate working directory checked out from
the same repo. Changes in the fork don't affect the main branch until you merge.

### Simple mode (outside a git repo)

A timestamped notes directory is created at `~/.claude/forks/<id>/`. The fork Claude
writes `FORK_NOTES.md` there. No git operations occur.

---

## File layout

```
~/.claude/forks/
└── <fork-id>/
    ├── FORK_HANDOFF.md   ← brief written by parent session at fork time
    └── FORK_NOTES.md     ← findings written by forked session

<repo-root>/.claude/worktrees/   ← git-mode forks (gitignored automatically)
└── <fork-id>/
    ├── FORK_HANDOFF.md
    └── FORK_NOTES.md
```

---

## Keybinding reference

| Key | Action |
|-----|--------|
| `<prefix> f` | `/fork` — vertical split (default) |
| `<prefix> F` | `/fork h` — horizontal split |
| `<prefix> M` | `/merge-fork` — review and close fork |

`<prefix>` is whatever your tmux prefix is (`Ctrl+a` or `Ctrl+b`).

---

## Troubleshooting

**"ERROR: Not inside a tmux session"**
Start tmux first (`tmux` or `tmux new-session`), then open Claude inside it.

**The keybind sends `/fork` to the wrong pane**
`send-keys` targets the active pane. Make sure the Claude pane is focused before
pressing the shortcut.

**Permission prompts still appear**
Check that the `permissions.allow` block from step 3 is present in `~/.claude/settings.json`
and that the JSON is valid (`jq . ~/.claude/settings.json`).

**Fork pane closes immediately**
The `claude` CLI failed to start. Run `/fork` manually from the Claude prompt to see
the error output from step 1.
