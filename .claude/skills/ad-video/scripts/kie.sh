#!/usr/bin/env bash
# kie.sh - create and collect Kie.ai generation jobs (images and video).
#
# Usage:
#   kie.sh image  --prompt TEXT [--ratio 9:16] [--resolution 1K|2K|4K]
#                 [--ref URL[,URL...]] [--background transparent|opaque|auto]
#                 [--out DIR] [--no-wait]
#   kie.sh video  --prompt TEXT [--ratio 9:16] [--resolution 480p|720p|1080p|4k]
#                 [--duration 4..15] [--first-frame URL] [--last-frame URL]
#                 [--ref URL[,URL...]] [--no-audio] [--out DIR] [--no-wait]
#   kie.sh raw    MODEL 'JSON_INPUT_OBJECT' [--out DIR] [--no-wait]
#   kie.sh status TASK_ID
#   kie.sh wait   TASK_ID [--timeout SECONDS]
#   kie.sh get    TASK_ID [--out DIR]      # wait, then download results
#
# Add --dry-run to any generation command to print the exact request body
# without sending it or spending credit.
#
# Prints result URLs on stdout, one per line. With --out, also downloads the
# files into DIR and prints the local paths on stderr.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$here/lib/common.sh"

KIE_API_BASE="${KIE_API_BASE:-https://api.kie.ai}"
adv_need KIE_API_KEY "Get a key at https://kie.ai -> API Keys." || exit 1

auth=(-H "Authorization: Bearer $KIE_API_KEY" -H "Content-Type: application/json")

api_post_task() {           # $1 = full JSON body
  local resp code
  resp="$(curl -sS -X POST "$KIE_API_BASE/api/v1/jobs/createTask" "${auth[@]}" -d "$1")" \
    || adv_fail "Request to Kie.ai failed (network or proxy error)."
  code="$(jq -r '.code // empty' <<<"$resp")"
  [ "$code" = "200" ] || adv_fail "Kie.ai rejected the task (code ${code:-unknown})." "$resp"
  jq -r '.data.taskId' <<<"$resp"
}

api_status() {              # $1 = taskId -> full record JSON
  # Kie.ai returns HTTP 200 even for auth and quota errors; the body carries
  # the real status in "code", so check that rather than the HTTP status.
  local resp code
  resp="$(curl -sS -G "$KIE_API_BASE/api/v1/jobs/recordInfo" \
    -H "Authorization: Bearer $KIE_API_KEY" --data-urlencode "taskId=$1")" \
    || adv_fail "Status request failed (network or proxy error)."
  code="$(jq -r '.code // empty' <<<"$resp")"
  [ "$code" = "200" ] || adv_fail "Kie.ai status call failed (code ${code:-unknown}): $(jq -r '.msg // ""' <<<"$resp")"
  printf '%s' "$resp"
}

wait_for() {                # $1 = taskId, $2 = timeout seconds
  local id="$1" timeout="${2:-900}" waited=0 interval=5 rec state progress
  while :; do
    rec="$(api_status "$id")"
    state="$(jq -r '.data.state // "unknown"' <<<"$rec")"
    case "$state" in
      success)
        jq -r '(.data.resultJson // "{}") | fromjson | (.resultUrls // [])[]' <<<"$rec"
        return 0 ;;
      fail)
        adv_fail "Task $id failed: $(jq -r '.data.failMsg // "no message"' <<<"$rec")" ;;
      waiting|queuing|generating)
        progress="$(jq -r '.data.progress // 0' <<<"$rec")"
        printf '\r%s: %s (%s%%) %ss elapsed   ' "$id" "$state" "$progress" "$waited" >&2 ;;
      *)
        adv_fail "Unexpected task state for $id." "$rec" ;;
    esac
    if [ "$waited" -ge "$timeout" ]; then
      echo >&2
      adv_fail "Timed out after ${timeout}s waiting for $id. Re-check with: kie.sh status $id"
    fi
    sleep "$interval"; waited=$((waited + interval))
    [ "$waited" -ge 60 ] && interval=10
  done
}

download_urls() {           # $1 = out dir; URLs on stdin
  local dir="$1" url name
  mkdir -p "$dir"
  while read -r url; do
    [ -n "$url" ] || continue
    name="$(basename "${url%%\?*}")"
    case "$name" in *.*) ;; *) name="$name.bin" ;; esac
    curl -sSL "$url" -o "$dir/$name" || adv_fail "Download failed: $url"
    echo "saved $dir/$name" >&2
    echo "$url"
  done
}

# ---- argument parsing -------------------------------------------------------
cmd="${1:-}"; shift || true
prompt=""; ratio=""; resolution=""; duration=""; first_frame=""; last_frame=""
refs=""; background=""; out=""; wait_flag=1; timeout=900; audio=1; model=""; raw_input=""
dry_run=0

while [ $# -gt 0 ]; do
  case "$1" in
    --prompt)      prompt="$2"; shift 2 ;;
    --ratio)       ratio="$2"; shift 2 ;;
    --resolution)  resolution="$2"; shift 2 ;;
    --duration)    duration="$2"; shift 2 ;;
    --first-frame) first_frame="$2"; shift 2 ;;
    --last-frame)  last_frame="$2"; shift 2 ;;
    --ref)         refs="$2"; shift 2 ;;
    --background)  background="$2"; shift 2 ;;
    --out)         out="$2"; shift 2 ;;
    --timeout)     timeout="$2"; shift 2 ;;
    --no-wait)     wait_flag=0; shift ;;
    --dry-run)     dry_run=1; shift ;;
    --no-audio)    audio=0; shift ;;
    -h|--help)     sed -n '2,29p' "$0"; exit 0 ;;
    *)             if [ -z "$model" ]; then model="$1"; elif [ -z "$raw_input" ]; then raw_input="$1"; fi; shift ;;
  esac
done

refs_json() { [ -n "$refs" ] && jq -cn --arg s "$refs" '$s | split(",") | map(select(length>0))' || echo "[]"; }

case "$cmd" in
  image)
    [ -n "$prompt" ] || adv_fail "image needs --prompt TEXT"
    if [ -n "$refs" ]; then
      m="gpt-image-2-image-to-image"
      input="$(jq -cn --arg p "$prompt" --argjson u "$(refs_json)" '{prompt:$p, input_urls:$u}')"
    else
      m="gpt-image-2-text-to-image"
      input="$(jq -cn --arg p "$prompt" '{prompt:$p}')"
    fi
    [ -n "$ratio" ]      && input="$(jq -c --arg v "$ratio" '.aspect_ratio=$v' <<<"$input")"
    [ -n "$resolution" ] && input="$(jq -c --arg v "$resolution" '.resolution=$v' <<<"$input")"
    [ -n "$background" ] && input="$(jq -c --arg v "$background" '.background=$v' <<<"$input")"
    body="$(jq -cn --arg m "$m" --argjson i "$input" '{model:$m, input:$i}')"
    ;;
  video)
    [ -n "$prompt" ] || adv_fail "video needs --prompt TEXT"
    input="$(jq -cn --arg p "$prompt" '{prompt:$p}')"
    [ -n "$ratio" ]       && input="$(jq -c --arg v "$ratio" '.aspect_ratio=$v' <<<"$input")"
    [ -n "$resolution" ]  && input="$(jq -c --arg v "$resolution" '.resolution=$v' <<<"$input")"
    [ -n "$duration" ]    && input="$(jq -c --argjson v "$duration" '.duration=$v' <<<"$input")"
    [ -n "$first_frame" ] && input="$(jq -c --arg v "$first_frame" '.first_frame_url=$v' <<<"$input")"
    [ -n "$last_frame" ]  && input="$(jq -c --arg v "$last_frame" '.last_frame_url=$v' <<<"$input")"
    [ -n "$refs" ]        && input="$(jq -c --argjson v "$(refs_json)" '.reference_image_urls=$v' <<<"$input")"
    [ "$audio" -eq 0 ]    && input="$(jq -c '.generate_audio=false' <<<"$input")"
    body="$(jq -cn --argjson i "$input" '{model:"bytedance/seedance-2", input:$i}')"
    ;;
  raw)
    [ -n "$model" ] && [ -n "$raw_input" ] || adv_fail "raw needs MODEL and a JSON input object"
    body="$(jq -cn --arg m "$model" --argjson i "$raw_input" '{model:$m, input:$i}')"
    ;;
  status)
    [ -n "$model" ] || adv_fail "status needs a TASK_ID"
    api_status "$model" | jq '{taskId:.data.taskId, state:.data.state, progress:.data.progress, failMsg:.data.failMsg, resultUrls:((.data.resultJson // "{}")|fromjson|.resultUrls)}'
    exit 0 ;;
  wait)
    [ -n "$model" ] || adv_fail "wait needs a TASK_ID"
    wait_for "$model" "$timeout"; echo >&2; exit 0 ;;
  get)
    [ -n "$model" ] || adv_fail "get needs a TASK_ID"
    if [ -n "$out" ]; then wait_for "$model" "$timeout" | download_urls "$out"; else wait_for "$model" "$timeout"; fi
    echo >&2; exit 0 ;;
  ""|-h|--help)
    sed -n '2,29p' "$0"; exit 0 ;;
  *)
    adv_fail "Unknown command: $cmd" ;;
esac

if [ "$dry_run" -eq 1 ]; then
  echo "DRY RUN - this request was not sent:" >&2
  jq . <<<"$body"
  exit 0
fi

task_id="$(api_post_task "$body")"
echo "task $task_id" >&2
if [ "$wait_flag" -eq 0 ]; then echo "$task_id"; exit 0; fi
if [ -n "$out" ]; then wait_for "$task_id" "$timeout" | download_urls "$out"; else wait_for "$task_id" "$timeout"; fi
echo >&2
