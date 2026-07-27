#!/bin/bash
# preflight.sh — check prerequisites before installing BUDDY. Safe to run anytime.
set -uo pipefail
ok(){ printf "  ✅ %s\n" "$1"; }
warn(){ printf "  ⚠️  %s\n" "$1"; WARN=1; }
bad(){ printf "  ❌ %s\n" "$1"; FAIL=1; }
FAIL=0; WARN=0

echo "BUDDY preflight"
echo "==============="

# OS
if [ "$(uname)" = "Darwin" ]; then ok "macOS detected (launchd always-on supported)"
else warn "Not macOS — the Buddy *skill* works, but the always-on scheduler (launchd) will not. You'll run 'gm' manually."; fi

# Required tools
command -v pi   >/dev/null 2>&1 && ok "pi installed ($(command -v pi))"      || bad "pi not found — install the Pi coding agent first."
command -v quick>/dev/null 2>&1 && ok "quick CLI installed"                   || bad "quick CLI not found — needed to deploy your cockpit."
command -v jq   >/dev/null 2>&1 && ok "jq installed"                          || warn "jq not found — some sweep steps use it. Recommended."
command -v base64>/dev/null 2>&1 && ok "base64 available"                     || bad "base64 not found (needed for cred handling)."

# pi config / MCPs (best-effort hint — we can't fully introspect)
if [ -d "$HOME/.pi/agent" ]; then ok "~/.pi/agent exists"
else warn "~/.pi/agent not found — open pi once so it initialises before installing."; fi

# Tool-gateway token (means MCPs have been used at least once)
if [ -f "$HOME/.cache/tool-gateway-token" ]; then ok "tool-gateway token cached (MCPs have authed)"
else warn "No tool-gateway token yet — open pi normally once so CRM/Vault/BigQuery/GWorkspace authenticate as YOU."; fi

echo
if [ "$FAIL" = "1" ]; then echo "❌ Missing hard requirements above. Fix those, then run ./install.sh"; exit 1
elif [ "$WARN" = "1" ]; then echo "⚠️  Ready with warnings. You can run ./install.sh — read the warnings first."; exit 0
else echo "✅ All good. Run ./install.sh"; fi
