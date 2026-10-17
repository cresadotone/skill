#!/usr/bin/env bash
# ship.sh - the complete publish, in one step.
#
# Wraps publish.sh with metadata preparation and verified access controls.
#   credentials -> semantic slug -> OG image -> head metadata -> upload + finalize ->
#   Site title/description/OG path/tags -> access mode -> profile listing -> live checks ->
#   deliverables copied out with a report.
#
# Run with bash (skill files are often mounted read-only and non-executable):
#   bash scripts/ship.sh ./dist --slug market-rent-calculator \
#     --title "Market Rent Calculator" --description "..." --keywords "a, b, c"
set -euo pipefail

BASE_URL="https://cresa.one"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET="" SLUG="" RENAME_FROM="" TITLE="" DESCRIPTION="" OG_DESCRIPTION="" KEYWORDS="" TAGS=""
PRIVACY="private" ACCESS="" PASSWORD="" ALLOW_EMAILS="" ALLOW_DOMAINS="" LIST_ON_PROFILE=""
OG_FILE="" OG_HTML="" OG_ART="" OG_HEADLINE="" OG_MUTED="" OG_TOKENS="" OG_FONT="" OG_ALT="" NO_OG=0
SITE_NAME="" AUTHOR="" THEME_COLOR="" JSON_LD="WebSite" APP_CATEGORY=""
OUT_DIR="" CLIENT="agent" DRY_RUN=0 ALLOW_GENERATED_SLUG=0 SPA=0

usage() {
  cat <<'USAGE'
Usage: bash ship.sh <file-or-dir> --slug <semantic-slug> --title <text> --description <text> [options]

Required
  --slug <slug>              Semantic, human-readable, 3-63 chars. Created if free, updated if you own it.
  --title <text>             Page + Site title (aim for 60 chars or fewer)
  --description <text>       Page + Site description (50 to 200 chars)

Metadata
  --keywords "a, b, c"       meta keywords; also seeds Site tags when --tags is absent
  --tags '["a","b"]'         Site tags (JSON array)
  --og-description <text>    Shorter copy for link previews (defaults to --description)
  --site-name <text>         og:site_name / app name (defaults to the title's first segment)
  --author <text>            meta author
  --theme-color <color>      Added only when the page has none
  --json-ld <type>           WebSite (default) | WebApplication | none
  --app-category <text>      schema.org applicationCategory for WebApplication

Open Graph image (first match wins; result is always /og.png, 1200x630)
  --og <image.png>           Use this image
  --og-html <card.html>      Render a fully custom 1200x630 HTML card
  --og-headline <text>       Headline for the token card (defaults to the title)
  --og-muted <text>          Muted continuation of the headline
  --og-tokens "bg=..;panel=..;hairline=..;ink=..;muted=..;primary=..;signal=.."
  --og-art <art.svg>         Inline SVG for the card's right panel
  --og-font <font.woff2>     Font to embed in the card
  --og-alt <text>            og:image:alt
  --no-og                    Skip the managed preview image and clear old viewer image metadata
  (an og.png already beside index.html is kept as-is)

Privacy and access
  --privacy private|public   private (default): noindex, no-referrer, removed from your profile list.
                             public: indexable; profile listing untouched unless --list.
  --access <mode>            anyone_with_link | password | restricted (default: leave unchanged)
  --password <text>          Password override (prefer $CRESAONE_SITE_PASSWORD)
  --allow-emails a@x,b@y     For --access restricted (full replacement)
  --allow-domains x.com      For --access restricted (full replacement)
  --list | --unlist          Force profile listing on or off

Other
  --rename-from <old-slug>   Rename an owned Site to --slug first (old URL 404s immediately)
  --spa                      Enable SPA routing
  --out <dir>                Where to copy deliverables (default: /mnt/user-data/outputs/<slug> when present)
  --client <name>            Attribution (default: agent)
  --allow-generated-slug     Permit word-word-a1b2 style slugs
  --dry-run                  Stage, build OG + metadata, print the plan; change nothing remotely
USAGE
  exit "${1:-1}"
}

die() { echo "error: $1" >&2; exit 1; }
note() { echo "ship: $1" >&2; }
need() { [[ -n "${2:-}" ]] || die "$1 requires a value"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) need "$1" "${2:-}"; SLUG="$2"; shift 2 ;;
    --rename-from) need "$1" "${2:-}"; RENAME_FROM="$2"; shift 2 ;;
    --title) need "$1" "${2:-}"; TITLE="$2"; shift 2 ;;
    --description) need "$1" "${2:-}"; DESCRIPTION="$2"; shift 2 ;;
    --og-description) need "$1" "${2:-}"; OG_DESCRIPTION="$2"; shift 2 ;;
    --keywords) need "$1" "${2:-}"; KEYWORDS="$2"; shift 2 ;;
    --tags) need "$1" "${2:-}"; TAGS="$2"; shift 2 ;;
    --site-name) need "$1" "${2:-}"; SITE_NAME="$2"; shift 2 ;;
    --author) need "$1" "${2:-}"; AUTHOR="$2"; shift 2 ;;
    --theme-color) need "$1" "${2:-}"; THEME_COLOR="$2"; shift 2 ;;
    --json-ld) need "$1" "${2:-}"; JSON_LD="$2"; shift 2 ;;
    --app-category) need "$1" "${2:-}"; APP_CATEGORY="$2"; shift 2 ;;
    --og) need "$1" "${2:-}"; OG_FILE="$2"; shift 2 ;;
    --og-html) need "$1" "${2:-}"; OG_HTML="$2"; shift 2 ;;
    --og-headline) need "$1" "${2:-}"; OG_HEADLINE="$2"; shift 2 ;;
    --og-muted) need "$1" "${2:-}"; OG_MUTED="$2"; shift 2 ;;
    --og-tokens) need "$1" "${2:-}"; OG_TOKENS="$2"; shift 2 ;;
    --og-art) need "$1" "${2:-}"; OG_ART="$2"; shift 2 ;;
    --og-font) need "$1" "${2:-}"; OG_FONT="$2"; shift 2 ;;
    --og-alt) need "$1" "${2:-}"; OG_ALT="$2"; shift 2 ;;
    --no-og) NO_OG=1; shift ;;
    --privacy) need "$1" "${2:-}"; PRIVACY="$2"; shift 2 ;;
    --access) need "$1" "${2:-}"; ACCESS="$2"; shift 2 ;;
    --password) need "$1" "${2:-}"; PASSWORD="$2"; shift 2 ;;
    --allow-emails) need "$1" "${2:-}"; ALLOW_EMAILS="$2"; shift 2 ;;
    --allow-domains) need "$1" "${2:-}"; ALLOW_DOMAINS="$2"; shift 2 ;;
    --list) LIST_ON_PROFILE="yes"; shift ;;
    --unlist) LIST_ON_PROFILE="no"; shift ;;
    --spa) SPA=1; shift ;;
    --out) need "$1" "${2:-}"; OUT_DIR="$2"; shift 2 ;;
    --client) need "$1" "${2:-}"; CLIENT="$2"; shift 2 ;;
    --allow-generated-slug) ALLOW_GENERATED_SLUG=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage 0 ;;
    -*) die "unknown option: $1" ;;
    *) [[ -z "$TARGET" ]] && TARGET="$1" || die "unexpected argument: $1"; shift ;;
  esac
done

# ---------------------------------------------------------------- 0. inputs
[[ -n "$TARGET" ]] || usage
[[ -e "$TARGET" ]] || die "$TARGET not found"
[[ -n "$SLUG" ]] || die "--slug is required. Pick a semantic name that says what the Site is (for example market-rent-calculator)."
[[ -n "$TITLE" ]] || die "--title is required"
[[ -n "$DESCRIPTION" ]] || die "--description is required"
[[ "$PRIVACY" == "private" || "$PRIVACY" == "public" ]] || die "--privacy must be private or public"
[[ "$SLUG" =~ ^[a-z0-9]([a-z0-9-]{1,61})[a-z0-9]$ && ! "$SLUG" =~ -- ]] || die "slug must be 3-63 chars of lowercase letters, digits and single hyphens"
if [[ "$ALLOW_GENERATED_SLUG" -eq 0 && "$SLUG" =~ ^[a-z]+-[a-z]+-[a-z0-9]{4}$ && "$SLUG" =~ [0-9] ]]; then
  die "'$SLUG' looks auto-generated. Choose a semantic slug, or pass --allow-generated-slug."
fi
case "$ACCESS" in
  ""|anyone_with_link|restricted) ;;
  password) PASSWORD="${PASSWORD:-${CRESAONE_SITE_PASSWORD:-}}"; [[ -n "$PASSWORD" ]] || die "--access password requires --password" ;;
  *) die "--access must be anyone_with_link, password or restricted" ;;
esac
if [[ "$ACCESS" == "restricted" && -z "$ALLOW_EMAILS$ALLOW_DOMAINS" ]]; then
  die "--access restricted requires --allow-emails and/or --allow-domains"
fi
[[ "${#TITLE}" -le 200 && "${#DESCRIPTION}" -le 2000 ]] || die "title must be at most 200 characters and description at most 2000"
[[ -z "$RENAME_FROM" || "$RENAME_FROM" =~ ^[a-z0-9]([a-z0-9-]{1,61})[a-z0-9]$ ]] || die "invalid --rename-from slug"
[[ "$JSON_LD" == WebSite || "$JSON_LD" == WebApplication || "$JSON_LD" == none ]] || die "invalid --json-ld type"
[[ "$LIST_ON_PROFILE" != yes || "$ACCESS" != password && "$ACCESS" != restricted ]] || die "protected Sites cannot be listed on a public profile"
command -v python3 >/dev/null 2>&1 || die "requires python3"
for cmd in curl file; do command -v "$cmd" >/dev/null 2>&1 || die "requires $cmd"; done

# ---------------------------------------------------------------- 1. dependencies
if [[ -x "${SKILL_DIR}/bin/jq" ]]; then
  PATH="${SKILL_DIR}/bin:$PATH"
fi
command -v jq >/dev/null 2>&1 || die "requires jq; install it or use https://cresa.one/install.sh"
export PATH

# Stage locally before any account writes. Do not upload credentials or symlinks.
STAGE="$(mktemp -d)"
WORK="$(mktemp -d)"
trap 'rm -rf "$STAGE" "$WORK"' EXIT
python3 - "$TARGET" "$STAGE" <<'STAGE_PY'
import shutil, sys
from pathlib import Path
source, dest = map(Path, sys.argv[1:])
def ignored(directory, names):
    return [n for n in names if n in {".git", ".cresaone", ".DS_Store", "cresaone_credentials.txt"}
            or n == ".env" or n.startswith(".env.")]
def copy_file(src, dst):
    if Path(src).is_symlink():
        raise ValueError("symlinks are not accepted in a Site bundle")
    return shutil.copy2(src, dst)
if source.is_symlink():
    raise ValueError("symlinks are not accepted in a Site bundle")
if source.is_dir():
    shutil.copytree(source, dest, dirs_exist_ok=True, ignore=ignored, copy_function=copy_file, symlinks=True)
    if any(p.is_symlink() for p in dest.rglob("*")):
        raise ValueError("symlinks are not accepted in a Site bundle")
else:
    if source.name in ignored(source.parent, [source.name]):
        raise ValueError("credential files cannot be published")
    copy_file(source, dest / ("index.html" if source.suffix.lower() in {".html", ".htm"} else source.name))
STAGE_PY
HAS_INDEX=0; [[ -f "$STAGE/index.html" ]] && HAS_INDEX=1
SITE_URL="https://${SLUG}.cresa.one/"

# ---------------------------------------------------------------- 2. credentials
# Resolve credentials only after dry-run staging, and never send them in argv.
normalize_key() {
  python3 -c '
import base64, re, sys
raw = sys.stdin.read().strip()
raw = re.sub(r"^[A-Z_][A-Z0-9_]*=", "", raw).strip().strip("\"\047")
if not raw.startswith("csk_"):
    try:
        raw = base64.b64decode(raw, validate=True).decode().strip()
    except (ValueError, UnicodeError):
        raise SystemExit("error: invalid API key encoding")
if not re.fullmatch(r"csk_[A-Za-z0-9_-]+", raw):
    raise SystemExit("error: expected a csk_ API key")
sys.stdout.write(raw)
'
}

# api updates API_STATUS and API_BODY in this shell; never call it in $(...).
api() {
  local method="$1" path="$2" body="${3:-}" allowed="${4:-}"
  local args=(--silent --show-error --connect-timeout 10 --max-time 60
    --output "$WORK/response.json" --write-out '%{http_code}'
    --request "$method" --header "@$WORK/headers" "$BASE_URL$path")
  if [[ -n "$body" ]]; then
    (umask 077; printf '%s' "$body" > "$WORK/request.json")
    args+=(--data-binary "@$WORK/request.json")
  fi
  API_STATUS="$(curl "${args[@]}")" || die "request failed: $method $path"
  API_BODY="$(cat "$WORK/response.json")"
  [[ "$API_STATUS" =~ ^2[0-9][0-9]$ || -n "$allowed" && "$API_STATUS" == "$allowed" ]] \
    || die "$method $path failed (HTTP $API_STATUS)"
  printf '%s' "$API_BODY" | jq -e 'type == "object"' >/dev/null \
    || die "$method $path returned invalid JSON"
}

# ---------------------------------------------------------------- 5. OG image -> /og.png
OG_SOURCE="none"
if [[ "$NO_OG" -eq 0 && "$HAS_INDEX" -eq 1 ]]; then
  if [[ -n "$OG_FILE" ]]; then
    [[ -f "$OG_FILE" ]] || die "--og $OG_FILE not found"
    cp "$OG_FILE" "$STAGE/og.png"; OG_SOURCE="file"
  elif [[ -n "$OG_HTML" ]]; then
    python3 "$SCRIPT_DIR/og-card.py" --html "$OG_HTML" --out "$STAGE/og.png" || die "could not render --og-html (needs python playwright + chromium)"
    OG_SOURCE="custom-html"
  elif [[ -f "$STAGE/og.png" ]]; then
    OG_SOURCE="existing"
  else
    # "Name – What it does" titles split into card name + headline, so the name is not printed twice.
    TITLE_NAME="$TITLE"; TITLE_REST="$TITLE"
    for sep in " – " " - " " | " ": "; do
      if [[ "$TITLE" == *"$sep"* ]]; then TITLE_NAME="${TITLE%%"$sep"*}"; TITLE_REST="${TITLE#*"$sep"}"; break; fi
    done
    CARD_ARGS=(--out "$STAGE/og.png" --name "${SITE_NAME:-$TITLE_NAME}" --headline "${OG_HEADLINE:-$TITLE_REST}" --headline-muted "$OG_MUTED" --footer "${SLUG}.cresa.one" --tokens "$OG_TOKENS")
    [[ -n "$OG_ART" ]] && CARD_ARGS+=(--art "$OG_ART")
    [[ -n "$OG_FONT" ]] && CARD_ARGS+=(--font-file "$OG_FONT")
    set +e; python3 "$SCRIPT_DIR/og-card.py" "${CARD_ARGS[@]}"; CARD_RC=$?; set -e
    if [[ "$CARD_RC" -eq 0 ]]; then
      OG_SOURCE="token-card"
    elif [[ "$CARD_RC" -eq 3 ]]; then
      note "no browser for the token card; falling back to og-image.py (house style)"
      OG_TMP="$WORK/og"; mkdir -p "$OG_TMP"
      if python3 -c "import PIL" >/dev/null 2>&1; then OG_RUN=(python3 "$SCRIPT_DIR/og-image.py")
      elif command -v uv >/dev/null 2>&1; then
        OG_RUN=(uv run)
        [[ "$DRY_RUN" -eq 1 ]] && OG_RUN+=(--offline)
        OG_RUN+=("$SCRIPT_DIR/og-image.py")
      else die "no browser, no Pillow and no uv: cannot render an OG card. Pass --og <image.png> or --no-og."; fi
      # og-image.py sets --title as a short display name and refuses text that cannot fit, so it gets the name and the rest goes below it.
      "${OG_RUN[@]}" --title "${SITE_NAME:-$TITLE_NAME}" --subtitle "${OG_HEADLINE:-$TITLE_REST}" --signal "$OG_MUTED" --footer "${SLUG}.cresa.one" --layout editorial-right --out "$OG_TMP" >&2 \
        || die "og-image.py could not fit the text. Shorten the name before the title separator, or pass --og <image.png> / --no-og."
      OG_PICK="$(find "$OG_TMP" -maxdepth 1 -name '*.png' ! -name '*_thumb.png' | head -n1)"
      [[ -n "$OG_PICK" ]] || die "og-image.py produced no card"
      cp "$OG_PICK" "$STAGE/og.png"; rm -rf "$OG_TMP"; OG_SOURCE="og-image.py"
    else
      die "og-card.py failed"
    fi
  fi
  DIMS="$(python3 - "$STAGE/og.png" <<'PY'
import struct, sys
with open(sys.argv[1], "rb") as f:
    head = f.read(24)
print("%dx%d" % struct.unpack(">II", head[16:24]) if len(head) == 24 and head[:8] == b"\x89PNG\r\n\x1a\n" else "not-png")
PY
)"
  [[ "$DIMS" == "1200x630" ]] || die "og.png must be a 1200x630 PNG (got $DIMS)"
fi
[[ "$NO_OG" -eq 0 ]] || rm -f "$STAGE/og.png"
OG_PATH=""; [[ -f "$STAGE/og.png" && "$NO_OG" -eq 0 ]] && OG_PATH="/og.png"

# ---------------------------------------------------------------- 6. head metadata
if [[ "$HAS_INDEX" -eq 1 ]]; then
  META_ARGS=(--html "$STAGE/index.html" --url "$SITE_URL" --title "$TITLE" --description "$DESCRIPTION" --privacy "$PRIVACY" --og-image "$OG_PATH" --json-ld "$JSON_LD")
  [[ -n "$OG_DESCRIPTION" ]] && META_ARGS+=(--og-description "$OG_DESCRIPTION")
  [[ -n "$KEYWORDS" ]] && META_ARGS+=(--keywords "$KEYWORDS")
  [[ -n "$SITE_NAME" ]] && META_ARGS+=(--site-name "$SITE_NAME")
  [[ -n "$AUTHOR" ]] && META_ARGS+=(--author "$AUTHOR")
  [[ -n "$THEME_COLOR" ]] && META_ARGS+=(--theme-color "$THEME_COLOR")
  [[ -n "$OG_ALT" ]] && META_ARGS+=(--og-image-alt "$OG_ALT")
  [[ -n "$APP_CATEGORY" ]] && META_ARGS+=(--app-category "$APP_CATEGORY")
  META_RESULT="$(python3 "$SCRIPT_DIR/inject-meta.py" "${META_ARGS[@]}")" || die "metadata injection failed"
  printf '%s' "$META_RESULT" | jq -r '.warnings[]? | "ship: warning: " + .' >&2
else
  note "no index.html at the Site root; skipping head metadata and OG (raw-file Site)"
fi

# ---------------------------------------------------------------- 7. tags
if [[ -z "$TAGS" && -n "$KEYWORDS" ]]; then
  TAGS="$(jq -cn --arg k "$KEYWORDS" '[$k | split(",")[] | ascii_downcase | gsub("^\\s+|\\s+$";"") | gsub("[^a-z0-9]+";"-") | gsub("^-|-$";"") | select(length>0) | .[0:32]] | unique | .[0:8]')"
fi
if [[ -n "$TAGS" ]]; then
  printf '%s' "$TAGS" | jq -e 'type=="array" and length<=200 and all(.[]; type=="string")' >/dev/null 2>&1 \
    || die "--tags must be a JSON array of at most 200 strings"
  TAGS="$(printf '%s' "$TAGS" | jq -c '
    map(gsub("^[[:space:]]+|[[:space:]]+$"; "") | ascii_downcase)
    | map(select(length > 0 and length <= 32))
    | reduce .[] as $tag ([]; if index($tag) then . else . + [$tag] end)
    | .[0:50]')"
fi

# ---------------------------------------------------------------- out dir
if [[ -z "$OUT_DIR" ]]; then
  if [[ -d /mnt/user-data/outputs ]]; then OUT_DIR="/mnt/user-data/outputs/$SLUG"; else OUT_DIR="./.cresaone/ship/$SLUG"; fi
fi
deliver() {
  mkdir -p "$OUT_DIR"
  [[ -f "$STAGE/index.html" ]] && cp "$STAGE/index.html" "$OUT_DIR/index.html"
  [[ -f "$STAGE/og.png" && "$NO_OG" -eq 0 ]] && cp "$STAGE/og.png" "$OUT_DIR/og.png"
  printf '%s\n' "$1" > "$OUT_DIR/ship-report.json"
}

ACTION="resolve-on-publish"
if [[ "$DRY_RUN" -eq 1 ]]; then
  REPORT="$(jq -n --arg slug "$SLUG" --arg url "$SITE_URL" --arg action "$ACTION" --arg og "$OG_SOURCE" --arg privacy "$PRIVACY" --arg access "${ACCESS:-unchanged}" --argjson tags "${TAGS:-[]}" \
    '{dryRun:true, slug:$slug, url:$url, action:$action, og:$og, privacy:$privacy, access:$access, tags:$tags}')"
  deliver "$REPORT"
  echo "$REPORT"
  note "dry-run complete; staged files copied to $OUT_DIR. Nothing was published."
  exit 0
fi

# ---------------------------------------------------------------- 8. resolve owner and slug
if [[ -n "${CRESAONE_API_KEY:-}" ]]; then
  CRESAONE_API_KEY="$(printf '%s' "$CRESAONE_API_KEY" | normalize_key)"
else
  for candidate in "./cresaone_credentials.txt" "/mnt/project/cresaone_credentials.txt" "$HOME/.cresaone/credentials"; do
    if [[ -s "$candidate" ]]; then
      CRESAONE_API_KEY="$(grep -v '^[[:space:]]*#' "$candidate" | grep -m1 . | normalize_key)"
      break
    fi
  done
fi
[[ -n "${CRESAONE_API_KEY:-}" ]] || die "no API key; ship.sh requires account-owner authorization"
export CRESAONE_API_KEY
(umask 077; printf 'authorization: Bearer %s\ncontent-type: application/json\n' "$CRESAONE_API_KEY" > "$WORK/headers")
api GET "/api/v1/profile/sites"
LOOKUP_SLUG="$SLUG"
if [[ -n "$RENAME_FROM" && "$RENAME_FROM" != "$SLUG" ]]; then LOOKUP_SLUG="$RENAME_FROM"; fi
api GET "/api/v1/publish/$LOOKUP_SLUG" "" 404
ACTION="create"
CURRENT_MODE="anyone_with_link"
if [[ "$API_STATUS" == 200 ]]; then
  ACTION="update"
  api GET "/api/v1/publish/$LOOKUP_SLUG/access"
  CURRENT_MODE="$(printf '%s' "$API_BODY" | jq -r '.access.mode // empty')"
  case "$CURRENT_MODE" in anyone_with_link|password|restricted) ;; *) die "unknown Site access mode" ;; esac
elif [[ "$LOOKUP_SLUG" != "$SLUG" ]]; then
  die "--rename-from Site was not found"
fi
FINAL_MODE="${ACCESS:-$CURRENT_MODE}"
[[ "$LIST_ON_PROFILE" != yes || "$FINAL_MODE" == anyone_with_link ]] || die "protected Sites cannot be listed on a public profile"
if [[ "$LOOKUP_SLUG" != "$SLUG" || "$ACTION" == create ]]; then
  bash "$SCRIPT_DIR/publish.sh" --check-slug "$SLUG" >/dev/null || die "slug '$SLUG' is unavailable"
fi

# Reserve a pending Site without uploading or finalizing any content.
RESERVED=0
if [[ "$ACTION" == create && "$FINAL_MODE" != anyone_with_link ]]; then
  api POST "/api/v1/publish" "$(jq -cn --arg slug "$SLUG" '{slug:$slug,files:[{path:"index.html",size:0,contentType:"text/html"}]}')"
  [[ "$(printf '%s' "$API_BODY" | jq -r '.slug')" == "$SLUG" ]] || die "pending Site reservation returned a different slug"
  RESERVED=1
fi

# Apply access before upload (and before renaming an existing Site).
if [[ -n "$ACCESS" ]]; then
  # Public creates already default to anyone_with_link; they do not exist yet.
  if [[ "$ACTION" == update || "$RESERVED" == 1 ]]; then
    case "$ACCESS" in
      anyone_with_link) api PATCH "/api/v1/publish/$LOOKUP_SLUG/access" '{"mode":"anyone_with_link"}' ;;
      password)
        # Password travels on stdin to jq, then via a mode-600 request file to curl.
        BODY="$(printf '%s' "$PASSWORD" | jq -Rs '{password:.}')"
        api PATCH "/api/v1/publish/$LOOKUP_SLUG/metadata" "$BODY"
        ;;
      restricted)
        BODY="$(jq -cn --arg e "$ALLOW_EMAILS" --arg d "$ALLOW_DOMAINS" \
          '{mode:"restricted",allowedEmails:($e|split(",")|map(gsub("^\\s+|\\s+$";"")|select(length>0))),allowedDomains:($d|split(",")|map(gsub("^\\s+|\\s+$";"")|select(length>0)))}')"
        api PATCH "/api/v1/publish/$LOOKUP_SLUG/access" "$BODY"
        ;;
    esac
    api GET "/api/v1/publish/$LOOKUP_SLUG/access"
    [[ "$(printf '%s' "$API_BODY" | jq -r '.access.mode')" == "$FINAL_MODE" ]] || die "access policy did not persist; content was not uploaded"
  fi
fi
if [[ "$LOOKUP_SLUG" != "$SLUG" ]]; then
  bash "$SCRIPT_DIR/publish.sh" --slug "$LOOKUP_SLUG" --rename-to "$SLUG" >&2 || die "rename failed"
fi

# Remove profile listing before replacing existing content when requested.
if [[ -z "$LIST_ON_PROFILE" && "$PRIVACY" == private ]]; then LIST_ON_PROFILE="no"; fi
if [[ "$LIST_ON_PROFILE" == no ]]; then
  api DELETE "/api/v1/profile/sites/$SLUG" "" 404
fi

# The metadata endpoint replaces viewer fields; omitting ogImagePath clears it.
if [[ "$NO_OG" -eq 1 && ( "$ACTION" == update || "$RESERVED" == 1 ) ]]; then
  api PATCH "/api/v1/publish/$SLUG/metadata" "$(jq -cn --arg t "$TITLE" --arg d "$DESCRIPTION" '{viewer:{title:$t,description:$d}}')"
fi

# ---------------------------------------------------------------- 9. publish
PUB_ARGS=("$STAGE" --slug "$SLUG" --title "$TITLE" --description "$DESCRIPTION" --client "$CLIENT")
[[ "$ACTION" == create && "$RESERVED" == 0 ]] && PUB_ARGS+=(--create)
[[ -n "$OG_PATH" ]] && PUB_ARGS+=(--og-image-path "$OG_PATH")
[[ -n "$TAGS" ]] && PUB_ARGS+=(--tags "$TAGS")
[[ "$SPA" -eq 1 ]] && PUB_ARGS+=(--spa)
if [[ "$FINAL_MODE" == anyone_with_link ]]; then PUB_ARGS+=(--verify); else PUB_ARGS+=(--no-verify); fi
bash "$SCRIPT_DIR/publish.sh" "${PUB_ARGS[@]}" >&2 || die "publish failed; inspect the owned Site before retrying"

# ---------------------------------------------------------------- 10. verify access and listing
api GET "/api/v1/publish/$SLUG/access"
[[ "$(printf '%s' "$API_BODY" | jq -r '.access.mode')" == "$FINAL_MODE" ]] || die "Site access changed during publish"
if [[ "$LIST_ON_PROFILE" == yes ]]; then
  api POST "/api/v1/profile/sites" "$(jq -cn --arg s "$SLUG" '{slug:$s}')"
fi
api GET "/api/v1/profile/sites"
LISTED="$(printf '%s' "$API_BODY" | jq -er --arg s "$SLUG" '[.sites[] | select(.slug==$s)] | if length>0 then "true" else "false" end')"
FAILS=()
[[ "$LIST_ON_PROFILE" != no || "$LISTED" == false ]] || FAILS+=("Site remains listed on profile")
[[ "$LIST_ON_PROFILE" != yes || "$LISTED" == true ]] || FAILS+=("Site was not listed on profile")

# ---------------------------------------------------------------- 11. live checks
api GET "/api/v1/publish/$SLUG"
SITE_JSON="$API_BODY"
[[ "$(printf '%s' "$SITE_JSON" | jq -r '.viewer.title // ""')" == "$TITLE" ]] || FAILS+=("Site title not stored")
[[ "$(printf '%s' "$SITE_JSON" | jq -r '.viewer.description // ""')" == "$DESCRIPTION" ]] || FAILS+=("Site description not stored")
[[ "$(printf '%s' "$SITE_JSON" | jq -r '.status')" == published ]] || FAILS+=("Site status is not published")
if [[ "$NO_OG" -eq 1 ]]; then
  [[ "$(printf '%s' "$SITE_JSON" | jq -r '.viewer.ogImagePath // empty')" == "" ]] || FAILS+=("Old Site ogImagePath was not cleared")
fi
if [[ -n "$OG_PATH" ]]; then
  [[ "$(printf '%s' "$SITE_JSON" | jq -r '.viewer.ogImagePath // ""')" == "$OG_PATH" ]] || FAILS+=("Site ogImagePath not stored")
  printf '%s' "$SITE_JSON" | jq -e '[.manifest[]? | select(.path=="og.png" and .contentType=="image/png")] | length==1' >/dev/null || FAILS+=("og.png missing from manifest or wrong content type")
fi
if [[ -n "$TAGS" ]]; then
  EXPECTED_TAGS="$(printf '%s' "$TAGS" | jq -c 'sort | unique')"
  ACTUAL_TAGS="$(printf '%s' "$SITE_JSON" | jq -c '.tags | sort | unique')"
  [[ "$EXPECTED_TAGS" == "$ACTUAL_TAGS" ]] || FAILS+=("Site tags not stored")
fi
if [[ "$FINAL_MODE" == anyone_with_link && "$HAS_INDEX" -eq 1 ]]; then
  LIVE="$(curl -fsS --connect-timeout 10 --max-time 60 "${SITE_URL}?cresaverify=$(date +%s)" || true)"
  grep -Fq "cresa-one:meta:start" <<<"$LIVE" || FAILS+=("managed metadata block not found in live HTML")
  grep -Fq "<title>" <<<"$LIVE" || FAILS+=("live HTML has no <title>")
  if [[ -n "$OG_PATH" ]]; then
    grep -Fq "property=\"og:image\" content=\"${SITE_URL%/}/og.png\"" <<<"$LIVE" || FAILS+=("og:image tag missing or pointing elsewhere")
    OG_HEAD="$(curl -sS --connect-timeout 10 --max-time 60 -o /dev/null -w '%{http_code} %{content_type}' "${SITE_URL}og.png?cresaverify=$(date +%s)")"
    [[ "$OG_HEAD" == 200\ image/png* ]] || FAILS+=("live og.png returned '$OG_HEAD'")
  fi
fi

# ---------------------------------------------------------------- 12. report + deliverables
FAIL_JSON="$(printf '%s\n' "${FAILS[@]:-}" | jq -R . | jq -cs 'map(select(length>0))')"
REPORT="$(jq -n --arg slug "$SLUG" --arg url "$SITE_URL" --arg action "$ACTION" --arg og "$OG_SOURCE" --arg privacy "$PRIVACY" \
  --arg access "$FINAL_MODE" --argjson listed "$LISTED" --argjson site "$SITE_JSON" \
  --arg title "$TITLE" --arg description "$DESCRIPTION" --argjson failures "$FAIL_JSON" --arg out "$OUT_DIR" \
  '{ok:($failures|length==0),slug:$slug,url:$url,action:$action,title:$title,description:$description,tags:$site.tags,og:$og,privacy:$privacy,access:$access,listedOnProfile:$listed,expiresAt:$site.expiresAt,persistence:(if ($site|has("expiresAt")|not) then "unknown" elif $site.expiresAt==null then "permanent" else "expires_at" end),deliverables:$out,failures:$failures}')"
deliver "$REPORT"
echo "$REPORT"
{
  echo "ship_result.url=$SITE_URL"
  echo "ship_result.action=$ACTION"
  echo "ship_result.access=$FINAL_MODE"
  echo "ship_result.privacy=$PRIVACY"
  echo "ship_result.listed_on_profile=$LISTED"
  echo "ship_result.og=$OG_SOURCE"
  echo "ship_result.deliverables=$OUT_DIR"
  echo "ship_result.persistence=$(printf '%s' "$REPORT" | jq -r .persistence)"
  echo "ship_result.expires_at=$(printf '%s' "$REPORT" | jq -r '.expiresAt // empty')"
} >&2
if [[ "${#FAILS[@]}" -gt 0 ]]; then
  printf 'ship: FAILED check: %s\n' "${FAILS[@]}" >&2
  exit 2
fi
note "shipped. Every check passed."
