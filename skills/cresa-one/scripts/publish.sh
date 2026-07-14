#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://cresa.one"
CREDENTIALS_FILE="$HOME/.cresaone/credentials"
API_KEY="${CRESAONE_API_KEY:-}"
API_KEY_SOURCE="none"
if [[ -n "${CRESAONE_API_KEY:-}" ]]; then
  API_KEY_SOURCE="env"
fi
ALLOW_NON_CRESAONE_BASE_URL=0
CREATE=0
SLUG=""
CLAIM_TOKEN=""
TITLE=""
DESCRIPTION=""
OG_IMAGE_PATH=""
TTL=""
CLIENT=""
TARGET=""
SPA_MODE=""
FROM_DRIVE=""
DRIVE_VERSION=""
TAGS=""
TAGS_JSON=""
METADATA_ONLY=""
VERIFY=1
VERIFY_LIMIT=50
RENAME_TO=""
CHECK_SLUG=""
SUGGEST_SLUG=0

usage() {
  cat <<'USAGE'
Usage: publish.sh [file-or-dir] [options]

Options:
  --api-key <key>         API key (or set $CRESAONE_API_KEY)
  --slug <slug>           Update existing publish (or requested slug with --create)
  --create                Create a new Site; with --slug, claim that slug
                          (authenticated only; fails when taken or invalid)
  --claim-token <token>   Claim token for anonymous updates
  --title <text>          Viewer title
  --description <text>    Viewer description
  --og-image-path <path>  Viewer/Open Graph image path (for example /og.png)
  --metadata-only         Patch viewer metadata/TTL/SPA/tags without uploading files
  --verify               Verify live bytes, content types, and metadata (default)
  --no-verify            Skip post-publish verification
  --rename-to <slug>     Rename --slug without uploading files (authenticated only)
  --check-slug <slug>    Print slug availability; exits non-zero when unavailable
  --suggest-slug         Print a fresh available slug (authenticated only)
  --ttl <seconds>         Expiry (authenticated only)
  --client <name>         Agent name for attribution (e.g. cursor, claude-code)
  --tags <json-array>     Replace Site tags after publish (authenticated only)
  --spa                   Enable SPA routing
  --from-drive <drv_...>  Publish a Drive snapshot instead of local files
  --version <dv_...>      Drive version for --from-drive (default: current head)
  --base-url <url>        API base (default: https://cresa.one)
  --allow-noncresaone-base-url
                         Allow auth requests to non-default API base URL
USAGE
  exit 1
}

die() { echo "error: $1" >&2; exit 1; }

require_flag_value() {
  [[ -n "${2:-}" ]] || die "$1 requires a value"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUNDLED_JQ="${SKILL_DIR}/bin/jq"

if [[ -x "$BUNDLED_JQ" ]]; then
  JQ_BIN="$BUNDLED_JQ"
elif command -v jq >/dev/null 2>&1; then
  JQ_BIN="$(command -v jq)"
else
  die "requires jq"
fi

for cmd in curl file; do
  command -v "$cmd" >/dev/null 2>&1 || die "requires $cmd"
done

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-key)      require_flag_value "$1" "${2:-}"; API_KEY="$2"; API_KEY_SOURCE="flag"; shift 2 ;;
    --slug)         require_flag_value "$1" "${2:-}"; SLUG="$2"; shift 2 ;;
    --create)       CREATE=1; shift ;;
    --claim-token)  require_flag_value "$1" "${2:-}"; CLAIM_TOKEN="$2"; shift 2 ;;
    --title)        require_flag_value "$1" "${2:-}"; TITLE="$2"; shift 2 ;;
    --description)  require_flag_value "$1" "${2:-}"; DESCRIPTION="$2"; shift 2 ;;
    --og-image-path) require_flag_value "$1" "${2:-}"; OG_IMAGE_PATH="$2"; shift 2 ;;
    --metadata-only) METADATA_ONLY="true"; shift ;;
    --verify)        VERIFY=1; shift ;;
    --no-verify)     VERIFY=0; shift ;;
    --rename-to)     require_flag_value "$1" "${2:-}"; RENAME_TO="$2"; shift 2 ;;
    --check-slug)    require_flag_value "$1" "${2:-}"; CHECK_SLUG="$2"; shift 2 ;;
    --suggest-slug)  SUGGEST_SLUG=1; shift ;;
    --ttl)          require_flag_value "$1" "${2:-}"; TTL="$2"; shift 2 ;;
    --client)       require_flag_value "$1" "${2:-}"; CLIENT="$2"; shift 2 ;;
    --tags)         require_flag_value "$1" "${2:-}"; TAGS="$2"; shift 2 ;;
    --base-url)     require_flag_value "$1" "${2:-}"; BASE_URL="$2"; shift 2 ;;
    --allow-noncresaone-base-url) ALLOW_NON_CRESAONE_BASE_URL=1; shift ;;
    --spa)          SPA_MODE="true"; shift ;;
    --from-drive)   require_flag_value "$1" "${2:-}"; FROM_DRIVE="$2"; shift 2 ;;
    --version)      require_flag_value "$1" "${2:-}"; DRIVE_VERSION="$2"; shift 2 ;;
    --help|-h)      usage ;;
    -*)             die "unknown option: $1" ;;
    *)              [[ -z "$TARGET" ]] && TARGET="$1" || die "unexpected argument: $1"; shift ;;
  esac
done

action_count=0
[[ "$METADATA_ONLY" == "true" ]] && action_count=$((action_count + 1))
[[ -n "$RENAME_TO" ]] && action_count=$((action_count + 1))
[[ -n "$CHECK_SLUG" ]] && action_count=$((action_count + 1))
[[ "$SUGGEST_SLUG" -eq 1 ]] && action_count=$((action_count + 1))
[[ "$action_count" -le 1 ]] || die "choose only one of --metadata-only, --rename-to, --check-slug, or --suggest-slug"

if [[ "$CREATE" -eq 1 ]]; then
  [[ "$action_count" -eq 0 ]] || die "--create cannot be combined with --metadata-only, --rename-to, --check-slug, or --suggest-slug"
  [[ -z "$FROM_DRIVE" ]] || die "--create is implicit for --from-drive; pass --from-drive --slug directly"
  [[ -z "$CLAIM_TOKEN" ]] || die "--create cannot be combined with --claim-token"
fi

if [[ -n "$RENAME_TO" ]]; then
  [[ -n "$SLUG" ]] || die "--rename-to requires --slug <old-slug>"
  [[ -z "$TARGET" ]] || die "--rename-to does not accept a local file-or-dir argument"
  [[ -z "$FROM_DRIVE" ]] || die "--rename-to cannot be combined with --from-drive"
  [[ -z "$TITLE$DESCRIPTION$OG_IMAGE_PATH$TTL$TAGS$SPA_MODE$CLAIM_TOKEN" ]] || die "--rename-to cannot be combined with publish or metadata mutation flags"
elif [[ -n "$CHECK_SLUG" || "$SUGGEST_SLUG" -eq 1 ]]; then
  [[ -z "$TARGET" ]] || die "slug helpers do not accept a local file-or-dir argument"
  [[ -z "$SLUG" ]] || die "slug helpers do not accept --slug"
  [[ -z "$FROM_DRIVE" ]] || die "slug helpers cannot be combined with --from-drive"
  [[ -z "$TITLE$DESCRIPTION$OG_IMAGE_PATH$TTL$TAGS$SPA_MODE$CLAIM_TOKEN" ]] || die "slug helpers cannot be combined with publish or metadata mutation flags"
elif [[ "$METADATA_ONLY" == "true" ]]; then
  [[ -n "$SLUG" ]] || die "--metadata-only requires --slug"
  [[ -z "$TARGET" ]] || die "--metadata-only does not accept a local file-or-dir argument"
  [[ -z "$FROM_DRIVE" ]] || die "--metadata-only cannot be combined with --from-drive"
elif [[ -n "$FROM_DRIVE" ]]; then
  [[ -z "$TARGET" ]] || die "--from-drive does not accept a local file-or-dir argument"
else
  [[ -n "$TARGET" ]] || usage
  [[ -e "$TARGET" ]] || die "path does not exist: $TARGET"
fi

# Load API key from credentials file if not provided via flag or env
if [[ -z "$API_KEY" && -f "$CREDENTIALS_FILE" ]]; then
  API_KEY=$(cat "$CREDENTIALS_FILE" | tr -d '[:space:]')
  [[ -n "$API_KEY" ]] && API_KEY_SOURCE="credentials"
fi

BASE_URL="${BASE_URL%/}"
STATE_DIR=".cresaone"
STATE_FILE="$STATE_DIR/state.json"

# Safety guard: avoid accidentally sending bearer auth to arbitrary endpoints.
if [[ -n "$API_KEY" && "$BASE_URL" != "https://cresa.one" && "$ALLOW_NON_CRESAONE_BASE_URL" -ne 1 ]]; then
  die "refusing to send API key to non-default base URL; pass --allow-noncresaone-base-url to override"
fi

api_error_message() {
  local response="$1"
  local fallback="$2"
  local err details
  if printf '%s' "$response" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
    err=$(printf '%s' "$response" | "$JQ_BIN" -r '.error')
    details=$(printf '%s' "$response" | "$JQ_BIN" -r '.details // empty')
    printf '%s%s' "$err" "${details:+ ($details)}"
  else
    printf '%s' "$fallback"
  fi
}

require_owner_auth() {
  local action="$1"
  [[ -n "$API_KEY" ]] || die "$action requires authentication; set CRESAONE_API_KEY or ~/.cresaone/credentials"
}

save_state_json() {
  local state_json="$1"
  local tmp
  mkdir -p "$STATE_DIR"
  tmp=$(mktemp "$STATE_DIR/state.json.XXXXXX")
  printf '%s\n' "$state_json" | "$JQ_BIN" '.' > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

if [[ -n "$CHECK_SLUG" ]]; then
  require_owner_auth "--check-slug"
  encoded_slug=$(printf '%s' "$CHECK_SLUG" | "$JQ_BIN" -sRr @uri)
  response=$(curl -sS "$BASE_URL/api/v1/publish/slug-available?slug=$encoded_slug" \
    -H "authorization: Bearer $API_KEY")
  if printf '%s' "$response" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
    die "slug check failed: $(api_error_message "$response" "unexpected response")"
  fi
  printf '%s\n' "$response" | "$JQ_BIN" '{slug,available,reason}'
  [[ $(printf '%s' "$response" | "$JQ_BIN" -r '.available') == "true" ]] || exit 1
  exit 0
fi

if [[ "$SUGGEST_SLUG" -eq 1 ]]; then
  require_owner_auth "--suggest-slug"
  response=$(curl -sS "$BASE_URL/api/v1/publish/slug-suggest" \
    -H "authorization: Bearer $API_KEY")
  if printf '%s' "$response" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
    die "slug suggestion failed: $(api_error_message "$response" "unexpected response")"
  fi
  suggested_slug=$(printf '%s' "$response" | "$JQ_BIN" -r '.slug // empty')
  [[ -n "$suggested_slug" ]] || die "slug suggestion returned no slug"
  printf '%s\n' "$suggested_slug"
  exit 0
fi

if [[ -n "$RENAME_TO" ]]; then
  require_owner_auth "--rename-to"
  body=$("$JQ_BIN" -n --arg slug "$RENAME_TO" '{slug:$slug}')
  response=$(curl -sS -X POST "$BASE_URL/api/v1/publish/$SLUG/rename" \
    -H "authorization: Bearer $API_KEY" \
    -H "content-type: application/json" \
    -d "$body")
  if printf '%s' "$response" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
    die "rename failed: $(api_error_message "$response" "unexpected response")"
  fi
  renamed_slug=$(printf '%s' "$response" | "$JQ_BIN" -r '.slug // empty')
  renamed_url=$(printf '%s' "$response" | "$JQ_BIN" -r '.siteUrl // empty')
  [[ -n "$renamed_slug" && -n "$renamed_url" ]] || die "rename returned an invalid response"

  old_slug_normalized=$(printf '%s' "$SLUG" | "$JQ_BIN" -sRr 'gsub("^[[:space:]]+|[[:space:]]+$"; "") | ascii_downcase')
  if [[ "$renamed_slug" == "$old_slug_normalized" ]]; then
    printf '%s\n' "$renamed_url"
    echo "slug unchanged: $renamed_slug" >&2
    echo "publish_result.slug=$renamed_slug" >&2
    echo "publish_result.action=rename_noop" >&2
    exit 0
  fi

  old_url="${renamed_url/\/\/$renamed_slug./\/\/$SLUG.}"
  if [[ -f "$STATE_FILE" ]] && "$JQ_BIN" -e --arg slug "$SLUG" '.publishes[$slug] != null' "$STATE_FILE" >/dev/null 2>&1; then
    state=$("$JQ_BIN" --arg old "$SLUG" --arg new "$renamed_slug" --arg url "$renamed_url" \
      '.publishes[$new] = (.publishes[$old] | .siteUrl = $url) | del(.publishes[$old])' "$STATE_FILE")
    save_state_json "$state"
    echo "updated $STATE_FILE" >&2
  fi

  printf '%s\n' "$renamed_url"
  echo "old URL: $old_url" >&2
  echo "new URL: $renamed_url" >&2
  echo "warning: old host now returns 404; shared links and cached previews break, and the freed slug can be claimed by others" >&2
  echo "publish_result.slug=$renamed_slug" >&2
  echo "publish_result.action=rename" >&2
  exit 0
fi

build_client_header() {
  local value="cresa-one-publish-sh"
  if [[ -n "$CLIENT" ]]; then
    local normalized_client
    normalized_client=$(echo "$CLIENT" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-')
    normalized_client="${normalized_client#-}"
    normalized_client="${normalized_client%-}"
    if [[ -n "$normalized_client" ]]; then
      value="${normalized_client}/publish-sh"
    fi
  fi
  echo "$value"
}

CLIENT_HEADER_VALUE="$(build_client_header)"

has_viewer_fields() {
  [[ -n "$TITLE" || -n "$DESCRIPTION" || -n "$OG_IMAGE_PATH" ]]
}

if [[ -n "$TAGS" ]]; then
  [[ -n "$API_KEY" ]] || die "--tags requires an authenticated publish; set CRESAONE_API_KEY or ~/.cresaone/credentials"
  if ! TAGS_JSON=$(printf '%s' "$TAGS" | "$JQ_BIN" -c 'if type == "array" and all(.[]; type == "string") then . else error("tags must be a JSON array of strings") end' 2>/dev/null); then
    die "--tags must be a JSON array of strings, e.g. '[\"cre\",\"calculator\"]'"
  fi
fi

apply_tags() {
  local slug="$1"
  local client_header_value="$2"
  [[ -n "$TAGS_JSON" ]] || return 0
  local body response out_tags
  body=$(printf '%s' "$TAGS_JSON" | "$JQ_BIN" '{tags:.}')
  echo "updating tags..." >&2
  response=$(curl -sS -X PUT "$BASE_URL/api/v1/publish/$slug/tags" \
    -H "authorization: Bearer $API_KEY" \
    -H "x-cresaone-client: $client_header_value" \
    -H "content-type: application/json" \
    -d "$body")
  if echo "$response" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
    err=$(echo "$response" | "$JQ_BIN" -r '.error')
    details=$(echo "$response" | "$JQ_BIN" -r '.details // empty')
    die "tag update failed: $err${details:+ ($details)}"
  fi
  out_tags=$(echo "$response" | "$JQ_BIN" -c '.tags // []')
  echo "publish_result.tags=$out_tags" >&2
}

fetch_site_details() {
  local slug="$1"
  curl -sS -X GET "$BASE_URL/api/v1/publish/$slug" \
    -H "authorization: Bearer $API_KEY" \
    -H "x-cresaone-client: $CLIENT_HEADER_VALUE"
}

build_viewer_json() {
  local slug="$1"
  local viewer="{}"
  if [[ -n "$slug" && -n "$API_KEY" ]]; then
    local response
    response=$(curl -sS -X GET "$BASE_URL/api/v1/publish/$slug" \
      -H "authorization: Bearer $API_KEY" \
      -H "x-cresaone-client: $CLIENT_HEADER_VALUE")
    if echo "$response" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
      err=$(echo "$response" | "$JQ_BIN" -r '.error')
      details=$(echo "$response" | "$JQ_BIN" -r '.details // empty')
      die "metadata fetch failed: $err${details:+ ($details)}"
    fi
    viewer=$(echo "$response" | "$JQ_BIN" -c '.viewer // {}')
  fi
  [[ -n "$TITLE" ]] && viewer=$(echo "$viewer" | "$JQ_BIN" --arg t "$TITLE" '.title = $t')
  [[ -n "$DESCRIPTION" ]] && viewer=$(echo "$viewer" | "$JQ_BIN" --arg d "$DESCRIPTION" '.description = $d')
  [[ -n "$OG_IMAGE_PATH" ]] && viewer=$(echo "$viewer" | "$JQ_BIN" --arg p "$OG_IMAGE_PATH" '.ogImagePath = $p')
  echo "$viewer"
}

patch_metadata() {
  local slug="$1"
  local body="{}"
  if [[ -n "$TTL" ]]; then
    body=$(echo "$body" | "$JQ_BIN" --argjson t "$TTL" '.ttlSeconds = $t')
  fi
  if [[ "$SPA_MODE" == "true" ]]; then
    body=$(echo "$body" | "$JQ_BIN" '.spaMode = true')
  fi
  if has_viewer_fields; then
    local viewer
    viewer=$(build_viewer_json "$slug")
    body=$(echo "$body" | "$JQ_BIN" --argjson v "$viewer" '.viewer = $v')
  fi
  [[ "$body" != "{}" ]] || return 0

  echo "patching metadata..." >&2
  local response
  response=$(curl -sS -X PATCH "$BASE_URL/api/v1/publish/$slug/metadata" \
    -H "authorization: Bearer $API_KEY" \
    -H "x-cresaone-client: $CLIENT_HEADER_VALUE" \
    -H "content-type: application/json" \
    -d "$body")
  if echo "$response" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
    err=$(echo "$response" | "$JQ_BIN" -r '.error')
    details=$(echo "$response" | "$JQ_BIN" -r '.details // empty')
    die "metadata update failed: $err${details:+ ($details)}"
  fi
  echo "publish_result.metadata_updated=true" >&2
}

verify_site_metadata() {
  local slug="$1"
  if [[ -z "$API_KEY" ]]; then
    if has_viewer_fields; then
      echo "verification note: viewer metadata round-trip requires owner authentication; live files will still be verified" >&2
    fi
    return 0
  fi

  local details failures=0 actual expected
  details=$(fetch_site_details "$slug")
  if printf '%s' "$details" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
    die "metadata verification failed: $(api_error_message "$details" "unexpected response")"
  fi

  if [[ -n "$TITLE" ]]; then
    actual=$(printf '%s' "$details" | "$JQ_BIN" -r '.viewer.title // empty')
    [[ "$actual" == "$TITLE" ]] || { echo "verification mismatch: viewer.title expected=$TITLE actual=$actual" >&2; failures=$((failures + 1)); }
  fi
  if [[ -n "$DESCRIPTION" ]]; then
    actual=$(printf '%s' "$details" | "$JQ_BIN" -r '.viewer.description // empty')
    [[ "$actual" == "$DESCRIPTION" ]] || { echo "verification mismatch: viewer.description expected=$DESCRIPTION actual=$actual" >&2; failures=$((failures + 1)); }
  fi
  if [[ -n "$OG_IMAGE_PATH" ]]; then
    actual=$(printf '%s' "$details" | "$JQ_BIN" -r '.viewer.ogImagePath // empty')
    [[ "$actual" == "$OG_IMAGE_PATH" ]] || { echo "verification mismatch: viewer.ogImagePath expected=$OG_IMAGE_PATH actual=$actual" >&2; failures=$((failures + 1)); }
  fi
  if [[ -n "$TAGS_JSON" ]]; then
    actual=$(printf '%s' "$details" | "$JQ_BIN" -c '.tags // [] | sort')
    expected=$(printf '%s' "$TAGS_JSON" | "$JQ_BIN" -c '
      map(gsub("^[[:space:]]+|[[:space:]]+$"; "") | ascii_downcase)
      | map(select(length > 0 and length <= 32))
      | reduce .[] as $tag ([]; if index($tag) then . else . + [$tag] end)
      | .[0:50]
      | sort
    ')
    [[ "$actual" == "$expected" ]] || { echo "verification mismatch: tags expected=$expected actual=$actual" >&2; failures=$((failures + 1)); }
  fi
  [[ "$failures" -eq 0 ]] || die "$failures metadata verification check(s) failed"
  echo "metadata verification passed" >&2
}

if [[ "$METADATA_ONLY" == "true" ]]; then
  [[ -n "$API_KEY" ]] || die "--metadata-only requires an authenticated Site; set CRESAONE_API_KEY or ~/.cresaone/credentials"
  if ! has_viewer_fields && [[ -z "$TTL" && "$SPA_MODE" != "true" && -z "$TAGS_JSON" ]]; then
    die "--metadata-only requires --title, --description, --og-image-path, --ttl, --spa, or --tags"
  fi
  patch_metadata "$SLUG"
  apply_tags "$SLUG" "$CLIENT_HEADER_VALUE"
  [[ "$VERIFY" -eq 0 ]] || verify_site_metadata "$SLUG"
  site_details=$(fetch_site_details "$SLUG")
  if printf '%s' "$site_details" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
    die "Site URL fetch failed: $(api_error_message "$site_details" "unexpected response")"
  fi
  SITE_URL=$(printf '%s' "$site_details" | "$JQ_BIN" -r '.siteUrl // empty')
  [[ -n "$SITE_URL" ]] || die "Site details returned no siteUrl"
  echo "$SITE_URL"
  echo "" >&2
  echo "publish_result.site_url=$SITE_URL" >&2
  echo "publish_result.slug=$SLUG" >&2
  echo "publish_result.action=metadata" >&2
  echo "publish_result.auth_mode=authenticated" >&2
  echo "publish_result.api_key_source=$API_KEY_SOURCE" >&2
  exit 0
fi

# Auto-load claim token from state file for slug updates (server uses it only for
# anonymous sites; harmless when an API key is also present).
if [[ "$CREATE" -eq 0 && -n "$SLUG" && -z "$CLAIM_TOKEN" && -f "$STATE_FILE" ]]; then
  CLAIM_TOKEN=$("$JQ_BIN" -r --arg s "$SLUG" '.publishes[$s].claimToken // empty' "$STATE_FILE" 2>/dev/null || true)
fi

if [[ -n "$FROM_DRIVE" ]]; then
  [[ -n "$API_KEY" ]] || die "--from-drive requires an account API key"
  BODY=$("$JQ_BIN" -n --arg d "$FROM_DRIVE" '{driveId:$d}')
  [[ -n "$DRIVE_VERSION" ]] && BODY=$(echo "$BODY" | "$JQ_BIN" --arg v "$DRIVE_VERSION" '.versionId = $v')
  [[ -n "$SLUG" ]] && BODY=$(echo "$BODY" | "$JQ_BIN" --arg s "$SLUG" '.slug = $s')
  if has_viewer_fields; then
    viewer=$(build_viewer_json "")
    BODY=$(echo "$BODY" | "$JQ_BIN" --argjson v "$viewer" '.viewer = $v')
  fi
  [[ "$SPA_MODE" == "true" ]] && BODY=$(echo "$BODY" | "$JQ_BIN" '.spaMode = true')

  echo "publishing from Drive..." >&2
  RESPONSE=$(curl -sS -X POST "$BASE_URL/api/v1/publish/from-drive" \
    -H "authorization: Bearer $API_KEY" \
    -H "x-cresaone-client: $CLIENT_HEADER_VALUE" \
    -H "content-type: application/json" \
    -d "$BODY")
  if echo "$RESPONSE" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
    err=$(echo "$RESPONSE" | "$JQ_BIN" -r '.error')
    die "$err"
  fi
  SITE_URL=$(echo "$RESPONSE" | "$JQ_BIN" -r '.siteUrl')
  OUT_SLUG=$(echo "$RESPONSE" | "$JQ_BIN" -r '.slug')
  CURRENT_VERSION=$(echo "$RESPONSE" | "$JQ_BIN" -r '.currentVersionId')
  DRIVE_VERSION_OUT=$(echo "$RESPONSE" | "$JQ_BIN" -r '.driveVersionId')
  echo "$SITE_URL"
  apply_tags "$OUT_SLUG" "$CLIENT_HEADER_VALUE"
  if [[ "$VERIFY" -eq 1 ]]; then
    echo "verification note: Drive publishes have no local file tree; verifying requested metadata only" >&2
    verify_site_metadata "$OUT_SLUG"
  fi
  echo "" >&2
  echo "publish_result.site_url=$SITE_URL" >&2
  echo "publish_result.slug=$OUT_SLUG" >&2
  echo "publish_result.action=from_drive" >&2
  echo "publish_result.auth_mode=authenticated" >&2
  echo "publish_result.api_key_source=$API_KEY_SOURCE" >&2
  echo "publish_result.persistence=permanent" >&2
  echo "publish_result.drive_id=$FROM_DRIVE" >&2
  echo "publish_result.drive_version_id=$DRIVE_VERSION_OUT" >&2
  echo "publish_result.current_version_id=$CURRENT_VERSION" >&2
  exit 0
fi

compute_sha256() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | cut -d' ' -f1
  else
    shasum -a 256 "$f" | cut -d' ' -f1
  fi
}

guess_content_type() {
  local f="$1"
  local ext="${f##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    html|htm) echo "text/html; charset=utf-8" ;;
    css)      echo "text/css; charset=utf-8" ;;
    js|mjs|cjs) echo "text/javascript; charset=utf-8" ;;
    json)     echo "application/json; charset=utf-8" ;;
    jsonld)   echo "application/ld+json; charset=utf-8" ;;
    map)      echo "application/json; charset=utf-8" ;;
    md|txt|log) echo "text/plain; charset=utf-8" ;;
    csv)      echo "text/csv; charset=utf-8" ;;
    tsv)      echo "text/tab-separated-values; charset=utf-8" ;;
    yaml|yml) echo "application/yaml; charset=utf-8" ;;
    toml)     echo "application/toml; charset=utf-8" ;;
    svg)      echo "image/svg+xml" ;;
    png)      echo "image/png" ;;
    jpg|jpeg) echo "image/jpeg" ;;
    gif)      echo "image/gif" ;;
    webp)     echo "image/webp" ;;
    avif)     echo "image/avif" ;;
    bmp)      echo "image/bmp" ;;
    tif|tiff) echo "image/tiff" ;;
    heic)     echo "image/heic" ;;
    heif)     echo "image/heif" ;;
    ico)      echo "image/x-icon" ;;
    pdf)      echo "application/pdf" ;;
    wasm)     echo "application/wasm" ;;
    webmanifest) echo "application/manifest+json; charset=utf-8" ;;
    zip)      echo "application/zip" ;;
    gz)       echo "application/gzip" ;;
    tar)      echo "application/x-tar" ;;
    tgz)      echo "application/gzip" ;;
    parquet)  echo "application/vnd.apache.parquet" ;;
    sqlite|sqlite3|db) echo "application/vnd.sqlite3" ;;
    mp4)      echo "video/mp4" ;;
    m4v)      echo "video/mp4" ;;
    mov)      echo "video/quicktime" ;;
    webm)     echo "video/webm" ;;
    ogv)      echo "video/ogg" ;;
    mpeg|mpg) echo "video/mpeg" ;;
    avi)      echo "video/x-msvideo" ;;
    mp3)      echo "audio/mpeg" ;;
    wav)      echo "audio/wav" ;;
    flac)     echo "audio/flac" ;;
    aiff|aif|aifc) echo "audio/aiff" ;;
    alac)     echo "audio/mp4" ;;
    m4a)      echo "audio/mp4" ;;
    aac)      echo "audio/aac" ;;
    ogg|oga)  echo "audio/ogg" ;;
    opus)     echo "audio/opus" ;;
    midi|mid) echo "audio/midi" ;;
    caf)      echo "audio/x-caf" ;;
    weba)     echo "audio/webm" ;;
    xml)      echo "application/xml; charset=utf-8" ;;
    woff2)    echo "font/woff2" ;;
    woff)     echo "font/woff" ;;
    ttf)      echo "font/ttf" ;;
    otf)      echo "font/otf" ;;
    eot)      echo "application/vnd.ms-fontobject" ;;
    gltf)     echo "model/gltf+json" ;;
    glb)      echo "model/gltf-binary" ;;
    usdz)     echo "model/vnd.usdz+zip" ;;
    stl)      echo "model/stl" ;;
    *)
      local detected
      detected=$(file --brief --mime-type "$f" 2>/dev/null || echo "application/octet-stream")
      echo "$detected"
      ;;
  esac
}

# Build file manifest as JSON array
FILES_JSON="[]"

if [[ -f "$TARGET" ]]; then
  sz=$(wc -c < "$TARGET" | tr -d ' ')
  ct=$(guess_content_type "$TARGET")
  bn=$(basename "$TARGET")
  h=$(compute_sha256 "$TARGET")
  FILES_JSON=$("$JQ_BIN" -n --arg p "$bn" --argjson s "$sz" --arg c "$ct" --arg h "$h" \
    '[{"path":$p,"size":$s,"contentType":$c,"hash":$h}]')
  FILE_MAP=$("$JQ_BIN" -n --arg p "$bn" --arg a "$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")" \
    '{($p):$a}')
elif [[ -d "$TARGET" ]]; then
  FILE_MAP="{}"
  while IFS= read -r -d '' f; do
    rel="${f#$TARGET/}"
    [[ "$rel" == ".DS_Store" ]] && continue
    [[ "$(basename "$rel")" == ".DS_Store" ]] && continue
    [[ "$rel" == .cresaone/* ]] && continue
    sz=$(wc -c < "$f" | tr -d ' ')
    ct=$(guess_content_type "$f")
    h=$(compute_sha256 "$f")
    abs=$(cd "$(dirname "$f")" && pwd)/$(basename "$f")
    FILES_JSON=$(echo "$FILES_JSON" | "$JQ_BIN" --arg p "$rel" --argjson s "$sz" --arg c "$ct" --arg h "$h" \
      '. + [{"path":$p,"size":$s,"contentType":$c,"hash":$h}]')
    FILE_MAP=$(echo "$FILE_MAP" | "$JQ_BIN" --arg p "$rel" --arg a "$abs" '. + {($p):$a}')
  done < <(find "$TARGET" -type f -print0 | sort -z)
else
  die "not a file or directory: $TARGET"
fi

file_count=$(echo "$FILES_JSON" | "$JQ_BIN" 'length')
[[ "$file_count" -gt 0 ]] || die "no files found"

verify_live_files() {
  local slug="$1"
  local site_url="$2"
  local selected selected_count failures=0 index=0
  local temp_dir file_path expected_type local_file encoded_path verify_url headers_file body_file
  local http_code actual_type local_hash live_hash local_size live_size normalized_expected normalized_actual

  if [[ -n "$API_KEY" ]]; then
    local access_response access_mode
    access_response=$(curl -sS -X GET "$BASE_URL/api/v1/publish/$slug/access" \
      -H "authorization: Bearer $API_KEY" \
      -H "x-cresaone-client: $CLIENT_HEADER_VALUE")
    if ! printf '%s' "$access_response" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
      access_mode=$(printf '%s' "$access_response" | "$JQ_BIN" -r '.access.mode // "anyone_with_link"')
      if [[ "$access_mode" != "anyone_with_link" ]]; then
        die "publish succeeded, but live byte verification is unavailable for $access_mode Sites; rerun with --no-verify and verify owner metadata separately"
      fi
    fi
  fi

  selected=$(printf '%s' "$FILES_JSON" | "$JQ_BIN" -c --argjson limit "$VERIFY_LIMIT" --arg og "${OG_IMAGE_PATH#/}" '
    ([.[0:$limit][]] + [.[] | select(
      ((.contentType // "") | startswith("text/html")) or
      ($og != "" and .path == $og)
    )]) | unique_by(.path)
  ')
  selected_count=$(printf '%s' "$selected" | "$JQ_BIN" 'length')
  if [[ "$selected_count" -lt "$file_count" ]]; then
    echo "verifying $selected_count of $file_count files (first $VERIFY_LIMIT plus all HTML and selected OG image)..." >&2
  else
    echo "verifying $selected_count live files..." >&2
  fi

  temp_dir=$(mktemp -d)
  while [[ "$index" -lt "$selected_count" ]]; do
    file_path=$(printf '%s' "$selected" | "$JQ_BIN" -r ".[$index].path")
    expected_type=$(printf '%s' "$selected" | "$JQ_BIN" -r ".[$index].contentType // \"application/octet-stream\"")
    local_file=$(printf '%s' "$FILE_MAP" | "$JQ_BIN" -r --arg path "$file_path" '.[$path] // empty')
    headers_file="$temp_dir/headers-$index"
    body_file="$temp_dir/body-$index"
    encoded_path=$(printf '%s' "$file_path" | "$JQ_BIN" -sRr @uri | sed 's/%2F/\//g')
    verify_url="${site_url%/}/$encoded_path?cresaverify=$(date +%s)-$index"
    http_code=$(curl -sS -D "$headers_file" -o "$body_file" -w '%{http_code}' "$verify_url" || true)
    actual_type=$(awk 'tolower($0) ~ /^content-type:/ { sub(/\r$/, ""); sub(/^[^:]*:[[:space:]]*/, ""); value=$0 } END { print value }' "$headers_file")

    if [[ ! -f "$local_file" || ! "$http_code" =~ ^[0-9]{3}$ || "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
      echo "verification failed: $file_path HTTP ${http_code:-unknown}" >&2
      failures=$((failures + 1))
      index=$((index + 1))
      continue
    fi

    local_hash=$(compute_sha256 "$local_file")
    live_hash=$(compute_sha256 "$body_file")
    local_size=$(wc -c < "$local_file" | tr -d ' ')
    live_size=$(wc -c < "$body_file" | tr -d ' ')
    normalized_expected=$(printf '%s' "$expected_type" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    normalized_actual=$(printf '%s' "$actual_type" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

    if [[ "$local_hash" != "$live_hash" || "$local_size" != "$live_size" ]]; then
      echo "verification failed: $file_path" >&2
      echo "  local hash=$local_hash size=$local_size" >&2
      echo "  live  hash=$live_hash size=$live_size" >&2
      failures=$((failures + 1))
    fi
    if [[ "$normalized_expected" != "$normalized_actual" ]]; then
      echo "verification failed: $file_path content-type expected=$expected_type actual=${actual_type:-missing}" >&2
      failures=$((failures + 1))
    fi
    index=$((index + 1))
  done
  rm -rf "$temp_dir"

  [[ "$failures" -eq 0 ]] || die "$failures live verification check(s) failed"
  echo "live file verification passed" >&2
  verify_site_metadata "$slug"
}

# Build request body
BODY=$(echo "$FILES_JSON" | "$JQ_BIN" '{files: .}')

if [[ -n "$TTL" ]]; then
  BODY=$(echo "$BODY" | "$JQ_BIN" --argjson t "$TTL" '.ttlSeconds = $t')
fi

if has_viewer_fields; then
  # New Sites have no existing viewer metadata to merge, so skip the GET.
  if [[ "$CREATE" -eq 1 ]]; then
    viewer=$(build_viewer_json "")
  else
    viewer=$(build_viewer_json "$SLUG")
  fi
  BODY=$(echo "$BODY" | "$JQ_BIN" --argjson v "$viewer" '.viewer = $v')
fi

if [[ "$CREATE" -eq 0 && -n "$CLAIM_TOKEN" && -n "$SLUG" ]]; then
  BODY=$(echo "$BODY" | "$JQ_BIN" --arg ct "$CLAIM_TOKEN" '.claimToken = $ct')
fi

if [[ "$SPA_MODE" == "true" ]]; then
  BODY=$(echo "$BODY" | "$JQ_BIN" '.spaMode = true')
fi

# Determine endpoint and method
if [[ "$CREATE" -eq 1 ]]; then
  if [[ -n "$SLUG" ]]; then
    require_owner_auth "--create --slug"
    BODY=$(echo "$BODY" | "$JQ_BIN" --arg s "$SLUG" '.slug = $s')
  fi
  URL="$BASE_URL/api/v1/publish"
  METHOD="POST"
elif [[ -n "$SLUG" ]]; then
  URL="$BASE_URL/api/v1/publish/$SLUG"
  METHOD="PUT"
else
  URL="$BASE_URL/api/v1/publish"
  METHOD="POST"
fi

# Build auth header
AUTH_ARGS=()
if [[ -n "$API_KEY" ]]; then
  AUTH_ARGS=(-H "authorization: Bearer $API_KEY")
fi

AUTH_MODE="anonymous"
if [[ -n "$API_KEY" ]]; then
  AUTH_MODE="authenticated"
fi

CLIENT_ARGS=(-H "x-cresaone-client: $CLIENT_HEADER_VALUE")

# Step 1: Create/update publish
echo "creating publish ($file_count files)..." >&2
RESPONSE=$(curl -sS -X "$METHOD" "$URL" \
  "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
  "${CLIENT_ARGS[@]+"${CLIENT_ARGS[@]}"}" \
  -H "content-type: application/json" \
  -d "$BODY")

# Check for errors
if echo "$RESPONSE" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
  err=$(echo "$RESPONSE" | "$JQ_BIN" -r '.error')
  details=$(echo "$RESPONSE" | "$JQ_BIN" -r '.details // empty')
  die "$err${details:+ ($details)}"
fi

OUT_SLUG=$(echo "$RESPONSE" | "$JQ_BIN" -r '.slug')
VERSION_ID=$(echo "$RESPONSE" | "$JQ_BIN" -r '.upload.versionId')
FINALIZE_URL=$(echo "$RESPONSE" | "$JQ_BIN" -r '.upload.finalizeUrl')
SITE_URL=$(echo "$RESPONSE" | "$JQ_BIN" -r '.siteUrl')
UPLOAD_COUNT=$(echo "$RESPONSE" | "$JQ_BIN" '.upload.uploads | length')
SKIPPED_COUNT=$(echo "$RESPONSE" | "$JQ_BIN" '.upload.skipped // [] | length')

[[ "$OUT_SLUG" != "null" ]] || die "unexpected response: $RESPONSE"

# Step 2: Upload files (skipped files are unchanged from previous version)
if [[ "$SKIPPED_COUNT" -gt 0 ]]; then
  echo "uploading $UPLOAD_COUNT files ($SKIPPED_COUNT unchanged, skipped)..." >&2
else
  echo "uploading $UPLOAD_COUNT files..." >&2
fi
upload_errors=0

for i in $(seq 0 $((UPLOAD_COUNT - 1))); do
  upload_path=$(echo "$RESPONSE" | "$JQ_BIN" -r ".upload.uploads[$i].path")
  upload_url=$(echo "$RESPONSE" | "$JQ_BIN" -r ".upload.uploads[$i].url")
  upload_ct=$(echo "$RESPONSE" | "$JQ_BIN" -r ".upload.uploads[$i].headers[\"Content-Type\"] // empty")

  if [[ -f "$TARGET" && ! -d "$TARGET" ]]; then
    local_file="$TARGET"
  else
    local_file=$(echo "$FILE_MAP" | "$JQ_BIN" -r --arg p "$upload_path" '.[$p]')
  fi

  if [[ ! -f "$local_file" ]]; then
    echo "warning: missing local file for $upload_path" >&2
    upload_errors=$((upload_errors + 1))
    continue
  fi

  ct_args=()
  if [[ -n "$upload_ct" ]]; then
    ct_args=(-H "Content-Type: $upload_ct")
  else
    ct_args=(-H "Content-Type: $(guess_content_type "$local_file")")
  fi

  http_code=$(curl -sS -o /dev/null -w "%{http_code}" -X PUT "$upload_url" \
    "${ct_args[@]+"${ct_args[@]}"}" \
    --data-binary "@$local_file")

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    echo "warning: upload failed for $upload_path (HTTP $http_code)" >&2
    upload_errors=$((upload_errors + 1))
  fi
done

[[ "$upload_errors" -eq 0 ]] || die "$upload_errors file(s) failed to upload"

# Step 3: Finalize
echo "finalizing..." >&2
FIN_RESPONSE=$(curl -sS -X POST "$FINALIZE_URL" \
  "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
  "${CLIENT_ARGS[@]+"${CLIENT_ARGS[@]}"}" \
  -H "content-type: application/json" \
  -d "{\"versionId\":\"$VERSION_ID\"}")

if echo "$FIN_RESPONSE" | "$JQ_BIN" -e '.error' >/dev/null 2>&1; then
  err=$(echo "$FIN_RESPONSE" | "$JQ_BIN" -r '.error')
  die "finalize failed: $err"
fi

# Save state
mkdir -p "$STATE_DIR"
if [[ -f "$STATE_FILE" ]]; then
  STATE=$(cat "$STATE_FILE")
else
  STATE='{"publishes":{}}'
fi

entry=$("$JQ_BIN" -n --arg s "$SITE_URL" '{siteUrl: $s}')

RESPONSE_CLAIM_TOKEN=$(echo "$RESPONSE" | "$JQ_BIN" -r '.claimToken // empty')
RESPONSE_CLAIM_URL=$(echo "$RESPONSE" | "$JQ_BIN" -r '.claimUrl // empty')
RESPONSE_EXPIRES=$(echo "$RESPONSE" | "$JQ_BIN" -r '.expiresAt // empty')

[[ -n "$RESPONSE_CLAIM_TOKEN" ]] && entry=$(echo "$entry" | "$JQ_BIN" --arg v "$RESPONSE_CLAIM_TOKEN" '.claimToken = $v')
[[ -n "$RESPONSE_CLAIM_URL" ]] && entry=$(echo "$entry" | "$JQ_BIN" --arg v "$RESPONSE_CLAIM_URL" '.claimUrl = $v')
[[ -n "$RESPONSE_EXPIRES" ]] && entry=$(echo "$entry" | "$JQ_BIN" --arg v "$RESPONSE_EXPIRES" '.expiresAt = $v')

STATE=$(echo "$STATE" | "$JQ_BIN" --arg slug "$OUT_SLUG" --argjson e "$entry" '.publishes[$slug] = $e')
save_state_json "$STATE"

apply_tags "$OUT_SLUG" "$CLIENT_HEADER_VALUE"

if [[ "$VERIFY" -eq 1 ]]; then
  verify_live_files "$OUT_SLUG" "$SITE_URL"
else
  echo "post-publish verification skipped (--no-verify)" >&2
fi

# Output
echo "$SITE_URL"

PERSISTENCE="permanent"
if [[ "$AUTH_MODE" == "anonymous" ]]; then
  PERSISTENCE="expires_24h"
elif [[ -n "$RESPONSE_EXPIRES" ]]; then
  PERSISTENCE="expires_at"
fi

SAFE_CLAIM_URL=""
if [[ -n "$RESPONSE_CLAIM_URL" && "$RESPONSE_CLAIM_URL" == https://* ]]; then
  SAFE_CLAIM_URL="$RESPONSE_CLAIM_URL"
fi

ACTION="create"
if [[ "$CREATE" -eq 0 && -n "$SLUG" ]]; then
  ACTION="update"
fi

echo "" >&2
echo "publish_result.site_url=$SITE_URL" >&2
echo "publish_result.slug=$OUT_SLUG" >&2
echo "publish_result.action=$ACTION" >&2
echo "publish_result.auth_mode=$AUTH_MODE" >&2
echo "publish_result.api_key_source=$API_KEY_SOURCE" >&2
echo "publish_result.persistence=$PERSISTENCE" >&2
echo "publish_result.expires_at=$RESPONSE_EXPIRES" >&2
echo "publish_result.claim_url=$SAFE_CLAIM_URL" >&2

if [[ "$AUTH_MODE" == "authenticated" ]]; then
  echo "authenticated publish (permanent, saved to your account)" >&2
else
  echo "anonymous publish (expires in 24h)" >&2
  if [[ -n "$SAFE_CLAIM_URL" ]]; then
    echo "claim URL: $SAFE_CLAIM_URL" >&2
  fi
  if [[ -n "$RESPONSE_CLAIM_TOKEN" ]]; then
    echo "claim token saved to $STATE_FILE" >&2
  fi
fi
