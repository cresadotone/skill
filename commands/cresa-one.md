---
description: Check cresa.one skill version, auto-update if needed, then show quick usage.
argument-hint: "[status|help]"
allowed-tools: ["Bash"]
---

# cresa.one Command

Run this preflight first, before responding to the user. It checks the installed cresa.one skill against live metadata and automatically updates through the hosted installer when a newer version is available.

```bash
set -euo pipefail

SKILL_FILE="${HOME}/.claude/skills/cresa-one/SKILL.md"
VERSION_URL="https://cresa.one/api/skill/version"
INSTALL_URL="https://cresa.one/install.sh"

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

installed="$(extract_local_version "$SKILL_FILE" 2>/dev/null || true)"
[[ -n "$installed" ]] || installed="not installed"

remote_json="$(curl -fsSL "$VERSION_URL" 2>/dev/null || true)"
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
  curl -fsSL "$INSTALL_URL" | bash
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

After preflight:

- If `$ARGUMENTS` is empty, `status`, or `help`, summarize installed version and these helpers:
  - Publish: `~/.claude/skills/cresa-one/scripts/publish.sh`
  - Drive: `~/.claude/skills/cresa-one/scripts/drive.sh`
  - Docs: `https://cresa.one/docs`
- If `$ARGUMENTS` asks to publish, store files, update metadata, manage tags, or use Drive, follow `~/.claude/skills/cresa-one/SKILL.md`.
- Never print API keys, Drive tokens, or `~/.cresaone/credentials`.
