#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLISH_SH="$SCRIPT_DIR/publish.sh"
MOCK_CAT_BIN=$(command -v cat)
export MOCK_CAT_BIN
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

TEST_SUITE="${1:-all}"
[[ "$TEST_SUITE" == all || "$TEST_SUITE" == expiry ]] || fail "usage: publish.test.sh [all|expiry]"

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || fail "expected '$expected' in $file"
}

assert_status() {
  local expected="$1"
  shift
  set +e
  "$@" >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"
  local actual=$?
  set -e
  [[ "$actual" -eq "$expected" ]] || {
    cat "$TEST_ROOT/stderr" >&2
    fail "expected exit $expected, got $actual: $*"
  }
}

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/site/.cresaone"
printf '<h1>verified</h1>\n' > "$TEST_ROOT/site/index.html"
printf '{"publishes":{"demo":{"siteUrl":"https://demo.mock.test","claimToken":"secret"}}}\n' \
  > "$TEST_ROOT/site/.cresaone/state.json"

cat > "$TEST_ROOT/bin/curl" <<'MOCK_CURL'
#!/usr/bin/env bash
set -euo pipefail

method=GET
data=""
headers_file=""
output_file=""
write_format=""
url=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -X) method="$2"; shift 2 ;;
    -d|--data|--data-raw) data="$2"; shift 2 ;;
    --data-binary) shift 2 ;;
    --connect-timeout|--max-time) shift 2 ;;
    -H) shift 2 ;;
    -D) headers_file="$2"; shift 2 ;;
    -o) output_file="$2"; shift 2 ;;
    -w) write_format="$2"; shift 2 ;;
    -s|-S|-f|-L|-I|-sS|-fsS|-fsSL) shift ;;
    --*) shift ;;
    *) url="$1"; shift ;;
  esac
done

if [[ -n "${MOCK_RETRY_DIR:-}" ]]; then
  printf '%s %s\n' "$method" "$url" >> "$MOCK_RETRY_DIR/requests"
fi

emit_json() {
  printf '%s\n' "$1"
}

case "$url" in
  *'/slug-available?'*)
    if [[ "$url" == *taken* ]]; then
      emit_json '{"slug":"taken","available":false,"reason":"That name is already taken."}'
    else
      emit_json '{"slug":"free-name","available":true}'
    fi
    ;;
  *'/slug-suggest') emit_json '{"slug":"bright-anchor-a1b2"}' ;;
  *'/rename')
    next=$(printf '%s' "$data" | jq -r '.slug' | tr '[:upper:]' '[:lower:]')
    emit_json "{\"slug\":\"$next\",\"siteUrl\":\"https://$next.mock.test\"}"
    ;;
  *'/access') emit_json "{\"access\":{\"mode\":\"${MOCK_ACCESS_MODE:-anyone_with_link}\"}}" ;;
  *'/tags') emit_json '{"slug":"demo","tags":["cre"]}' ;;
  *'/metadata')
    if [[ -n "${MOCK_EXPECT_TTL:-}" ]]; then
      printf '%s' "$data" | jq -e --argjson ttl "$MOCK_EXPECT_TTL" 'has("ttlSeconds") and .ttlSeconds == $ttl' >/dev/null || exit 71
    fi
    emit_json '{"success":true}'
    ;;
  'https://mock.test/api/v1/publish')
    slug=$(printf '%s' "$data" | jq -r '.slug // "random-name-a1b2"')
    if [[ -n "${MOCK_EXPECT_TTL:-}" ]]; then
      printf '%s' "$data" | jq -e --argjson ttl "$MOCK_EXPECT_TTL" 'has("ttlSeconds") and .ttlSeconds == $ttl' >/dev/null || exit 71
    fi
    emit_json "{\"slug\":\"$slug\",\"siteUrl\":\"https://$slug.mock.test\",\"status\":\"pending\",\"expiresAt\":\"${MOCK_EXPIRES_AT:-}\",\"upload\":{\"versionId\":\"ver_1\",\"finalizeUrl\":\"https://mock.test/finalize\",\"uploads\":[{\"path\":\"index.html\",\"url\":\"https://upload.test/index.html\",\"headers\":{}}],\"skipped\":[]}}"
    ;;
  *'/api/v1/publish/demo')
    if [[ "$method" == GET ]]; then
      emit_json '{"slug":"demo","siteUrl":"https://demo.mock.test","viewer":{"title":"Test Site"},"tags":["cre"],"manifest":[{"path":"index.html","size":18,"contentType":"text/html; charset=utf-8"}]}' |
        jq --arg expiry "${MOCK_EXPIRES_AT:-}" 'if $expiry == "__missing__" then . else .expiresAt = (if $expiry == "" then null else $expiry end) end'
    else
      emit_json '{"slug":"demo","siteUrl":"https://demo.mock.test","status":"published","upload":{"versionId":"ver_1","finalizeUrl":"https://mock.test/finalize","uploads":[{"path":"index.html","url":"https://upload.test/index.html","headers":{}}],"skipped":[]}}'
    fi
    ;;
  'https://mock.test/finalize') emit_json '{"success":true}' ;;
  'https://upload.test/index.html')
    outcome=200
    if [[ -n "$headers_file" ]]; then
      printf 'HTTP/1.1 200 OK\r\n' > "$headers_file"
      [[ -z "${MOCK_RETRY_AFTER:-}" ]] || printf 'Retry-After: %s\r\n' "$MOCK_RETRY_AFTER" >> "$headers_file"
    fi
    if [[ -n "${MOCK_RETRY_DIR:-}" ]]; then
      count=0
      [[ ! -f "$MOCK_RETRY_DIR/count" ]] || count=$(cat "$MOCK_RETRY_DIR/count")
      count=$((count + 1))
      printf '%s' "$count" > "$MOCK_RETRY_DIR/count"
      IFS=, read -r -a outcomes <<< "${MOCK_UPLOAD_SEQUENCE:-200}"
      index=$((count - 1))
      [[ "$index" -lt "${#outcomes[@]}" ]] || index=$((${#outcomes[@]} - 1))
      outcome="${outcomes[$index]}"
    fi
    case "$outcome" in
      exit:*) printf '000'; exit "${outcome#exit:}" ;;
      *) [[ -z "$write_format" ]] || printf '%s' "$outcome" ;;
    esac
    ;;
  'https://demo.mock.test/index.html?'*)
    printf 'HTTP/1.1 200 OK\r\nContent-Type: %s\r\nCache-Control: public, max-age=60\r\n\r\n' \
      "${MOCK_CONTENT_TYPE:-text/html; charset=utf-8}" > "$headers_file"
    if [[ "${MOCK_CORRUPT:-0}" == 1 ]]; then
      printf 'corrupt\n' > "$output_file"
    else
      cp "$MOCK_SITE_DIR/index.html" "$output_file"
    fi
    [[ -z "$write_format" ]] || printf '200'
    ;;
  *)
    echo "mock curl: unexpected $method $url" >&2
    exit 70
    ;;
esac
MOCK_CURL
chmod +x "$TEST_ROOT/bin/curl"

cat > "$TEST_ROOT/bin/sleep" <<'MOCK_SLEEP'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" >> "$MOCK_RETRY_DIR/delays"
MOCK_SLEEP
chmod +x "$TEST_ROOT/bin/sleep"

# Isolate credential-file reads without changing HOME or touching real credentials.
cat > "$TEST_ROOT/bin/cat" <<'MOCK_CAT'
#!/usr/bin/env bash
if [[ "$#" -eq 1 && "$1" == */.cresaone/credentials ]]; then
  exit 0
fi
exec "$MOCK_CAT_BIN" "$@"
MOCK_CAT
chmod +x "$TEST_ROOT/bin/cat"

run_publish() {
  (
    cd "$TEST_ROOT/site"
    PATH="$TEST_ROOT/bin:$PATH" \
      CRESAONE_API_KEY="test-key" \
      MOCK_SITE_DIR="$TEST_ROOT/site" \
      MOCK_CORRUPT="${MOCK_CORRUPT:-0}" \
      MOCK_CONTENT_TYPE="${MOCK_CONTENT_TYPE:-text/html; charset=utf-8}" \
      MOCK_ACCESS_MODE="${MOCK_ACCESS_MODE:-anyone_with_link}" \
      MOCK_RETRY_DIR="${MOCK_RETRY_DIR:-}" \
      MOCK_UPLOAD_SEQUENCE="${MOCK_UPLOAD_SEQUENCE:-200}" \
      MOCK_RETRY_AFTER="${MOCK_RETRY_AFTER:-}" \
      MOCK_EXPIRES_AT="${MOCK_EXPIRES_AT:-}" \
      MOCK_EXPECT_TTL="${MOCK_EXPECT_TTL:-}" \
      "$PUBLISH_SH" --base-url https://mock.test --allow-noncresaone-base-url "$@"
  )
}

run_publish_noauth() {
  (
    cd "$TEST_ROOT/site"
    PATH="$TEST_ROOT/bin:$PATH" \
      CRESAONE_API_KEY="" \
      MOCK_SITE_DIR="$TEST_ROOT/site" \
      MOCK_EXPIRES_AT="${MOCK_EXPIRES_AT:-}" \
      MOCK_EXPECT_TTL="${MOCK_EXPECT_TTL:-}" \
      "$PUBLISH_SH" --base-url https://mock.test "$@"
  )
}

# CI runs everything; the expiry group keeps local red/green cycles focused.
if [[ "$TEST_SUITE" == all ]]; then
  assert_status 1 run_publish --slug
  assert_contains "$TEST_ROOT/stderr" "--slug requires a value"

  assert_status 0 run_publish --check-slug free-name
  assert_contains "$TEST_ROOT/stdout" '"available": true'

  assert_status 1 run_publish --check-slug taken
  assert_contains "$TEST_ROOT/stdout" '"available": false'

  assert_status 0 run_publish --suggest-slug
  assert_contains "$TEST_ROOT/stdout" "bright-anchor-a1b2"

  assert_status 1 run_publish --slug demo --rename-to renamed --title ignored
  assert_contains "$TEST_ROOT/stderr" "cannot be combined"

  assert_status 0 run_publish --slug demo --rename-to renamed
  jq -e '.publishes.renamed.siteUrl == "https://renamed.mock.test" and (.publishes.demo == null)' \
    "$TEST_ROOT/site/.cresaone/state.json" >/dev/null || fail "rename did not move state"
  assert_contains "$TEST_ROOT/stderr" "old host now returns 404"

  assert_status 0 run_publish --slug renamed --rename-to RENAMED
  jq -e '.publishes.renamed.siteUrl == "https://renamed.mock.test"' \
    "$TEST_ROOT/site/.cresaone/state.json" >/dev/null || fail "same-slug rename removed state"
  assert_contains "$TEST_ROOT/stderr" "slug unchanged"

  assert_status 0 run_publish "$TEST_ROOT/site" --slug demo
  assert_contains "$TEST_ROOT/stderr" "live file verification passed"
  jq -e '.publishes.demo.siteUrl == "https://demo.mock.test"' \
    "$TEST_ROOT/site/.cresaone/state.json" >/dev/null || fail "publish state was not saved"

  assert_status 0 run_publish "$TEST_ROOT/site" --slug demo --title "Test Site" \
    --tags '[" CRE ","cre","","this-tag-is-longer-than-thirty-two-characters"]'
  assert_contains "$TEST_ROOT/stderr" "metadata verification passed"

  MOCK_ACCESS_MODE=password assert_status 1 run_publish "$TEST_ROOT/site" --slug demo
  assert_contains "$TEST_ROOT/stderr" "live byte verification is unavailable for password Sites"
  jq -e '.publishes.demo.siteUrl == "https://demo.mock.test"' \
    "$TEST_ROOT/site/.cresaone/state.json" >/dev/null || fail "protected verification failure lost publish state"

  MOCK_CORRUPT=1 assert_status 1 run_publish "$TEST_ROOT/site" --slug demo
  assert_contains "$TEST_ROOT/stderr" "local hash="
  jq -e '.publishes.demo.siteUrl == "https://demo.mock.test"' \
    "$TEST_ROOT/site/.cresaone/state.json" >/dev/null || fail "verification failure lost publish state"

  MOCK_CONTENT_TYPE='application/octet-stream' assert_status 1 run_publish "$TEST_ROOT/site" --slug demo
  assert_contains "$TEST_ROOT/stderr" "content-type expected=text/html; charset=utf-8 actual=application/octet-stream"

  MOCK_CORRUPT=1 assert_status 0 run_publish "$TEST_ROOT/site" --slug demo --no-verify
  assert_contains "$TEST_ROOT/stderr" "verification skipped"

  assert_status 1 run_publish --create --rename-to foo
  assert_contains "$TEST_ROOT/stderr" "--create cannot be combined"

  assert_status 1 run_publish --create --from-drive drv_1
  assert_contains "$TEST_ROOT/stderr" "implicit for --from-drive"

  assert_status 1 run_publish "$TEST_ROOT/site" --create --slug fresh-name --claim-token nope
  assert_contains "$TEST_ROOT/stderr" "--create cannot be combined with --claim-token"

  assert_status 1 run_publish_noauth "$TEST_ROOT/site" --create --slug fresh-name --no-verify
  assert_contains "$TEST_ROOT/stderr" "requires authentication"

  assert_status 0 run_publish "$TEST_ROOT/site" --create --slug fresh-name --no-verify
  assert_contains "$TEST_ROOT/stdout" "https://fresh-name.mock.test"
  assert_contains "$TEST_ROOT/stderr" "publish_result.action=create"
  jq -e '.publishes["fresh-name"].siteUrl == "https://fresh-name.mock.test"' \
    "$TEST_ROOT/site/.cresaone/state.json" >/dev/null || fail "create-with-slug state was not saved"

  assert_status 0 run_publish "$TEST_ROOT/site" --create --no-verify
  assert_contains "$TEST_ROOT/stdout" "https://random-name-a1b2.mock.test"
  assert_contains "$TEST_ROOT/stderr" "publish_result.action=create"

  [[ $(find "$TEST_ROOT/site" -type f | wc -l | tr -d ' ') -ge 2 ]] || fail "test fixture missing state file"
  assert_status 0 run_publish "$TEST_ROOT/site" --slug demo --no-verify
  assert_contains "$TEST_ROOT/stderr" "creating publish (1 files)"
fi

MOCK_EXPIRES_AT="2030-01-01T01:00:00.000Z" MOCK_EXPECT_TTL=3600 \
  assert_status 0 run_publish_noauth "$TEST_ROOT/site" --ttl 3600 --no-verify
assert_contains "$TEST_ROOT/stderr" "publish_result.auth_mode=anonymous"
assert_contains "$TEST_ROOT/stderr" "publish_result.persistence=expires_at"
assert_contains "$TEST_ROOT/stderr" "publish_result.expires_at=2030-01-01T01:00:00.000Z"
assert_contains "$TEST_ROOT/stderr" "anonymous publish (expires at 2030-01-01T01:00:00.000Z)"

MOCK_EXPIRES_AT="2030-01-01T02:00:00.000Z" MOCK_EXPECT_TTL=7200 \
  assert_status 0 run_publish "$TEST_ROOT/site" --ttl 7200 --no-verify
assert_contains "$TEST_ROOT/stderr" "publish_result.auth_mode=authenticated"
assert_contains "$TEST_ROOT/stderr" "publish_result.persistence=expires_at"
assert_contains "$TEST_ROOT/stderr" "publish_result.expires_at=2030-01-01T02:00:00.000Z"
assert_contains "$TEST_ROOT/stderr" "authenticated publish (expires at 2030-01-01T02:00:00.000Z, saved to your account)"

assert_status 0 run_publish_noauth "$TEST_ROOT/site" --ttl 3600 --no-verify
assert_contains "$TEST_ROOT/stderr" "publish_result.persistence=unknown"
assert_contains "$TEST_ROOT/stderr" "anonymous publish (expiry not returned; confirm Site status)"

# Preserve ordinary default-expiry and permanent authenticated results.
MOCK_EXPIRES_AT="2030-01-02T00:00:00.000Z" \
  assert_status 0 run_publish_noauth "$TEST_ROOT/site" --no-verify
assert_contains "$TEST_ROOT/stderr" "publish_result.persistence=expires_at"
assert_contains "$TEST_ROOT/stderr" "anonymous publish (expires at 2030-01-02T00:00:00.000Z)"

assert_status 0 run_publish "$TEST_ROOT/site" --no-verify
assert_contains "$TEST_ROOT/stderr" "publish_result.persistence=permanent"
assert_contains "$TEST_ROOT/stderr" "authenticated publish (permanent, saved to your account)"

MOCK_EXPIRES_AT="2030-02-03T04:05:06.000Z" MOCK_EXPECT_TTL=3600 \
  assert_status 0 run_publish --metadata-only --slug demo --ttl 3600 --no-verify
assert_contains "$TEST_ROOT/stderr" "publish_result.action=metadata"
assert_contains "$TEST_ROOT/stderr" "publish_result.persistence=expires_at"
assert_contains "$TEST_ROOT/stderr" "publish_result.expires_at=2030-02-03T04:05:06.000Z"

MOCK_EXPIRES_AT="__missing__" MOCK_EXPECT_TTL=3600 \
  assert_status 0 run_publish --metadata-only --slug demo --ttl 3600 --no-verify
assert_contains "$TEST_ROOT/stderr" "publish_result.persistence=unknown"

# A confirmed null expiry is different from a missing field.
MOCK_EXPECT_TTL=null assert_status 0 run_publish --metadata-only --slug demo --ttl null
assert_contains "$TEST_ROOT/stderr" "publish_result.persistence=permanent"
grep -Fxq 'publish_result.expires_at=' "$TEST_ROOT/stderr" || fail "cleared TTL did not report an empty expiry"

retry_case() {
  local sequence="$1" expected_status="$2" expected_attempts="$3"
  local retry_dir
  retry_dir=$(mktemp -d "$TEST_ROOT/retry.XXXXXX")
  MOCK_RETRY_DIR="$retry_dir" MOCK_UPLOAD_SEQUENCE="$sequence" \
    assert_status "$expected_status" run_publish "$TEST_ROOT/site" --slug demo --no-verify
  [[ $(cat "$retry_dir/count") == "$expected_attempts" ]] || fail "wrong retry count for $sequence"
  [[ $(grep -c 'PUT https://mock.test/api/v1/publish/demo' "$retry_dir/requests") == 1 ]] || fail "publish was retried"
  if [[ "$expected_status" -eq 0 ]]; then
    [[ $(grep -c 'POST https://mock.test/finalize' "$retry_dir/requests") == 1 ]] || fail "expected one finalize"
  else
    ! grep -q '/finalize' "$retry_dir/requests" || fail "failed upload was finalized"
    assert_contains "$TEST_ROOT/stderr" "remains pending (not finalized)"
  fi
  case "$expected_attempts" in
    1) [[ ! -e "$retry_dir/delays" ]] || fail "non-retryable error slept" ;;
    2) [[ $(cat "$retry_dir/delays") == "${MOCK_RETRY_AFTER:-1}" ]] || fail "wrong first retry delay" ;;
    4) [[ $(tr '\n' ',' < "$retry_dir/delays") == '1,2,4,' ]] || fail "unbounded retry delay" ;;
  esac
}

if [[ "$TEST_SUITE" == all ]]; then
  for transient in 408 429 500 502 503 504 exit:6 exit:7 exit:18 exit:28 exit:52 exit:55 exit:56; do
    retry_case "$transient,200" 0 2
  done
  retry_case '503' 1 4
  retry_case 'exit:28' 1 4
  MOCK_RETRY_AFTER=2 retry_case '429,200' 0 2
  MOCK_RETRY_AFTER=120 retry_case '429' 1 1
  MOCK_RETRY_AFTER='Wed, 21 Oct 2030 07:28:00 GMT' retry_case '503' 1 1
  for permanent in 400 401 403 404 409 422 exit:26 exit:60; do
    retry_case "$permanent" 1 1
  done
fi

echo "publish.sh tests passed"
