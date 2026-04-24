#!/usr/bin/env bash
# install.sh — copy fork-skill commands into your Claude Code user commands directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="${HOME}/.claude/commands"

mkdir -p "$COMMANDS_DIR"

cp "$SCRIPT_DIR/commands/fork.md" "$COMMANDS_DIR/fork.md"
cp "$SCRIPT_DIR/commands/merge-fork.md" "$COMMANDS_DIR/merge-fork.md"

echo "Installed:"
echo "  ${COMMANDS_DIR}/fork.md"
echo "  ${COMMANDS_DIR}/merge-fork.md"
echo ""
echo "Next steps:"
echo "  1. Add tmux bindings — see examples/tmux.conf.snippet"
echo "  2. Add permissions   — see examples/settings-snippet.json"
echo "     Merge into: ~/.claude/settings.json"
echo ""
echo "Done. Run /fork inside a tmux + Claude session to test."
