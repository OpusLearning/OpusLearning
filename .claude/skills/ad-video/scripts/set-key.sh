#!/usr/bin/env bash
# set-key.sh - store a credential without it touching the command line.
#
# Usage:
#   printf %s "the-secret" | scripts/set-key.sh KIE_API_KEY
#   scripts/set-key.sh ZERNIO_API_KEY      # then paste and press ctrl-d
#
# Reads the value from stdin, never from an argument, so it stays out of
# shell history and out of the process list. Writes it into the credentials
# file with permissions 600, preserving any other values already there.
# The value is never echoed, not even partially.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$here/lib/common.sh"

name="${1:-KIE_API_KEY}"
case "$name" in
  KIE_API_KEY|ZERNIO_API_KEY|ZERNIO_PROFILE_ID) ;;
  *) adv_fail "Unknown credential: $name. Use KIE_API_KEY, ZERNIO_API_KEY or ZERNIO_PROFILE_ID." ;;
esac

if [ -t 0 ]; then
  printf 'Paste the value for %s, then press enter and ctrl-d:\n' "$name" >&2
fi

# Take the first line only, and strip whitespace a paste tends to carry.
IFS= read -r value || true
value="${value#"${value%%[![:space:]]*}"}"
value="${value%"${value##*[![:space:]]}"}"

[ -n "$value" ] || adv_fail "Nothing on stdin. $name was not changed."
case "$value" in
  *[[:space:]]*) adv_fail "That value contains a space, so it is probably not a key. $name was not changed." ;;
esac

mkdir -p "$(dirname "$ADV_ENV_FILE")"
umask 077
tmp="$(mktemp "${ADV_ENV_FILE}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if [ -f "$ADV_ENV_FILE" ]; then
  grep -v "^${name}=" "$ADV_ENV_FILE" > "$tmp" || true
else
  printf '# Credentials for the ad-video skill. Keep out of any repository.\n' > "$tmp"
fi

# Written with printf rather than echo so no shell expansion touches it.
printf '%s=%s\n' "$name" "$value" >> "$tmp"
chmod 600 "$tmp"
mv "$tmp" "$ADV_ENV_FILE"
trap - EXIT

printf '%s stored in %s (%d characters, permissions 600).\n' "$name" "$ADV_ENV_FILE" "${#value}" >&2
unset value

echo >&2
exec "$here/check-setup.sh"
