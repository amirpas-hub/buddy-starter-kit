#!/bin/bash
# notify.sh — fire a native macOS banner so Amir actually SEES the T-30 prep alert.
# Usage: notify.sh "Title" "Message"
# Called by call-sweep.sh after a prep brief is written. Best-effort; never fails the sweep.
TITLE="${1:-BUDDY}"
MSG="${2:-Prep ready}"
/usr/bin/osascript -e "display notification \"${MSG//\"/\\\"}\" with title \"${TITLE//\"/\\\"}\" sound name \"Ping\"" >/dev/null 2>&1 || true
