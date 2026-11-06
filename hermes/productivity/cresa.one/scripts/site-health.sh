#!/usr/bin/env bash
# site-health.sh - read-only health check for one cresa.one Site.
#
# Public checks (no key needed): HTTP reachability, TLS validity and certificate
# expiry, access-gate detection, and the share image. Owner checks (account API
# key): publish status, finalize/pending-upload state, expiry, access policy,
# metadata consistency, and recent analytics including 404 paths.
#
#   bash scripts/site-health.sh market-rent-calculator
#   bash scripts/site-health.sh https://market-rent-calculator.cresa.one/ --json
set -euo pipefail

BASE_URL="https://cresa.one"
CREDENTIALS_FILE="$HOME/.cresaone/credentials"
API_KEY="${CRESAONE_API_KEY:-}"
ALLOW_NON_CRESAONE_BASE_URL=0
TARGET="" SLUG="" PUBLIC_URL="" RANGE="7d" JSON_ONLY=0 OWNER=1 TIMEOUT=15
EXPIRY_WARN_SECONDS=$((24 * 3600))
CERT_WARN_SECONDS=$((14 * 24 * 3600))

usage() {
  cat <<'USAGE'
Usage: site-health.sh <slug|site-url> [options]

Read-only. Never changes the Site.

Options:
  --slug <slug>           Owner slug when the argument is a custom-domain URL
  --url <url>             Public URL to probe (default: https://{slug}.cresa.one/)
  --range <window>        Analytics window: 24h, 7d (default), 30d, 90d, all
  --no-owner              Skip authenticated checks even when a key is available
  --json                  Print only the JSON report on stdout
  --timeout <seconds>     Per-request timeout (default: 15)
  --api-key <key>         API key (prefer $CRESAONE_API_KEY or ~/.cresaone/credentials)
  --base-url <url>        API base (default: https://cresa.one)
  --allow-noncresaone-base-url
                          Allow sending the API key to a non-default --base-url

Exit status: 0 healthy or warnings only, 1 usage or dependency error, 2 a check failed.
USAGE
  exit "${1:-1}"
}

die() { echo "error: $1" >&2; exit 1; }

require_value() { [[ -n "${2:-}" ]] || die "$1 requires a value"; }

# Windows (Git Bash, MSYS2, Cygwin): curl and jq are native programs. Disable
# MSYS argument rewriting and pass file paths through native_path instead.
CRESA_WINDOWS=0
case "$(uname -s 2>/dev/null || true)" in
  MINGW*|MSYS*|CYGWIN*)
    CRESA_WINDOWS=1
    export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
    ;;
esac
native_path() {
  if [[ "$CRESA_WINDOWS" -eq 1 ]] && command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s\n' "$1"
  fi
}

SCRIPT_SOURCE="${BASH_SOURCE[0]//\\//}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

JQ_BIN=""
for candidate in "${SKILL_DIR}/bin/jq" "${SKILL_DIR}/bin/jq.exe"; do
  if [[ -x "$candidate" ]]; then JQ_BIN="$candidate"; break; fi
done
[[ -n "$JQ_BIN" ]] || JQ_BIN="$(command -v jq 2>/dev/null || true)"
[[ -n "$JQ_BIN" ]] || die "requires jq"
if [[ "$CRESA_WINDOWS" -eq 1 ]] && "$JQ_BIN" -b -n 1 >/dev/null 2>&1; then
  # Native jq.exe writes CRLF unless -b is set; bash comparisons need LF.
  JQ_EXE="$JQ_BIN"
  JQ_BIN="jq_lf"
  jq_lf() { "$JQ_EXE" -b "$@"; }
fi
command -v curl >/dev/null 2>&1 || die "requires curl"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) require_value "$1" "${2:-}"; SLUG="$2"; shift 2 ;;
    --url) require_value "$1" "${2:-}"; PUBLIC_URL="$2"; shift 2 ;;
    --range) require_value "$1" "${2:-}"; RANGE="$2"; shift 2 ;;
    --no-owner) OWNER=0; shift ;;
    --json) JSON_ONLY=1; shift ;;
    --timeout) require_value "$1" "${2:-}"; TIMEOUT="$2"; shift 2 ;;
    --api-key) require_value "$1" "${2:-}"; API_KEY="$2"; shift 2 ;;
    --base-url) require_value "$1" "${2:-}"; BASE_URL="${2%/}"; shift 2 ;;
    --allow-noncresaone-base-url) ALLOW_NON_CRESAONE_BASE_URL=1; shift ;;
    --help|-h) usage 0 ;;
    -*) die "unknown option: $1" ;;
    *) [[ -z "$TARGET" ]] || die "unexpected argument: $1"; TARGET="$1"; shift ;;
  esac
done

[[ -n "$TARGET" || -n "$SLUG" ]] || usage
case "$RANGE" in 24h|7d|30d|90d|all) ;; *) die "--range must be 24h, 7d, 30d, 90d, or all" ;; esac
[[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]] || die "--timeout must be a positive integer"

# Accept a slug, {slug}.cresa.one, or any https URL.
if [[ "$TARGET" == http://* || "$TARGET" == https://* ]]; then
  [[ -n "$PUBLIC_URL" ]] || PUBLIC_URL="$TARGET"
  host="${TARGET#*://}"; host="${host%%/*}"; host="${host%%:*}"
  if [[ -z "$SLUG" && "$host" == *.cresa.one ]]; then SLUG="${host%.cresa.one}"; fi
elif [[ -n "$TARGET" ]]; then
  candidate="${TARGET%/}"; candidate="${candidate%.cresa.one}"
  [[ -n "$SLUG" ]] || SLUG="$candidate"
fi
if [[ -n "$SLUG" ]]; then
  [[ "$SLUG" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || die "invalid slug: $SLUG"
fi
[[ -n "$PUBLIC_URL" ]] || PUBLIC_URL="https://${SLUG}.cresa.one/"
[[ "$PUBLIC_URL" == http://* || "$PUBLIC_URL" == https://* ]] || die "--url must start with https://"
PUBLIC_HOSTPORT="${PUBLIC_URL#*://}"; PUBLIC_HOSTPORT="${PUBLIC_HOSTPORT%%/*}"; PUBLIC_HOSTPORT="${PUBLIC_HOSTPORT%%\?*}"
PUBLIC_HOST="${PUBLIC_HOSTPORT%%:*}"
PUBLIC_ORIGIN="${PUBLIC_URL%%://*}://${PUBLIC_HOSTPORT}"
[[ "$PUBLIC_URL" != "$PUBLIC_ORIGIN" ]] || PUBLIC_URL="${PUBLIC_ORIGIN}/"

if [[ "$OWNER" -eq 1 && -z "$API_KEY" && -f "$CREDENTIALS_FILE" ]]; then
  API_KEY="$(tr -d '[:space:]' < "$CREDENTIALS_FILE")"
fi
if [[ -n "$API_KEY" && "$BASE_URL" != "https://cresa.one" && "$ALLOW_NON_CRESAONE_BASE_URL" -ne 1 ]]; then
  die "refusing to send the API key to $BASE_URL without --allow-noncresaone-base-url"
fi

WORK="$(native_path "$(mktemp -d)")"
trap 'rm -rf "$WORK"' EXIT
CHECKS="[]"
FAILS=0
WARNS=0

# add_check <name> <ok|warn|fail|skip> <detail>
add_check() {
  CHECKS="$(printf '%s' "$CHECKS" | "$JQ_BIN" -c --arg n "$1" --arg s "$2" --arg d "$3" '. + [{check:$n,status:$s,detail:$d}]')"
  case "$2" in
    fail) FAILS=$((FAILS + 1)) ;;
    warn) WARNS=$((WARNS + 1)) ;;
  esac
}

# api <path>: sets API_CODE and API_BODY; never prints the key.
api() {
  local out="$WORK/api.json"
  API_CODE="$(curl -sS --connect-timeout 10 --max-time "$TIMEOUT" -o "$out" -w '%{http_code}' \
    -H "@$WORK/auth" -H "x-cresaone-client: site-health-sh" "$BASE_URL$1" 2>/dev/null || echo 000)"
  API_BODY="$(cat "$out" 2>/dev/null || true)"
  printf '%s' "$API_BODY" | "$JQ_BIN" -e 'type == "object"' >/dev/null 2>&1 || API_BODY="{}"
}

api_error() {
  printf '%s' "$API_BODY" | "$JQ_BIN" -r '.message // .error // empty' 2>/dev/null || true
}

seconds_until() {
  printf '%s' "$1" | "$JQ_BIN" -Rr 'try ((sub("\\.[0-9]+"; "") | fromdateiso8601) - now | floor) catch ""' 2>/dev/null || true
}

human_duration() {
  local s="${1#-}"
  if [[ "$s" -ge 86400 ]]; then echo "$((s / 86400))d"; elif [[ "$s" -ge 3600 ]]; then echo "$((s / 3600))h"; else echo "$((s / 60))m"; fi
}

# ---------------------------------------------------------------- public: HTTP + TLS
HTTP_CODE="000"
GATE="none"
BODY_FILE="$WORK/body"
probe_url="${PUBLIC_URL}"
if [[ "$probe_url" == *\?* ]]; then probe_url="${probe_url}&cresahealth=$(date +%s)"; else probe_url="${probe_url}?cresahealth=$(date +%s)"; fi
set +e
probe="$(curl -sS --connect-timeout 10 --max-time "$TIMEOUT" -o "$BODY_FILE" \
  -w '%{http_code} %{time_total}' "$probe_url" 2>"$WORK/curl.err")"
curl_rc=$?
set -e
read -r HTTP_CODE http_time <<<"${probe:-000 0}"
if [[ "$curl_rc" -ne 0 ]]; then
  case "$curl_rc" in
    6) reason="DNS lookup failed for $PUBLIC_HOST" ;;
    7) reason="could not connect to $PUBLIC_HOST" ;;
    28) reason="timed out after ${TIMEOUT}s" ;;
    35|51|53|54|58|59|60|64|66|77|80|82|83|90|91) reason="TLS handshake or certificate verification failed (curl $curl_rc)" ;;
    *) reason="request failed (curl $curl_rc): $(tr -d '\r' < "$WORK/curl.err" | head -n 1)" ;;
  esac
  add_check http fail "$reason"
  if [[ "$PUBLIC_URL" == https://* ]]; then
    case "$curl_rc" in 35|51|53|54|58|59|60|64|66|77|80|82|83|90|91) add_check tls fail "$reason" ;; esac
  fi
else
  if grep -Eq 'action="/__cresa/(unlock|request|verify)"' "$BODY_FILE" 2>/dev/null; then
    if grep -Fq 'action="/__cresa/unlock"' "$BODY_FILE"; then GATE="password"; else GATE="restricted"; fi
  fi
  case "$HTTP_CODE" in
    2??)
      if [[ "$GATE" == none ]]; then add_check http ok "HTTP $HTTP_CODE in ${http_time}s"
      else add_check http ok "HTTP $HTTP_CODE in ${http_time}s; $GATE access gate shown"; fi
      ;;
    401|403) add_check http ok "HTTP $HTTP_CODE in ${http_time}s; access gate" ;;
    404) add_check http fail "HTTP 404: not published, disabled, never finalized, or wrong slug" ;;
    410) add_check http fail "HTTP 410: the Site has expired" ;;
    3??) add_check http warn "HTTP $HTTP_CODE redirect not followed" ;;
    *) add_check http fail "HTTP $HTTP_CODE in ${http_time}s" ;;
  esac
  if [[ "$PUBLIC_URL" == https://* ]]; then
    if command -v openssl >/dev/null 2>&1; then
      openssl s_client -connect "${PUBLIC_HOST}:443" -servername "$PUBLIC_HOST" </dev/null >"$WORK/tls.txt" 2>/dev/null || true
      cert="$(openssl x509 -in "$WORK/tls.txt" -noout -enddate 2>/dev/null | tr -d '\r' || true)"
      if [[ "$cert" == notAfter=* ]]; then
        if openssl x509 -in "$WORK/tls.txt" -noout -checkend "$CERT_WARN_SECONDS" >/dev/null 2>&1; then
          add_check tls ok "certificate valid; expires ${cert#notAfter=}"
        else
          add_check tls warn "certificate expires within 14 days (${cert#notAfter=})"
        fi
      else
        add_check tls ok "certificate verified by curl; expiry not readable"
      fi
    else
      add_check tls ok "certificate verified by curl; install openssl to report expiry"
    fi
  else
    add_check tls warn "not served over HTTPS"
  fi
fi

# ---------------------------------------------------------------- owner checks
SITE_JSON="{}"
ACCESS_MODE=""
PUBLIC_PREVIEW="false"
if [[ "$OWNER" -eq 0 ]]; then
  add_check owner skip "owner checks disabled with --no-owner"
elif [[ -z "$API_KEY" ]]; then
  add_check owner skip "no API key; status, expiry, access policy, and analytics need account-owner authorization"
elif [[ -z "$SLUG" ]]; then
  add_check owner skip "pass --slug to run owner checks for a custom-domain URL"
else
  (umask 077; printf 'authorization: Bearer %s\n' "$API_KEY" > "$WORK/auth")

  api "/api/v1/publish/$SLUG"
  if [[ "$API_CODE" == 200 ]]; then
    SITE_JSON="$API_BODY"
    status="$(printf '%s' "$SITE_JSON" | "$JQ_BIN" -r '.status // "unknown"')"
    current="$(printf '%s' "$SITE_JSON" | "$JQ_BIN" -r '.currentVersionId // empty')"
    pending="$(printf '%s' "$SITE_JSON" | "$JQ_BIN" -r '.pendingVersionId // empty')"
    files="$(printf '%s' "$SITE_JSON" | "$JQ_BIN" -r '[.manifest[]?] | length')"
    bytes="$(printf '%s' "$SITE_JSON" | "$JQ_BIN" -r '[.manifest[]?.size // 0] | add // 0')"
    case "$status" in
      published) add_check status ok "published; $files files, $bytes bytes" ;;
      pending)
        if [[ -z "$current" ]]; then add_check status fail "pending: no version was ever finalized, so nothing is live"
        else add_check status warn "pending: status is not published"; fi
        ;;
      archived) add_check status warn "archived: retained but not served" ;;
      disabled) add_check status warn "disabled: visitors get 404 until the status is published again" ;;
      *) add_check status warn "unknown status: $status" ;;
    esac
    if [[ -z "$current" ]]; then
      add_check version fail "no finalized version; upload and finalize before sharing"
    elif [[ -n "$pending" ]]; then
      add_check version warn "upload $pending is pending; resume it with uploads/refresh or cancel it with uploads/cancel"
    else
      add_check version ok "current version $current finalized; no pending upload"
    fi
    expires="$(printf '%s' "$SITE_JSON" | "$JQ_BIN" -r 'if has("expiresAt") then (.expiresAt // "permanent") else "unknown" end')"
    case "$expires" in
      permanent) add_check expiry ok "permanent (no expiry)" ;;
      unknown) add_check expiry warn "expiry not returned by the API" ;;
      *)
        left="$(seconds_until "$expires")"
        if [[ -z "$left" ]]; then add_check expiry warn "expires at $expires"
        elif [[ "$left" -le 0 ]]; then add_check expiry fail "expired at $expires"
        elif [[ "$left" -le "$EXPIRY_WARN_SECONDS" ]]; then add_check expiry warn "expires in $(human_duration "$left") ($expires); claim it or extend the TTL"
        else add_check expiry ok "expires in $(human_duration "$left") ($expires)"; fi
        ;;
    esac
    og_path="$(printf '%s' "$SITE_JSON" | "$JQ_BIN" -r '.viewer.ogImagePath // empty')"
    title="$(printf '%s' "$SITE_JSON" | "$JQ_BIN" -r '.viewer.title // empty')"
    has_index="$(printf '%s' "$SITE_JSON" | "$JQ_BIN" -r '[.manifest[]?.path] | index("index.html") != null')"
    meta_notes=()
    [[ -n "$title" ]] || meta_notes+=("no Site title")
    if [[ -n "$og_path" ]]; then
      printf '%s' "$SITE_JSON" | "$JQ_BIN" -e --arg p "${og_path#/}" '[.manifest[]?.path] | index($p) != null' >/dev/null \
        || meta_notes+=("ogImagePath $og_path is not in the published files")
    elif [[ "$has_index" == true ]]; then
      meta_notes+=("no share image (ogImagePath)")
    fi
    if [[ "${#meta_notes[@]}" -eq 0 ]]; then add_check metadata ok "title and share image set"
    else add_check metadata warn "$(IFS=';'; echo "${meta_notes[*]}" | sed 's/;/; /g')"; fi
  elif [[ "$API_CODE" == 404 ]]; then
    add_check status fail "Site $SLUG was not found in this account"
  elif [[ "$API_CODE" == 401 || "$API_CODE" == 403 ]]; then
    add_check owner fail "API key rejected (HTTP $API_CODE): $(api_error)"
  else
    add_check status fail "could not read Site details (HTTP $API_CODE) $(api_error)"
  fi

  if [[ "$SITE_JSON" != "{}" ]]; then
    api "/api/v1/publish/$SLUG/access"
    if [[ "$API_CODE" == 200 ]]; then
      ACCESS_MODE="$(printf '%s' "$API_BODY" | "$JQ_BIN" -r '.access.mode // empty')"
      PUBLIC_PREVIEW="$(printf '%s' "$API_BODY" | "$JQ_BIN" -r '.access.publicPreviewEnabled // false')"
      emails="$(printf '%s' "$API_BODY" | "$JQ_BIN" -r '[.access.allowedEmails[]?] | length')"
      domains="$(printf '%s' "$API_BODY" | "$JQ_BIN" -r '[.access.allowedDomains[]?] | length')"
      case "$ACCESS_MODE" in
        anyone_with_link) add_check access ok "anyone with the link can view" ;;
        password) add_check access ok "password protected; public preview $PUBLIC_PREVIEW" ;;
        restricted)
          if [[ "$((emails + domains))" -eq 0 ]]; then add_check access warn "restricted with an empty allowlist; nobody can sign in"
          else add_check access ok "restricted to $emails emails and $domains domains; public preview $PUBLIC_PREVIEW"; fi
          ;;
        *) add_check access warn "unknown access mode: ${ACCESS_MODE:-missing}" ;;
      esac
      if [[ "$HTTP_CODE" =~ ^2 ]]; then
        if [[ "$ACCESS_MODE" == anyone_with_link && "$GATE" != none ]]; then
          add_check gate fail "policy is anyone_with_link but the public URL shows a $GATE gate"
        elif [[ "$ACCESS_MODE" == password || "$ACCESS_MODE" == restricted ]] && [[ "$GATE" == none ]]; then
          add_check gate fail "policy is $ACCESS_MODE but the public URL served content without a gate"
        else
          add_check gate ok "public URL matches the $ACCESS_MODE policy"
        fi
      fi
    else
      add_check access warn "could not read access policy (HTTP $API_CODE) $(api_error)"
    fi

    api "/api/v1/publishes/$SLUG/analytics?range=$RANGE"
    if [[ "$API_CODE" == 200 ]]; then
      summary="$(printf '%s' "$API_BODY" | "$JQ_BIN" -r --arg r "$RANGE" '"\(.totals.rangeViews // 0) views, \(.totals.rangeVisitors // 0) visitors in \($r); last event \(.lastEventAt // "none")"')"
      missing="$(printf '%s' "$API_BODY" | "$JQ_BIN" -r '[.top404Paths[]? | "\(.path // "?") (\(.hits // 0))"] | .[0:3] | join(", ")')"
      if [[ -n "$missing" ]]; then add_check analytics warn "$summary; recent 404s: $missing"
      else add_check analytics ok "$summary; no recent 404s"; fi
    else
      add_check analytics skip "analytics unavailable (HTTP $API_CODE) $(api_error)"
    fi
  fi
fi

# ---------------------------------------------------------------- public share image
og_path="$(printf '%s' "$SITE_JSON" | "$JQ_BIN" -r '.viewer.ogImagePath // empty')"
og_public=0
if [[ "$ACCESS_MODE" == anyone_with_link || "$PUBLIC_PREVIEW" == true ]]; then og_public=1; fi
if [[ -z "$ACCESS_MODE" && "$GATE" == none ]]; then og_public=1; fi
if [[ -n "$og_path" && "$HTTP_CODE" =~ ^2 && "$og_public" -eq 1 ]]; then
  og_url="${PUBLIC_ORIGIN}/${og_path#/}?cresahealth=$(date +%s)"
  og_head="$(curl -sS --connect-timeout 10 --max-time "$TIMEOUT" -o "$WORK/og" -w '%{http_code} %{content_type}' "$og_url" 2>/dev/null || echo "000")"
  if [[ "$og_head" == 200\ image/* ]]; then add_check og-image ok "$og_path served as ${og_head#200 }"
  else add_check og-image warn "$og_path returned '$og_head'"; fi
fi

# ---------------------------------------------------------------- report
if [[ "$FAILS" -gt 0 ]]; then OVERALL=fail; elif [[ "$WARNS" -gt 0 ]]; then OVERALL=warn; else OVERALL=ok; fi
REPORT="$("$JQ_BIN" -n --arg slug "$SLUG" --arg url "$PUBLIC_URL" --arg status "$OVERALL" \
  --arg access "$ACCESS_MODE" --arg gate "$GATE" --argjson checks "$CHECKS" \
  --arg checkedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{status:$status,slug:(if $slug == "" then null else $slug end),url:$url,checkedAt:$checkedAt,
    access:(if $access == "" then null else $access end),gate:$gate,checks:$checks}')"
if [[ "$JSON_ONLY" -eq 1 ]]; then
  printf '%s\n' "$REPORT"
else
  echo "site-health: $PUBLIC_URL"
  printf '%s' "$CHECKS" | "$JQ_BIN" -r '.[] | "  \(.status | ascii_upcase | .[0:4] | . + "    " | .[0:5]) \(.check | . + "          " | .[0:10]) \(.detail)"'
  echo "site-health: $OVERALL ($FAILS failed, $WARNS warnings)"
fi
echo "health_result.status=$OVERALL" >&2
echo "health_result.url=$PUBLIC_URL" >&2
[[ "$OVERALL" != fail ]] || exit 2
exit 0
