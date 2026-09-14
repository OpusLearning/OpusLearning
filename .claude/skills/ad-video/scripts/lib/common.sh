#!/usr/bin/env bash
# Shared helpers for the ad-video skill scripts.
# Loads credentials from the environment, or from a credentials file that
# lives outside the repository so keys are never committed.

set -euo pipefail

ADV_ENV_FILE="${ADV_ENV_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/ad-video/env}"

adv_load_env() {
  if [ -f "$ADV_ENV_FILE" ]; then
    # shellcheck disable=SC1090
    set -a; . "$ADV_ENV_FILE"; set +a
  fi
}

adv_need() {
  local var="$1" hint="${2:-}"
  if [ -z "${!var:-}" ]; then
    echo "Missing $var." >&2
    [ -n "$hint" ] && echo "  $hint" >&2
    echo "  Set it in $ADV_ENV_FILE or export it, then re-run." >&2
    return 1
  fi
}

adv_require() {
  command -v "$1" >/dev/null 2>&1 || { echo "$1 is required but not installed." >&2; exit 1; }
}

# Print an API error body without leaking the request headers.
adv_fail() {
  echo "$1" >&2
  [ -n "${2:-}" ] && echo "Response: $2" >&2
  exit 1
}

adv_require curl
adv_require jq
adv_load_env
