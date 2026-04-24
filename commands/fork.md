---
description: Fork the current Claude session into a new tmux pane with a handoff brief. Works with or without a git repo.
---

# /fork — Fork Claude Session

Fork this session at the current point: generate a handoff brief, and open a new tmux
pane with Claude pre-briefed. In git repos, creates a new branch + worktree. Outside git,
creates a notes directory under `~/.claude/forks/` and reuses the current working directory.

> **AUTOMATIC EXECUTION**: Run every step below without asking the user any questions.
> Derive the handoff brief entirely from this conversation. If no explicit fork directive was
> given, the fork continues the current task. Default split is vertical. Never pause for input.

## Arguments
`$ARGUMENTS` may optionally begin with:
- `v` — vertical split (side by side) **← default**
- `h` — horizontal split (top / bottom)

---

## Step 1 — Validate Environment

```bash
set -euo pipefail

if [ -z "${TMUX:-}" ]; then
  echo "ERROR: Not inside a tmux session. Start tmux first, then re-run /fork."
  exit 1
fi

echo "OK: tmux detected"
```

---

## Step 2 — Detect Mode and Compute Paths

Run the following. It determines whether to use git-worktree mode or simple mode, creates
the necessary directories, and outputs all path variables you will use in later steps.

```bash
set -euo pipefail

TS=$(date +%Y%m%d-%H%M%S)
CURRENT_DIR=$(pwd)

if git rev-parse --git-dir > /dev/null 2>&1; then
  # --- GIT MODE ---
  CURRENT_BRANCH=$(git branch --show-current)

  if [[ "$CURRENT_BRANCH" == fork/* ]]; then
    echo "ERROR: Already in a forked session (branch: $CURRENT_BRANCH)."
    echo "Only the main session can fork. Use /merge-fork to finish this fork first."
    exit 1
  fi

  SLUG=$(echo "$CURRENT_BRANCH" | sed 's|/|-|g; s|[^a-zA-Z0-9-]||g' | cut -c1-20)
  FORK_ID="${TS}-${SLUG}"
  FORK_BRANCH="fork/${FORK_ID}"
  REPO_ROOT=$(git rev-parse --show-toplevel)
  FORK_NOTES_DIR="${REPO_ROOT}/.claude/worktrees/${FORK_ID}"
  NEW_PANE_DIR="${FORK_NOTES_DIR}"
  MODE="git"

  mkdir -p "${REPO_ROOT}/.claude/worktrees"
  git worktree add "$FORK_NOTES_DIR" -b "$FORK_BRANCH"

  GITIGNORE="${REPO_ROOT}/.gitignore"
  if ! grep -qF ".claude/worktrees/" "$GITIGNORE" 2>/dev/null; then
    printf '\n# Claude Code fork worktrees\n.claude/worktrees/\n' >> "$GITIGNORE"
  fi

  echo "MODE=git"
  echo "FORK_BRANCH=${FORK_BRANCH}"
  echo "CURRENT_BRANCH=${CURRENT_BRANCH}"
else
  # --- SIMPLE MODE ---
  SLUG=$(basename "$CURRENT_DIR" | sed 's|[^a-zA-Z0-9-]||g' | cut -c1-20)
  FORK_ID="${TS}-${SLUG}"
  FORK_NOTES_DIR="${HOME}/.claude/forks/${FORK_ID}"
  NEW_PANE_DIR="${CURRENT_DIR}"
  MODE="simple"

  mkdir -p "$FORK_NOTES_DIR"

  echo "MODE=simple"
fi

echo "FORK_ID=${FORK_ID}"
echo "FORK_NOTES_DIR=${FORK_NOTES_DIR}"
echo "NEW_PANE_DIR=${NEW_PANE_DIR}"
echo "CURRENT_DIR=${CURRENT_DIR}"
```

Note every output value — you will use them in steps 3–5.

---

## Step 3 — Generate and Write Handoff Brief

Based on this conversation, write the handoff brief to
`{FORK_NOTES_DIR}/FORK_HANDOFF.md` (use the actual value from step 2).

The file must contain:

```markdown
# Fork Handoff Brief — {FORK_ID}

**Mode**: {git (branch: FORK_BRANCH) | simple (directory: FORK_NOTES_DIR)}
**Working directory**: {NEW_PANE_DIR}
**Forked at**: {TIMESTAMP}

## Objective
{Clear statement of the specific problem or task being worked on right now}

## Progress So Far
{What has been tried, what decisions were made, what is currently in progress}

## Key Files
{List the most relevant file paths and what matters about each}

## Fork Directive
{If a specific alternative approach was requested in the conversation, state it clearly as:
"Your goal is to explore [X approach] instead of [current approach], because [reason]."
Otherwise use: "Your goal is to continue the current task from where the main session left
off. Explore any pending sub-tasks, next steps, or alternative approaches to the objective."}

## Shared Scratchpad
Document your findings in `{FORK_NOTES_DIR}/FORK_NOTES.md`.
When done, write your recommendation in the `## Recommendation` section.
```

Use the **Write** tool to write this file.

---

## Step 4 — Write FORK_NOTES.md

Write `{FORK_NOTES_DIR}/FORK_NOTES.md` using the **Write** tool
(fill in actual values from step 2 and a one-paragraph summary from step 3):

```markdown
# Fork Notes — {FORK_ID}

**Mode**: {MODE}
**Working directory**: {NEW_PANE_DIR}
**Notes directory**: {FORK_NOTES_DIR}
**Forked at**: {TIMESTAMP}

## Context Summary
{One paragraph summarizing what this fork inherited from the parent session}

## Findings
_Document key findings here as you work_

## Recommendation
_Summarize your recommended approach when done — the parent session will read this_
```

---

## Step 5 — Split Tmux Pane and Launch Fork

Parse the split direction from `$ARGUMENTS`:
- Starts with `h` → tmux flag `-v` (horizontal: new pane above/below)
- Anything else (default) → tmux flag `-h` (vertical: new pane side by side)

Run the following bash command, substituting the **actual literal values** of
`FORK_NOTES_DIR`, `NEW_PANE_DIR`, and `FORK_ID` from step 2's output:

```bash
SPLIT="-h"
ARGS="${ARGUMENTS:-}"
[[ "$ARGS" == h* ]] && SPLIT="-v"

FORK_NOTES_DIR="{FORK_NOTES_DIR}"   # replace with actual value
NEW_PANE_DIR="{NEW_PANE_DIR}"       # replace with actual value
FORK_ID="{FORK_ID}"                 # replace with actual value

tmux split-window $SPLIT -c "$NEW_PANE_DIR" \
  "claude --append-system-prompt-file '${FORK_NOTES_DIR}/FORK_HANDOFF.md' \
  -n 'fork:${FORK_ID}' \
  'You are in a forked Claude session. Read your FORK_HANDOFF.md, then introduce yourself: state the task you inherited and the specific alternative approach you will explore.'"
```

---

## Step 6 — Report

Tell the user:

```
Forked  →  fork ID: {FORK_ID}
Notes:     {FORK_NOTES_DIR}/FORK_NOTES.md
Pane dir:  {NEW_PANE_DIR}

The fork pane is open — Claude is starting with your handoff brief.
Write findings to FORK_NOTES.md in the fork pane.
Run /merge-fork when ready to review and clean up.
```
