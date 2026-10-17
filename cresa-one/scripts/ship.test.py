#!/usr/bin/env python3
"""Offline regression tests for the ship wrapper and metadata/OG helpers."""
import base64
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent
MOCK = r"""
import json, os, sys
from pathlib import Path
from urllib.parse import urlsplit
root = Path(os.environ["SHIP_TEST_ROOT"])
state = json.loads((root / "state.json").read_text())
args = sys.argv[1:]
event = {}
def persist():
    (root / "state.json").write_text(json.dumps(state))
    with (root / "events.jsonl").open("a") as out:
        out.write(json.dumps(event) + "\n")
def flag(name, default=""):
    return args[args.index(name) + 1] if name in args else default
if Path(sys.argv[0]).name == "publish.py":
    if "--check-slug" in args:
        event = {"kind":"check-slug"}
        persist()
        print('{"available":true}')
        sys.exit(0)
    if "--rename-to" in args:
        state["slug"] = flag("--rename-to")
        event = {"kind":"rename"}
        persist()
        sys.exit(0)
    target = Path(args[0])
    files = [p.relative_to(target).as_posix() for p in target.rglob("*") if p.is_file()]
    event = {"kind":"upload","mode":state["mode"],"files":files,"args":args[1:]}
    state["exists"] = True
    state["published"] = True
    state["html"] = (target / "index.html").read_text()
    state["title"] = flag("--title")
    state["description"] = flag("--description")
    state["tags"] = json.loads(flag("--tags", json.dumps(state.get("tags", []))))
    if state.get("ignore_tags"): state["tags"] = ["stale"]
    persist()
    sys.exit(0)

method = flag("--request", flag("-X", "GET"))
url = next(a for a in args if a.startswith("https://"))
path = urlsplit(url).path
output = flag("--output", flag("-o"))
write = flag("--write-out", flag("-w"))
raw = flag("--data-binary", "{}")
body = json.loads(Path(raw[1:]).read_text()) if raw.startswith("@") else json.loads(raw)
assert not any("csk_" in a for a in args), "key leaked through curl argv"
event = {"kind":"api","method":method,"path":path}
status, result = 200, {}
if state.get("fail_path") == path and state.get("fail_method", method) == method:
    status, result = state.get("fail_status", 503), {"error":"fixture_failure"}
elif urlsplit(url).hostname != "cresa.one":
    result = state.get("html", "")
elif path == "/api/v1/profile/sites":
    if method == "POST": state["listed"] = True
    result = {"sites":[{"slug":state.get("slug","demo-site")}] if state.get("listed") else []}
elif path.startswith("/api/v1/profile/sites/"):
    if state.get("listed"):
        if not state.get("ignore_unlist"): state["listed"] = False
    else:
        status = 404
elif path == "/api/v1/publish":
    state["exists"] = True
    state["reserved"] = True
    result = {"slug":body["slug"],"status":"pending","isLive":False}
elif path.endswith("/access"):
    if method == "PATCH" and not state.get("ignore_access"):
        state["mode"] = body["mode"]
    result = {"access":{"mode":state["mode"]}}
elif path.endswith("/metadata"):
    if "password" in body and not state.get("ignore_access"): state["mode"] = "password"
    if "viewer" in body: state.pop("viewer_og",None)
    result = {"passwordProtected":True}
elif path.startswith("/api/v1/publish/"):
    if not state["exists"]:
        status, result = 404, {"error":"not_found"}
    else:
        result = {
            "slug":state.get("slug","demo-site"),"status":"published" if state.get("published") else "pending",
            "siteUrl":"https://demo-site.cresa.one/","expiresAt":state.get("expiry"),
            "viewer":{"title":state.get("title"),"description":state.get("description"),"ogImagePath":state.get("viewer_og")},
            "tags":state.get("tags",[]),"manifest":[]
        }
else:
    raise AssertionError("unhandled request: " + method + " " + path)
persist()
text = result if isinstance(result, str) else json.dumps(result)
if output: Path(output).write_text(text)
else: print(text)
if write: print(write.replace("%{http_code}", str(status)).replace("%{content_type}", "text/html"), end="")
"""


class ShipTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bundle = self.root / "bundle"
        shutil.copytree(SCRIPTS.parent, self.bundle, ignore=shutil.ignore_patterns("__pycache__"))
        self.site = self.root / "site"
        self.site.mkdir()
        self.source = '<!doctype html><html><head><meta charset="utf-8"><title>Old</title></head><body>Secret body</body></html>'
        (self.site / "index.html").write_text(self.source)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for path in [self.bin / "curl", self.bundle / "scripts/publish.py"]:
            path.write_text("#!" + sys.executable + "\n" + MOCK)
            path.chmod(0o755)
        (self.bundle / "scripts/publish.sh").write_text('#!/bin/bash\nexec python3 "$(dirname "$0")/publish.py" "$@"\n')
        self.state = {"exists":False,"mode":"anyone_with_link","listed":False}
        self.env = {**os.environ, "PATH":str(self.bin)+os.pathsep+os.environ["PATH"],
                    "SHIP_TEST_ROOT":str(self.root), "CRESAONE_API_KEY":"csk_offline_fixture",
                    "CRESAONE_SITE_PASSWORD":"fixture-password"}
        self.env.pop("CRESAONE_DRIVE_TOKEN", None)

    def run_ship(self, *extra, expected=0):
        (self.root / "state.json").write_text(json.dumps(self.state))
        result = subprocess.run(["bash", str(self.bundle / "scripts/ship.sh"), str(self.site),
            "--slug","demo-site","--title","Demo","--description","A safe description for the offline regression fixture.",
            "--no-og","--out",str(self.root / "output"),*extra],
            cwd=self.root, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stderr)
        self.assertNotIn("csk_offline_fixture", result.stdout + result.stderr)
        self.state = json.loads((self.root / "state.json").read_text())
        self.events = [json.loads(line) for line in (self.root / "events.jsonl").read_text().splitlines()] if (self.root / "events.jsonl").exists() else []
        return result

    def test_dry_run_is_offline_even_with_key_and_rename(self):
        result = self.run_ship("--dry-run","--rename-from","old-site")
        self.assertTrue(json.loads(result.stdout)["dryRun"])
        self.assertEqual(self.events, [])
        self.assertEqual((self.site / "index.html").read_text(), self.source)

    def test_new_password_site_gated_before_upload(self):
        self.run_ship("--access","password")
        upload = next(e for e in self.events if e["kind"] == "upload")
        self.assertEqual(upload["mode"], "password")
        self.assertNotIn("--create",upload["args"])
        self.assertIn("--no-verify",upload["args"])
        self.assertTrue(self.state["reserved"])

    def test_new_restricted_site_gated_before_upload(self):
        self.run_ship("--access","restricted","--allow-emails","viewer@example.com")
        self.assertEqual(next(e for e in self.events if e["kind"]=="upload")["mode"], "restricted")

    def test_failed_access_prevents_upload(self):
        self.state.update(fail_path="/api/v1/publish/demo-site/access",fail_method="PATCH")
        self.run_ship("--access","restricted","--allow-emails","viewer@example.com",expected=1)
        self.assertFalse(any(e["kind"]=="upload" for e in self.events))

    def test_unpersisted_access_prevents_upload(self):
        self.state["ignore_access"] = True
        self.run_ship("--access","password",expected=1)
        self.assertFalse(any(e["kind"]=="upload" for e in self.events))

    def test_failed_owner_lookup_does_not_create(self):
        self.state.update(fail_path="/api/v1/publish/demo-site",fail_method="GET")
        self.run_ship(expected=1)
        self.assertFalse(any(e["kind"] in {"upload","check-slug"} for e in self.events))

    def test_profile_delete_failure_prevents_upload(self):
        self.state.update(exists=True,listed=True,fail_path="/api/v1/profile/sites/demo-site",fail_method="DELETE")
        self.run_ship(expected=1)
        self.assertFalse(any(e["kind"]=="upload" for e in self.events))

    def test_false_unlist_is_reported_as_failure(self):
        self.state.update(exists=True,listed=True,ignore_unlist=True)
        result = self.run_ship(expected=2)
        self.assertIn("Site remains listed on profile", json.loads(result.stdout)["failures"])

    def test_explicit_empty_tags_clear_old_tags(self):
        self.state.update(exists=True,tags=["old"])
        result = self.run_ship("--tags","[]")
        self.assertEqual(json.loads(result.stdout)["tags"], [])

    def test_explicit_tags_follow_api_normalization(self):
        report = json.loads(self.run_ship("--tags",'[" Client Work ","R&D","client work",""]').stdout)
        self.assertEqual(report["tags"], ["client work","r&d"])

    def test_no_og_clears_existing_viewer_image(self):
        self.state.update(exists=True,viewer_og="/og.png")
        (self.site/"og.png").write_bytes(b"not used with --no-og")
        self.run_ship()
        self.assertNotIn("viewer_og",self.state)
        self.assertNotIn("og.png",next(e for e in self.events if e["kind"]=="upload")["files"])

    def test_tag_mismatch_is_failure(self):
        self.state.update(exists=True,ignore_tags=True)
        result = self.run_ship("--tags",'["new"]',expected=2)
        self.assertIn("Site tags not stored",json.loads(result.stdout)["failures"])

    def test_expiry_is_preserved_in_report(self):
        self.state.update(exists=True,expiry="2030-01-01T00:00:00.000Z")
        report = json.loads(self.run_ship().stdout)
        self.assertEqual(report["persistence"], "expires_at")
        self.assertEqual(report["expiresAt"], self.state["expiry"])

    def test_source_credentials_never_enter_upload(self):
        (self.site/"cresaone_credentials.txt").write_text("csk_do_not_upload")
        (self.site/".env").write_text("fixture")
        (self.site/".git").mkdir()
        (self.site/".git/config").write_text("fixture")
        self.run_ship()
        files = next(e for e in self.events if e["kind"]=="upload")["files"]
        self.assertEqual(files, ["index.html"])

    def test_invalid_tags_fail_before_network(self):
        self.run_ship("--tags",'[1]',expected=1)
        self.assertEqual(self.events, [])

    def test_symlinks_fail_before_network(self):
        (self.site/"linked.html").symlink_to(self.site/"index.html")
        self.run_ship(expected=1)
        self.assertEqual(self.events, [])

    def test_base64_credentials_are_decoded(self):
        self.env["CRESAONE_API_KEY"] = base64.b64encode(b"csk_offline_fixture").decode()
        self.run_ship()

    def test_existing_protected_site_keeps_access(self):
        self.state.update(exists=True,mode="restricted")
        self.run_ship()
        upload = next(e for e in self.events if e["kind"]=="upload")
        self.assertEqual(upload["mode"],"restricted")
        self.assertIn("--no-verify",upload["args"])

    def test_help_succeeds(self):
        result = subprocess.run(["bash",str(self.bundle/"scripts/ship.sh"),"--help"],capture_output=True,text=True)
        self.assertEqual(result.returncode,0)


class MetadataTests(unittest.TestCase):
    def inject(self, source, *extra):
        with tempfile.TemporaryDirectory() as tmp:
            page = Path(tmp)/"index.html"
            page.write_text(source)
            result = subprocess.run([sys.executable,str(SCRIPTS/"inject-meta.py"),"--html",str(page),
                "--url","https://demo-site.cresa.one/","--title","Demo & Test",
                "--description",'Safe </script><script>alert("x")</script> description',
                *extra],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            return page.read_text()

    def test_repeated_injection_is_identical(self):
        source = '<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Old</title></head><body>Body</body></html>'
        first = self.inject(source,"--theme-color","#111111")
        self.assertEqual(self.inject(first,"--theme-color","#111111"), first)

    def test_unquoted_and_spaced_attributes_are_replaced(self):
        page = self.inject('<head><meta name = description content="old"><meta property=og:title content="old"><link rel = canonical href="/old"></head>')
        self.assertNotIn('content="old"',page)
        self.assertNotIn('href="/old"',page)
        self.assertEqual(page.count('property="og:title"'),1)

    def test_script_and_comments_are_preserved(self):
        script = """<script>const demo = '<meta name="description" content="example"><title>sample</title>';</script>"""
        comment = '<!-- <meta name="description" content="example"> -->'
        page = self.inject("<head>"+script+comment+"</head>")
        self.assertIn(script,page)
        self.assertIn(comment,page)

    def test_existing_appearance_tags_stay(self):
        source = '<head><link rel=icon href="/favicon.ico"><meta name = theme-color content="#abcdef"></head>'
        page = self.inject(source,"--theme-color","#111111")
        self.assertIn('href="/favicon.ico"',page)
        self.assertIn('content="#abcdef"',page)
        self.assertNotIn('data:image/svg+xml',page)

    def test_private_to_public_removes_private_directives(self):
        page = self.inject(self.inject("<head></head>"),"--privacy","public")
        self.assertNotIn("no-referrer",page)
        self.assertNotIn("noindex",page)

    def test_json_ld_does_not_break_out(self):
        page = self.inject("<head></head>")
        self.assertNotIn('<script>alert("x")</script>',page)
        self.assertIn("Safe &lt;/script&gt;",page)


class CardTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("og_card", SCRIPTS/"og-card.py")
        self.card = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.card)

    def test_css_colors(self):
        self.assertEqual(self.card.parse_tokens("ink=oklch(0.95 0.01 110)")["ink"], "oklch(0.95 0.01 110)")

    def test_rejects_style_injection(self):
        with self.assertRaises(SystemExit): self.card.parse_tokens("ink=red}</style>")
        with self.assertRaises(SystemExit): self.card.parse_tokens("ink=url(https://example.com)")

    def test_substitutions_are_not_recursive(self):
        from argparse import Namespace
        args=Namespace(tokens="",art=None,font_file=None,name="{{HEADLINE}}",headline="<b>Example</b>",headline_muted="",footer="example.com")
        page=self.card.fill_template(args)
        self.assertIn('{{HEADLINE}}</div>',page)
        self.assertIn('&lt;b&gt;Example&lt;/b&gt;',page)


if __name__ == "__main__":
    unittest.main()
