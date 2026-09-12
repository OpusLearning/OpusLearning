#!/usr/bin/env bash
# Packages gh-repo-reach as a .skill file for upload to a claude.ai profile,
# which syncs it to every Claude Code session on every machine, including
# cloud and web sessions where the user-level install does not persist.
#
# Writes dist/gh-repo-reach.skill in the repository root.

set -euo pipefail

command -v zip >/dev/null 2>&1 || { echo "zip is required" >&2; exit 1; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_src="$(cd "$here/.." && pwd)"
repo_root="$(cd "$skill_src/../../.." && pwd)"
dist="$repo_root/dist"
out="$dist/gh-repo-reach.skill"

mkdir -p "$dist"
rm -f "$out"

( cd "$(dirname "$skill_src")" && zip -q -r "$out" "gh-repo-reach" -x '*/evals/*' '*.DS_Store' )

echo "Packaged $out"
echo "Upload it under Settings then Capabilities on claude.ai to sync it everywhere."
