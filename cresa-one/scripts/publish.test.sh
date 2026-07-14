#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLISH_SH="$SCRIPT_DIR/publish.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

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
    -H) shift 2 ;;
    -D) headers_file="$2"; shift 2 ;;
    -o) output_file="$2"; shift 2 ;;
    -w) write_format="$2"; shift 2 ;;
    -s|-S|-f|-L|-I|-sS|-fsS|-fsSL) shift ;;
    --*) shift ;;
    *) url="$1"; shift ;;
  esac
done

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
  'https://mock.test/api/v1/publish')
    slug=$(printf '%s' "$data" | jq -r '.slug // "random-name-a1b2"')
    emit_json "{\"slug\":\"$slug\",\"siteUrl\":\"https://$slug.mock.test\",\"status\":\"pending\",\"upload\":{\"versionId\":\"ver_1\",\"finalizeUrl\":\"https://mock.test/finalize\",\"uploads\":[{\"path\":\"index.html\",\"url\":\"https://upload.test/index.html\",\"headers\":{}}],\"skipped\":[]}}"
    ;;
  *'/api/v1/publish/demo')
    if [[ "$method" == GET ]]; then
      emit_json '{"slug":"demo","siteUrl":"https://demo.mock.test","viewer":{"title":"Test Site"},"tags":["cre"],"manifest":[{"path":"index.html","size":18,"contentType":"text/html; charset=utf-8"}]}'
    else
      emit_json '{"slug":"demo","siteUrl":"https://demo.mock.test","status":"published","upload":{"versionId":"ver_1","finalizeUrl":"https://mock.test/finalize","uploads":[{"path":"index.html","url":"https://upload.test/index.html","headers":{}}],"skipped":[]}}'
    fi
    ;;
  'https://mock.test/finalize') emit_json '{"success":true}' ;;
  'https://upload.test/index.html')
    [[ -z "$write_format" ]] || printf '200'
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

run_publish() {
  (
    cd "$TEST_ROOT/site"
    PATH="$TEST_ROOT/bin:$PATH" \
      CRESAONE_API_KEY="test-key" \
      MOCK_SITE_DIR="$TEST_ROOT/site" \
      MOCK_CORRUPT="${MOCK_CORRUPT:-0}" \
      MOCK_CONTENT_TYPE="${MOCK_CONTENT_TYPE:-text/html; charset=utf-8}" \
      MOCK_ACCESS_MODE="${MOCK_ACCESS_MODE:-anyone_with_link}" \
      "$PUBLISH_SH" --base-url https://mock.test --allow-noncresaone-base-url "$@"
  )
}

run_publish_noauth() {
  (
    cd "$TEST_ROOT/site"
    PATH="$TEST_ROOT/bin:$PATH" \
      CRESAONE_API_KEY="" \
      HOME="$TEST_ROOT/fakehome" \
      MOCK_SITE_DIR="$TEST_ROOT/site" \
      "$PUBLISH_SH" --base-url https://mock.test "$@"
  )
}

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

echo "publish.sh tests passed"
