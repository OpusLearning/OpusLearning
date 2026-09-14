#!/usr/bin/env bash
# check-setup.sh - verify credentials exist and actually work.
# Creates the credentials file as a template on first run. Never prints keys.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$here/lib/common.sh"

if [ ! -f "$ADV_ENV_FILE" ]; then
  mkdir -p "$(dirname "$ADV_ENV_FILE")"
  cat > "$ADV_ENV_FILE" <<'TEMPLATE'
# Credentials for the ad-video skill. Keep this file out of any repository.
# Kie.ai  -> https://kie.ai  (sign in, API Keys, create key, add credit)
KIE_API_KEY=
# Zernio  -> https://zernio.com  (API keys; key starts sk_)
ZERNIO_API_KEY=
# Zernio profile ID: open your profile in the Zernio dashboard, 24-char id
ZERNIO_PROFILE_ID=
TEMPLATE
  chmod 600 "$ADV_ENV_FILE"
  echo "Created template $ADV_ENV_FILE (permissions 600)."
  echo "Fill in the three values, then run this script again."
  exit 1
fi

status=0
mask() { local v="$1"; [ -n "$v" ] && echo "set (${#v} chars)" || echo "MISSING"; }

echo "Credentials file: $ADV_ENV_FILE"
echo "  KIE_API_KEY:       $(mask "${KIE_API_KEY:-}")"
echo "  ZERNIO_API_KEY:    $(mask "${ZERNIO_API_KEY:-}")"
echo "  ZERNIO_PROFILE_ID: $(mask "${ZERNIO_PROFILE_ID:-}")"
echo

if [ -n "${KIE_API_KEY:-}" ]; then
  # Kie.ai answers HTTP 200 and reports the real status in the body "code".
  body="$(curl -sS -G "${KIE_API_BASE:-https://api.kie.ai}/api/v1/jobs/recordInfo" \
    -H "Authorization: Bearer $KIE_API_KEY" --data-urlencode "taskId=setup-check" 2>/dev/null || echo '')"
  code="$(jq -r '.code // empty' <<<"$body" 2>/dev/null || true)"
  case "$code" in
    200|404|422) echo "Kie.ai: key accepted (code $code)" ;;
    401|403)     echo "Kie.ai: key REJECTED (code $code) - check the key"; status=1 ;;
    402)         echo "Kie.ai: key valid but out of credit (code 402) - top up before generating"; status=1 ;;
    "")          echo "Kie.ai: could not reach the API or got a non-JSON reply"; status=1 ;;
    *)           echo "Kie.ai: unexpected code $code - $(jq -r '.msg // ""' <<<"$body")"; status=1 ;;
  esac
else
  echo "Kie.ai: skipped, no key"; status=1
fi

if [ -n "${ZERNIO_API_KEY:-}" ]; then
  code="$(curl -sS -o /dev/null -w '%{http_code}' -G "${ZERNIO_API_BASE:-https://zernio.com/api/v1}/accounts" \
    -H "Authorization: Bearer $ZERNIO_API_KEY" || echo 000)"
  case "$code" in
    200)     echo "Zernio: key accepted, accounts endpoint reachable" ;;
    401|403) echo "Zernio: key REJECTED (HTTP $code)"; status=1 ;;
    404)     echo "Zernio: HTTP 404 - base URL may differ; try ZERNIO_API_BASE=https://zernio.com/api"; status=1 ;;
    000)     echo "Zernio: could not reach the API"; status=1 ;;
    *)       echo "Zernio: unexpected HTTP $code"; status=1 ;;
  esac
else
  echo "Zernio: skipped, no key"; status=1
fi

echo
[ "$status" -eq 0 ] && echo "Setup is usable." || echo "Setup incomplete. Publishing steps will not run until the above is fixed."
exit "$status"
