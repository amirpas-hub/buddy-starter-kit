#!/bin/bash
# uninstall.sh — remove BUDDY (backs up first). Leaves pi + MCP config untouched.
set -uo pipefail
ts(){ date +%Y%m%d-%H%M%S; }
back(){ [ -e "$1" ] && mv "$1" "$1.removed-$(ts)" && echo "  moved $1 → $1.removed-$(ts)"; }

echo "Uninstalling BUDDY (everything is backed up, not deleted)…"
if [ "$(uname)" = "Darwin" ]; then
  PLIST="$HOME/Library/LaunchAgents/io.buddy.dispatch.plist"
  launchctl unload "$PLIST" 2>/dev/null || true
  back "$PLIST"
fi
back "$HOME/buddy-scheduler"
back "$HOME/.pi/agent/skills/buddy"
back "$HOME/Desktop/buddy-site/buddy-cockpit"
echo "Done. Your AGENTS.md was left in place (edit or remove it yourself if you want)."
