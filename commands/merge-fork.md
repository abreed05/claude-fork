---
description: Review a forked Claude session's findings, optionally merge its branch (git forks), and remove the fork
---

# /merge-fork — Merge or Close a Forked Session

Review a fork's findings, optionally merge its git branch into the current branch (git
forks only), and clean up. Works with both git-worktree forks and simple (non-git) forks.

## Arguments
`$ARGUMENTS` may optionally contain a fork ID to skip the selection step.

---

## Step 1 — Find All Active Forks

Run:

```bash
set -euo pipefail

FORKS=()
FORK_SOURCES=()

# Git worktree forks (if in a git repo)
if git rev-parse --git-dir > /dev/null 2>&1; then
  REPO_ROOT=$(git rev-parse --show-toplevel)
  WORKTREES_DIR="${REPO_ROOT}/.claude/worktrees"
  if [ -d "$WORKTREES_DIR" ]; then
    for dir in "$WORKTREES_DIR"/*/; do
      [ -d "$dir" ] && FORKS+=("$(basename "$dir")") && FORK_SOURCES+=("git:$dir")
    done
  fi
fi

# Simple (non-git) forks
SIMPLE_DIR="${HOME}/.claude/forks"
if [ -d "$SIMPLE_DIR" ]; then
  for dir in "$SIMPLE_DIR"/*/; do
    [ -d "$dir" ] && FORKS+=("$(basename "$dir")") && FORK_SOURCES+=("simple:$dir")
  done
fi

if [ ${#FORKS[@]} -eq 0 ]; then
  echo "NO_FORKS: No active forks found."
  exit 0
fi

echo "Found ${#FORKS[@]} fork(s):"
for i in "${!FORKS[@]}"; do
  SRC="${FORK_SOURCES[$i]}"
  TYPE="${SRC%%:*}"
  DIR="${SRC#*:}"
  MODIFIED=""
  if [ "$TYPE" = "git" ]; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null || echo "unknown")
    MODIFIED="branch=$BRANCH"
  else
    MODIFIED="simple"
  fi
  echo "  [$((i+1))] ${FORKS[$i]}  ($MODIFIED)"
done
```

If `NO_FORKS` is output, inform the user and stop.

---

## Step 2 — Select Fork

If `$ARGUMENTS` contains a fork ID, match it against the list.
If only one fork exists, auto-select it.
If multiple forks exist and no argument was given, ask the user:
> "Which fork? (Reply with number or fork ID)"

Once selected, run:

```bash
set -euo pipefail

FORK_ID="{selected fork ID}"    # replace with actual value

# Determine type and paths
WORKTREE_CANDIDATE="${HOME}/$(git rev-parse --show-toplevel 2>/dev/null | sed "s|$HOME/||")/.claude/worktrees/${FORK_ID}"
SIMPLE_CANDIDATE="${HOME}/.claude/forks/${FORK_ID}"

if [ -d "$WORKTREE_CANDIDATE" ] && git -C "$WORKTREE_CANDIDATE" rev-parse --git-dir > /dev/null 2>&1; then
  FORK_TYPE="git"
  FORK_DIR="$WORKTREE_CANDIDATE"
  FORK_BRANCH="fork/${FORK_ID}"
  echo "TYPE=git"
  echo "FORK_DIR=${FORK_DIR}"
  echo "FORK_BRANCH=${FORK_BRANCH}"
elif [ -d "$SIMPLE_CANDIDATE" ]; then
  FORK_TYPE="simple"
  FORK_DIR="$SIMPLE_CANDIDATE"
  echo "TYPE=simple"
  echo "FORK_DIR=${FORK_DIR}"
else
  # Fallback: search both locations
  if git rev-parse --git-dir > /dev/null 2>&1; then
    REPO_ROOT=$(git rev-parse --show-toplevel)
    FORK_DIR="${REPO_ROOT}/.claude/worktrees/${FORK_ID}"
    FORK_BRANCH="fork/${FORK_ID}"
    echo "TYPE=git"
  else
    FORK_DIR="${HOME}/.claude/forks/${FORK_ID}"
    echo "TYPE=simple"
  fi
  echo "FORK_DIR=${FORK_DIR}"
fi

echo "FORK_ID=${FORK_ID}"
```

Note `TYPE`, `FORK_DIR`, `FORK_BRANCH` (git only), and `FORK_ID` from the output.

---

## Step 3 — Show Findings

Read and display the contents of `{FORK_DIR}/FORK_NOTES.md` to the user.

For **git forks**, also run:

```bash
FORK_BRANCH="{FORK_BRANCH}"    # replace with actual value

echo "=== Changes in fork branch ==="
git diff HEAD..."${FORK_BRANCH}" --stat 2>/dev/null || echo "(no diff)"

echo ""
echo "=== Commits in fork ==="
git log HEAD.."${FORK_BRANCH}" --oneline 2>/dev/null || echo "(no commits)"
```

---

## Step 4 — Ask What to Do

For a **git fork**, present:

```
What would you like to do?

  [1] Merge branch into current branch
  [2] Cherry-pick specific commits
  [3] Keep fork active (just read findings, do nothing)
  [4] Discard — remove worktree and branch
```

For a **simple fork**, present:

```
What would you like to do?

  [1] Keep fork active (findings noted, do nothing)
  [2] Remove fork directory (clean up)
```

Wait for the user's choice before continuing.

---

## Step 5 — Execute Choice

### Git fork — option 1 (merge):

```bash
FORK_BRANCH="{FORK_BRANCH}"
git merge "$FORK_BRANCH" --no-ff -m "Merge fork: $FORK_BRANCH"
```
Proceed to cleanup (step 6).

### Git fork — option 2 (cherry-pick):

```bash
FORK_BRANCH="{FORK_BRANCH}"
git log HEAD.."$FORK_BRANCH" --oneline --reverse
```
Show the list to the user and ask which commits to pick. Then:
```bash
git cherry-pick {chosen-hashes}
```
Proceed to cleanup (step 6).

### Git fork — option 3 (keep):
Inform the user the fork is still active. Stop here — skip step 6.

### Git fork — option 4 (discard):
Confirm: "This will delete the worktree and branch permanently. Sure? (yes/no)"
Wait for yes before proceeding to step 6.

### Simple fork — option 1 (keep):
Inform the user the fork directory remains at `{FORK_DIR}`. Stop here — skip step 6.

### Simple fork — option 2 (remove):
Proceed to step 6.

---

## Step 6 — Cleanup

### For a git fork:

```bash
FORK_DIR="{FORK_DIR}"
FORK_BRANCH="{FORK_BRANCH}"

git worktree remove "$FORK_DIR" --force
git branch -d "$FORK_BRANCH" 2>/dev/null || git branch -D "$FORK_BRANCH"
echo "Removed: $FORK_BRANCH"
```

### For a simple fork:

```bash
FORK_DIR="{FORK_DIR}"
rm -rf "$FORK_DIR"
echo "Removed: $FORK_DIR"
```

---

## Step 7 — Report

Tell the user:
- Which fork was processed
- Whether changes were merged / cherry-picked / discarded / kept
- Whether the fork directory/branch was removed
