#!/usr/bin/env bash
# zernio.sh - inspect connected social accounts and publish through Zernio.
#
# Usage:
#   zernio.sh accounts                       # list connected accounts for the profile
#   zernio.sh upload FILE                    # presign + PUT, prints the public URL
#   zernio.sh post --content TEXT
#                  [--media URL_OR_FILE[,...]]
#                  [--platform NAME:ACCOUNT_ID]...   (repeatable)
#                  [--all]                           (every active account)
#                  [--now | --at 'YYYY-MM-DDTHH:MM:SS' --tz Europe/London]
#                  [--dry-run]
#
# Default with neither --now nor --at is a draft in Zernio, which is the safe
# option: nothing is published until a human confirms.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$here/lib/common.sh"

ZERNIO_API_BASE="${ZERNIO_API_BASE:-https://zernio.com/api/v1}"
adv_need ZERNIO_API_KEY "Create one at https://zernio.com -> API keys (starts sk_)." || exit 1

auth=(-H "Authorization: Bearer $ZERNIO_API_KEY")
json=(-H "Content-Type: application/json")

zget()  { curl -sS -G "$ZERNIO_API_BASE$1" "${auth[@]}" "${@:2}" || adv_fail "GET $1 failed."; }
zpost() { curl -sS -X POST "$ZERNIO_API_BASE$1" "${auth[@]}" "${json[@]}" -d "$2" || adv_fail "POST $1 failed."; }

list_accounts() {
  local args=()
  [ -n "${ZERNIO_PROFILE_ID:-}" ] && args=(--data-urlencode "profileId=$ZERNIO_PROFILE_ID")
  zget /accounts "${args[@]}"
}

upload_file() {                     # $1 = local path -> prints publicUrl
  local file="$1" name type resp upload_url public_url
  [ -f "$file" ] || adv_fail "No such file: $file"
  name="$(basename "$file")"
  case "${name##*.}" in
    mp4) type=video/mp4 ;; mov) type=video/quicktime ;; webm) type=video/webm ;;
    m4v) type=video/x-m4v ;; jpg|jpeg) type=image/jpeg ;; png) type=image/png ;;
    gif) type=image/gif ;; webp) type=image/webp ;; pdf) type=application/pdf ;;
    *) adv_fail "Unsupported file type: $name" ;;
  esac
  resp="$(zpost /media/presign "$(jq -cn --arg f "$name" --arg c "$type" '{filename:$f, contentType:$c}')")"
  upload_url="$(jq -r '.uploadUrl // .data.uploadUrl // empty' <<<"$resp")"
  public_url="$(jq -r '.publicUrl // .data.publicUrl // empty' <<<"$resp")"
  [ -n "$upload_url" ] && [ -n "$public_url" ] || adv_fail "Presign did not return upload/public URLs." "$resp"
  curl -sS -X PUT "$upload_url" -H "Content-Type: $type" --upload-file "$file" >/dev/null \
    || adv_fail "Upload of $file failed."
  echo "$public_url"
}

media_type_for() { case "${1##*.}" in mp4|mov|webm|m4v|avi|mpeg) echo video ;; pdf) echo document ;; *) echo image ;; esac; }

cmd="${1:-}"; shift || true
content=""; media=""; at=""; tz=""; publish_now=0; dry_run=0; all_accounts=0
declare -a platforms=()

while [ $# -gt 0 ]; do
  case "$1" in
    --content)  content="$2"; shift 2 ;;
    --media)    media="$2"; shift 2 ;;
    --platform) platforms+=("$2"); shift 2 ;;
    --all)      all_accounts=1; shift ;;
    --now)      publish_now=1; shift ;;
    --at)       at="$2"; shift 2 ;;
    --tz)       tz="$2"; shift 2 ;;
    --dry-run)  dry_run=1; shift ;;
    -h|--help)  sed -n '2,17p' "$0"; exit 0 ;;
    *)          [ -z "${positional:-}" ] && positional="$1"; shift ;;
  esac
done

case "$cmd" in
  accounts)
    list_accounts | jq '[ (.accounts // .data // .) | .[] | {accountId:(._id // .accountId), platform, username, active} ]'
    exit 0 ;;
  upload)
    [ -n "${positional:-}" ] || adv_fail "upload needs a FILE"
    upload_file "$positional"
    exit 0 ;;
  post) ;;
  ""|-h|--help) sed -n '2,17p' "$0"; exit 0 ;;
  *) adv_fail "Unknown command: $cmd" ;;
esac

[ -n "$content" ] || adv_fail "post needs --content TEXT"

# Media: local paths are uploaded first, https URLs are used as-is.
media_json='[]'
if [ -n "$media" ]; then
  IFS=',' read -ra items <<<"$media"
  for item in "${items[@]}"; do
    [ -n "$item" ] || continue
    case "$item" in
      https://*) url="$item" ;;
      http://*)  adv_fail "Media must be served over HTTPS: $item" ;;
      *)         echo "uploading $item" >&2; url="$(upload_file "$item")" ;;
    esac
    media_json="$(jq -c --arg u "$url" --arg t "$(media_type_for "$item")" '. + [{url:$u, type:$t}]' <<<"$media_json")"
  done
fi

# Platforms: explicit name:accountId pairs, or every active connected account.
platform_json='[]'
if [ "$all_accounts" -eq 1 ]; then
  platform_json="$(list_accounts | jq -c '[ (.accounts // .data // .) | .[] | select((.active // true) == true) | {platform, accountId:(._id // .accountId)} ]')"
else
  for p in "${platforms[@]:-}"; do
    [ -n "$p" ] || continue
    case "$p" in *:*) ;; *) adv_fail "--platform expects NAME:ACCOUNT_ID, got: $p" ;; esac
    platform_json="$(jq -c --arg n "${p%%:*}" --arg a "${p#*:}" '. + [{platform:$n, accountId:$a}]' <<<"$platform_json")"
  done
fi
[ "$(jq 'length' <<<"$platform_json")" -gt 0 ] \
  || adv_fail "No target accounts. Run 'zernio.sh accounts' and pass --platform NAME:ACCOUNT_ID, or --all."

body="$(jq -cn --arg c "$content" --argjson m "$media_json" --argjson p "$platform_json" \
  '{content:$c, platforms:$p} + (if ($m|length)>0 then {mediaItems:$m} else {} end)')"
if [ "$publish_now" -eq 1 ]; then
  body="$(jq -c '.publishNow=true' <<<"$body")"
elif [ -n "$at" ]; then
  [ -n "$tz" ] || adv_fail "--at also needs --tz, e.g. --tz Europe/London"
  body="$(jq -c --arg a "$at" --arg z "$tz" '.scheduledFor=$a | .timezone=$z' <<<"$body")"
fi

if [ "$dry_run" -eq 1 ]; then
  echo "DRY RUN - this request was not sent:" >&2
  jq . <<<"$body"
  exit 0
fi

zpost /posts "$body" | jq .
