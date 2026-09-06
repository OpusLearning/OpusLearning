#!/usr/bin/env bash
# Installs finish-the-work at user level so it applies in every Claude Code
# session on this machine, not only inside this repository.
#
# Copies the skill to ~/.claude/skills/finish-the-work, the hook script to
# ~/.claude/hooks, and merges SessionStart, PostCompact and UserPromptSubmit
# hooks into ~/.claude/settings.json. Existing settings are preserved and a
# timestamped backup is written first. Safe to re-run; duplicate hook entries
# are not added.

set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_src="$(cd "$here/.." && pwd)"
root="$(cd "$skill_src/../.." && pwd)"          # <repo>/.claude
hook_src="$root/hooks/finish-the-work-context.sh"

claude_home="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
skill_dst="$claude_home/skills/finish-the-work"
hook_dst="$claude_home/hooks/finish-the-work-context.sh"
settings="$claude_home/settings.json"

mkdir -p "$skill_dst" "$claude_home/hooks"
cp "$skill_src/SKILL.md" "$skill_dst/SKILL.md"
cp "$hook_src" "$hook_dst"
chmod +x "$hook_dst"

if [ -f "$settings" ]; then
  cp "$settings" "$settings.bak.$(date +%Y%m%d%H%M%S)"
  existing="$(cat "$settings")"
else
  existing='{}'
fi

hook_path="$hook_dst"
merged="$(jq -n --argjson s "$existing" --arg h "$hook_path" '
  def entry($args; $t): {hooks:[{type:"command", command:("\"" + $h + "\" " + $args), timeout:$t}]};
  def add($ev; $args; $t):
    .hooks[$ev] = ((.hooks[$ev] // [])
      | if any(.[]?.hooks[]?; .command | contains($h)) then . else . + [entry($args; $t)] end);
  $s
  | .hooks = (.hooks // {})
  | add("SessionStart"; "SessionStart"; 10)
  | add("PostCompact"; "PostCompact"; 10)
  | add("UserPromptSubmit"; "UserPromptSubmit --brief"; 5)
')"
printf '%s\n' "$merged" > "$settings"

echo "Installed skill to $skill_dst"
echo "Installed hook to  $hook_dst"
echo "Updated            $settings"
echo "Open /hooks once or restart Claude Code to load the new hooks."
