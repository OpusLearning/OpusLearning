#!/usr/bin/env bash
# Installs gh-repo-reach at user level so it is available in every Claude
# Code session on this machine, in every project, not only inside this
# repository.
#
# Copies the skill to ~/.claude/skills/gh-repo-reach. Unlike finish-the-work
# this skill is triggered by its description rather than always on, so no
# hooks and no settings.json changes are needed. Safe to re-run.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_src="$(cd "$here/.." && pwd)"

claude_home="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
skill_dst="$claude_home/skills/gh-repo-reach"

mkdir -p "$skill_dst"
cp "$skill_src/SKILL.md" "$skill_dst/SKILL.md"
mkdir -p "$skill_dst/scripts"
cp "$skill_src/scripts/install-user-level.sh" "$skill_dst/scripts/install-user-level.sh"
chmod +x "$skill_dst/scripts/install-user-level.sh"

echo "Installed skill to $skill_dst"
echo "It applies to all projects on this machine. Restart Claude Code to load it."
