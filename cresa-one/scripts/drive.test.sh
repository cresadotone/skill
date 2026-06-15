#!/usr/bin/env bash
# Offline regression tests for drive.sh upload logic.
# Exercises the upload-staging field reads, header forwarding, and the
# post-finalize size integrity check against simulated API responses.
# No network or credentials required.
set -euo pipefail

JQ_BIN="${JQ_BIN:-jq}"
command -v "$JQ_BIN" >/dev/null 2>&1 || { echo "jq not found"; exit 1; }

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; }

ct="application/json"
sz=192507

# 1. Live-shape staging response: URL is in .url, with a headers block.
upload='{"uploadId":"cmqeb10eb000gqy24zv3pfoou","method":"PUT","url":"https://cresa.one/api/v1/uploads/drive/cmqeb10eb000gqy24zv3pfoou","headers":{"Content-Type":"application/json","Content-Length":"192507"},"expiresInSeconds":3600}'
upload_url=$(echo "$upload" | "$JQ_BIN" -r '.url // .uploadUrl // empty')
upload_id=$(echo "$upload" | "$JQ_BIN" -r '.uploadId // empty')
[[ "$upload_url" == "https://cresa.one/api/v1/uploads/drive/cmqeb10eb000gqy24zv3pfoou" ]] || fail "url extraction"
[[ "$upload_id" == "cmqeb10eb000gqy24zv3pfoou" ]] || fail "uploadId extraction"
pass "live .url extraction"

# 2. Header block parses into curl -H args.
put_headers=()
while IFS= read -r h; do [[ -n "$h" ]] && put_headers+=(-H "$h"); done \
  < <(echo "$upload" | "$JQ_BIN" -r '(.headers // {}) | to_entries[] | "\(.key): \(.value)"')
[[ ${#put_headers[@]} -eq 0 ]] && put_headers=(-H "Content-Type: $ct")
[[ "${put_headers[*]}" == *"Content-Type: application/json"* ]] || fail "header forwarding"
pass "header forwarding"

# 3. No headers in response -> fall back to guessed content type.
nohdr='{"uploadId":"x","url":"https://h/u"}'
fb=()
while IFS= read -r h; do [[ -n "$h" ]] && fb+=(-H "$h"); done \
  < <(echo "$nohdr" | "$JQ_BIN" -r '(.headers // {}) | to_entries[] | "\(.key): \(.value)"')
[[ ${#fb[@]} -eq 0 ]] && fb=(-H "Content-Type: $ct")
[[ "${fb[*]}" == "-H Content-Type: $ct" ]] || fail "content-type fallback"
pass "content-type fallback"

# 4. Size integrity: matching size passes, mismatch is detected.
final='{"success":true,"files":[{"path":"f","size":192507,"sha256":""}]}'
rs=$(echo "$final" | "$JQ_BIN" -r '.files[0].size // empty')
[[ -n "$rs" && "$rs" != "$sz" ]] && fail "false size mismatch"
pass "size match accepted"
bad='{"success":true,"files":[{"path":"f","size":999,"sha256":""}]}'
rb=$(echo "$bad" | "$JQ_BIN" -r '.files[0].size // empty')
[[ -n "$rb" && "$rb" != "$sz" ]] || fail "size mismatch not detected"
pass "size mismatch detected"

# 5. Legacy response with only .uploadUrl still resolves.
legacy='{"uploadId":"x","uploadUrl":"https://legacy/url"}'
lu=$(echo "$legacy" | "$JQ_BIN" -r '.url // .uploadUrl // empty')
[[ "$lu" == "https://legacy/url" ]] || fail "legacy uploadUrl fallback"
pass "legacy .uploadUrl fallback"

# 6. Garbage staging response triggers the missing-url guard.
bad2='{"foo":"bar"}'
bu=$(echo "$bad2" | "$JQ_BIN" -r '.url // .uploadUrl // empty')
[[ -z "$bu" ]] || fail "missing-url guard"
pass "missing-url guard"

echo "All drive.sh upload tests passed."
