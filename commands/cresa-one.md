---
description: Check cresa.one skill version, auto-update if needed, then show quick usage.
argument-hint: "[status|help]"
allowed-tools: ["Bash"]
---

# cresa.one Command

Run this preflight first, before responding to the user. It checks the installed cresa.one skill against live metadata and automatically updates through the hosted installer when a newer version is available. It picks the installer for the platform: `install.ps1` through PowerShell on Windows (Git Bash, MSYS2, or Cygwin), `install.sh` everywhere else.

```bash
set -euo pipefail

SKILL_FILE="${HOME}/.claude/skills/cresa-one/SKILL.md"
VERSION_URL="https://cresa.one/api/skill/version"
INSTALL_URL="https://cresa.one/install.sh"
WINDOWS_INSTALL_URL="https://cresa.one/install.ps1"

extract_local_version() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  sed -n 's/^\*\*Skill version: \([^*][^*]*\)\*\*$/\1/p' "$file" | head -n 1
}

version_gt() {
  awk -v a="$1" -v b="$2" '
    BEGIN {
      split(a, av, "."); split(b, bv, ".");
      for (i = 1; i <= 3; i++) {
        ai = av[i] + 0; bi = bv[i] + 0;
        if (ai > bi) exit 0;
        if (ai < bi) exit 1;
      }
      exit 1;
    }
  '
}

run_installer() {
  case "$(uname -s 2>/dev/null || true)" in
    MINGW*|MSYS*|CYGWIN*)
      powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm '${WINDOWS_INSTALL_URL}' | iex"
      ;;
    *)
      curl -fsSL "$INSTALL_URL" | bash
      ;;
  esac
}

installed="$(extract_local_version "$SKILL_FILE" 2>/dev/null || true)"
[[ -n "$installed" ]] || installed="not installed"

remote_json="$(curl -fsSL --max-time 3 "$VERSION_URL" 2>/dev/null || true)"
latest="$(printf '%s' "$remote_json" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"

echo "cresa.one skill"
echo "current: ${installed}"
if [[ -n "$latest" ]]; then
  echo "latest: ${latest}"
else
  echo "latest: unavailable"
fi

if [[ -n "$latest" ]] && { [[ "$installed" == "not installed" ]] || version_gt "$latest" "$installed"; }; then
  echo ""
  echo "newer version found; running hosted installer..."
  run_installer
  installed="$(extract_local_version "$SKILL_FILE" 2>/dev/null || true)"
  [[ -n "$installed" ]] || installed="unknown"
  echo ""
  echo "cresa.one skill ready: ${installed}"
elif [[ -z "$latest" ]]; then
  echo "update check skipped: could not read ${VERSION_URL}"
else
  echo "already current"
fi
```

If the shell tool is PowerShell rather than Bash, run this equivalent preflight instead:

```powershell
$skillFile = Join-Path $env:USERPROFILE ".claude\skills\cresa-one\SKILL.md"
$installed = "not installed"
if (Test-Path -LiteralPath $skillFile) {
  $match = Select-String -LiteralPath $skillFile -Pattern '^\*\*Skill version: ([^*]+)\*\*$' | Select-Object -First 1
  if ($match) { $installed = $match.Matches[0].Groups[1].Value }
}
try { $latest = (Invoke-RestMethod -Uri "https://cresa.one/api/skill/version" -TimeoutSec 3).version } catch { $latest = $null }
"cresa.one skill"; "current: $installed"
if ($latest) { "latest: $latest" } else { "latest: unavailable" }
if ($latest -and ($installed -eq "not installed" -or [version]$latest -gt [version]$installed)) {
  ""; "newer version found; running hosted installer..."
  irm https://cresa.one/install.ps1 | iex
} elseif (-not $latest) { "update check skipped: could not read https://cresa.one/api/skill/version" } else { "already current" }
```

After preflight:

- If installer output includes `present files to the user`, present files to the user using the current environment's file presentation/attachment mechanism. The listed `.skill` and `.zip` archives are for quick installation in Claude Desktop, Codex, or other skill-compatible apps.
- If `$ARGUMENTS` is empty, `status`, or `help`, summarize installed version and these helpers (on Windows the same files live under `%USERPROFILE%\.claude\skills\cresa-one\` and run in Git Bash):
  - Ship: `~/.claude/skills/cresa-one/scripts/ship.sh` (Python 3.10+)
  - Publish: `~/.claude/skills/cresa-one/scripts/publish.sh`
  - Site health: `~/.claude/skills/cresa-one/scripts/site-health.sh`
  - Drive: `~/.claude/skills/cresa-one/scripts/drive.sh`
  - Docs: `https://cresa.one/docs`
- If `$ARGUMENTS` asks to publish, check a Site, store files, update metadata, manage tags, or use Drive, follow `~/.claude/skills/cresa-one/SKILL.md`.
- Never print API keys, Drive tokens, or `~/.cresaone/credentials`.
