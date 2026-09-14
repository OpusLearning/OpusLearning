#!/usr/bin/env bash
# setup-local.sh - store the Kie.ai key on this machine and prove it works.
# Nothing is echoed, nothing leaves this computer, nothing is sent anywhere
# except the one authentication check against Kie.ai itself.

set -u
file="${XDG_CONFIG_HOME:-$HOME/.config}/ad-video/env"
mkdir -p "$(dirname "$file")"

printf 'Paste your Kie.ai API key (it will not be shown), then press enter: ' >&2
stty -echo 2>/dev/null
IFS= read -r key
stty echo 2>/dev/null
printf '\n' >&2

# Strip whitespace a paste tends to carry.
key="$(printf %s "$key" | tr -d '[:space:]')"
if [ -z "$key" ]; then echo "Nothing entered. Nothing was changed." >&2; exit 1; fi

umask 077
if [ -f "$file" ]; then
  tmp="$(mktemp "${file}.XXXXXX")"
  grep -v '^KIE_API_KEY=' "$file" > "$tmp" 2>/dev/null || true
  printf 'KIE_API_KEY=%s\n' "$key" >> "$tmp"
  chmod 600 "$tmp"; mv "$tmp" "$file"
else
  printf '# Credentials for the ad-video skill. Do not commit this file.\n' > "$file"
  printf 'KIE_API_KEY=%s\n' "$key" >> "$file"
  chmod 600 "$file"
fi
printf 'Stored %d characters in %s (permissions 600).\n' "${#key}" "$file" >&2

body="$(curl -sS -G https://api.kie.ai/api/v1/jobs/recordInfo \
  -H "Authorization: Bearer $key" --data-urlencode 'taskId=setup-check' 2>/dev/null)"
unset key

case "$body" in
  *'"code":401'*|*'"code":403'*) echo "Key REJECTED. Check you copied all of it." >&2; exit 1 ;;
  *'"code":402'*) echo "Key is valid but the balance is empty. Top up at https://kie.ai/billing" >&2; exit 1 ;;
  '')             echo "Could not reach Kie.ai. Check your connection." >&2; exit 1 ;;
  *)              echo "Key works. You are ready to generate." >&2 ;;
esac
