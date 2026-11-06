#!/usr/bin/env python3
"""Offline tests for site-health.sh with mocked curl, openssl, and Windows tools."""
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parent / "site-health.sh"
KEY = "csk_test_health_fixture"

CURL = r"""
import json, os, sys
from pathlib import Path
from urllib.parse import urlsplit
root = Path(os.environ["HEALTH_TEST_ROOT"])
state = json.loads((root / "state.json").read_text())
args = sys.argv[1:]
with (root / "curl.log").open("a") as log:
    log.write(json.dumps(args) + "\n")
def flag(name, default=""):
    return args[args.index(name) + 1] if name in args else default
url = next(a for a in args if a.startswith("http"))
parts = urlsplit(url)
code, body, ctype = 200, "", "text/html"
if parts.hostname == "cresa.one":
    header = flag("-H")
    auth = Path(header[1:]).read_text() if header.startswith("@") else header
    if f"Bearer {state['key']}" not in auth:
        code, body = 401, json.dumps({"error": "unauthorized", "message": "bad key"})
    elif parts.path.endswith("/access"):
        body = json.dumps({"access": state["access"]})
    elif parts.path.endswith("/analytics"):
        body = json.dumps(state["analytics"])
    else:
        code = state.get("site_code", 200)
        body = json.dumps(state["site"])
elif parts.path.endswith("/og.png"):
    code, body, ctype = state.get("og_code", 200), "PNG", "image/png"
else:
    code, body = state.get("public_code", 200), state.get("public_body", "<h1>live</h1>")
out = flag("-o")
if out:
    Path(out).write_text(body)
fmt = flag("-w")
sys.stdout.write(fmt.replace("%{http_code}", str(code)).replace("%{time_total}", "0.042")
                 .replace("%{content_type}", ctype))
"""

OPENSSL = r"""#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    s_client) echo "-----BEGIN CERTIFICATE-----"; exit 0 ;;
    -enddate) echo "notAfter=Jan  1 00:00:00 2030 GMT"; exit 0 ;;
    -checkend) exit "${HEALTH_CERT_EXPIRING:-0}" ;;
  esac
done
exit 1
"""


def iso(delta):
    return (datetime.now(timezone.utc) + delta).strftime("%Y-%m-%dT%H:%M:%S.000Z")


class SiteHealthTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="cresa-health-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        curl = self.bin / "curl"
        curl.write_text("#!" + sys.executable + "\n" + CURL)
        (self.bin / "openssl").write_text(OPENSSL)
        for tool in ["curl", "openssl"]:
            (self.bin / tool).chmod(0o755)
        self.state = {
            "key": KEY,
            "site": {
                "slug": "market-rent", "siteUrl": "https://market-rent.cresa.one/",
                "status": "published", "expiresAt": None,
                "currentVersionId": "sv_current", "pendingVersionId": None,
                "manifest": [{"path": "index.html", "size": 120, "contentType": "text/html"},
                             {"path": "og.png", "size": 900, "contentType": "image/png"}],
                "viewer": {"title": "Market Rent", "ogImagePath": "/og.png"},
            },
            "access": {"mode": "anyone_with_link", "allowedEmails": [], "allowedDomains": [],
                       "publicPreviewEnabled": False},
            "analytics": {"totals": {"rangeViews": 12, "rangeVisitors": 5, "allTimeViews": 40},
                          "lastEventAt": "2026-11-01T00:00:00.000Z", "top404Paths": []},
        }
        self.env = {**os.environ, "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
                    "HOME": str(self.root / "home"), "HEALTH_TEST_ROOT": str(self.root),
                    "CRESAONE_API_KEY": KEY}

    def run_health(self, *args, expected=0):
        (self.root / "state.json").write_text(json.dumps(self.state))
        result = subprocess.run(["bash", str(SCRIPT), "market-rent", "--json", *args], env=self.env,
                                cwd=self.root, text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stderr + result.stdout)
        report = json.loads(result.stdout)
        return report, {c["check"]: c for c in report["checks"]}

    def test_healthy_public_site_reports_every_check(self):
        report, checks = self.run_health()
        self.assertEqual(report["status"], "ok")
        for name in ["http", "tls", "status", "version", "expiry", "metadata", "access", "gate", "analytics", "og-image"]:
            self.assertEqual(checks[name]["status"], "ok", (name, checks[name]))
        self.assertIn("2030", checks["tls"]["detail"])
        self.assertIn("permanent", checks["expiry"]["detail"])
        log = (self.root / "curl.log").read_text()
        self.assertNotIn(KEY, log, "API key leaked through curl argv")

    def test_protected_policy_without_gate_fails(self):
        self.state["access"].update(mode="password")
        report, checks = self.run_health(expected=2)
        self.assertEqual(report["status"], "fail")
        self.assertEqual(checks["gate"]["status"], "fail")
        self.assertNotIn("og-image", checks)

    def test_gate_is_detected_for_restricted_sites(self):
        self.state["access"].update(mode="restricted", allowedEmails=["a@example.com"])
        self.state["public_body"] = '<form method="POST" action="/__cresa/request"><input name="email">'
        report, checks = self.run_health()
        self.assertEqual(report["gate"], "restricted")
        self.assertEqual(checks["gate"]["status"], "ok")

    def test_pending_upload_expiry_and_404s_warn(self):
        self.state["site"].update(pendingVersionId="sv_pending", expiresAt=iso(timedelta(hours=2)))
        self.state["analytics"]["top404Paths"] = [{"path": "/missing.css", "referrer": "", "hits": 7}]
        self.env["HEALTH_CERT_EXPIRING"] = "1"
        report, checks = self.run_health()
        self.assertEqual(report["status"], "warn")
        self.assertEqual(checks["version"]["status"], "warn")
        self.assertIn("sv_pending", checks["version"]["detail"])
        self.assertEqual(checks["expiry"]["status"], "warn")
        self.assertEqual(checks["tls"]["status"], "warn")
        self.assertIn("/missing.css (7)", checks["analytics"]["detail"])

    def test_never_finalized_and_expired_sites_fail(self):
        self.state["site"].update(status="pending", currentVersionId=None, expiresAt=iso(timedelta(hours=-1)))
        self.state["public_code"] = 404
        report, checks = self.run_health(expected=2)
        for name in ["http", "status", "version", "expiry"]:
            self.assertEqual(checks[name]["status"], "fail", name)

    def test_without_key_only_public_checks_run(self):
        self.env.pop("CRESAONE_API_KEY")
        report, checks = self.run_health()
        self.assertEqual(checks["owner"]["status"], "skip")
        self.assertNotIn("status", checks)
        self.assertNotIn("cresa.one/api", (self.root / "curl.log").read_text())

    def test_rejected_key_fails_without_echoing_it(self):
        self.state["key"] = "csk_other"
        result_report, checks = self.run_health(expected=2)
        self.assertEqual(checks["owner"]["status"], "fail")
        self.assertNotIn(KEY, json.dumps(result_report))

    def test_windows_shell_uses_native_paths_and_lf_jq(self):
        real_jq = shutil.which("jq")
        self.assertIsNotNone(real_jq)
        for name, script in {
            "uname": "#!/bin/sh\necho MINGW64_NT-10.0-22631\n",
            "cygpath": '#!/bin/sh\necho "$@" >> "$HEALTH_TEST_ROOT/cygpath.log"\nprintf "%s\\n" "$2"\n',
            "jq": '#!/bin/sh\nprintf "%s\\n" "$1" >> "$HEALTH_TEST_ROOT/jq.log"\nexec ' + real_jq + ' "$@"\n',
        }.items():
            path = self.bin / name
            path.write_text(script)
            path.chmod(0o755)
        report, checks = self.run_health()
        self.assertEqual(report["status"], "ok")
        self.assertIn("-m", (self.root / "cygpath.log").read_text())
        first_args = (self.root / "jq.log").read_text().splitlines()
        self.assertGreater(len(first_args), 5)
        self.assertEqual(set(first_args), {"-b"}, "every native jq call must disable CRLF output")


if __name__ == "__main__":
    unittest.main()
