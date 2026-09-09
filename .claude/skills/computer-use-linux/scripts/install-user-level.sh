#!/usr/bin/env bash
# Installs the computer-use-linux skill at user level so it is available in
# every Claude Code session on this machine, then optionally installs and
# registers the MCP server itself.
#
# Usage:
#   install-user-level.sh              copy skill, then run scripts/install.sh
#   install-user-level.sh --skill-only copy skill only
#
# Copies this skill directory to ~/.claude/skills/computer-use-linux
# (or $CLAUDE_CONFIG_DIR/skills). Safe to re-run; it overwrites the copy.

set -euo pipefail

skill_only=0
[ "${1:-}" = "--skill-only" ] && skill_only=1

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_src="$(cd "$here/.." && pwd)"
claude_home="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
skill_dst="$claude_home/skills/computer-use-linux"

mkdir -p "$claude_home/skills"
rm -rf "$skill_dst"
cp -R "$skill_src" "$skill_dst"
chmod +x "$skill_dst"/scripts/*.sh

echo "Installed skill to $skill_dst"

if [ "$skill_only" = 1 ]; then
  echo "Run $skill_dst/scripts/install.sh to install and register the MCP server."
  exit 0
fi

"$skill_dst/scripts/install.sh"
