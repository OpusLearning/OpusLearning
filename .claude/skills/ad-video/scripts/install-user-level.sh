#!/usr/bin/env bash
# Installs ad-video at user level so it is available in every Claude Code
# session on this machine, not only inside this repository.
# Safe to re-run. Credentials in ~/.config/ad-video/env are left untouched.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_src="$(cd "$here/.." && pwd)"
claude_home="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
skill_dst="$claude_home/skills/ad-video"

mkdir -p "$skill_dst"
cp -R "$skill_src/." "$skill_dst/"
chmod +x "$skill_dst"/scripts/*.sh "$skill_dst"/scripts/lib/*.sh

echo "Installed ad-video to $skill_dst"
"$skill_dst/scripts/check-setup.sh" || true
