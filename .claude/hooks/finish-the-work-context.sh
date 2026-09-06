#!/usr/bin/env bash
# Injects the finish-the-work skill into Claude's context.
#
# Registered for SessionStart and PostCompact so the skill is present at the
# start of every session and restored after context compaction. Registered
# for UserPromptSubmit with --brief so every turn carries a one-line reminder
# to run the quiet check. Reads hook JSON on stdin (ignored) and prints hook
# JSON on stdout. Exits 0 on every path so a missing file never blocks a turn.
#
# Layout assumption: this script lives in <root>/.claude/hooks/ (project) or
# <root>/hooks/ (user, ~/.claude) and the skill lives in
# <sibling>/skills/finish-the-work/SKILL.md. Both layouts resolve the same way.

set -u
cat >/dev/null 2>&1 || true

event="${1:-SessionStart}"
mode="${2:-full}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill="$here/../skills/finish-the-work/SKILL.md"

if [ ! -f "$skill" ] || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

if [ "$mode" = "--brief" ]; then
  context="finish-the-work is active. Run the quiet check: intended outcome, what counts as finished, next useful action, who controls it. Answer the actual request; reflect a stall only with evidence; close the loop on substantial action tasks."
else
  body="$(sed '1,/^---$/{/^---$/!d;};1d' "$skill" | sed '1{/^---$/d;}')"
  context="The finish-the-work skill applies to this whole session. Follow it in every reply without being asked. Full text:

$body"
fi

jq -cn --arg ev "$event" --arg ctx "$context" \
  '{hookSpecificOutput:{hookEventName:$ev, additionalContext:$ctx}}'
